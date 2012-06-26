@istest
private class Test_TaskAssignment {

	static testmethod void testassignTasks1()
	{
		list<Schema.PicklistEntry> picklistValues = User.Assigned_Task_Queues__c.getDescribe().getPicklistValues();
		list<String> stringpicklistValues = new list<String>();
		for (Schema.Picklistentry pe : picklistValues)
		{
			stringpicklistValues.add(pe.getLabel());
		}
		
		Profile prof = [select Id from Profile limit 1];
		
		list<User> testusers = new list<User>();
		for (Integer i = 0; i < 2; i++)
		{
			User newuser = new User(
				LastName = 'testuser' + i,
				Max_Assigned_Tasks__c = 5,
	            Assigned_Task_Queues__c = stringpicklistValues[i],
				alias = 'tuser', 
	        	email='standarduser@example.com', 
	        	emailencodingkey='UTF-8', 
	            languagelocalekey='en_US', 
	            localesidkey='en_US', 
	            ProfileId = prof.Id,
			    timezonesidkey='America/Los_Angeles',
	            username='testuser7844584552' + i + '@avalonbay.com.testing',
	            Department = 'RS Community'
	            );
	    	if (i == 1)
	        {
	           	newuser.Assigned_Task_Queues__c += ';' + stringpicklistValues[0];
	        }
	    	testusers.add(newuser);
		}
		insert testusers;
		
		Id rtid = [select Id from Recordtype where Name = 'Customer Group' and SObjectType = 'Account' limit 1].Id;
		list<Account> testaccs = new list<Account>();
		for (Integer i = 0; i < 2; i++)
		{
			Account newacc = new Account(
				Name = 'testacc' + i,
				RecordtypeId = rtid);
			testaccs.add(newacc);
		}
		insert testaccs;
		
		list<Contact> testcons = new list<Contact>();
		for (Integer i = 0; i < 2; i++)
		{
			Contact newcon = new Contact(
				LastName = 'testcon' + i,
				AccountId = testaccs[i].Id);
			testcons.add(newcon);	
		}
		insert testcons;
		
		Task existingTask = new Task(
			OwnerId = testusers[0].Id,
			WhatId = testaccs[0].Id,
			WhoId = testcons[0].Id,
			ActivityDate = system.today(),
			Status = 'Open');
		insert existingTask;
		
		list<Case> testcases = new list<Case>();
		for (Integer i = 0; i < 2; i++)
		{
			Case newcase = new Case(
				AccountId = testaccs[i].Id,
				Subject = 'testcase' + i);
			testcases.add(newcase);	
		}
		insert testcases;
		
		list<Task> testTasks = new list<Task>();
		for (Integer i = 0; i < 2; i++)
		{
			Task newtask = new Task(
				WhatId = testcases[i].Id,
				WhoId = testcons[i].Id,
				Task_Queue__c = stringpicklistValues[i],
				ActivityDate = system.today());
			testTasks.add(newtask);
		}
		
test.startTest();
		list<Task> confirmTasks = TaskAssignment.assignTasks(testTasks);
test.stopTest();
		system.assertEquals(2, confirmTasks.size());
		
		map<Id, Integer> user2taskcountmap = new map<Id, Integer>();
		for (User u : testusers)
		{
			user2taskcountmap.put(u.Id, 0);
		}
		
		for (Task t : confirmTasks)
		{
			user2taskcountmap.put(t.OwnerId, user2taskcountmap.get(t.OwnerId) + 1);
			system.assert(t.Task_Assigned__c == TRUE);
		}
		user2taskcountmap.put(existingTask.OwnerId, user2taskcountmap.get(existingTask.OwnerId) + 1);
system.debug('\n\n107 user2taskcountmap ' + user2taskcountmap);
			
		testusers = [select Assigned_Task_Queues__c, Current_Assigned_Tasks__c, Available_Assigned_Tasks__c, Max_Assigned_Tasks__c
			from User
			where Id in:testusers];
		system.assertEquals(2, testusers.size());
system.debug('\n\n113 testusers ' + testusers);		
		for (User u : testusers)
		{
		//	system.assertEquals(u.Available_Assigned_Tasks__c, u.Max_Assigned_Tasks__c - u.Current_Assigned_Tasks__c);
		//	system.assertEquals(user2taskcountmap.get(u.Id), u.Current_Assigned_Tasks__c);
		}
	}
	
