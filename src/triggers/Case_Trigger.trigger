trigger Case_Trigger on Case (before insert, before update) {
	/*
	Purpose:  	After	
	 				Determine who should be the case approver and populate the Case Approver field on Case
	 				
	Created By:  Jeremy Nottingham (Synaptic) 8/6/12
	  
	Last Modified By:  Jeremy Nottingham (Synaptic) 8/6/12
	 
	Current Version:  v1.2
	 
	Revision Log:  
	 			v1.0 - (JN 8/6/12) Created this Trigger
	 
	*/
	
	if (Trigger.IsAfter)
	{
		set<Id> ownerids = new set<Id>();
		set<Id> caseidstogetapproval = new set<id>();
		String userprefix = '005';
		
		for (Case c : Trigger.new)
		{
			//get ownerids for new cases or if the owner has changed, only for users not queues
			if ((String.valueOf(c.OwnerId).substring(0,3) == userprefix)
				&& ((Trigger.IsInsert) 
				|| (Trigger.newmap.get(c.Id).OwnerId != Trigger.oldmap.get(c.Id).OwnerId)))
			{
				ownerids.add(c.OwnerId);
				caseidstogetapproval.add(c.Id);
			}	
		}
		
		CaseApproval ca = new CaseApproval(ownerids);
		
		
		for (Case c : Trigger.new)
		{
			if (caseidstogetapproval.contains(c.Id))
				c.Case_Approver__c = ca.userid2approvermap.get(c.OwnerId).Id;
		}
	}
}