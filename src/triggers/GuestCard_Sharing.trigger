trigger GuestCard_Sharing on Guest_Card__c (before insert, before update, after insert, after update) {
    /*
    Purpose:    Runs after insert and after update on Guest_Card__c. 
                AFTER: - Uses Guest_Card_share object to share guest card with the correct list of users, 
                         based on role hierarchy: All users in portfolio region (under same SPOD) have Read-Only, Community Users (same role) have Read-Write
                        - If IsUpdate and Initial_Lead_Type__c is changed, and Initial_Lead_Type__c == 'Email' // or Initial_Lead_Type__c = 'Walk In'
                            Find Initial Followup Task and close it.
                        - If IsUpdate and (MRI Leasing Associate or AVB_Associate__c is changed)
                            Change AVB_Associate_First_Last_Name__c on all Events and Tasks for that GC, regardless of Initial Visit Date
                       		Populate on parent Customer Group Account
                        - If IsInsert and Initial_Lead_Type__c != 'Email' //REMOVED and != 'Walk In'
                            Create Initial Follow Up Task
                        - If MRI Leasing Associate is changed
                            
                BEFORE: - Also validates that there can be only one Guest Card for each Community/Customer Group combo.
                		- If Needs_Contact__c checkbox has been unchecked, change Owner to the Community
    					- If (IsInsert) OR (IsUpdate and MRI Leasing Associate is changed)
                            Change AVB_Associate__c on triggering Guest Card to match name from MRI Leasing Associate
                       		
    Created By:     Jeremy Nottingham (SAP) - 2/16/2011
    
    Last Modified By:   Jeremy Nottingham (SAP) - 3/30/2012
    
    Current Version:    v1.8
    
    Revision Log:       v1.0 - (JN) Created trigger and header.
                        v1.1 - (JN 3/20/11) Added validation for 1 Guest Card per Customer Group/Community combo
                        v1.2 - (JN 3/30/11) Changed sharing region / role hierarchy logic. Now using role containing SPOD as top of readonly sharing region
                        v1.3 - (JN 4/20/11) Removed Initial Task creation, as this functionality will be performed by the RMAction trigger. 
                             - Also modified related test method. Coverage 100%
                        v1.4 - (JN 5/3/11) Added Initial Followup task creation back in.
                        v1.5 - (JN 9/15/11) Now skipping initial followup Task creation if GC is inserted as "Leased"
                        v1.6 - (JN 9/23/11) Added logic to close Initial Followup Task automatically if Initial Lead Type changes to 'Email' or 'Walk In'
                             - Added logic to pass changed AVB Associate to Tasks and Events
                        v1.7 - (JN 9/30/11) 
                        v1.8 - (JN 3/30/12) Added MRI Leasing Associate support, removed Initial Visit Date requirement

    */

/*  AFTER  */    
    if (Trigger.IsAfter) {
        /*  Fix Sharing  */
    	set<id> ownerGCIds = new set<Id>(); //GCs that are new or have had the OwnerId changed
        set<id> EmailGCids = new set<Id>(); //GCs that have been made Initial Lead Type of 'Email' or 'Walk In'
        set<id> AVBAssocGCids = new set<Id>(); //GCs that have had AVB Associate/MRI Leasing Associate changed
        
        set<Id> ownerids = new set<id>(); //owners from affected GCs
        set<id> affectedRoleIds = new set<Id>(); //User Ids
        
        map<id, set<id>> ownerid2readwriteidset = new map<id, set<Id>>(); //map of user Id to a set of Ids from the users that can readwrite this user's records
        map<id, set<id>> ownerid2readonlyidset = new map<id, set<Id>>();//map of user Id to a set of Ids from the users that can only read this user's records
        
        list<Guest_Card__Share> gcsharestoinsert = new list<Guest_Card__Share>();
        list<Guest_Card__Share> gcsharestodelete = new list<Guest_Card__Share>(); 
        
        map<id, set<Id>> spodid2subrolesmap = new map<id, set<id>>(); //Id of spod Role to set of Role Ids from subordinate Roles
        map<id, id> roleid2spodroleidmap = new map<id, id>(); //Role Id to parent/top spod Role Id 
        map<id, list<User>> roleid2usersmap = new map<id, list<User>>(); //Role Id to list of users who have that role
        
        //Get OwnerIds and Guest Card Ids if we need to do any sharing modification on the record
        for (Guest_Card__c gc : Trigger.new) {
            if ((Trigger.IsInsert) || (Trigger.oldmap.get(gc.id).OwnerId != Trigger.newmap.get(gc.id).OwnerId))
            {
                ownerGCIds.add(gc.id);
                ownerids.add(gc.OwnerId);
            }
            
            //get GCs to find initial followup tasks to close
            if ((Trigger.IsUpdate)
                && (Trigger.oldmap.get(gc.id).Initial_Lead_Type__c != Trigger.newmap.get(gc.id).Initial_Lead_Type__c)
                && ((gc.Initial_Lead_Type__c == 'Email')))
                    //removed 031212 JN|| (gc.Initial_Lead_Type__c == 'Walk In')))
            {
                EmailGCids.add(gc.id);
            }
        
            //get GCs to change AVB Associate name
            if ((Trigger.IsUpdate)
                && ((Trigger.oldmap.get(gc.id).MRI_Leasing_Associate__c != Trigger.newmap.get(gc.id).MRI_Leasing_Associate__c)
                	|| (Trigger.oldmap.get(gc.id).AVB_Associate__c != Trigger.newmap.get(gc.id).AVB_Associate__c)))
            {
                AVBAssocGCids.add(gc.id);
            }
        }
        
        list<User> owners = [select id, Name, UserRoleId, UserRole.Name, ProfileId, Profile.Name from User where id in :ownerids];
        map<id, User> ownerid2usermap = new map<id, User>(owners);
        
        //get set of Roles going
        for (User u : owners) {
            affectedRoleIds.add(u.UserRoleId);
        }
        
        
        //Map role hierarchy, paying attention to portfolio management segmentation. populate map of Sspod id to subordinate role Ids
        list<UserRole> roles = [select id, ParentRoleId, Name from UserRole];
        map<id, UserRole> roleid2rolemap = new map<id, UserRole>(roles);
        
        //initialize spodid2subrolesmap with spod role Ids
        for (UserRole role : roles) {
            roleid2spodroleidmap.put(role.Id, null);
            
            if (role.Name.contains('SPOD')) {
                spodid2subrolesmap.put(role.id, new set<id>());
            }
        }
         
        Id currentId;
        Id parentId;
        set<id> otherRoleIds = new set<id>();
        for (UserRole role : roles) {
            currentId = role.id;
            Boolean spodFound = false;
            
            //If this is a spod, or it's not in our list of affected roles, go to the next record
            if ((spodid2subrolesmap.containsKey(role.id))) {
                otherRoleIds.add(role.id);  
                continue;
            }
            
            //climb the hierarchy until you find a spod, then put this role id into the set for that spod and go to the next role
            while (spodFound == false){
                //If this role has a parentId, it will be in a spod
                if (roleid2rolemap.get(currentId).parentRoleId != null) {
                    parentId = roleid2rolemap.get(currentId).parentRoleId;
                } else {
                    //if no ParentId, keep this role to use later
                    otherRoleIds.add(currentId);
                    break; 
                }
                if (spodid2subrolesmap.containsKey(parentId)) {
                    spodFound = true;
                    roleid2spodroleidmap.put(role.id, parentId);
                    spodid2subrolesmap.get(parentId).add(role.id);
                } else {
                    currentId = parentId;
                }
            }
        }
        
        //get all Role Ids that will be affected
        for (Id spodId : spodid2subrolesmap.keyset()) {
            if (spodid2subrolesmap.get(spodId).size() > 0) {
                affectedRoleIds.add(spodId);
                affectedRoleIds.addall(spodid2subrolesmap.get(spodId));
            }
        }
        //add Roles for users not in a spod
        affectedRoleIds.addall(otherRoleIds);
        
        list<User> affectedusers = [select id, Name, UserRoleId from User where UserRoleId in :affectedRoleIds and IsActive = TRUE]; //edited for only Active users 3/21
        for (User u : affectedusers) {
            if (roleid2usersmap.containsKey(u.UserRoleId)) {
                roleid2usersmap.get(u.UserRoleId).add(u);
            } else {
                roleid2usersmap.put(u.UserRoleId, new list<User>{ u });
            }
        }

        //go through affected GCs and delete all Guest_Card__shares (if any) and create Guest_Card__share records for all readwrite and readonly users
         
        //delete existing Sharing entries on this Guest Card
        list<Guest_Card__Share> gcshares = [select  UserOrGroupId, RowCause, ParentId, Id 
            from Guest_Card__Share 
            where ParentId in :ownerGCIds
                and (RowCause = :Schema.Guest_Card__Share.RowCause.Community__c
                    or RowCause = :Schema.Guest_Card__Share.RowCause.POD__c)];
        delete gcshares;
        
        //Go through affected GCs and add sharing rules
        gcshares = new list<Guest_Card__Share>();
        for (Id gcid : ownerGCIds) {
            Guest_Card__c gc = Trigger.newmap.get(gcid);
            if (ownerid2usermap.containsKey(gc.OwnerId))
            {
	            User Owner = ownerid2usermap.get(gc.OwnerId);
	            Id spodRoleId = roleid2spodroleidmap.get(Owner.UserRoleId);
	
	            //ReadWrite users: same Role as owner
	            if ((Owner.UserRoleId != null) && (roleid2usersmap.get(Owner.UserRoleId) != null)){
	                for (User u : roleid2usersmap.get(Owner.UserRoleId)) {
	                    gcshares.add(new Guest_Card__Share(
	                        ParentId = gcid,
	                        UserOrGroupId = u.id,
	                        AccessLevel = 'Edit',
	                        RowCause = Schema.Guest_Card__Share.RowCause.Community__c));
	                }
	            }
	            //Read Only users: all in spod
	            if ((spodRoleId != null) && (spodid2subrolesmap.get(spodRoleId) != null)) {
	                for (Id i : spodid2subrolesmap.get(spodRoleId)) {
	                    if(roleid2usersmap.get(i) == null) continue;
	
	                    for (User u : roleid2usersmap.get(i)) {
	                        gcshares.add(new Guest_Card__Share(
	                            ParentId = gcid,
	                            UserOrGroupId = u.id,
	                            AccessLevel = 'Read',
	                            RowCause = Schema.Guest_Card__Share.RowCause.POD__c));
	                    }
	                }
	            } //end if spodRole != null
        	}
            
        }
        if (gcshares.size() > 0) insert gcshares;
        /*  End Fix Sharing  */
        
        //Find and close Initial Followup Tasks for Email-type GCs
        if (EmailGCids.size() > 0)
        {
            list<Task> taskstoclose = [select Id, Status, Description 
                from Task
                where AVB_Type__c = 'Lead Pursuit Process' 
                    and Subject_Sub_Category__c = 'Initial Followup'
                    and IsClosed = false
                    and WhatId in :EmailGCids];
            for (Task t : taskstoclose)
            {
                t.Status = 'Complete';
                t.Description = (t.Description == null) ? '' : t.Description;
                t.Description += '  Task closed automatically for Guest Card with Initial Lead Type = \'Email\'';
            }
            
            update taskstoclose;
        }
        
        //Find and update Events and Tasks for AVB Associate/MRI Leasing Associate change
        if (AVBAssocGCids.size() > 0)
        {
            list<Guest_Card__c> gcs = [select AVB_Associate__c, MRI_Leasing_Associate__c, 
            	MRI_Leasing_Associate__r.LeasingAssociateName__c, Prospect_Account__c,
                (select Id, AVB_Associate_First_Last_Name__c from Tasks where IsClosed = false),
                (select Id, AVB_Associate_First_Last_Name__c from Events)
                from Guest_Card__c
                where Id in :AVBAssocGCids];
            list<Task> taskstoupdate = new list<Task>();
            list<Event> eventstoupdate = new list<Event>();
            map<Id, Account> accid2accmaptoupdate = new map<Id, Account>();
            
            for (Guest_Card__c gc : gcs)
            {
                //AVB Associate should come from the MRI Leasing Associate record, unless there isn't one or the name on it is blank
                String associateName = gc.AVB_Associate__c;
                if ((gc.MRI_Leasing_Associate__c != null)
                	&& (gc.MRI_Leasing_Associate__r.LeasingAssociateName__c != null))
                	associateName = gc.MRI_Leasing_Associate__r.LeasingAssociateName__c;
                	
                for (Task t : gc.Tasks)
                {
                    t.AVB_Associate_First_Last_Name__c = associateName;
                    taskstoupdate.add(t);
                }
                for (Event e : gc.Events)
                {
                    e.AVB_Associate_First_Last_Name__c = associateName;
                    eventstoupdate.add(e);
                }
            	
            	//update MRI Leasing Associate on CG Account
            	if ((gc.Prospect_Account__c != null)
            		&& (gc.MRI_Leasing_Associate__c != null))
            	{
            		accid2accmaptoupdate.put(gc.Prospect_Account__c, new Account(
            			Id = gc.Prospect_Account__c,
            			MRI_Leasing_Associate__c = gc.MRI_Leasing_Associate__c));
            	}
            }
            
            update taskstoupdate;
            update eventstoupdate;
            update accid2accmaptoupdate.values();
        }
        
        /*  Create Tasks  */
	    if (Trigger.IsInsert) {
	        Id leadrtid = [select id from Recordtype where SObjectType = 'Task' and Name = 'Pilot Lead Process' limit 1].id;
	        list<Task> newtasks = new list<Task>();
	        for (Guest_Card__c gc : Trigger.new) {
	            //Only create Task for non-Leased GCs owned by real Users
	            if ((gc.Status__c != 'Leased')
	                //removed 031212 JN && (gc.Initial_Lead_Type__c != 'Walk In')
	                && (gc.Initial_Lead_Type__c != 'Email')
	                && (((String)gc.OwnerId).substring(0,3) == '005'))
	            {
	                newtasks.add(new Task(
	                    OwnerId = gc.OwnerId,
	                    RecordtypeId = leadrtid,
	                    AVB_Type__c = 'Lead Pursuit Process',
	                    Subject_Sub_Category__c = 'Initial Followup',
	                    //QB4164; cjc; Change timing on the initial Follow up task to = today
	                    //ActivityDate = system.today().addDays(2),
	                    ActivityDate = system.today(),
	                    //QB4164; cjc; Change timing on the initial Follow up task to = today
	                    AVB_Associate_First_Last_Name__c = gc.AVB_Associate__c,
	                    WhatId = gc.Id
	                    ));
	            }
	        } //end for gc : trigger.new
	        
	        if (newtasks.size() > 0) 
	            insert newtasks;
	    }
	    /*  End Create Tasks  */
        
    } //end if IsAfter

/*  BEFORE  */    
    if (Trigger.IsBefore) {
        
        /*  Validate uniqueness of Guest Card  */
    	set<id> triggeringids = new set<id>();
        if (Trigger.IsUpdate) triggeringids = Trigger.newmap.keyset();
        //collect Customer Group ids
        set<id> cgids = new set<id>();
        for (Guest_Card__c gc : Trigger.new) {
            cgids.add(gc.Prospect_Account__c);
        }
        
        //Query Customer Groups with attached Guest Cards and Community info, excluding anything being updated now
        map<id, Account> cgid2cgmap = new map<id, Account>([select id, Parent.OwnerId,
            (select Community__c from Guest_Cards__r where id not in :triggeringids)
            from Account
            where id in :cgids]);
        
        //Go through triggered records and validate there is no other GC on that Customer Group with that Community
        for (Guest_Card__c gc : Trigger.new) {
            if (gc.Prospect_Account__c != null) {
                Account cg = cgid2cgmap.get(gc.Prospect_Account__c);
                for (Guest_Card__c queriedgc : cg.Guest_Cards__r) {
                    if (gc.Community__c == queriedgc.Community__c) {
                        gc.addError('There is already a Guest Card for this Customer Group at this Community. Please choose a different Community.');
                    }
                }
                
                //if Needs Contact just changed to unchecked, assign this GC to the Community it belongs to (from CCC web leads queue)
                if ((Trigger.IsUpdate)
                	&& (gc.Needs_Contact__c == FALSE)
                	&& (Trigger.oldmap.get(gc.Id).Needs_Contact__c == TRUE))
                {
                	gc.OwnerId = cg.Parent.OwnerId;
                }
            }
        }
        /*  End Guest Card Uniqueness Validation  */ 
    	
		/*  Start MRI Leasing Associate update on GC  */
		//gather MRI Leasing Associate Ids to query
		set<Id> mrilaids = new set<ID>();
		for (Guest_Card__c gc : Trigger.new)
		{
			if ((gc.MRI_Leasing_Associate__c != null)
				&& ((Trigger.IsInsert)
					|| (gc.MRI_Leasing_Associate__c != Trigger.oldmap.get(gc.Id).MRI_Leasing_Associate__c)))
			{
				mrilaids.add(gc.MRI_Leasing_Associate__c);
			}
		}
		
		//query for MRI Leasing Associates and update on triggering Guest Card
		if (mrilaids.size() > 0)
		{
			map<Id, MRILeasingAssociate__c> mriid2mrimap = new map<Id, MRILeasingAssociate__c>(
				[select Id, LeasingAssociateName__c
				from MRILeasingAssociate__c
				where Id in :mrilaids]);
			
			for (Guest_Card__c gc : Trigger.new)
			{
				if ((gc.MRI_Leasing_Associate__c != null)
					&& ((Trigger.IsInsert)
						|| (gc.MRI_Leasing_Associate__c != Trigger.oldmap.get(gc.Id).MRI_Leasing_Associate__c))
					&& (mriid2mrimap.containsKey(gc.MRI_Leasing_Associate__c))
					&& (mriid2mrimap.get(gc.MRI_Leasing_Associate__c).LeasingAssociateName__c != null)
					&& (mriid2mrimap.get(gc.MRI_Leasing_Associate__c).LeasingAssociateName__c.contains(' ')))
				{
					gc.AVB_Associate__c = mriid2mrimap.get(gc.MRI_Leasing_Associate__c).LeasingAssociateName__c;
				}
			}
		} //end if mrilaids.size > 0
		/*  END MRI Leasing Associate update on GC  */
		
    } //end if Trigger.IsBefore
    
    
}