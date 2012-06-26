@isTest 

private class Test_AddGuestCard {
	
	    static testmethod void testSearch()
    {
        //just in case somebody else has this email address
        list<Guest_Card__c> gcstodelete = [select Id from Guest_Card__c where Email__c = 'test@avalonbay.com.test'];
        delete gcstodelete;
        
        
        list<Guest_Card__c> testgcs = new list<Guest_Card__c>();
        for (Integer i = 0; i < 1; i++)
        {
            Guest_Card__c testgc = new Guest_Card__c(
                Email__c = 'test@avalonbay.com.test',
                AVB_Associate__c = 'avb assoc',
                Cell_Phone__c = '5555555555',
                Address_City__c = 'testVille',
                Address_State__c = 'TE',
                Home_Phone__c = '5555555555');
                
            testgcs.add(testgc);
        }
        insert testgcs;
        
        Contact c = new Contact();
        c.FirstName = 'testFirst';
        c.LastName = 'testLast';
        
        insert c;
        
        
        //create user
        Profile p = [select id from profile where name='System Administrator'];
 
        User user = new User(alias = 'test123', email='test123xyzzz@noemailqq.com',
            emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id, country='United States', department='CCC',
            timezonesidkey='America/Los_Angeles', username='test123xyzzz@noemailqq.com');
        insert user;
        
        //create community account
                
        Account commAccount = new Account ();
        commAccount.RecordTypeId = [select Id from RecordType where Name = 'Community' and SObjectType = 'Account'].Id;
        commAccount.Account_ID__c = 'ABC123';
        commAccount.Name = 'test account';
        commAccount.Community_ID__c = 'XYZ';
        commAccount.OwnerId = user.Id;
        
        insert commAccount;
        
     	
       //create mri leasing ass account - associate to user
       
       MRILeasingAssociate__c mri = new MRILeasingAssociate__c ();
       mri.LeasingAssociateID__c = 'tMcGee';
       mri.LeasingAssociateName__c = 'Tester McGee';
       mri.LeasingAssociatePrimaryCommunity__c = 'ABC123';
       mri.SalesforceUserAccount__c = user.Id;
       mri.IsLeasingAssociateActive__c = True;
       
       insert mri;
       
system.debug('\n\n619 mri' + mri);
       
       //system.runas(usercreated) { put all the code in here }
        

        
test.startTest();

//run test as user created
system.runas(user){
	

        Ctl_AddGuestCard agc = new Ctl_AddGuestCard();
        agc.searchGC.Email__c = 'test@avalonbay.com.test';
        

        agc.doSearch();

      
        system.assertEquals(null, agc.doSearch());
        //confirm pulled correct search results
        list<Ctl_AddGuestCard.SearchResult> theseresults = agc.searchResults;
        
        system.assertEquals(1, theseresults.size());
        system.assertEquals(theseresults[0].gc.Id, testgcs[0].Id);
        
        system.assertEquals(null, agc.clearPage());
        //confirm all cleared out
        system.assertEquals(null, agc.searchGC.Email__c);
        theseresults = agc.searchResults;
        system.assertEquals(null, theseresults);
        
        //system.assertNotEquals(null, agc.saveGC());
        
        Ctl_AddGuestCard cagc = new Ctl_AddGuestCard();
        cagc.searchContact.LastName = 'testLast';
        cagc.searchContact.FirstName = 'testFirst';
        cagc.doSearch();
        
        Ctl_AddGuestCard cagc2 = new Ctl_AddGuestCard();
        cagc2.searchGC.Cell_Phone__c = '(555) 555-5555';
        cagc2.searchGC.Home_Phone__c = '5555555555';
        cagc2.searchGC.Address_City__c = 'testVille';
        cagc2.searchGC.Address_State__c = 'TE';
        cagc2.doSearch();
        
        Ctl_AddGuestCard cagc22 = new Ctl_AddGuestCard();
        cagc22.searchGC.Cell_Phone__c = '(555) 555-5555';
        cagc22.doSearch();
        
        Ctl_AddGuestCard cagc23 = new Ctl_AddGuestCard();
        cagc23.searchGC.Home_Phone__c = '(555) 555-5555';
        cagc23.doSearch();
        
        Ctl_AddGuestCard cagc24 = new Ctl_AddGuestCard();
        cagc24.searchGC.Address_City__c = 'testVille';
        cagc24.doSearch();
        
        Ctl_AddGuestCard cagc25 = new Ctl_AddGuestCard();
        cagc25.searchGC.Address_State__c = 'TE';
        cagc25.doSearch();
        
        PageReference pageRef = Page.SearchAddGuestCard;
	    Test.setCurrentPageReference(pageRef);
	    
        Ctl_AddGuestCard agc2 = new Ctl_AddGuestCard();
        agc.newGuestCard();
        
        //pull up edit page
        PageReference pageRef2 = Page.EditGuestCard;
        Test.setCurrentPageReference(pageRef2);
        
        agc.thisContact.FirstName = 'testFirst';
        agc.thisContact.LastName = 'testLast'; 
		agc.thisGC.Bed__c = decimal.Valueof(2);
		agc.thisGC.Bath__c = decimal.Valueof(2);
		agc.thisGC.Class_ID__c = '0';
		agc.thisGC.When_will_you_be_moving_in__c = system.Today();
		agc.thisGC.Email__c = 'test@noemailavb.com';
		agc.thisGC.Home_Phone__c = '(555) 555-5555'; 
		agc.thisGC.Cell_Phone__c = '(555) 555-5555';
		agc.thisGC.Work_Phone__c = '5555555555';
		agc.thisGC.Work_Phone_2__c = '5555555555'; 
		agc.thisGC.How_did_you_hear_about_us__c = 'testing';
		agc.thisGC.Secondary_Marketing_Source__c = 'testing'; 
		agc.thisGC.Initial_Visit_Date__c = system.Now();
		agc.thisGC.Inactive_Reason__c = 'Location';
		agc.thisGC.Class_ID__c = '0';
		agc.thisGC.Where_else_did_you_lease__c = 'testing'; 
		agc.thisGC.Level_One_Appointment_Created__c = True;
		agc.thisGC.When_will_you_be_moving_in__c = system.Today();
		agc.thisGC.Reason_for_relocating__c = 'testing'; 
		agc.thisGC.Lease_term_desired__c = 'testing'; 
		agc.thisGC.Other_communities_being_considered__c = 'testing'; 
		agc.thisGC.Price_Range_Desired__c = '1'; 
		agc.thisGC.How_Many_Occupants__c = '1'; 
		agc.thisGC.What_is_most_important_to_you__c = 'testing'; 
		agc.thisGC.Have_a_pet_other_than_a_service_animal__c = 'Yes';
		agc.thisGC.What_features_are_most_important__c = 'test';
		agc.thisGC.Pet_Type_Breed__c = 'testing'; 
		agc.thisGC.Guest_Card_Details__c = 'testing'; 
		agc.thisGC.Email__c = 'test@noemail.com';
		agc.thisGC.Address_Street_1__c = '123 Test St';
		agc.thisGC.Address_Street_2__c = '123 Test St';
		agc.thisGC.Address_City__c = 'testville';
		agc.thisGC.Address_State__c = 'VA';
		agc.thisGC.Fax__c = '5555555555';
		agc.thisGC.Address_Postal_Code__c = '24515';
		agc.thisGC.Other_residents__c = 'test';
		agc.thisGC.Other_resident_phone__c  = '5555555555';
		agc.thisGC.Other_resident_email_s__c = 'test@noemail.com';
		
system.debug('\n\n177 saving now');		
		agc.saveGC();
		agc.cancelGC();
		
		       
	List<Guest_Card__c> returnlist = [select Id, Community__c, OwnerId, MRI_Leasing_Associate__c, 
		AVB_Associate__c, Name, Home_Phone__c, Email__c 
		from Guest_Card__c 
		where Community__c = :commAccount.ID];
	
system.debug('\n\n702 returnlist' + returnlist);
	
	//confirm size of returnlist
		system.assertEquals(1, returnlist.size());
	
	//confirm Community was populated
        system.assertEquals(commAccount.ID, returnlist[0].Community__c);

    	//confirm MRI Leasing Associate was populated
        system.assertEquals(mri.ID, returnlist[0].MRI_Leasing_Associate__c);
            
	//confirm Owner was populated
        system.assertNotEquals(null, returnlist[0].OwnerId);    

	returnlist[0].Bed__c = decimal.Valueof(3);
	
	update returnlist;
	
}   
    
test.stopTest();   


	
	}
	
