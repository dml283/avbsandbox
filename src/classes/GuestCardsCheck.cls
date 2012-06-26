global class GuestCardsCheck {
 /*
    Purpose:   - On a nightly basis, any Guest Cards that meet certain conditions will be 
               automatically changed to "Inactive" status. A scheduled class will call this 
               class method to perform this check.
          
    Created By:   Jeremy Scott (Synaptic) 1/26/2012
  
    Last Modified By:   Jeremy Nottingham (Synaptic) 2/15/12
        
    Current Version:   v1.1
  
    Revision Log:   v1.0 - (JS 1/26/2012) Set up class with header and methods
                    v1.1 - (JN 2/15/12) Change move in date field in query string, fix test method

  
  */    
  
    public static Date todayMinusThirty = system.Today().addDays(-30);
    public static Date todayMinusSixty = system.Today().addDays(-60);

/*
    public static Date todayMinusThirty = system.Today().addDays(-3);
    public static Date todayMinusSixty = system.Today().addDays(-6);
*/
         
    //public static String checkGCQuery = 'select Id from Guest_Card__c where Initial_Lead_Type__c = \'Independent Lead Source\''
    public static String checkGCQuery = 'select Id from Guest_Card__c where Initial_Lead_Type__c = \'Email\''
                                        + ' AND ((When_will_you_be_moving_in__c != Null AND LastActivityDate <= :todayMinusThirty)'
                                        + ' OR (When_will_you_be_moving_in__c = Null AND LastActivityDate <= :todayMinusSixty))';
    
    public static void checkGuestCards ()
    {
        
system.debug('\n\n30 checkGCQuery ' + checkGCQuery);
		if (Test.IsRunningTest())
			checkGCQuery += ' limit 100';
        //collect a list of records that need to be inactivated
        List <Guest_Card__c> InactiveGCs = Database.query(checkGCQuery);
        
        for (Guest_Card__c gc :InactiveGCs)
        {
            gc.Status__c = 'Inactive';
            //gc.Inactive_Reason__c = 'Non Response/Unknown';
            gc.Inactive_Reason__c = 'Auto Inactivated';
        }
        
        update inactiveGCs;  
    }
    
    
    public static testMethod void testGuestCardCheck() {  
        
        Guest_Card__c gc = new Guest_Card__c ();
           gc.Name = 'test';
           gc.Rating__c = '1';
           gc.Initial_Lead_Type__c = 'Independent Lead Source';
           gc.Inactive_Reason__c = null;
           gc.When_will_you_be_moving_in__c = null;
           gc.AVB_Associate__c = 'avb assoc';
           gc.Status__c = 'Active';
           insert gc;
           
test.startTest();       
        GuestCardsCheck.checkGCQuery = 'select Id from Guest_Card__c where id = \'' + gc.Id + '\'';
        GuestCardsCheck.checkGuestCards();
test.stopTest();
        
        gc = [select Status__c, Inactive_Reason__c from Guest_Card__c where Id = :gc.Id];
        system.assertEquals('Inactive', gc.Status__c);  
        system.assertEquals('Auto Inactivated', gc.Inactive_Reason__c); 
                
        
    }
}