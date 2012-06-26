@isTest
private class Task_MoveInMoveOutTrigTest {
    /*
    static testMethod void TestTaskTrigger() {
        //Get 5 accounts, make 5 Cases and then 5 Tasks to update and trip the trigger, only three of them are good.
        
        RecordType rt = [select id from RecordType where Name = 'Move Out Tracking Process'];
        Id cgrtid = [select Id from RecordType where Name = 'Customer Group' and SObjectType = 'Account'].id;
        set<Id> caseids = new set<id>();
        User u = [select id from User where IsActive = true limit 1];
        list<Account> accs = new list<Account>();
        for (Integer i = 0; i < 5; i++) {
        	accs.add(new Account(Name = 'testacc',RecordTypeID = cgrtid, OwnerID = u.id));
        }
        insert accs;
        
        list<Contact> cons = new list<Contact>();
        for (integer i = 0; i < 5; i++) {
        	cons.add(new Contact(AccountID = accs[i].id, LastName = 'testname',OwnerID = u.id, Primary_Contact__c = true));
        }
        insert cons;
        list<Case> cases = new list<Case>();
        for (Integer i = 0; i < 5; i++) {
            cases.add(new Case(
                    RecordTypeID = rt.id,
                    AccountID = cons[i].AccountId,
                    Origin = 'MRI Import',
                    Status = 'New',
                    Priority = 'Medium',
                    Rejected__c = False,
                    Reason = 'Notice To Vacate',
                    Case_Primary_Type__c = 'Notice To Vacate',
                    NTV_Date__c = system.today().addDays(-1),
                    Move_Out_Date__c = system.today().addDays(10),
                    Preliminary_Inspection_Date__c = system.today().addDays(5),
                    OwnerID = u.id,
                    AVB_Contact_Name__c = 'MRI Import'
                )); 
        }
        insert cases;
        for (Case c : cases) {
            caseids.add(c.id);
            c.Status = 'Open';
        }
        update cases;
        
        
        list<Task> tasks = [select id, AVB_Associate_First_Last_Name__c from Task where WhatID in :caseids and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(10, tasks.size()); //2 open Tasks per new Move Out
system.debug('\n\ntasksforthiscase ' + tasks);      
        
        delete tasks;
        
        list<Task> taskstoinsert = new list<Task>();
        for (Integer i = 0; i < 5; i++) {
            taskstoinsert.add(new Task( 
                WhatID = cases[i].id,
                OwnerID = u.id,
                AVB_Type__c = 'Move Out Process',
                Subject_Sub_Category__c = 'Notice to Vacate Follow-up',
                ActivityDate = system.today().addDays(2),
                AVB_Associate_First_Last_Name__c = 'MRI Import'
                ));
        }
        //one bad one
        Account acc = [select id from Account limit 1];
        taskstoinsert.add(new Task( 
            WhatID = acc.id,
            OwnerID = u.id,
            AVB_Type__c = null,
            Subject_Sub_Category__c = null,
            ActivityDate = system.today().addDays(2),
            AVB_Associate_First_Last_Name__c = 'MRI Import'
            )); 
        insert taskstoinsert;
        system.assertEquals(6,taskstoinsert.size());
        
        
        for (Integer i = 0; i < 4; i++) {
            if (i == 0) taskstoinsert[i].Outcome__c = 'No Response – send move out packet';
            if (i == 1) taskstoinsert[i].Outcome__c = 'Saved – remove notice from MRI';
            if (i == 2) taskstoinsert[i].Outcome__c = 'Could not Save – send move out packet';
            if (i == 3) taskstoinsert[i].AVB_Type__c = 'Forwarding Address'; //bad
            if (i == 4) taskstoinsert[i].Subject_Sub_Category__c = 'Move Out Packet/Process Inquiry'; //bad
            taskstoinsert[i].Status = 'Completed';
        }
        
test.StartTest();       
       update taskstoinsert;
test.StopTest();       
        
        tasks = [select id, AVB_Associate_First_Last_Name__c, Subject_Sub_Category__c, Outcome__c from Task 
            where WhatID in :caseids 
            and IsClosed != true and AVB_Type__c = 'Move Out Process' 
            and (Subject_Sub_Category__c = 'Move Out Packet/Process Inquiry' or Subject_Sub_Category__c = 'Remove Notice from MRI')];
        system.assertEquals(3,tasks.size());
system.debug('\n\ntasksafter ' + tasks);        
        for (Task t : tasks) {
            system.assertEquals('MRI Import', t.AVB_Associate_First_Last_Name__c);
            if (t.Subject_Sub_Category__c == 'Remove Notice from MRI') system.assertEquals(null,t.Outcome__c);
        }
        
    }
    
    static testmethod void testcaseupdate() 
    {
        ID rtid = [select ID from RecordType where SObjectType = 'Account' and Name = 'Customer Group'].id;
        User u = [select id from User where IsActive = true limit 1];
        list<Account> accs = new list<Account>();
        for (Integer i = 0; i < 4; i++) {
        	accs.add(new Account(Name = 'testacc',RecordTypeID = rtid, OwnerID = u.id));
        }
        insert accs;
        
        list<Contact> cons = new list<Contact>();
        for (integer i = 0; i < 4; i++) {
        	cons.add(new Contact(AccountID = accs[i].id, LastName = 'testname',OwnerID = u.id, Primary_Contact__c = true));
        }
        insert cons;
        
        
        //New Move In
        Case NewMICase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move In Tracking Process'),
                AccountID = cons[0].Accountid,
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
        
        insert NewMICase;
        NewMICase.Status = 'Open';
        update NewMICase;
        
        list<Task> mitasks = [select id, Status, Outcome__c from Task where WhatID = :NewMICase.id];
        system.assertEquals(3, mitasks.size());
        for (Task t : mitasks) {
            t.Status = 'Complete';
            t.Outcome__c = 'Cancelled';
        }
        
        //New Move Out
        Case NewMOCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = cons[1].Accountid,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.today().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert NewMOCase;
        NewMOCase.Status = 'Open';
        update NewMOCase;
        
        list<Task> motasks = [select id from Task where WhatID = :NewMOCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(2, motasks.size()); //2 open Tasks on new Move Out
        for (Task t : motasks) {
            t.Status = 'Complete';
            t.Outcome__c = 'Cancelled';
        }
        
        //New Move Out: not finished
        Case BadMOCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = cons[2].Accountid,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.today().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert BadMOCase;
        BadMOCase.Status = 'Open';
        update BadMOCase;
        
        //Don't close all the Tasks on this Case
        list<Task> badmotasks = [select id from Task where WhatID = :BadMOCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(2, badmotasks.size()); //2 open Tasks on new Move Out
        badmotasks[0].Status = 'Complete';
        badmotasks[0].Outcome__c = 'Cancelled';
        
        list<Task> alltasks = new list<Task>();
        alltasks.addall(mitasks);
        alltasks.addall(motasks);
        alltasks.addall(badmotasks);
        
test.StartTest();       
        update alltasks;
        
test.stopTest();        
        //This Case is now Closed
        NewMICase = [select No_Open_Tasks__c, Status from Case where id = :NewMICase.id];
        system.assertEquals(True, NewMICase.No_Open_Tasks__c);
        system.assertEquals('Closed',NewMICase.Status);
        
        //This Case is Not Closable because not all Tasks have been created and then closed
        NewMOCase = [select No_Open_Tasks__c, Status from Case where id = :NewMOCase.id];
        system.assertEquals(False, NewMOCase.No_Open_Tasks__c);  
        system.assertEquals('Open',NewMOCase.Status);
        
        //This Case is not Closable, because there is a Task open.
        BadMOCase = [select No_Open_Tasks__c, Status from Case where id = :BadMOCase.id];
        system.assertEquals(False, BadMOCase.No_Open_Tasks__c);
        system.assertEquals('Open',BadMOCase.Status);
    }
    
    static testmethod void testsavedcase()
    {
        //start Move Out, close Follow Up task with Saved Outcome, check that Final Inspection is Closed.
        Id cgrtid = [select id from RecordType where Name = 'Customer Group' and SObjectType = 'Account'].id;
        User u = [select id from User where IsActive = true limit 1];
        list<Account> accs = new list<Account>();
        for (Integer i = 0; i < 4; i++) {
        	accs.add(new Account(Name = 'testacc',RecordTypeID = cgrtid, OwnerID = u.id));
        }
        insert accs;
        
        list<Contact> cons = new list<Contact>();
        for (integer i = 0; i < 4; i++) {
        	cons.add(new Contact(AccountID = accs[i].id, LastName = 'testname',OwnerID = u.id, Primary_Contact__c = true));
        }
        insert cons;
        Contact con = [select Accountid from Contact where Primary_Contact__c = true limit 1];
        Case NewMOCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = con.Accountid,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.today().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert NewMOCase;
        
        list<Task> motasks = [select id, Status, Outcome__c, Subject_Sub_Category__c from Task 
            where WhatID = :NewMOCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(2, motasks.size()); //2 open Tasks on new Move Out
system.debug('\n\nmotasks ' + motasks);     
        Task finalinspectionTask;
        Task followUpTask;
        for (Task t : motasks) {
            if (t.Subject_Sub_Category__c == 'Final Move Out Inspection/Estimates Inquiry') finalInspectionTask = t;
            if (t.Subject_Sub_Category__c == 'Notice to Vacate Follow-up') followUpTask = t;
        }
        followUpTask.Outcome__c = 'Saved – remove notice from MRI';
        followUpTask.Status = 'Complete';
        
test.startTest();
        update followUpTask;
test.StopTest();                
        finalinspectionTask = [select IsClosed from Task where id = :finalinspectionTask.id];
        system.assertEquals(True, finalinspectionTask.IsClosed); //Final Inspection Task is now closed.
        
    }
    */
    
