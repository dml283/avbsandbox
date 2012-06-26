@isTest
private class Case_MoveInMoveOutTrigTest {
    //MoveInMoveOut move = new MoveInMoveOut();

    static testmethod void testNewMoveIn()
    {
        //New Move In
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move In Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Move In',
                Case_Primary_Type__c = 'Move In',
                Expected_MoveIn_Date__c = system.today().addDays(10),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
test.startTest();       
        insert WorkingCase;
                    
test.stopTest();
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move In Process'];
        system.assertEquals(3, tasks.size());
        
    }
    
    static testmethod void testStatusChange()
    {
        //Status Change pass-through
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.now().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert WorkingCase;
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //4 open Tasks on new Move Out
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out

test.StartTest();       
        update WorkingCase;
test.stopTest();

        tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //still 4, should not have affected Tasks
        
    }


    static testmethod void testCancelMoveIn()
    {
        //Cancel Move In
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move In Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Move In',
                Case_Primary_Type__c = 'Move In',
                Expected_MoveIn_Date__c = system.today().addDays(10),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert WorkingCase;
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out
        update WorkingCase;
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move In Process'];
        system.assertEquals(3, tasks.size());//New Move In
        
        WorkingCase.Reason = 'Cancelled';
        WorkingCase.Status = 'Closed';

test.startTest();
        update WorkingCase;
test.stopTest();    
        tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move In Process'];
system.debug('\n\nWorkingCase ' + WorkingCase + '\ntasks ' + tasks);        
        system.assertEquals(0, tasks.size());//Should all be closed now
        
    }
    
    static testmethod void testReschedMoveIn()
    {
        //Reschedule Move In
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move In Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Move In',
                Case_Primary_Type__c = 'Move In',
                Expected_MoveIn_Date__c = system.today().addDays(10),
                OwnerID = u.id
                //AVB_Contact_Name__c = cgu.?
            );
        
        insert WorkingCase;
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out
        update WorkingCase;
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move In Process'];
        system.assertEquals(3, tasks.size());//New Move In
        
        WorkingCase.Expected_MoveIn_Date__c = system.today().addDays(20);
test.startTest();
        update WorkingCase;
test.stopTest();    
        tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move In Process'];
        system.assertEquals(3, tasks.size());// Move In
            
    }
    
    static testmethod void testBadNewMoveIn()
    {
        //New Move In
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move In Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Move In',
                Case_Primary_Type__c = 'Move In',
                Expected_MoveIn_Date__c = null,
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
test.startTest();       
        insert WorkingCase;
                    
test.stopTest();
        list<Task> tasks = [select id, ActivityDate from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move In Process'];
        system.assertEquals(3, tasks.size());
        system.assertEquals(system.today(),tasks[0].ActivityDate); //Dates set to today, because there's no move in date.
        
    }
    
    static testmethod void testNewMoveOut()
    {
        //New Move Out
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.now().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
test.StartTest();       
        insert WorkingCase;
test.stopTest();        
        list<Task> tasks = [select id, ActivityDate, Subject_Sub_Category__c from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //2 open Tasks on new Move Out
        for (Task t : tasks) {
            if (t.Subject_Sub_Category__c == 'Notice to Vacate Follow-up') 
            	system.assertEquals(WorkingCase.NTV_Date__c.addDays(2), t.ActivityDate);
            if (t.Subject_Sub_Category__c == 'Final Move Out Inspection/Estimates Inquiry') 
            	system.assertEquals(WorkingCase.Preliminary_Inspection_Date__c.date().addDays(2), t.ActivityDate);
            if (t.Subject_Sub_Category__c == 'Move Out Packet/Process Inquiry') 
            	system.assertEquals(WorkingCase.NTV_Date__c.addDays(4), t.ActivityDate);
            if (t.Subject_Sub_Category__c == 'Move Out Complete Follow Up') 
            	system.assertEquals(WorkingCase.Move_Out_Date__c.addDays(3), t.ActivityDate);
        }            
    }
    
    static testmethod void testCancelMoveOut()
    {
        //Cancel Move Out
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.now().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        
        insert WorkingCase;
        
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //4 open Tasks on new Move Out
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out
        update WorkingCase;
        tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //still 4, should not have affected Tasks
        
        WorkingCase.Move_Out_Date__c = null;
test.StartTest();
        update WorkingCase;
test.stopTest();        
        tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(0, tasks.size()); //should be closed now
        
    }
    
    static testmethod void testReschedMoveOut()
    {
        //Reschedule Move Out
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.now().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        
        insert WorkingCase;
        
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //4 open Tasks on new Move Out
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out
        update WorkingCase;
        
        tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //
        
        WorkingCase.Move_Out_Date__c = system.today().addDays(30);
test.StartTest();
        update WorkingCase;
test.stopTest();        
        tasks = [select id, ActivityDate, Subject_Sub_Category__c from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //4 open Tasks on new Move Out
        for (Task t : tasks) {
            if (t.Subject_Sub_Category__c == 'Notice to Vacate Follow-up') system.assertEquals(WorkingCase.NTV_Date__c.addDays(2),t.ActivityDate);
            if (t.Subject_Sub_Category__c == 'Final Move Out Inspection/Estimates Inquiry') system.assertEquals(WorkingCase.Preliminary_Inspection_Date__c.date().addDays(2),t.ActivityDate);
            if (t.Subject_Sub_Category__c == 'Move Out Complete Follow Up') system.assertEquals(WorkingCase.Move_Out_Date__c.addDays(3),t.ActivityDate);
        }
        
    }
    
    static testmethod void testRejectMoveOut()
    {
        //Rejected Move Out
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.now().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert WorkingCase;
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //4 open Tasks on new Move Out
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out
        update WorkingCase;


        tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(4, tasks.size()); //still 4, should not have affected Tasks
        
        WorkingCase.Rejected__c = true;

test.StartTest();
system.debug('\n\nsendreject');
        update WorkingCase;
system.debug('\n\nsentreject');
test.stopTest();
        tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(0, tasks.size());//those Tasks should be closed now.
    }
    
    
    static testmethod void testOtherRecordType()
    {
        RecordType rt = [select id from RecordType 
            where SobjectType = 'Case' and Name != 'Move In Tracking Process' and Name != 'Move Out Tracking Process' limit 1];
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = rt.id,
                AccountID = acc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Some reason',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
test.startTest();       
        insert WorkingCase;
test.StopTest();        
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c like 'Move%'];
        system.assertEquals(0, tasks.size()); //shouldn't be any Tasks on this Case
        
    }
    

}