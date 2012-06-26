trigger CGU_MoveInMoveOut on Customer_Group_to_Unit_Relationships__c (before update, after insert, after update) {
/* Jeremy Nottingham 2010 
    This Trigger acts on data generally imported through legacy MRI system.
    Based on what action the CGU insert/update is meant to do, this creates new and updates existing Cases
*/
    /*
    Purpose:    When Customer Group Unit is 
                    Inserted
                        If Move In Date not in past
                            New Move In Case
                    Updated
                        Move In 
                            Reschedule Move In
                            Cancel Move In
                        Move Out
                            New Move Out
                            Reschedule Move Out
                            Cancel Move Out
                        
    
    Created By:     Jeremy Nottingham (Synaptic) 8/10
    
    Last Modified By:   Jeremy Nottingham (Synaptic) 9/30/11
    
    Current Version:    v1.1
    
    Revision Log:       v1.0 - (JN) Created this trigger and header. 
                        v1.1 - (JN 9/30/11) added additional filter for New Move Out: only if Move Out Reason != 'Evict/Skip/Non-renewal'
    */
    list<Customer_Group_to_Unit_Relationships__c> cgus = Trigger.new; //Customer_Group_Units
    MoveInMoveOut move = new MoveInMoveOut();
        
    map<String, ID> casertmap = MoveInMoveOut.casertmap(); //RecordTypeIds for Move In/Move Out
    list<Case> casestoinsert = new list<Case>();
    list<Case> casestoupdate = new list<Case>();
    
    set<id> cgids = new set<id>();
    for (Customer_Group_to_Unit_Relationships__c cgu : cgus) {
        cgids.add(cgu.Customer_Group__c);
    }
    //map<id, Account> cgidtocgmap = new map<id, Account>([select OwnerID, (select id from Contacts where Primary_Contact__c = true limit 1) from Account where id in :cgids]); //to get Customer Group OwnerID
    map<id, Account> cgidtocgmap = new map<id, Account>([select OwnerID, (select id from Contacts order by Primary_Contact__c desc limit 1) from Account where id in :cgids]); //to get Customer Group OwnerID

    
                    
    if (Trigger.isInsert)
    {
        
        for (Customer_Group_to_Unit_Relationships__c cgu : cgus) {
            
            //Only run if Move In Date is not null or in past
            if (cgu.Move_In_Date__c >= system.today()) {
        
        
            
            //Primary Contact if there is one.
            ID caseContactID = (cgidtocgmap.get(cgu.Customer_Group__c).Contacts.size() > 0) 
                ? cgidtocgmap.get(cgu.Customer_Group__c).Contacts[0].id 
                : null;
    
            //New Move In
    
            Case WorkingCase = new Case(
                RecordTypeID = casertmap.get('Move In Tracking Process'),
                AccountID = cgu.Customer_Group__c,
                ContactID = caseContactID,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Move In',
                Case_Primary_Type__c = 'Move In',
                Expected_MoveIn_Date__c = cgu.Move_In_Date__c,
                OwnerID = cgidtocgmap.get(cgu.Customer_Group__c).OwnerID, 
                AVB_Contact_Name__c = cgu.Responsible_Associate__c
            );
            
            casestoinsert.add(WorkingCase);
            }
        }
    }
    
    if (Trigger.isUpdate)
    {
        if (Trigger.isBefore) {
            
            //Fix fields on CGU before insert
            for (Customer_Group_to_Unit_Relationships__c cgu : cgus) {
                Customer_Group_to_Unit_Relationships__c newcgu = Trigger.newmap.get(cgu.id);
                Customer_Group_to_Unit_Relationships__c oldcgu = Trigger.oldmap.get(cgu.id);
                if ((newcgu.NTV_Date__c != oldcgu.NTV_Date__c) 
                    && (newcgu.Expected_Move_Out_Date__c != oldcgu.Expected_Move_Out_Date__c)
                    && (oldcgu.NTV_Date__c == null)
                    && (oldcgu.Expected_Move_Out_Date__c == null)
                    && (cgu.Preliminary_Inspection_Date__c == null))
                    //New Move Out but with null Preliminary Inspection Date. Fix before running rest of Trigger.
                    cgu.Preliminary_Inspection_Date__c = cgu.Expected_Move_Out_Date__c.addDays(-14);
            }   
        
        } else { //must be After
        
            set<id> accids = new set<Id>(); //Customer Groups involved
            
            //get set of Customer Group (Account) IDs
            for (Customer_Group_to_Unit_Relationships__c cgu : cgus) accids.add(cgu.Customer_Group__c);     
            
            //Query for Cases here, before loop.
            list<Case> workingcases = [select id, AccountID, CaseNumber, Status, Reason, Owner.Email, OwnerID, LastModifiedDate from Case where Status = 'Open' and AccountID in :accids];
            
            //Populate case map
            for (Case c : workingcases) move.accidcasemap.put(c.AccountID, c);
            
            //main loop through CGUs
            for (Customer_Group_to_Unit_Relationships__c cgu : cgus) {
                Case WorkingCase;
                Customer_Group_to_Unit_Relationships__c newcgu = Trigger.newmap.get(cgu.id);
                Customer_Group_to_Unit_Relationships__c oldcgu = Trigger.oldmap.get(cgu.id);
                
                //Primary Contact if there is one.
                ID caseContactID = (cgidtocgmap.get(cgu.Customer_Group__c).Contacts.size() > 0) 
                    ? cgidtocgmap.get(cgu.Customer_Group__c).Contacts[0].id 
                    : null;
    
                if ( ((newcgu.Cancelled__c) && (!oldcgu.Cancelled__c))
                    || ((newcgu.Move_In_Date__c == null) && (oldcgu.Move_In_Date__c != null)) ) {
                    //[Cancel Move In]
                    if (move.accidcasemap.get(cgu.Customer_Group__c) != null) {
                        WorkingCase = move.accidcasemap.get(cgu.Customer_Group__c);
                        WorkingCase.Status = 'Closed';
                        WorkingCase.Reason = 'Cancelled';
                        casestoupdate.add(WorkingCase);
                        move.emailCaseUpdate('Cancel Move In',WorkingCase);
                    } else {
                        //No open case
                    }
                    continue;
                }
                
                //cjcindc 19MAR12; create cases when MID populated post CGU creation
                /*original
                if ((newcgu.Move_In_Date__c != oldcgu.Move_In_Date__c)
                    && (newcgu.Move_In_Date__c != null))
                {
                    //Reschedule Move In    
                    if (move.accidcasemap.get(cgu.Customer_Group__c) != null) {
                        WorkingCase = move.accidcasemap.get(cgu.Customer_Group__c);
                        WorkingCase.Expected_MoveIn_Date__c = cgu.Move_In_Date__c;
                        casestoupdate.add(WorkingCase);
                        move.emailCaseUpdate('Reschedule Move In',WorkingCase);
                    } else {
                        //No open case
                    }
                    continue;   
                }
                //original*/
                //*new
                if (newcgu.Move_In_Date__c != oldcgu.Move_In_Date__c)
                {
                    if (oldcgu.Move_In_Date__c == null)
                    {
                        //New Move In    
                        Case NewMoveInCase = new Case(
                            RecordTypeID = casertmap.get('Move In Tracking Process'),
                            AccountID = cgu.Customer_Group__c,
                            ContactID = caseContactID,
                            Origin = 'MRI Import',
                            Status = 'New',
                            Priority = 'Medium',
                            Rejected__c = False,
                            Reason = 'Move In',
                            Case_Primary_Type__c = 'Move In',
                            Expected_MoveIn_Date__c = cgu.Move_In_Date__c,
                            OwnerID = cgidtocgmap.get(cgu.Customer_Group__c).OwnerID, 
                            AVB_Contact_Name__c = cgu.Responsible_Associate__c);
            
                            casestoinsert.add(NewMoveInCase);
                    }
                    else if (newcgu.Move_In_Date__c != null)
                    {
                         if (move.accidcasemap.get(cgu.Customer_Group__c) != null) 
                         {
                            WorkingCase = move.accidcasemap.get(cgu.Customer_Group__c);
                            WorkingCase.Expected_MoveIn_Date__c = cgu.Move_In_Date__c;
                            
                            casestoupdate.add(WorkingCase);
                            move.emailCaseUpdate('Reschedule Move In', WorkingCase);
                        } 
                        else 
                        {
                            //No open case
                        }
                        
                        continue;    
                    }
                }
                //new*/
                //cjcindc 19MAR12; create cases when MID populated post CGU creation
                
                if ((newcgu.NTV_Date__c != oldcgu.NTV_Date__c) 
                    && (newcgu.Expected_Move_Out_Date__c != oldcgu.Expected_Move_Out_Date__c)
                    && (oldcgu.NTV_Date__c == null)
                    && (oldcgu.Expected_Move_Out_Date__c == null)
                    && (newcgu.NTV_Date__c >= system.today()-5)
                    && (newcgu.Move_Out_Reason__c != 'Evict/Skip/Non-renewal'))
                {
                    //New Move Out x

                    WorkingCase = new Case(
                        AccountID = cgu.Customer_Group__c,
                        ContactID = caseContactID,
                        RecordTypeID = casertmap.get('Move Out Tracking Process'),
                        Origin = 'MRI Import',
                        Status = 'New',
                        Priority = 'Medium',
                        Rejected__c = False,
                        Reason = 'Notice to Vacate',
                        Case_Primary_Type__c = 'Notice to Vacate',  
                        NTV_Date__c = cgu.NTV_Date__c,  
                        Move_Out_Date__c = cgu.Expected_Move_Out_Date__c,   
                        Preliminary_Inspection_Date__c = cgu.Preliminary_Inspection_Date__c,
                        OwnerID = cgidtocgmap.get(cgu.Customer_Group__c).OwnerID,
                        AVB_Contact_Name__c = cgu.Responsible_Associate__c
                    );
                    casestoinsert.add(WorkingCase);
                    continue; //Next cgu
                }
                
                if ((newcgu.NTV_Date__c == null) && (oldcgu.NTV_Date__c != null)
                    && (newcgu.Expected_Move_Out_Date__c == null) && (oldcgu.Expected_Move_Out_Date__c != null))
                {
                    //Cancel Move Out x
                    if (move.accidcasemap.get(cgu.Customer_Group__c) != null) {
                        WorkingCase = move.accidcasemap.get(cgu.Customer_Group__c);
                        WorkingCase.Status = 'Closed';
                        WorkingCase.Reason = 'Cancelled';
                        casestoupdate.add(WorkingCase);
                        move.emailCaseUpdate('Cancel Move Out',WorkingCase);
                        WorkingCase.Move_Out_Date__c = null;
                    } else {
                        //no open case
                    }
                    continue;
                }
                
                if (((newcgu.Expected_Move_Out_Date__c != oldcgu.Expected_Move_Out_Date__c)
                    || (newcgu.Preliminary_Inspection_Date__c != oldcgu.Preliminary_Inspection_Date__c))
                    && (newcgu.NTV_Date__c != null) && (oldcgu.NTV_Date__c != null)
                    && (newcgu.Expected_Move_Out_Date__c != null) && (oldcgu.Expected_Move_Out_Date__c != null)
                    && (newcgu.Preliminary_Inspection_Date__c != null) && (oldcgu.Preliminary_Inspection_Date__c != null)
                    && (newcgu.Move_Out_Reason__c != 'Evict/Skip/Non-renewal'))
                {
                    //Reschedule Move Out   
                    if (move.accidcasemap.get(cgu.Customer_Group__c) != null) {
                        WorkingCase = move.accidcasemap.get(cgu.Customer_Group__c);
                        WorkingCase.Move_Out_Date__c = cgu.Expected_Move_Out_Date__c;
                        WorkingCase.NTV_Date__c = cgu.NTV_Date__c;
                        WorkingCase.Preliminary_Inspection_Date__c = cgu.Preliminary_Inspection_Date__c;
                        casestoupdate.add(WorkingCase);
                        move.emailCaseUpdate('Reschedule Move Out',WorkingCase);
                    } else {
                        //no open case
                    }
                    continue;
                }//if resched move out
                
            }//for CGU
        }//else isBefore (must be after)
    }//if isUpdate   

    if (casestoinsert.size() > 0) insert casestoinsert;

    if (casestoupdate.size() > 0) update casestoupdate; 
    
    String emailresults = move.SendEmails();
    for (Case c : casestoinsert) {
        //Status must be New to create, but Open to be part of the tracking process.
        c.Status = 'Open';
    }
    update casestoinsert;
    
}