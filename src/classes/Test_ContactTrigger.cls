@istest
private class Test_ContactTrigger {

	static testmethod void testGuestCardFind()
	{
		ID cgrtid = [select Id from Recordtype where SOBjecttype = 'Account' and Name = 'Customer Group' limit 1].Id;
		
		list<Account> testcgs = new list<Account>();
		testcgs.add(new Account(
			Name = 'testperson and other occupants',
			RecordtypeID = cgrtid
			));
		insert testcgs;
		
		Guest_Card__c testgc = new Guest_Card__c(
			Prospect_Account__c = testcgs[0].Id,
			Name = testcgs[0].Name,
			AVB_Associate__c = 'test associate');
		insert testgc;
		
		Contact testcon = new Contact(
			AccountId = testcgs[0].Id,
			LastName = 'testcon',
			Primary_Contact__c = TRUE);
		
test.startTest();
		insert testcon;
		
test.stopTest();
		testgc = [select Contact__c from Guest_Card__c where Id = :testgc.Id];
		system.assertEquals(testcon.Id, testgc.Contact__c);
	}
}