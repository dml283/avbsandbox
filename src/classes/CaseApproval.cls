public with sharing class CaseApproval {
	/*
	Purpose:  	determine who should be the approving user on a Case	
	 
	Created By:  Jeremy Nottingham (Synaptic) 8/6/12
	  
	Last Modified By:  Jeremy Nottingham (Synaptic) 8/6/12
	 
	Current Version:  v1.2
	 
	Revision Log:  
	 			v1.0 - (JN 8/6/12) Created this Trigger
	 
	*/
	public list<Case> cases;
	public set<Id> caseids;
	public map<Id, User> caseid2approvermap;
	public map<Id, User> userid2approvermap;
	
	public static map<Id, Id> roleid2parentroleidmap;
	
	public CaseApproval(list<Case> cases)
	{
		this.cases = cases;
		caseids = new set<Id>();
		for (Case c : cases)
		{
			caseids.add(c.Id);
		}
		mapRoles();
		//determineCaseApprovers();
	}
	
	private void determineCaseApprovers()
	{
		set<Id> ownerids = new set<Id>(); //User Id
		for (Case c : cases)
		{
			//collect owner ids
			ownerids.add(c.OwnerId);
		}
		
		//query for owners
		map<Id, User> userid2usermap = new map<Id, User>([
			select Id, UserRoleId, ProfileId, Profile.Name
			from User 
			where Id in :ownerids]);
		
		for (User u : userid2usermap.values()) 
		{
			//Determine proper approver based on attributes of the user
			if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CC user'))
			{
				//routes to CM
			} else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CSM user'))
			{
				//routes to CM
			} else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CM user'))
			{
				//routes to POD
			} else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('POD user'))
			{
				//no approval necessary
			} else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('VP user'))
			{
				//no approval necessary
			} else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CSO Specialist'))
			{
				//routes to manager	
			} else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CSO Manager'))
			{
				//routes to manager
			} else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CSO Sr. Mgr/Director'))
			{
				//no approval necessary	
			} else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('Retail User'))
			{
				//routes to manager
			}
		}
			
	}
	
	private void mapRoles()
	{
		CaseApproval.roleid2parentroleidmap = new map<Id, Id>();
		//get Role Hierarchy
		map<Id, UserRole> allroles = new map<Id, UserRole>([
			select Id, ParentRoleId
			from UserRole]);
		
		for (UserRole role : allroles.values())
		{
			CaseApproval.roleid2parentroleidmap.put(role.Id, role.ParentRoleId);
		}
	}
}





