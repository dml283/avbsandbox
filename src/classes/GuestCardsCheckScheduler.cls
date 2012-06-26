global class GuestCardsCheckScheduler implements Schedulable{
 /*
  Purpose:   - On a nightly basis, any Guest Cards that meet certain conditions will be 
  			   automatically changed to "Inactive" status. A scheduled class will call this 
  			   class method to perform this check.
          
  Created By:   Jeremy Scott (Synaptic) 1/26/2012
  
    
  Current Version:   v1.1
  
  Revision Log:    	v1.0 - (JN 1/26/2012) Set up class with header and methods
  					v1.1 - (JN 2/15/12) Fixed testmethod, changed move in date field in querystring.

  
  */	
  
    global void execute(SchedulableContext ctx)
    {
       GuestCardsCheck.checkGuestCards();
    } 

	public static testMethod void testschedule() 
	{  

       	Test.StartTest();
		GuestCardsCheckScheduler gccs = new GuestCardsCheckScheduler();
		String sch = '0 0 23 * * ?';        
		system.schedule('Guest Card Deactivates', sch, gccs);
		Test.stopTest(); 
		
	}
	

}