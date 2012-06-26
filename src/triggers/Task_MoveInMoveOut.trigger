trigger Task_MoveInMoveOut on Task (after update) {
/* Jeremy Nottingham 2010
    Trigger creates tasks to continue Move Out Process when one Task is finished.

*/
    list<Task> tasks = Trigger.new;
    list<Task> taskstoinsert = new list<Task>();
    list<Task> taskstoupdate = new list<Task>();
    set<Id> casestocheckids = new set<Id>(); //if Task is Closed, the Case needs checked for closability
    set<Id> casestocloseids = new set<Id>(); //After checked, the Case needs closed.
    set<id> savedcaseids = new set<id>();  //if Move Out is Saved, the case is in this set
    map<String, Id> rtmap = MoveInMoveOut.casertmap();      
    
    set<Id> caseids = new set<Id>();
    for (Task t : tasks) {
        if ((t.WhatId != null)
        	&& (String.valueof(t.WhatID).substring(0,3) == '500'))
        {
        	caseids.add(t.WhatID);
        }
    }
    list<Case> cases = [select AccountID, RecordtypeId, Status, No_Open_Tasks__c, (select id, WhatID, ActivityDate, AVB_Type__c, Status, Subject_Sub_Category__c, IsClosed from Tasks) from Case where id in :caseids];
    map<id, Case> caseidcasemap = new map<id, Case> (cases);
    map<id, id> caseidcgidmap = new map<id, id>();
    map<id, id> cgidcontactidmap = new map<id, id>();
    map<id, list<Task>> caseidtasklistmap = new map<id, list<Task>>(); 
    set<id> cgids = new set<Id>(); //Customer Group IDs for cases
    
    for (Case c : cases) {
        cgids.add(c.AccountID);
        caseidcgidmap.put(c.id, c.AccountID);
        caseidtasklistmap.put(c.id, c.Tasks);
    }
        
    list<Contact> primarycontacts = [select id, AccountID from Contact 
        where Accountid in :cgids and Primary_Contact__c = true];
    for (Contact c : primarycontacts) {
        cgidcontactidmap.put(c.AccountID, c.id);
    }

    
    for (Task t : tasks) {
        if ((t.AVB_Type__c != 'Move Out Process')
            && (t.AVB_Type__c != 'Move In Process')) continue; //skip non-move Tasks
        
        //Compare for changes
        Task newtask = Trigger.newmap.get(t.id);
        Task oldtask = Trigger.oldmap.get(t.id);
        
        //Move Out Process
        if ((newtask.Subject == oldtask.Subject) //this was added to avoid firing on the Task Subject workflow rule 6/2/11 JN
        	&& (t.AVB_Type__c == 'Move Out Process')) {
            
            //Logic on 'Notice to Vacate Follow-up' Tasks only
            if ((t.Subject_Sub_Category__c == 'Notice to Vacate Follow-up')
                && (newtask.Outcome__c != 'Cancelled')) {
                
                //if newly closed as part of the process
                if ((newtask.IsClosed == true) && (oldtask.IsClosed == false)) {
                    
                    //Saved Resident on follow up (got them to stay)
                    if (newtask.Outcome__c == 'Saved – remove notice from MRI')
                    {
                        //Make new task to remove notice from MRI
                        taskstoinsert.add(new Task(
                            WhatID = t.Whatid,
                            WhoID = cgidcontactidmap.get(caseidcgidmap.get(t.WhatID)),
                            OwnerID = t.OwnerID,
                            RecordTypeID = rtmap.get('Remove NTV'),
                            AVB_Associate_First_Last_Name__c = t.AVB_Associate_First_Last_Name__c,
                            AVB_Type__c = 'Move Out Process',
                            Subject = 'Remove Notice from MRI',
                            Subject_Sub_Category__c = 'Remove Notice from MRI',
                            Outcome__c = null,
                            ActivityDate = system.today().addDays(2)
                            ));
                        
                        //Close Final Inspection Task
                        for (Task tt : caseidtasklistmap.get(t.WhatID)) {
                            if (tt.Subject_Sub_Category__c == 'Final Move Out Inspection/Estimates Inquiry') {
                                
                                if (tt.IsClosed == false) {
                                    tt.Status = 'Complete';
                                    taskstoupdate.add(tt);
                                }
                            }
                        }
                        savedcaseids.add(t.WhatID);
                    }   //remove notice from MRI
                    
                    //Resident not saved on Follow Up; send Move Out Packet
                    if ((newtask.Outcome__c == 'No Response – send move out packet') 
                        || (newtask.Outcome__c == 'Could not Save – send move out packet'))
                    {
                        //Make new task to send Move Out Packet
                        /* 9/27/11JN
                        taskstoinsert.add(new Task(
                            WhatID = t.Whatid,
                            WhoID = cgidcontactidmap.get(caseidcgidmap.get(t.WhatID)),
                            OwnerID = t.OwnerID,
                            RecordTypeID = rtmap.get('Send Move Out Packet'),
                            AVB_Associate_First_Last_Name__c = t.AVB_Associate_First_Last_Name__c,
                            AVB_Type__c = 'Move Out Process',
                            Subject = 'Move Out Packet/Process Inquiry',
                            Subject_Sub_Category__c = 'Move Out Packet/Process Inquiry',
                            ActivityDate = system.today().addDays(2)
                            ));
                        */
                    }//send move out packet     
                        
                }//If just made closed.
            }//end if 'Notice to Vacate Follow-up'
            
            //other Task closing, maybe this Case is ready to close 
            if ((t.Subject_Sub_Category__c != 'Notice to Vacate Follow-up') 
                || (t.Outcome__c == 'Cancelled'))
            { 
                casestocheckids.add(t.WhatID);
            }
            
            if ((newtask.IsClosed == true) && (oldtask.IsClosed == false)) casestocheckids.add(t.WhatID);
        }//end if 'Move Out Process'
        
        //close on closed task
        if ((caseids.contains(newtask.WhatId))
        	&& (newtask.IsClosed == true) 
        	&& (oldtask.IsClosed == false)) {
system.debug('\n\n close on close ');       
            casestocheckids.add(t.WhatID);
        }
        
        
        
    } //for Task t
    
    insert taskstoinsert;
    update taskstoupdate;
    
    //Cause closing of a Case if all the Tasks on that Case are closed now.
    if (casestocheckids.size() > 0) {
        
        for (id cid : casestocheckids) {
            Case thiscase = caseidcasemap.get(cid);
            if (thiscase == null) continue;
            
            //initialize completion check var
            Integer checknum = 1;
            
            //for each kind of case, make sure there is one of each kind of task and that it's closed. If any are missing, we can't close it.
             if (thiscase.RecordTypeID == MoveInMoveOut.casertmap().get('Move Out Tracking Process')) {  
                for (Task t : caseidtasklistmap.get(cid)) {
                    if ((t.Subject_Sub_Category__c == 'Notice to Vacate Follow-up') && (t.IsClosed)) checknum *= 2;
                    if ((t.Subject_Sub_Category__c == 'Final Move Out Inspection/Estimates Inquiry') && (t.IsClosed)) checknum *= 3;
                    if ((t.Subject_Sub_Category__c == 'Move Out Packet/Process Inquiry') && (t.IsClosed)) checknum *= 5;
                    if ((t.Subject_Sub_Category__c == 'Move Out Complete Follow Up') && (t.IsClosed)) checknum *= 7;
                }
                if (checknum == 2*3*5*7) {
                    casestocloseids.add(cid);
                }
            } else {
                if (thiscase.RecordTypeID == MoveInMoveOut.casertmap().get('Move In Tracking Process')) {
                    for (Task t : caseidtasklistmap.get(cid)) {
                        if ((t.Subject_Sub_Category__c == 'Move In Confirmation') && (t.IsClosed)) checknum *= 2;
                        if ((t.Subject_Sub_Category__c == 'Apartment Preparation') && (t.IsClosed)) checknum *= 3;
                        if ((t.Subject_Sub_Category__c == 'MI Follow Up') && (t.IsClosed)) checknum *= 5;
                    }
                    if (checknum == 2*3*5) {
                        casestocloseids.add(cid);
                    }
                }
            }
        }
                                 
        /*
        //Get unique CaseIDs for Cases with open Tasks in our set (Cases to exclude from Closable)
        list<AggregateResult> ars = [select WhatID from Task where IsClosed = false and WhatID in :casestocheckids group by WhatID]; 
        set<id> nonclosablecaseids = new set<id>();
        for (AggregateResult ar : ars) {
            nonclosablecaseids.add(String.valueof(ar.get('WhatID')));
        }
        
        //compare list of open task Cases with list of changed Cases to find the closable ones
        set<id> closablecaseids = new set<id>();
        for (ID i : casestocheckids) {
            if (!nonclosablecaseids.contains(i)) closablecaseids.add(i);
        }
        */
        
    //Close the Cases
        list<Case> casesthatcanclose= new list<Case>();
        
        for (Id cid : casestocloseids) {
            Case thiscase = caseidcasemap.get(cid);
            
            //Check that box on each Case
            thiscase.No_Open_Tasks__c = true;
            
            //Automatically close Cases
            //if ( (thiscase.RecordTypeID == MoveInMoveOut.casertmap().get('Move In Tracking Process'))
            //  || (thiscase.RecordTypeID == MoveInMoveOut.casertmap().get('Move Out Tracking Process')) )
            thiscase.Status = 'Closed';
            
            //add this case to list to close
            casesthatcanclose.add(thiscase); 
        }
        update casesthatcanclose;
    }//end if casestocheckids
     
}