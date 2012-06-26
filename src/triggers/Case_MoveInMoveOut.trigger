trigger Case_MoveInMoveOut on Case (before update, after insert, after update) {
	/*
	Purpose:	For MIMO-type Cases only
					BEFORE
						If Rejected__c is TRUE, change Status to 'Rejected'
					AFTER
						If Reason is Move In
							Creates or updates Tasks as necessary 	
						If Reason is Notice To Vacate
							Creates or updates Tasks as necessary 	
							

	Created By: 	Jeremy Nottingham (SAP) - 2/16/2011
	
	Last Modified By: 	Jeremy Nottingham (SAP) - 9/23/2011
	
	Current Version: 	v1.0
	
	Revision Log:		v1.0 - (JN 08/10) Created trigger and header.
						v1.1 - (JN 9/27/11) Added logic to create 2 additional tasks for new move out, these had been in other places in the code.
							

	*/


    list<Case> cases = Trigger.new;
    list<Task> taskstoinsert = new list<Task>();
    list<Task> taskstoupdate = new list<Task>();
    set<id> caseidstomakeopen = new set<Id>();
    map<String, Id> rtmap = MoveInMoveOut.casertmap();      
    MoveInMoveOut move = new MoveInMoveOut();
    
    //Update Case has to be before db commit
    if (Trigger.isBefore) {
        for (Case c : cases) {
            if ((c.Rejected__c) 
                && (c.Status != 'Rejected')) {
                c.Status = 'Rejected';
            }
        }
    }
    
    //most of the logic is here.
    if (Trigger.isAfter) {
        map<id, id> cgidcontactidmap = new map<id, id>(); 
        set<id> cgids = new set<Id>(); //Customer Group IDs for cases
        
        for (Case c : cases) {
            cgids.add(c.AccountID);
system.debug('\n\ncgid added ' + c.AccountID);
        }
        
        /* 100721 jkn now getting ContactID from parent Case, saved a query too!
        list<Contact> primarycontacts = [select id, AccountID from Contact 
            where Primary_Contact__c = true and Accountid in :cgids];
        for (Contact c : primarycontacts) {
            cgidcontactidmap.put(c.Accountid, c.id);
        }
        */
//Insert
        if (Trigger.isinsert) {
            
            for (Case c : cases) {
                
                //keep out other Record Types
                if ((c.RecordTypeID != rtmap.get('Move Out Tracking Process')) 
                    && (c.RecordTypeID != rtmap.get('Move In Tracking Process'))) continue;
                
                //New Move In
                if (c.Reason == 'Move In') {
                    if (c.Expected_MoveIn_Date__c != null) {
                        taskstoinsert.add(new Task(
                            WhatID = c.id,
                            WhoID = c.ContactID,
                            OwnerID = c.OwnerID,
                            RecordTypeID = rtmap.get('Move In Confirmation'),
                            AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                            AVB_Type__c = 'Move In Process',
                            Outcome__c = null,
                            Subject = 'Move In Confirmation',
                            Subject_Sub_Category__c = 'Move In Confirmation',
                            ActivityDate = c.Expected_MoveIn_Date__c.addDays(-2)
                            ));
                        taskstoinsert.add(new Task(
                            WhatID = c.id,
                            WhoID = c.ContactID,
                            OwnerID = c.OwnerID,
                            RecordTypeID = rtmap.get('Prepare Apartment'),
                            AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                            AVB_Type__c = 'Move In Process',
                            Outcome__c = null,
                            Subject = 'Apartment Preparation',
                            Subject_Sub_Category__c = 'Apartment Preparation',
                            ActivityDate = c.Expected_MoveIn_Date__c.addDays(-1)
                            ));
                        taskstoinsert.add(new Task(
                            WhatID = c.id,
                            WhoID = c.ContactID,
                            OwnerID = c.OwnerID,
                            RecordTypeID = rtmap.get('Move In Follow Up'),
                            AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                            AVB_Type__c = 'Move In Process',
                            Outcome__c = null,
                            Subject = 'MI Follow Up',
                            Subject_Sub_Category__c = 'MI Follow Up',
                            //cjc QB3082
                            //ActivityDate = c.Expected_MoveIn_Date__c.addDays(2)
                            ActivityDate = c.Expected_MoveIn_Date__c.addDays(5)
                            ));
                    } else { //these will be if there's no move in date
                        taskstoinsert.add(new Task(
                            WhatID = c.id,
                            WhoID = c.ContactID,
                            OwnerID = c.OwnerID,
                            RecordTypeID = rtmap.get('Move In Confirmation'),
                            AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                            AVB_Type__c = 'Move In Process',
                            Outcome__c = null,
                            Subject = 'Move In Confirmation No Move In Date Provided',
                            Subject_Sub_Category__c = 'Move In Confirmation',
                            ActivityDate = system.today()
                            ));
                        taskstoinsert.add(new Task(
                            WhatID = c.id,
                            WhoID = c.ContactID,
                            OwnerID = c.OwnerID,
                            RecordTypeID = rtmap.get('Prepare Apartment'),
                            AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                            AVB_Type__c = 'Move In Process',
                            Outcome__c = null,
                            Subject = 'Apartment Preparation No Move In Date Provided',
                            Subject_Sub_Category__c = 'Apartment Preparation',
                            ActivityDate = system.today()
                            ));
                        taskstoinsert.add(new Task(
                            WhatID = c.id,
                            WhoID = c.ContactID,
                            OwnerID = c.OwnerID,
                            RecordTypeID = rtmap.get('Move In Follow Up'),
                            AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                            AVB_Type__c = 'Move In Process',
                            Outcome__c = null,
                            Subject = 'MI Follow Up No Move In Date Provided',
                            Subject_Sub_Category__c = 'MI Follow Up',
                            ActivityDate = system.today()
                            ));
                    } //end if move in date not null
                    caseidstomakeopen.add(c.id);
                    continue;
                }
                
                //New Move Out
                if (c.Reason == 'Notice To Vacate') {
                    taskstoinsert.add(new Task(
                        WhatID = c.id,
                        WhoID = c.ContactID,
                        OwnerID = c.OwnerID,
                        RecordTypeID = rtmap.get('Notice to Vacate Follow Up'),
                        AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                        AVB_Type__c = 'Move Out Process',
                        Outcome__c = null,
                        Subject = 'Notice to Vacate Follow-up',
                        Subject_Sub_Category__c = 'Notice to Vacate Follow-up',
                        ActivityDate = c.NTV_Date__c.addDays(2)
                        
                        ));
                    taskstoinsert.add(new Task(
                        WhatID = c.id,
                        WhoID = c.ContactID,
                        OwnerID = c.OwnerID,
                        RecordTypeID = rtmap.get('Pre Inspection Follow Up'),
                        AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                        AVB_Type__c = 'Move Out Process',
                        Outcome__c = null,
                        Subject = 'Final Move Out Inspection/Estimates Inquiry',
                        Subject_Sub_Category__c = 'Final Move Out Inspection/Estimates Inquiry',
                        ActivityDate = c.Preliminary_Inspection_Date__c.date().addDays(2)
                        ));
                    
                    //092711 added move out packet and move out follow up tasks
                    taskstoinsert.add(new Task(
                        WhatID = c.Id,
                        WhoID = c.ContactID,
                        OwnerID = c.OwnerID,
                        RecordTypeID = rtmap.get('Send Move Out Packet'),
                        AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                        AVB_Type__c = 'Move Out Process',
                        Outcome__c = null,
                        Subject = 'Move Out Packet/Process Inquiry',
                        Subject_Sub_Category__c = 'Move Out Packet/Process Inquiry',
                        ActivityDate = c.NTV_Date__c.addDays(4)
                        ));
                	taskstoinsert.add(new Task(
		                WhatID = c.id,
		                WhoID = c.ContactID,
		                OwnerID = c.OwnerID,
		                RecordTypeID = rtmap.get('Move Out Follow Up'),
		                AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
		                AVB_Type__c = 'Move Out Process',
		                Outcome__c = null,
		                Subject = 'Move Out Complete Follow Up',
		                Subject_Sub_Category__c = 'Move Out Complete Follow Up',
		                ActivityDate = c.Move_Out_Date__c.addDays(3)
		                ));
          
                    caseidstomakeopen.add(c.id);
                }
            }
        }
        
//Update
        if (Trigger.isupdate) {
            //These cases are open already, so get all the tasks for them in a map
            set<id> caseids = new set<id>();
            map<id, list<Task>> casetaskmap = new map<id, list<Task>>();
            for (Case c : cases)
            {
            	if ((c.RecordTypeID == rtmap.get('Move Out Tracking Process')) 
                    || (c.RecordTypeID == rtmap.get('Move In Tracking Process')))
                {
            		caseids.add(c.id);
                }
            }

            list<Task> alltasks = [select id, WhatID, ActivityDate, AVB_Type__c, Subject_Sub_Category__c, Status, IsClosed 
                from Task where IsClosed != true and WhatID in :caseids];
 
            for (Task t : alltasks) {
                if (casetaskmap.get(t.WhatID) == null) {
                    casetaskmap.put(t.WhatID, new list<Task> { t });
                } else {
                    casetaskmap.get(t.WhatID).add(t);
                }
            }
            
            //go through Cases
            for (Case c : cases) {
                     
                Case newcase = Trigger.newmap.get(c.id);
                Case oldcase = Trigger.oldmap.get(c.id);
                list<Task> tasks = casetaskmap.get(c.id);
        
                //if it's just a status change, skip out of loop
                if ((newcase.Status == 'Open') && (oldcase.Status == 'New')) continue;

                if (c.RecordTypeID == rtmap.get('Move Out Tracking Process')) {
                    
                    //Rejected Move Out
                    if ((newcase.Rejected__c) 
                        && (!oldcase.Rejected__c)) 
                    {
                        if (tasks != null) {
                            for (Task t : tasks) {
                                t.Status = 'Rejected';
                                taskstoupdate.add(t);
                            }
                        }
                        continue;
                    }//rejected move out
                    
                    //Resched Move Out
                    if (((newcase.Move_Out_Date__c != oldcase.Move_Out_Date__c)
                        || (newcase.Preliminary_Inspection_Date__c != oldcase.Preliminary_Inspection_Date__c))
                        && (newcase.Preliminary_Inspection_Date__c != null) && (oldcase.Preliminary_Inspection_Date__c != null)
                        && (newcase.Move_Out_Date__c != null) && (oldcase.Move_Out_Date__c != null))
                    {
                        if (tasks != null) {                        
                            for (Task t : tasks) {
                                if (t.AVB_Type__c == 'Move Out Process')
                                {
                                	if (t.Subject_Sub_Category__c == 'Notice to Vacate Follow-up') 
	                                	t.ActivityDate = c.NTV_Date__c.addDays(2);
	                                if (t.Subject_Sub_Category__c == 'Final Move Out Inspection/Estimates Inquiry') 
	                                	t.ActivityDate = c.Preliminary_Inspection_Date__c.Date().addDays(2);
	                                if (t.Subject_Sub_Category__c == 'Move Out Packet/Process Inquiry') 
	                                	t.ActivityDate = c.NTV_Date__c.addDays(4);
	                                if (t.Subject_Sub_Category__c == 'Move Out Complete Follow Up') 
	                                	t.ActivityDate = c.Move_Out_Date__c.addDays(3);
	                            	taskstoupdate.add(t);
                                }
                            }
                        }
                        continue; 
                    }//resched move Out
                    
                    //Cancel Move Out
                    if ((newcase.Move_Out_Date__c != oldcase.Move_Out_Date__c)
                        && (newcase.Move_Out_Date__c == null)) 
                    {
                        if (tasks != null) {
                            for (Task t : tasks) {
                                t.Status = 'Cancelled';
                                t.Outcome__c = 'Cancelled';
                                taskstoupdate.add(t);
                            }
                        }
                        continue;
                    }//cancel move out
                }
                
                if (c.RecordTypeID == rtmap.get('Move In Tracking Process')) {
                
                    //Resched Move In
                    if ((newcase.Expected_MoveIn_Date__c != oldcase.Expected_MoveIn_Date__c)) 
                    {
                        if (tasks != null) {
                            for (Task t : tasks) {
                                if (t.Subject_Sub_Category__c == 'Move In Confirmation') t.ActivityDate = c.Expected_MoveIn_Date__c.addDays(-2);
                                if (t.Subject_Sub_Category__c == 'Apartment Preparation') t.ActivityDate = c.Expected_MoveIn_Date__c.addDays(-1);
                                /* QB3082; cjc
                                if (t.Subject_Sub_Category__c == 'MI Follow Up') t.ActivityDate = c.Expected_MoveIn_Date__c.addDays(2);
                                */
                                if (t.Subject_Sub_Category__c == 'MI Follow Up') t.ActivityDate = c.Expected_MoveIn_Date__c.addDays(5);
                                
                                taskstoupdate.add(t);                           
                            }
                        }
                    
                        continue;
                    }//resched move in
                    
                    //Cancel Move In
                    if ((newcase.Status == 'Closed')
                        && (newcase.Reason == 'Cancelled')
                        && (oldcase.Reason != 'Cancelled')) 
                    {
                        if (tasks != null) {
                            for (Task t : tasks) {
                                t.Status = 'Cancelled';
                                taskstoupdate.add(t);
                            }
                        }
                    }//cancel move in
                }
            }        
        }
        
        insert taskstoinsert;
        update taskstoupdate;
        
        
    } //if Trigger.isAfter
    
}