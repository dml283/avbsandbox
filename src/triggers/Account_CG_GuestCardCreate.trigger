trigger Account_CG_GuestCardCreate on Account (before insert, before update, after insert, after update) {
    /*
    Purpose:    - When a 'Customer Group' recordtype  Prospect Account is created through insert from MRI, create a Guest Card with applicable information, 
                    assigned to the Community that owns the Customer Group.
                - Before Insert, Before Update
                    If an Account should be created in MRI, check the "Create in MRI" checkbox
                - (After Insert) 
                    When a 'Customer Group' recordtype Account is created without existing in MRI, populate the Unique_Record_ID__c field from the record ID
                - If a Customer Group Status__c field is changed to 'Resident', the applicable MRI Guest Card is modified:
                    Status => 'Leased'
                    Lease Date => YESTERDAY()
                - If a Customer Group MRI Leasing Associate is changed, this is copied to all Guest Cards
    Created By:     Jeremy Nottingham (Synaptic) 1/31/2011
    
    Last Modified By:   Jeremy Nottingham (Synaptic) 2/14/2011
    
    Current Version:    v2.0
    
    Revision Log:       v1.0 - (JN) Created trigger and header.
                        v1.1 - (JN 3/10/11) Added support for Status__c changing to Resident
                             - Fleshed out Rating system and completed all TODO notes. Test coverage = 100%
                        v1.2 - (JN 5/3/11) Corrected typographical error that prevented Status changes from working on Guest Card.
                        v1.3 - (JN 5/9/11) Changed validation on AVB Associate Name to require a space character
                        v1.4 - (JN 5/17/11) Checking for inactive users; now ignoring any records with inactive users in Guest Card process
                        v2.0 - (JN 2/14/12) Added before function to populate Create In MRI as necessary
                                Added after function to populate Unique_Record_ID__c with SFDC ID on new Accounts
                                Added MRI Leasing ASssociate support
    */
    
    Id cgRtId = [select id from Recordtype where SObjectType = 'Account' and Name = 'Customer Group'].id;
        
    if (Trigger.IsBefore)
    {
        for (Account a : Trigger.new)
        {
            /* Send this Account to MRI if appropriate  */
            if ((Trigger.IsInsert)
                && (a.RecordtypeId == cgRtId)
                && (a.Exists_In_MRI__c == FALSE)
                && ((a.Created_From_ILS__c == FALSE)
                    || (a.Status__c == 'Resident')))
            {
                a.Create_In_MRI__c = TRUE;
            }
            
            if ((Trigger.IsUpdate)
                && (a.RecordtypeId == cgRtId)
                && (a.Exists_In_MRI__c == TRUE)
                && ((a.Created_From_ILS__c == FALSE)
                    || (a.Status__c == 'Resident')))
            {
                a.Update_In_MRI__c = TRUE;
            }
        }
    }
    
    if (Trigger.IsAfter)
    {
        set<id> CGids = new set<id>();
        set<Id> MRIIDs = new set<Id>();
        
        //These are the Users in the Pilot program. This set of IDs will not be used once Prospect Pursuit is in production
        set<id> pilotOwnerIds = new set<id>();
        set<id> pilotProfileIds = new set<id>();
        //list<Profile> pilotprofiles = [select id from Profile where Name like '%Community%' or Name = 'System Administrator'];
        
        //cjc 31MAY12: QB4348 - remove profile restriction; filter GC creation solely on Community on LM flag
        //list<Profile> pilotprofiles = [select id from Profile where Name like 'Pilot%' or Name = 'System Administrator'];
        list<Profile> pilotprofiles = [select id from Profile];
        //cjc 31MAY12: QB4348 - remove profile restriction; filter GC creation solely on Community on LM flag
        
        for (Profile p : pilotprofiles) {
            pilotprofileIds.add(p.id);
        }
system.debug('\n\npilot profiles ' + pilotprofileIds);  
        //Get Ids from Account Owners to query and get Profile info
        set<id> ownerIds = new set<id>();
        for (Account a : Trigger.new) {
            if (a.RecordtypeId == cgRtId) ownerIds.add(a.OwnerId); 
        }
        
        map<id, User> ownerid2usermap = new map<id, User>([select Id, ProfileId from User where id in :ownerIds and IsActive = true]);
        
        //Limit action to Customer Group Accounts and Community Profile Users only
        for (Account a : Trigger.new) {
            
            if ((a.RecordtypeId == cgRtId)
                && (ownerid2usermap.containsKey(a.OwnerId)) //added 5/17/11 JN
                && (pilotprofileIds.contains(ownerid2usermap.get(a.OwnerId).ProfileId))               
                && ((Test.IsRunningTest()) || (a.ParentIsLiveOnLM__c == 'true'))) //cjc 22MAY12: QB4348 - remove profile restriction; filter GC creation solely on Community on LM flag

            {
                CGids.add(a.id);
                MRIIDs.add(a.MRI_Leasing_Associate__c);
            }
        }
        
        if ((Trigger.IsInsert) && (CGids.size() > 0)) {
            //Guest Cards to be created and inserted
            list<Guest_Card__c> guestcardstoinsert = new list<Guest_Card__c>();
            
            //Account list to update triggering records
            list<Account> accstoupdate = new list<Account>();
            
            //Query for MRI Leasing Associates
            map<Id, MRILeasingAssociate__c> mriId2mrimap = new map<Id, MRILeasingAssociate__c>(
                [select Id, LeasingAssociateName__c 
                from MRILeasingAssociate__c
                where Id in :MRIIDs]);
            
            //Query for associated Community Accounts
            set<id> communityIds = new set<id>();
            for (Id cgid : CGids) 
            {
                communityIds.add(Trigger.newmap.get(cgid).ParentId);
            }
            map<id, Account> commid2commmap = new map<id, Account>([select id, Target_Class_IDs__c 
                from Account where id in :communityIds]);
            
            for (Id cgid : CGids) {
                Account cg = Trigger.newmap.get(cgid);
    
                if (cg.ParentId != null) {
                    Account comm = commid2commmap.get(cg.ParentId);
                    //Calculate rating for each CG
                    String rating;
                    
                    //See if Desired Unit Type on CG matches against Target Unit Type on Community
                    list<String> communits = new list<String>();
                    if (comm.Target_Class_IDs__c != null) communits = comm.Target_Class_IDs__c.split(';',0);
                    list<String> cgunits = new list<String>();
                    if (cg.PROSPECT_ClassID__c != null) cgunits = cg.PROSPECT_ClassID__c.split(';',0);
                    Boolean MatchedUnit = false;
                    for (String communit : communits) {
                        if (MatchedUnit) break;
                        for (String cgunit : cgunits) {
                            if (communit == cgunit) {
                                MatchedUnit = true;
                            }
                        }
                    }
                    
                    //Calculate days until Expected Move In Date
                    Integer DaysUntilMoveIn = 61; //Default to far future
                    if (cg.Expected_Move_In_Date__c != null) DaysUntilMoveIn = system.today().addDays(-1).daysbetween(cg.Expected_Move_In_Date__c); 
                    
                    //Determine actual rating based on days until move in and whether there's a Unit Type match
                    if ((MatchedUnit) && (DaysUntilMoveIn <= 30)) {
                        rating = 'Hot';
                    } else if (DaysUntilMoveIn <= 60) {
                        rating = 'Warm';
                    } else {
                        rating = 'Future';
                    }
                    
                    //Fill in default name if it's null or not two words on the CG account.
                    String AVBassociateName = cg.PROSPECT_LeasingAgent__c;
                    if (cg.MRI_Leasing_Associate__c != null)
                        AVBassociateName = mriId2mrimap.get(cg.MRI_Leasing_Associate__c).LeasingAssociateName__c;
                    if (AVBAssociateName == 'Internet') {
                        AVBAssociateName = 'Inter Net';
                     
                    } else if (AVBAssociateName == 'OnlineLease') {
                        AVBAssociateName = 'Online Lease';
                    
                    } else if ((AVBAssociateName == null)
                        || (!AVBAssociateName.contains(' '))) 
                    {
                        AVBAssociateName = 'Not Yet Assigned';
                    }
                    
                    String GCStatus = 'Active';
                    //Check to see if this inserted CG is a Resident already
                    if (cg.Status__c == 'Resident')
                    {
                        GCStatus = 'Leased';
                    }
                    
                    //Create Guest Card for cg, populate values 
                    Guest_Card__c newgc = new Guest_Card__c(
                        Name = cg.Name.substring(0, Math.min(69, cg.Name.length())), 
                        Prospect_Account__c = cgid,
                        Class_ID__c = cg.PROSPECT_ClassID__c,
                        Shared__c = 'No',
                        Status__c = GCStatus,
                        AVB_Associate__c = AVBassociateName,
                        MRI_Leasing_Associate__c = cg.MRI_Leasing_Associate__c,
                        OwnerId = cg.OwnerID, 
                        How_did_you_Hear_About_Us__c = cg.Marketing_Source__c,
                        Rating__c = rating,
                        When_will_you_be_moving_in__c = cg.Expected_Move_In_Date__c, 
                        Lease_term_desired__c = cg.Lease_Term__c,
                        Email__c = cg.PROSPECT_Email__c,
                        Home_Phone__c = cg.PROSPECT_HomePhone__c,
                        Work_Phone__c = cg.PROSPECT_WorkPhone__c, 
                        Work_Phone_2__c = cg.PROSPECT_WorkPhone2__c, 
                        Bed__c = cg.PROSPECT_Bed__c,
                        Bath__c = cg.PROSPECT_Bath__c,
                        Guest_Card_Details__c = cg.Description,
                        Fax__c = cg.PROSPECT_Fax__c, 
                        Cell_Phone__c = cg.PROSPECT_CellPhone__c, 
                        Address_Street_2__c = cg.PROSPECT_AddressLine2__c, 
                        Address_Street_1__c = cg.PROSPECT_AddressLine1__c, 
                        Address_State__c = cg.PROSPECT_AddressState__c, 
                        Address_Postal_Code__c = cg.PROSPECT_AddressZip__c, 
                        Address_City__c = cg.PROSPECT_AddressCity__c,
                        Community__c = comm.id
                        );
    
                    //handle Leased Guest Card Lease Date    
                    if (newgc.Status__c == 'Leased')
                    {
                        newgc.Lease_Date__c = system.today().addDays(-1);
                    }
                    
                    guestcardstoinsert.add(newgc); 
                } //end if ParentId != null
                
                /*  pop Unique_Record_ID__c  */
                if (cg.Exists_In_MRI__c != TRUE)
                {
                    accstoupdate.add(new Account(
                        Id = cg.Id,
                        Unique_Record_ID__c = cg.Id));
                }
            }
            
            //Insert new Guest Cards if any
            if (guestcardstoinsert.size() > 0) insert guestcardstoinsert;
            
            //Update records for Unique Record ID if necessary
            if (accstoupdate.size() > 0)
                update accstoupdate;
            
        } //end if Trigger.IsInsert
        
        
        if ((Trigger.IsUpdate) && (CGids.size() > 0)) {
            //Collect triggering CGs where Status__c has just changed to 'Resident'         
            set<id> residentIds = new set<id>();
            set<id> mrileasingassocIds = new set<id>();
            
            for (Id cgid : CGids) {
                Account oldacc = Trigger.oldmap.get(cgid);
                Account newacc = Trigger.newmap.get(cgid);
                
                if ((oldacc.Status__c != newacc.Status__c) && (newacc.Status__c == 'Resident')) {
                    residentIds.add(cgid);
                }
                
                if (oldacc.MRI_Leasing_Associate__c != newacc.MRI_Leasing_Associate__c)
                {
                    mrileasingassocids.add(cgid);
                }
                
            }
            
            //Query for relevant GCs on new Resident Accounts
            if ((residentIds.size() > 0)
                || (mrileasingassocids.size() > 0)) 
            {
                list<Guest_Card__c> GCstoupdate = [select Status__c, Lease_Date__c, Prospect_Account__c, MRI_Leasing_Associate__c
                    from Guest_Card__c 
                    where (Prospect_Account__c in :residentIds
                            or Prospect_Account__c in :mrileasingassocids) 
                        and Shared__c = 'No' 
                        and Lease_Date__c = null
                        ];
                
                //go through and modify GCs
                for (Guest_Card__c gc : GCstoupdate) {
                    //Changed to Resident
                    if (residentIds.contains(gc.Prospect_Account__c))
                    {
                        gc.Status__c = 'Leased';
                        gc.Lease_Date__c = system.today().addDays(-1);
                    }
                    
                    //changed MRI Leasing Associate
                    if (mrileasingassocids.contains(gc.Prospect_Account__c))
                    {
                        gc.MRI_Leasing_Associate__c = Trigger.newmap.get(gc.Prospect_Account__c).MRI_Leasing_Associate__c;
                    }
                }
                
                //update records
                if (GCstoupdate.size() > 0) update GCstoupdate;
            }
        }
    } //end if Trigger.IsAfter
    
}