	static testmethod void testcloseAssignedTasks1()
	{
		//Warn not to run task assignment through triggers
		TaskAssignment.IsTestingTaskAssignment = TRUE; 
		
		list<Schema.PicklistEntry> picklistValues = User.Assigned_Task_Queues__c.getDescribe().getPicklistValues();
		list<String> stringpicklistValues = new list<String>();
		for (Schema.Picklistentry pe : picklistValues)
		{
			stringpicklistValues.add(pe.getLabel());
		}
		
		Profile prof = [select Id from Profile limit 1];
		
		list<User> testusers = new list<User>();
		for (Integer i = 0; i < 2; i++)
		{
			User newuser = new User(
				LastName = 'testuser' + i,
				Max_Assigned_Tasks__c = 5,
	            Assigned_Task_Queues__c = stringpicklistValues[i],
				alias = 'tuser', 
	        	email='standarduser@example.com', 
	        	emailencodingkey='UTF-8', 
	            languagelocalekey='en_US', 
	            localesidkey='en_US', 
	            ProfileId = prof.Id,
			    timezonesidkey='America/Los_Angeles',
	            username='testuser7844584552' + i + '@avalonbay.com.testing',
	            Department = 'RS Community'
	            );
	    	if (i == 1)
	        {
	           	newuser.Assigned_Task_Queues__c += ';' + stringpicklistValues[0];
	        }
	    	testusers.add(newuser);
		}
		insert testusers;
		
		Id rtid = [select Id from Recordtype where Name = 'Customer Group' and SObjectType = 'Account' limit 1].Id;
		list<Account> testaccs = new list<Account>();
		for (Integer i = 0; i < 2; i++)
		{
			Account newacc = new Account(
				Name = 'testacc' + i,
				RecordtypeId = rtid);
			testaccs.add(newacc);
		}
		insert testaccs;
		
		list<Contact> testcons = new list<Contact>();
		for (Integer i = 0; i < 2; i++)
		{
			Contact newcon = new Contact(
				LastName = 'testcon' + i,
				AccountId = testaccs[i].Id);
			testcons.add(newcon);	
		}
		insert testcons;
		
		list<Case> testcases = new list<Case>();
		for (Integer i = 0; i < 2; i++)
		{
			Case newcase = new Case(
				AccountId = testaccs[i].Id,
				Subject = 'testcase' + i);
			testcases.add(newcase);	
		}
		insert testcases;
		
		list<Task> testTasks = new list<Task>();
		for (Integer i = 0; i < 2; i++)
		{
			Task newtask = new Task(
				WhatId = testcases[i].Id,
				WhoId = testcons[i].Id,
				Task_Queue__c = stringpicklistValues[i],
				ActivityDate = system.today(),
				Status = 'Open');
			testTasks.add(newtask);
		}
		insert testTasks;
		
		for (Task t : testTasks)
		{
			t.Status = 'Completed';
		}
		update testTasks;
		
test.startTest();
		TaskAssignment.closeAssignedTasks(testTasks);
test.stopTest();		
		testusers = [select Assigned_Task_Queues__c, Current_Assigned_Tasks__c, Available_Assigned_Tasks__c, Max_Assigned_Tasks__c
			from User
			where Id in:testusers];
		system.assertEquals(2, testusers.size());
		for (User u : testusers)
		{
		//	system.assertEquals(u.Available_Assigned_Tasks__c, u.Max_Assigned_Tasks__c);
		//	system.assertEquals(0, u.Current_Assigned_Tasks__c);
		}
		
	}
}