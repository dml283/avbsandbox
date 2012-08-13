public with sharing class CaseApproval {
	/* 
	Purpose:  	determine who should be the approving user on a Case	
	 
	Created By:  Jeremy Nottingham (Synaptic) 8/6/12
	  
	Last Modified By:  Jeremy Nottingham (Synaptic) 8/6/12
	 
	Current Version:  v1.2
	 
	Revision Log:  
	 			v1.0 - (JN 8/6/12) Created this Trigger
	 
	*/
	set<id> ownerids;
	public map<Id, User> userid2approvermap = new map<Id, User>();
	
	public static map<Id, Id> roleid2parentroleidmap = new map<Id, Id>();
	public static map<Id, UserRole> roleid2rolemap;
	
	static map<String, String> profname2jobmap = new map<String, String>
	{
		'' => 'CC user',
		'' => 'CSM user',
		'' => 'CM user',
		'' => 'CSO Specialist',
		'' => 'CSO Manager',
		'' => 'CSO Sr. Mgr/Director',
		'Retail' => 'Retail User'
	
	};
	
	static map<String, String> job2rolewordmap = new map<String, String>
	{
		'' => 'CC user',
		'' => 'CSM user',
		'' => 'CM user',
		'POD user' => 'POD',
		'VP user' => 'VP',
		'' => 'CSO Specialist',
		'' => 'CSO Manager',
		'' => 'CSO Sr. Mgr/Director'
	};
	
	public CaseApproval(set<Id> ownerids)
	{
		this.ownerids = ownerids;
		
		//map out role hierarchy
		mapRoles();
		
		//map map of user id to approver id
		//determineApprovers();
	}
	
	private void determineApprovers()
	{
		//query for owners
		map<Id, User> userid2usermap = new map<Id, User>([
			select Id, Username, UserRoleId, UserRole.Name, ProfileId, Profile.Name 
			from User 
			where Id in :ownerids]);
		
		for (User u : userid2usermap.values()) 
		{
			//Determine proper approver based on attributes of the user
			//CSM user
			if (u.Username.toLowerCase().contains('_csm'))
			{
				//routes to CM
			} 
			
			//CM user
			else if (u.Username.toLowerCase().contains('_cm'))
			{
				//routes to POD
			} 
//TODO			
			//CC User
			else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CC user'))
			{
				//routes to CM
			} 
			
			//POD User
			else if (u.UserRole.Name.toLowerCase().contains(job2rolewordmap.get('POD user')))
			{
				//no approval necessary, just put the user in as their own approver
				userid2approvermap.put(u.Id, u);
			} 
			
			//VP User
			else if (u.UserRole.Name.toLowerCase().contains(job2rolewordmap.get('VP user')))
			{
				//no approval necessary, just put the user in as their own approver
				userid2approvermap.put(u.Id, u);
			} 
//TODO			
			//CSO Specialist
			else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CSO Specialist'))
			{
				//routes to manager	
			} 
//TODO			
			//CSO Manager
			else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CSO Manager'))
			{
				//routes to manager
			} 
//TODO			
			//CSO Sr Mgr/Director
			else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('CSO Sr. Mgr/Director'))
			{
				//no approval necessary, just put the user in as their own approver
				userid2approvermap.put(u.Id, u);
			} 
//TODO			
			//Retail User
			else if (profname2jobmap.get(u.Profile.Name).equalsIgnoreCase('Retail User'))
			{
				//routes to manager
			}
		}
			
	}
	
	private void mapRoles()
	{
		CaseApproval.roleid2parentroleidmap = new map<Id, Id>();
		//get Role Hierarchy
		roleid2rolemap = new map<Id, UserRole>([
			select Id, ParentRoleId
			from UserRole]);
		
		for (UserRole role : roleid2rolemap.values())
		{
			CaseApproval.roleid2parentroleidmap.put(role.Id, role.ParentRoleId);
		}
	}
	
	public static void checkNeedsApprovalOnIssues(list<Case_Issue__c> issues)
	{
		set<Id> caseids = new set<Id>();
		for (Case_Issue__c issue : issues)
		{
			caseids.add(issue.Case__c);
		}
		map<Id, Case> caseid2casemap = new map<Id, Case>([select Id, OwnerId
			from Case 
			where Id in :caseids]);
		
		//ownerids = new set<Id>();
		//for (Case c : caseid2casemap.values()) 
		//	ownerids.add(c.OwnerId);
		
		//map<Id, 
		for (Case_Issue__c issue : issues)
		{
			if (issue.Charge_Type__c == 'this')
			{
				
			} else if (issue.Charge_Type__c == 'this')
			{
				
			} 
		}
		
	}
}