@istest
public class Test_CaseIssueTrigger {

	static testmethod void testValidations()
	{
		//insert with previously referred resident on Case Issue
		//insert with move in date in the past
		//insert with referred resident = previous resident who moved out less than 30 days before the Expected Move In on the Case Issue
		
		list<Recordtype> rts = [select Id, Name, SobjectType from Recordtype];
		Id cgrtid;
		Id refrtid;
		for (Recordtype rt : rts)
		{
			if ((rt.Name == 'Resident Referral') && (rt.SobjectType == 'Case_Issue__c'))
				refrtid = rt.Id;
			if ((rt.Name == 'Customer Group') && (rt.SobjectType == 'Account'))
				cgrtid = rt.Id;
		}
		
		list<Account> prevcgs = new list<Account>();
		for (Integer i = 0; i < 5; i++)
		{
			prevcgs.add(new Account(
				Name = 'caseperson ' + i + ' and other occupants',
				RecordtypeId = cgrtid));
		}
		insert prevcgs;
		
		//this CGU just moved out yesterday
		list<Customer_Group_to_Unit_Relationships__c> cgus = new list<Customer_Group_to_Unit_Relationships__c>();
		cgus.add(new Customer_Group_to_Unit_Relationships__c(
			Customer_Group__c = prevcgs[2].Id,
			Move_Out_Date__c = system.today().addDays(-1)));
		insert cgus;
		
		list<Contact> prevcons = new list<Contact>();
		for (Integer i = 0; i < 5; i++)
		{
			prevcons.add(new Contact(
				LastName = 'casetestcon ' + i,
				AccountId = prevcgs[i].Id));
		}
		insert prevcons;
		
		Account prevrefacc = new Account(
			Name = 'acc', 
			RecordtypeId = cgrtid);
		insert prevrefacc;
		
		//contact was referred previously by another person
		list<Contact> prevrefcons = new list<Contact>();
		prevrefcons.add(new Contact(
			LastName = 'casetestcon 1',
			AccountId = prevrefacc.Id));
		insert prevrefcons;
		
		list<Case> prevcases = new list<Case>();
		for (Integer i = 0; i < 5; i++)
		{
			prevcases.add(new Case(
				Subject = 'testsub',
				ContactId = prevcons[i].Id));
		}
		insert prevcases;
		
		list<Case_Issue__c> previssues = new list<Case_Issue__c>();
		Case_Issue__c prevci1 = new Case_Issue__c(
			Case__c = prevcases[1].Id,
			RecordtypeId = refrtId,
			Referred_Resident__c = prevcons[1].Id);
		previssues.add(prevci1);
		insert previssues;
		
		list<Account> refcgs = new list<Account>();
		for (Integer i = 0; i < 5; i++)
		{
			refcgs.add(new Account(
				Name = 'refperson ' + i + ' and other occupants',
				RecordtypeId = cgrtid));
		}
		insert refcgs;
		
		list<Contact> refcons = new list<Contact>();
		for (Integer i = 0; i < 5; i++)
		{
			refcons.add(new Contact(
				LastName = 'reftestcon ' + i,
				AccountId = refcgs[i].Id));
		}
		insert refcons;
		
		list<Case> testcases = new list<Case>();
		for (Integer i = 0; i < 5; i++)
		{
			testcases.add(new Case(
				Subject = 'testsub',
				ContactId = prevcons[i].Id));
		}
		insert testcases;
		
		list<Case_Issue__c> testissues = new list<Case_Issue__c>();
		//this contact is on a previously referred case issue
		Case_Issue__c newci0 = new Case_Issue__c(
			Case__c = testcases[0].Id,
			RecordtypeId = refrtId,
			Referred_Resident__c = prevcons[0].Id);
		testissues.add(newci0);
		//this issue has a move in date in the past
		Case_Issue__c newci1 = new Case_Issue__c(
			Case__c = testcases[1].Id,
			RecordtypeId = refrtId,
			Expected_Move_in_Date__c = system.today().addDays(-7),
			Referred_Resident__c = prevcons[1].Id);
		testissues.add(newci1);
		//this Contact is on a CG that moved out less than 30 days before the new move in
		Case_Issue__c newci2 = new Case_Issue__c(
			Case__c = testcases[2].Id,
			RecordtypeId = refrtId,
			Expected_Move_in_Date__c = system.today().addDays(7),
			Referred_Resident__c = prevcons[2].Id);
		testissues.add(newci2);
		
test.startTest();	
system.debug('\n\n125 inserting issues');	
		insert testissues;
test.stopTest();		
		list<Case> resultcases = [select Id, Warning_Message__c from Case where Id in :testcases];
		Integer checker = 1;
		for (Case c : resultcases)
		{
			if (c.Id == testcases[0].Id)
			{
				system.assertEquals('Applicant already referred by casetestcon 1', c.Warning_Message__c);
				checker *= 2;
			}
			if (c.Id == testcases[1].Id)
			{
				system.assertEquals('Applicant moved in prior to request', c.Warning_Message__c);
				checker *= 3;
			}
			if (c.Id == testcases[2].Id)
			{
				system.assertEquals('Prior Resident is not eligible for a referral bonus', c.Warning_Message__c);
				checker *= 5;
			}
			if (c.Id == testcases[3].Id)
			{
				
			}
			if (c.Id == testcases[4].Id)
			{
				
			}
		}
		system.assertEquals(2 * 3 * 5, checker);
	}
	
}//end class Test_CaseIssueTrigger