	static testmethod void testClone()
    {
    	//create user
        Profile p2 = [select id from profile where name='System Administrator'];
 
        User user2 = new User(alias = 'test123', email='test123xyzzz@noemailqq.com',
            emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p2.Id, country='United States', department='CCC',
            timezonesidkey='America/Los_Angeles', username='test123xyzzz@noemailqq.com');
        insert user2;
        
       Contact c = new Contact ();
       c.FirstName = 'testFirst';
       c.LastName = 'testLast';
       
       insert c;
        
     
       Guest_Card__c gc = new Guest_Card__c ();
       gc.Name = 'test';
       gc.Rating__c = '1';
       gc.Initial_Lead_Type__c = 'Independent Lead Source';
       gc.Inactive_Reason__c = null;
       gc.When_will_you_be_moving_in__c = null;
       gc.AVB_Associate__c = 'avb assoc';
       gc.Status__c = null;
       
       insert gc;
       
       Guest_Card__c gc2 = new Guest_Card__c ();
       gc2.Name = 'test';
       gc2.Rating__c = '1';
       gc2.Initial_Lead_Type__c = 'Independent Lead Source';
       gc2.Inactive_Reason__c = null;
       gc2.When_will_you_be_moving_in__c = null;
       gc2.AVB_Associate__c = 'avb assoc';
       gc2.Status__c = null;
       gc2.Contact__c = c.Id;
       
       insert gc2;
       
       test.startTest();

//run test as user created
system.runas(user2){
	
		Pagereference pageRef = Page.EditGuestCard;
		Test.setCurrentPage(pageRef);
		
		ApexPages.currentPage().getParameters().put('Id', gc.Id);
		ApexPages.currentPage().getParameters().put('mode', 'clone');
		Ctl_AddGuestCard cagc = new Ctl_AddGuestCard();
		cagc.cloneGC();
		
		//test clone when contact is != Null		
		Pagereference pageRef2 = Page.EditGuestCard;
		Test.setCurrentPage(pageRef2);
		
		ApexPages.currentPage().getParameters().put('Id', gc2.Id);
		ApexPages.currentPage().getParameters().put('mode', 'clone');
		Ctl_AddGuestCard cagc2 = new Ctl_AddGuestCard();
		cagc2.cloneGC();
	
	
		test.stopTest();   
	
	
		}
    }
    
