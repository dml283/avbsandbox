@isTest
private class Test_TaskGuestCardTrig {

    static testMethod void testAVBAssoc() {
        
        list<Guest_Card__c> testgcs = new list<Guest_Card__c>();
        testgcs.add(new Guest_Card__c(
        	AVB_Associate__c = 'current associate name'
        	));
        insert testgcs;
        
        testgcs = [select AVB_Associate__c
			from Guest_Card__c
			where Id in :testgcs];
		system.assertEquals('current associate name', testgcs[0].AVB_Associate__c);
		
        list<Task> testtasks = new list<Task>();
        for (Guest_Card__c gc : testgcs)
        {
        	testtasks.add(new Task(
        		WhatId = gc.Id,
        		AVB_Type__c = 'Lead Pursuit Process',
        		AVB_Associate_First_Last_Name__c = 'new associate name'));
        }
        
test.startTest();
system.debug('\n\n27 insert tasks ' + testtasks);		
		insert testtasks;
		
		testgcs = [select AVB_Associate__c
			from Guest_Card__c
			where Id in :testgcs];
		system.assertNotEquals('new associate name', testgcs[0].AVB_Associate__c);
		
		testtasks[0].AVB_Associate_First_Last_Name__c = 'updated associate name';
		update testtasks;
test.stopTest();       
    	testgcs = [select AVB_Associate__c
			from Guest_Card__c
			where Id in :testgcs];
		system.assertNotEquals('updated associate name', testgcs[0].AVB_Associate__c);
		
    
    }
    
    static testmethod void testnullAVBAssoc()
    {
        list<Guest_Card__c> testgcs = new list<Guest_Card__c>();
        testgcs.add(new Guest_Card__c(
        	AVB_Associate__c = 'current associate name'
        	));
        insert testgcs;
        
        testgcs = [select AVB_Associate__c
			from Guest_Card__c
			where Id in :testgcs];
		system.assertEquals('current associate name', testgcs[0].AVB_Associate__c);
		
        list<Task> testtasks = new list<Task>();
        for (Guest_Card__c gc : testgcs)
        {
        	testtasks.add(new Task(
        		WhatId = gc.Id,
        		AVB_Type__c = 'Lead Pursuit Process',
        		AVB_Associate_First_Last_Name__c = null));
        }
        
test.startTest();
		insert testtasks;
		
test.stopTest();       

		testtasks = [select AVB_Associate_First_Last_Name__c
			from Task
			where Id in :testtasks];
		system.assertEquals('current associate name', testtasks[0].AVB_Associate_First_Last_Name__c);    	
    }
}