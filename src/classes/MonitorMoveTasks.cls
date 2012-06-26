global class MonitorMoveTasks implements Schedulable{
/*  2010 Jeremy Nottingham
    Part of Move In/ Move Out process. 
    Checks each day for overdue Tasks in this process, and alerts appropriate CM
    --Should run *after midnight*, as it looks for tasks that expired exactly yesterday
    --Should run every day of the week. If this is modified, tasks may be missed if they fall on an unchecked day.
*/
    
    global void execute(SchedulableContext sc)
    {
        MoveInMoveOut move = new MoveInMoveOut();
        move.checkOpenMoveTasks(); //escalate open Move Out Tasks
        //removed 9/28/11 JN. These tasks are now created initially with move out
        //move.createMoveTasks(); //create scheduled Move Out Task(s)
    }
    
    
    
    
    static testmethod void testcheck() {
        String sch = '0 0 2 * * ?'; //CRON code for every day at 2:00 AM
        User u = [select id from User where IsActive = true limit 1];
        RecordType rt = [select id from RecordType where Name = 'Move Out Tracking Process' and SobjectType = 'Case']; 
        Account testacc = [select id from Account limit 1];
        Case WorkingCase = new Case(
                RecordTypeID = rt.id,
                AccountID = testacc.id,
                Origin = 'MRI Import',
                Status = 'New',
                Priority = 'Medium',
                Rejected__c = False,
                Reason = 'Some reason',
                Case_Primary_Type__c = 'Notice To Vacate',
                NTV_Date__c = system.today().addDays(-1),
                Move_Out_Date__c = system.today().addDays(10),
                OwnerID = u.id
                
            );
        insert WorkingCase;
        
        
        list<Task> testtasks = new list<Task>();
        testtasks.add(new Task(
            WhatID = WorkingCase.id,
            AVB_Type__c = 'Move Out Process',
            Subject_Sub_Category__c = 'Final Move Out Inspection/Estimates Inquiry',
            ActivityDate = system.today().addDays(-1),
            Outcome__c = null));
        
        insert testtasks;
Test.startTest();
        // Schedule the test job
        String jobId = System.schedule('testMonitor', sch, new MonitorMoveTasks());
        
        // Get the information from the CronTrigger API object
        CronTrigger ct = [SELECT id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];
        
        // Verify the expressions are the same
        System.assertEquals(sch, ct.CronExpression);
        
        // Verify the job has not run
        System.assertEquals(0, ct.TimesTriggered);
        
        //job will run at stoptest()
Test.stopTest();
        
        //Verify the Task was updated. Note: this actually happens in MoveInMoveOut
        
        
    }
    /*
    static testmethod void testcreate() {
        String sch = '0 0 2 * * ?'; //CRON code for every day at 2:00 AM
        RecordType rt = [select id from RecordType where Name = 'Move Out Tracking Process' and SobjectType = 'Case']; 
        Account acc = [select id from Account limit 1];
        User u = [select id from User where IsActive = true limit 1];
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
                OwnerID = u.id
                //AVB_Contact_Name__c = cgu.?
            );
        
        insert WorkingCase;
        
        WorkingCase.Status = 'Open'; //Case must be Open to be in Move Out Process
        update WorkingCase;
        list<Task> tasks = [select id from Task where WhatID = :WorkingCase.id and IsClosed != true and AVB_Type__c = 'Move Out Process'];
        system.assertEquals(2, tasks.size());//New Move Out
        
        delete tasks;
        
Test.startTest();
        // Schedule the test job
        String jobId = System.schedule('testMonitor', sch, new MonitorMoveTasks());
        
        // Get the information from the CronTrigger API object
        CronTrigger ct = [SELECT id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];
        
        // Verify the expressions are the same
        System.assertEquals(sch, ct.CronExpression);
        
        // Verify the job has not run
        System.assertEquals(0, ct.TimesTriggered);
        
        //job will run at stoptest()
Test.stopTest();
        
        //Verify the Task was updated. Note: this actually happens in MoveInMoveOut
        //System.assertEquals('Escalated - Do Not Close', testtasks[0].Outcome__c);
        
    }
    */
}