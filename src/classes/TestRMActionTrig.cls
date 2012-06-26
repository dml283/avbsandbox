@istest
private class TestRMActionTrig {
	
	static testmethod void testRMActiontrig()
	{
		Datetime actdate = system.now().addDays(1);
		
		//test insert of RMA on Account with a non-shared (MRI) Guest Card
		Account a = new Account(Name = 'testacc');
		insert a;
		
		Guest_Card__c testgc = new Guest_Card__c(
			Prospect_Account__c = a.id,
			Shared__c = 'No',
			Rating__c = 'Hot',
			AVB_Associate__c = 'test person',
			Name = 'testgc');
		insert testgc;
		
		list<RMAction__c> testrmas = new list<RMAction__c>();
		testrmas.add(new RMAction__c(
			Account__c = a.id,
			ActCode__c = 'GC',
			ActDescription__c = 'test description',
			Name = 'testrma'));
		testrmas.add(new RMAction__c(
			Account__c = a.id,
			ActCode__c = 'AT',
			ActDate__c = actdate,
			Name = 'testrma'));
		testrmas.add(new RMAction__c(
			Account__c = a.id,
			ActCode__c = 'EM',
			Name = 'testrma'));
		
test.startTest();
		insert testrmas;
		
		//Verify that the RMAction was associated with the Guest Card
		testgc = [select id, Initial_Lead_Type__c, Guest_Card_Details__c, Rating__c,
			(select Id from RMActions__r),
			(select Id, AVB_Type__c, Subject_Sub_Category__c, StartDateTime from Events),
			(select Id, AVB_Type__c, Subject_Sub_Category__c, Status from Tasks where Status != 'Complete')
			from Guest_Card__c where id = :testgc.id];
		system.assertEquals(3, testgc.RMActions__r.size());
		system.assertEquals(1, testgc.Events.size());
		system.assertEquals(actdate, testgc.Events[0].StartDateTime);
		
		system.assertEquals('Email', testgc.Initial_Lead_Type__c);
		system.assertEquals('Warm', testgc.Rating__c);
		
		system.assertEquals('test description', testgc.Guest_Card_Details__c);
		
		testrmas = new list<RMAction__c>();
		testrmas.add(new RMAction__c(
			Account__c = a.id,
			ActCode__c = 'PH',
			Name = 'testrma'));
		testrmas.add(new RMAction__c(
			Account__c = a.id,
			ActCode__c = 'GC',
			ActDescription__c = 'addendum',
			Name = 'testrma'));
		insert testrmas;
		
		//Verify that the RMAction was associated with the Guest Card
		testgc = [select id, Initial_Lead_Type__c, Guest_Card_Details__c,
			(select Id from RMActions__r),
			(select Id, AVB_Type__c, Subject_Sub_Category__c, StartDateTime from Events)
			from Guest_Card__c where id = :testgc.id];
		system.assertEquals(5, testgc.RMActions__r.size());
		system.assertEquals(1, testgc.Events.size());
		
		system.assertEquals('Call', testgc.Initial_Lead_Type__c);
		system.assertEquals('test description addendum', testgc.Guest_Card_Details__c);
		
		testrmas = new list<RMAction__c>();
		testrmas.add(new RMAction__c(
			Account__c = a.id,
			ActCode__c = 'IT',
			Name = 'testrma'));
		insert testrmas;
		
		//Verify that the RMAction was associated with the Guest Card
		testgc = [select id, Initial_Lead_Type__c, Guest_Card_Details__c,
			(select Id from RMActions__r),
			(select Id, AVB_Type__c, Subject_Sub_Category__c, StartDateTime from Events)
			from Guest_Card__c where id = :testgc.id];
		system.assertEquals(6, testgc.RMActions__r.size());
		system.assertEquals(1, testgc.Events.size());
		
		system.assertEquals('Internet', testgc.Initial_Lead_Type__c);
		system.assertEquals('test description addendum', testgc.Guest_Card_Details__c);
		
		testrmas = new list<RMAction__c>();
		testrmas.add(new RMAction__c(
			Account__c = a.id,
			ActCode__c = 'WI',
			Name = 'testrma'));
		insert testrmas;
test.stopTest();
		
		//Verify that the RMAction was associated with the Guest Card
		testgc = [select id, Initial_Lead_Type__c, Guest_Card_Details__c,
			(select Id from RMActions__r),
			(select Id, AVB_Type__c, Subject_Sub_Category__c, StartDateTime from Events)
			from Guest_Card__c where id = :testgc.id];
		system.assertEquals(7, testgc.RMActions__r.size());
		system.assertEquals(2, testgc.Events.size());
		
		system.assertEquals('Walk In', testgc.Initial_Lead_Type__c);
		system.assertEquals('test description addendum', testgc.Guest_Card_Details__c);
		

	}
}