    static testmethod void testEdit()
    {
    	//create user
        Profile p3 = [select id from profile where name='System Administrator'];
 
        User user3 = new User(alias = 'test123', email='test123xyzzz@noemailqq.com',
            emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p3.Id, country='United States', department='CCC',
            timezonesidkey='America/Los_Angeles', username='test123xyzzz@noemailqq.com');
        insert user3;
        
     
       Guest_Card__c gc2 = new Guest_Card__c ();
       gc2.Name = 'test';
       gc2.Rating__c = '1';
       gc2.Initial_Lead_Type__c = 'Independent Lead Source';
       gc2.Inactive_Reason__c = null;
       gc2.When_will_you_be_moving_in__c = null;
       gc2.AVB_Associate__c = 'avb assoc';
       gc2.Status__c = null;
       
       insert gc2;
       
       test.startTest();

//run test as user created
system.runas(user3){
	
		Pagereference pageRef = Page.EditGuestCard;
		Test.setCurrentPage(pageRef);
		
		ApexPages.currentPage().getParameters().put('Id', gc2.Id);
		ApexPages.currentPage().getParameters().put('mode', 'edit');
		Ctl_AddGuestCard cagc2 = new Ctl_AddGuestCard();
		gc2.Cell_Phone__c = '5555555555';
		gc2.Home_Phone__c = '5555555555';
		
		cagc2.saveGC();
		
		ApexPages.currentPage().getParameters().put('Id', gc2.Id);
		ApexPages.currentPage().getParameters().put('mode', null);
		Ctl_AddGuestCard cagc3 = new Ctl_AddGuestCard();
		cagc3.saveGC();
		
		
		ApexPages.currentPage().getParameters().put('mode', 'clone');
		Ctl_AddGuestCard cagc4 = new Ctl_AddGuestCard();
		
	
		test.stopTest();   
	
	
		}
    }
    
    static testmethod void testValidation()
    {
    	//create user
        Profile p4 = [select id from profile where name='System Administrator'];
 
        User user4 = new User(alias = 'test123', email='test123xyzzz@noemailqq.com',
            emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p4.Id, country='United States', department='CCC',
            timezonesidkey='America/Los_Angeles', username='test123xyzzz@noemailqq.com');
        insert user4;
        
     
       Guest_Card__c gc3 = new Guest_Card__c ();
       gc3.Name = 'test';
       gc3.Rating__c = '1';
       gc3.Initial_Lead_Type__c = 'Independent Lead Source';
       gc3.Inactive_Reason__c = null;
       gc3.When_will_you_be_moving_in__c = null;
       gc3.AVB_Associate__c = 'avb assoc';
       gc3.Status__c = null;

       
       insert gc3;
       
       test.startTest();

//run test as user created
system.runas(user4){
	
		PageReference pageRef = Page.SearchAddGuestCard;
	    Test.setCurrentPageReference(pageRef);
	    
        Ctl_AddGuestCard agc4 = new Ctl_AddGuestCard();
        agc4.newGuestCard();
        
        //pull up edit page
        PageReference pageRef3 = Page.EditGuestCard;
        Test.setCurrentPageReference(pageRef3);
        
        agc4.thisContact.FirstName = 'testFirst';
        agc4.thisContact.LastName = 'testLast'; 
		agc4.thisGC.Bed__c = decimal.Valueof(2);
		agc4.thisGC.Bath__c = decimal.Valueof(2);
		agc4.thisGC.Rating__c = '0';
		agc4.thisGC.Class_Id__c = '0';
		agc4.thisGC.Initial_Visit_Date__c = system.Today().addDays(-4);
		
		agc4.saveGC();
		
		ApexPages.Message[] msgs=ApexPages.getMessages();
		Boolean found=false;
		
		
	
	test.stopTest();   
}
    	
    }

}