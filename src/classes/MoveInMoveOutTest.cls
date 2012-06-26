public with sharing class MoveInMoveOutTest {
/* Jeremy Nottingham 2010 */
    
    
    static testmethod void testrtmap()
    {
        map<String, ID> rtmap;
        //make sure that the custom settings are already created.
        list<RecordTypes__c> rtsettings = RecordTypes__c.getall().values();
        if (rtsettings.size() < 8) rtmap = MoveInMoveOut.casertmap();
        
        RecordType testrt = [select Name, ID from RecordType where SObjectType = 'Case' and Name = 'Move In Tracking Process' limit 1];
        RecordType testrt2 = [select Name, ID from RecordType where SObjectType = 'Task' and Name = 'Pre Inspection Follow Up' limit 1];
        
test.startTest();       
        rtmap = MoveInMoveOut.casertmap();
test.StopTest();        
        system.assertEquals(testrt.ID, rtmap.get(testrt.Name));
        system.assertEquals(testrt2.ID, rtmap.get(testrt2.Name));
    }
    
    static testmethod void testrtmapnew()
    {
        list<RecordTypes__c> rtsettings = RecordTypes__c.getall().values();
        if (rtsettings.size() > 0) delete rtsettings;
        rtsettings = RecordTypes__c.getall().values();
        system.assertEquals(0, rtsettings.size());
        
test.startTest();
        map<String, ID> rtmap = MoveInMoveOut.casertmap();

test.stopTest();
        rtsettings = RecordTypes__c.getall().values();
        system.assertNOTEquals(0, rtsettings.size());
                
    }
    
    static testmethod void testcheckOpenMoveTasks()
    {
        RecordType rt = [select id from RecordType where Name = 'Move Out Tracking Process' and SobjectType = 'Case']; 
        RecordType cgrt = [select id from RecordType where Name = 'Customer Group' and SObjectType = 'Account']; 
        User u = [select id from User where IsActive = true limit 1];
        Account acc = new Account(RecordTypeID = cgrt.id, Status__c = 'Resident', Name = 'testacc', OwnerID = u.id); 
        insert acc;
        //[select id, OwnerID from Account where Status__c ='Resident' and RecordTypeID = :cgrt.id limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = rt.id,
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-15),
                Move_Out_Date__c = system.today().addDays(-1),
                Preliminary_Inspection_Date__c = system.today().addDays(5),
                OwnerID = acc.OwnerID,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert WorkingCase;
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out
        update WorkingCase;
        list<Task> tasks = [select id, ActivityDate from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        //system.assertEquals(2, tasks.size());//New Move Out
        
        for (Task t : tasks) {
            t.ActivityDate = system.today().addDays(-1);
        }
        update tasks;
        
        list<Task> taskstoinsert = new list<Task>();
        taskstoinsert.add(new Task(
            WhatID = WorkingCase.id,
            OwnerID = WorkingCase.OwnerID,
            AVB_Type__c = 'Move Out Process',
            Subject_Sub_Category__c = 'Move Out Packet/Process Inquiry',
            ActivityDate = system.today().addDays(-1)
            ));
        taskstoinsert.add(new Task(
            WhatID = WorkingCase.id,
            OwnerID = WorkingCase.OwnerID,
            AVB_Type__c = 'Move Out Process',
            Subject_Sub_Category__c = 'Schedule Final Move Out',
            ActivityDate = system.today().addDays(-1)
            ));
        taskstoinsert.add(new Task(
            WhatID = WorkingCase.id,
            OwnerID = WorkingCase.OwnerID,
            AVB_Type__c = 'Move Out Process',
            Subject_Sub_Category__c = 'Move Out Complete Follow Up',
            ActivityDate = system.today().addDays(-1)
            ));
        insert taskstoinsert;
        
        tasks = [select id, ActivityDate from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        //system.assertEquals(5, tasks.size());//bunch of tasks now
        
test.StartTest();
        MoveInMoveOut move = new MoveInMoveOut();
        move.checkOpenMoveTasks();
        
        Integer count = Limits.getEmailInvocations();
        system.assertEquals(1,count); //verify 1 email batch sent
test.StopTest();    

        
        tasks = [select id, Outcome__c from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        for (Task t : tasks) {
            system.assertEquals('Escalated - Do Not Close',t.Outcome__c);
        }
        
            
    }
    /*// removed 092711 JN 
    static testmethod void testcreateMoveTasks()
    {
        RecordType mort = [select id from RecordType where Name = 'Move Out Tracking Process' and SobjectType = 'Case'];
        RecordType cgrt = [select id from RecordType where Name = 'Customer Group' and SObjectType = 'Account']; 
        User u = [select id from User where IsActive = true limit 1]; 
        Account acc = new Account(Status__c = 'Resident', RecordTypeID = cgrt.id, Name = 'testacc', OwnerID = u.id);
        insert acc;
        //[select id, OwnerID from Account where Status__c = 'Resident' and RecordTypeID = :cgrt.id limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = mort.id,
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-15),
                Move_Out_Date__c = system.today().addDays(-1),
                Preliminary_Inspection_Date__c = system.today().addDays(5),
                OwnerID = acc.OwnerID,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert WorkingCase;
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out
        update WorkingCase;
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        //system.assertEquals(2, tasks.size());//New Move Out
        
        delete tasks;
        
test.StartTest();
        MoveInMoveOut move = new MoveInMoveOut();
        move.createMoveTasks();
        
test.StopTest();        
        
        tasks = [select id, ActivityDate from Task where WhatID = :WorkingCase.id and IsClosed = false and Subject_Sub_Category__c = 'Move Out Complete Follow Up'];
        system.assertEquals(1,tasks.size()); //only one task
        system.assertEquals(system.today().addDays(2),tasks[0].ActivityDate); //72 hours after move out date (yesterday) 
    } 
    */
    static testmethod void testemail()
    {
        RecordType rt = [select id from RecordType where Name = 'Move Out Tracking Process' and SobjectType = 'Case']; 
        RecordType cgrt = [select id from RecordType where Name = 'Customer Group' and SObjectType = 'Account']; 
        User u = [select id from User where IsActive = true limit 1];
        Account acc = new Account(Name = 'testacc',Status__c = 'Resident', RecordTypeID = cgrt.id, OwnerID = u.id);
        insert acc;
        //[select id, OwnerID from Account where Status__c = 'Resident' and RecordTypeID = :cgrt.id limit 1];
        Case c = new Case(
                RecordTypeID = rt.id,
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-15),
                Move_Out_Date__c = system.today().addDays(-1),
                Preliminary_Inspection_Date__c = system.today().addDays(5),
                OwnerID = acc.OwnerID,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert c;
        
system.debug('\n\n Case ' + c);         
test.StartTest();       
        MoveInMoveOut move = new MoveInMoveOut();
        move.emailCaseUpdate('Reschedule Move Out', c);
        move.emailCaseUpdate('Cancel Move Out', c);
        move.emailCaseUpdate('Reschedule Move In', c);
        move.emailCaseUpdate('Cancel Move In', c);
        
        system.assertEquals(4, move.emailstosend.size()); //right number of messages
        system.assertEquals('Update: Move Out Rescheduled', move.emailstosend[0].getSubject());
        system.assertEquals('Update: Move Out Cancelled', move.emailstosend[1].getSubject());
        system.assertEquals('Update: Move In Rescheduled', move.emailstosend[2].getSubject());
        system.assertEquals('Update: Move In Cancelled', move.emailstosend[3].getSubject());
        String emailresults = move.sendEmails();
        
        move.emailstosend.clear();
        Messaging.SingleEmailMessage badmail = new Messaging.SingleEmailMessage();
        badmail.setToAddresses(new list<String> { 'bademailaddress' });
        badmail.setHtmlBody('body');
        move.emailstosend.add(badmail); //errors
        emailresults = move.sendEmails();
        system.assertNotEquals('Sending Failure',emailresults.substring(0,14)); //errors with sending
        
        move.emailstosend.clear(); //empty list
        emailresults = move.sendEmails();
        system.assertEquals('No Emails To Send',emailresults); //returned empty error with sending
        
        Integer count = Limits.getEmailInvocations();
        system.assertEquals(2,count); //verify 2 email batches sent     
test.StopTest();        
    }
    
}