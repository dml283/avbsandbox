@istest
private class Test_EventGuestCardTrig {
	
	
	static testmethod void testEventtrigger()
	{
		Guest_Card__c testgc = new Guest_Card__c(
			Name = 'testGuest Card',
			AVB_Associate__c = 'test associate');
		insert testgc;
		
		testgc = [select Initial_Visit_Date__c, (Select Id from Tasks) from Guest_Card__c where id = :testgc.id];
		system.assertEquals(null, testgc.Initial_Visit_Date__c);
		if (testgc.Tasks.size() > 0) delete testgc.Tasks;
		
		Datetime startdt = system.now();
		Datetime enddt = system.now().addHours(1);
		
		Event testevent = new Event(
			WhatId = testGC.id,
			StartDateTime = startdt,
			EndDateTime = enddt,
			AVB_Type__c = 'Lead Pursuit Process',
			AVB_Associate_First_Last_Name__c = 'test associate',
			Subject_Sub_Category__c = 'Initial Visit',
			Status__c = 'Open');
test.startTest();
		insert testevent;
		testgc = [select Initial_Visit_Date__c, (Select Id from Tasks) from Guest_Card__c where id = :testgc.id];
		system.assertEquals(null, testgc.Initial_Visit_Date__c);
		system.assertEquals(0, testgc.Tasks.size());
		
		testevent.Status__c = 'Complete';	
		update testevent;
test.stopTest();	
		testgc = [select Initial_Visit_Date__c, (Select Id, ActivityDate, Subject_Sub_Category__c from Tasks) from Guest_Card__c where id = :testgc.id];
		system.assertEquals(startdt, testgc.Initial_Visit_Date__c);
		system.assertEquals(1, testgc.Tasks.size());
		system.assertEquals(system.today().addDays(2),testgc.Tasks[0].ActivityDate);
			
	}
	
	static testmethod void testDateCopy()
	{
		Datetime dt = system.now();
		Event testevent = new Event(
			Subject = 'test',
			AVB_Type__c = 'Lead Pursuit Process',
			Subject_Sub_Category__c = 'Initial Visit',
			StartDateTime = dt,
			EndDateTime = dt.addDays(2));

test.startTest();
	
		insert testevent;
		testevent = [select StartDate__c from Event where id = :testevent.id];
		system.assertEquals(system.today(), testevent.StartDate__c);
		
		testevent.StartDateTime = dt.addDays(1);
		update testevent;
		testevent = [select StartDate__c from Event where id = :testevent.id];
		system.assertEquals(system.today().addDays(1), testevent.StartDate__c);
		
test.stopTest();

	}
	
	static testmethod void testEventtrigger1()
	{
		Guest_Card__c testgc = new Guest_Card__c(
			Name = 'testGuest Card',
			AVB_Associate__c = 'test associate');
		insert testgc;
		
		
		Event testevent = new Event(
			WhatId = testGC.id,
			StartDateTime = system.now(),
			EndDateTime = system.now().addHours(1),
			AVB_Associate_First_Last_Name__c = 'new event associate name',
			AVB_Type__c = 'Lead Pursuit Process',
			Subject_Sub_Category__c = 'Initial Visit',
			Status__c = 'Open');
test.startTest();
		insert testevent;
		testgc = [select AVB_Associate__c from Guest_Card__c where id = :testgc.id];
		system.assertNotEquals('new event associate name', testgc.AVB_Associate__c);
		
		testevent.AVB_Associate_First_Last_Name__c = 'updating event associate name';	
		update testevent;
test.stopTest();	
		testgc = [select AVB_Associate__c from Guest_Card__c where id = :testgc.id];
		system.assertNotEquals('updating event associate name', testgc.AVB_Associate__c);
			
	}
	
	
}