    static testmethod void testautoclosecase()
    { //make all kinds of tasks
    	//start Move Out
        Id cgrtid = [select id from RecordType where Name = 'Customer Group' and SObjectType = 'Account'].id;
        User u = [select id from User where IsActive = true limit 1];
        list<Account> accs = new list<Account>();
        for (Integer i = 0; i < 4; i++) {
        	accs.add(new Account(Name = 'testacc',RecordTypeID = cgrtid, OwnerID = u.id));
        }
        insert accs;
        
        list<Contact> cons = new list<Contact>();
        for (integer i = 0; i < 4; i++) {
        	cons.add(new Contact(AccountID = accs[i].id, LastName = 'testname',OwnerID = u.id, Primary_Contact__c = true));
        }
        insert cons;
        Contact con = [select Accountid from Contact where Primary_Contact__c = true limit 1];
        Case NewMOCase = new Case(
                RecordTypeID = MoveInMoveOut.casertmap().get('Move Out Tracking Process'),
                AccountID = con.Accountid,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Notice To Vacate',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                Preliminary_Inspection_Date__c = system.today().addDays(5),
                OwnerID = u.id,
                AVB_Contact_Name__c = 'MRI Import'
            );
        
        insert NewMOCase;
system.debug('\n\nrt ' + NewMOCase.RecordtypeID);        
        NewMOCase.Status = 'Open';
        update NewMOCase;
        
        list<Task> motasks = [select id, Status, Outcome__c, Subject_Sub_Category__c from Task 
            where WhatID = :NewMOCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        if (motasks.size() > 0) delete motasks;
  		
  		motasks.clear();
  		motasks.add(new Task(
        	WhatID = NewMOCase.ID,
        	AVB_Type__c = 'Move Out Process',
        	Subject_Sub_Category__c = 'Notice to Vacate Follow-up',
        	Status='Complete'   
        	));
        motasks.add(new Task(
        	WhatID = NewMOCase.ID,
        	AVB_Type__c = 'Move Out Process',
        	Subject_Sub_Category__c = 'Final Move Out Inspection/Estimates Inquiry',
        	Status='Complete'   
        	));
        motasks.add(new Task(
        	WhatID = NewMOCase.ID,
        	AVB_Type__c = 'Move Out Process',
        	Subject_Sub_Category__c = 'Move Out Packet/Process Inquiry',
        	Status='Complete'   
        	));
        motasks.add(new Task(
        	WhatID = NewMOCase.ID,
        	AVB_Type__c = 'Move Out Process',
        	Subject_Sub_Category__c = 'Move Out Complete Follow Up',
        	Status='Open'   
        	));
        insert motasks;
        
        motasks[3].Status = 'Complete';
test.startTest();
        update motasks[3];        
test.StopTest();      
		motasks = [select id, Status, Outcome__c, Subject_Sub_Category__c from Task 
        	where WhatID = :NewMOCase.id and IsClosed = true and AVB_Type__c = 'Move Out Process'];
system.debug('\n\nmotasks ' + motasks);
        
        system.assertEquals(4, motasks.size()); 
        
        NewMOCase = [select Status from Case where id = :NewMOCase.ID];
		system.assertequals('Closed', NewMOCase.Status);
    }
}