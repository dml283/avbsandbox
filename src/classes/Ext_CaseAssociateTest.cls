@isTest
private class Ext_CaseAssociateTest {

	static testmethod void Ext_CaseAssociate()
	{
  
		Profile p = [select id from profile where name like 'CCC%' limit 1];
		
		User user1=new User(alias = 'test123', email='test7805678442@avalonbay.com.blueberry',
		            emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
		            localesidkey='en_US', profileid = p.Id, country='United States', department='CCC',
		            timezonesidkey='America/Los_Angeles', username='1test7805678442@avalonbay.com.blueberry');
		User user2=new User(alias = 'test123', email='test7805678442@avalonbay.com.blueberry',
		            emailencodingkey='UTF-8', lastname='Testing', languagelocalekey='en_US',
		            localesidkey='en_US', profileid = p.Id, country='United States', department='CCC',
		            timezonesidkey='America/Los_Angeles', username='2test7805678442@avalonbay.com.blueberry');
		list<User> users = new list<User>{ user1, user2 };
		insert users;     
		
		Account account = new Account();// specify all the required fields
		account.name = 'testing';
		insert account;
		
		Contact contact = new Contact();// specify all the required fields
		contact.lastname = 'test';
		insert contact;
		
		Case ca = new Case();
		ca.accountId = account.Id;
		ca.contactId = contact.Id;
		ca.Referred_Resident__c = contact.Id;
		insert ca;
		
		Case_Associate__c testcas = new Case_Associate__c(
			Case__c = ca.Id,
			User__c = user1.Id);
		insert testcas;
		
	    PageReference pageRef = Page.caseuserselect;       
	    pageRef.getParameters().put('id' , ca.id);
	    Test.setCurrentPageReference(pageRef);
	      
        ApexPages.StandardController controller = new ApexPages.StandardController(ca);
        Ext_CaseAssociate sc = new Ext_CaseAssociate(controller); 
	   
	    list<Ext_CaseAssociate.cUser> userList = sc.getusers();
	    // assert statement that userList has been created
	    System.assert(userList.size()>0);
	    //verify User1 is excluded from query
	    Boolean foundUser1 = FALSE;
	    for (Ext_CaseAssociate.cUser cuser : userList)
	    {
	    	if (cuser.use.Id == user1.Id)
	    	{
	    		foundUser1 = TRUE;
	    		break;
	    	}
	    }
	    system.assertEquals(FALSE, foundUser1);
	    
	    sc.userList[0].selected=True; 
	    string userIndex=sc.userList[0].use.ID; 
		
	    sc.processSelected();  
	    List <Case_Associate__c> calist = [select Id, User__c, Case__c from Case_Associate__c where Case__c = :ca.Id and User__c != :user1.Id];
	    System.assertequals (1,calist.size());
	    System.assertequals (userIndex, calist[0].User__c);
    
		PageReference pageRe = sc.cancel();
	    System.assertNotEquals(Null,pageRe);
	    
	}

}