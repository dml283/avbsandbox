public with sharing class Ctl_AddGuestCard {
    /*
        Purpose:        Support Add Guest Card wizard


        Created By:     Jeremy Nottingham (Synaptic) 1/16/2012
        
        Last Modified By:       Jeremy Nottingham (Synaptic) 3/7/2012
        
        Current Version:        v1.5
        
        Revision Log:           v1.0 - (JN 1/16/12) Created this class
                                v1.5 - (JN 030812) Handle clone properly, remove save validation step
                                                
    */
    
    public static final Integer MaxSearchResults = 50; //Maximum number of records before triggering a "too many" error.
    
    public String retURL;
    public String mode {get; private set; } //what is this page being used for? edit, new, clone, search
    public Boolean ShowCreateButton { get; private set; }
    public Id thisGCId; 
    public Boolean HasPermissionToEdit { get; private set; }
    
    public list<SelectOption> communityOptions { 
    	get
    	{
    		if (communityOptions == null)
    		{
    			communityOptions = new list<SelectOption>();
    			set<Id> commids = new set<Id>();
    			
    			//Accounts retrieved based on Region/SPOD membership
    			list<Account> regionalAccs = GuestCard_Ext.getAvailableCommunities(Userinfo.getUserId());
    			map<String, Account> name2accmap = new map<String, Account>();
    			for (Account a : regionalAccs)
    			{
    				name2accmap.put(a.Name, a);
    				commids.add(a.Id);
    			}
    			
    			//Accounts retrieved based on natural sharing of records. If there are an additional here, they will be added to the list
    			list<Account> naturalAccs = [select Id, Name 
    				from Account 
    				where Recordtype.Name = 'Community'
    					and Id not in :commids];
    			for (Account a : naturalAccs)
    			{
    				name2accmap.put(a.Name, a);
    			}
    			
    			list<String> accnames = new list<String>(name2accmap.keyset());
    			accnames.sort();
    			for (String a : accnames)
    			{
    				communityOptions.add(new SelectOption(name2accmap.get(a).Id, name2accmap.get(a).Name));
    			}
    			
    		}
    		return communityOptions;
    	}
    	private set; }
    public Id chosenCommunityId { get; set; }
    
    //Just used to copy values from for new GC in a clone situation
    Guest_Card__c thisGCtoClone;
    
    //GC used for search field criteria, then to populate fields on New Guest Card
    public Guest_Card__c searchGC 
    { 
        get 
        {
            if (searchGC == null)
            {
                //if we were passed an ID, take field values from that GC
                if (thisGC.Id != null)
                {
                    searchGC = thisGC.clone();
                }
                else
                {
                    searchGC = new Guest_Card__c();
                }
                mode = 'search';
            } //end if searchGC == null
            return searchGC;
        } 
        set; 
    } //used for Guest Card search fields on page
    
    public Guest_Card__c thisGC { get; set; } //used for new Guest Card record, either shared or brand new on page
    
    public Contact searchContact //used for Contact search fields on page
    { 
        get
        {
            if (searchContact == null) searchContact = new Contact();
            return searchContact;
        }
        set; 
    }
    
    public Contact thisContact { get; set; }
    
    public list<SearchResult> searchResults { get; private set; }
    public String searchResultsSize { get; private set; }
    
    public Ctl_AddGuestCard()
    {
        thisgcid = ApexPages.CurrentPage().getParameters().get('id');
        String updmode = ApexPages.CurrentPage().getParameters().get('mode');
        if (retURL == null)
        	retURL = ApexPages.CurrentPage().getParameters().get('retURL');
        ShowCreateButton = FALSE;
        
        
        	
        if (thisgcid != null)
        {
	        	
	        	
            thisGC = [Select Work_Phone__c, Work_Phone_2__c, Where_else_did_you_lease__c, When_will_you_be_moving_in__c, 
                What_is_most_important_to_you__c, What_features_are_most_important__c, SystemModstamp, Status__c, Stale__c, 
                Secondary_Marketing_Source__c, SHARED__c, Reason_for_relocating__c, Rating__c, Prospect_Account__c, Primary_Contact__c, 
                Price_Range_Desired__c, Pet_Type_Breed__c, OwnerId, Owner.FirstName, Owner.LastName, Other_residents__c, 
                Other_resident_phone__c, Other_resident_email_s__c, Owner.Name, LastActivityDate,
                Other_communities_being_considered__c, Name, Level_One_Appointment_Created__c, Leased_Number__c, Lease_term_desired__c, 
                Lease_Date__c, Lead_Number__c, Initial_Visit_Number__c, Initial_Visit_Date__c, Initial_Lead_Type__c, InitialVisitAge__c, 
                Inactive_Reason__c, Id, How_did_you_hear_about_us__c, How_Many_Occupants__c, Home_Phone__c, Have_a_pet_other_than_a_service_animal__c, 
                Guest_Card_Details__c, Fax__c, Email__c, Days_Active__c, CreatedDate, CreatedById, Contact__c, Contact_Info_has_been_edited__c, 
                Community__c, Class_ID__c, Cell_Phone__c, Bed__c, Bath__c, Address_Street_2__c, Address_Street_1__c, Address_State__c, 
                Address_Postal_Code__c, Address_City__c, AVB_Associate__c, MRI_Leasing_Associate__c
                from Guest_Card__c 
                where Id = :thisgcid]; 
            if (thisGC == null) thisGC = new Guest_Card__c();
            
            if (updmode == 'clone')
            {
                cloneGC();
                mode = 'clone';
                newGuestCard();
            }
            else if ((updmode == 'edit') || (updmode == null))
            {
                mode = 'edit';
	            UserRecordAccess access = [SELECT RecordId, HasEditAccess, MaxAccessLevel
				    FROM UserRecordAccess
				    WHERE UserId = :Userinfo.getUserId()
				    AND RecordId = :thisGCid];
				
		        if (access.HasEditAccess == TRUE)
		        	HasPermissionToEdit = TRUE;
		        else
		        	HasPermissionToEdit = FALSE;
		        
		        chosenCommunityId = thisGC.Community__c;
	        }
            
            if (retURL == null)
                retURL = '/' + thisGC.Id;
        }
        else //if 'new', we should still have thisGC
        {
            if (thisGC == null)
                thisGC = new Guest_Card__c();
        }
    }
    
    public class SearchResult
    {
        public Guest_Card__c gc { get; set; }
        //public Account cgAccount {get; set; }
        public Contact contact { get; set; }
        
        public SearchResult(Guest_Card__c passedgc)
        {
            this.gc = passedgc;
                 
        }
    }
    
    public PageReference clearPage()
    {
        PageReference pageref = null;
        this.searchGC = new Guest_Card__c();
        this.searchContact = new Contact();
        searchResults = null;
        searchResultssize = null;
        return pageref;
    }
    
    public PageReference saveGC()
    {
        Account newAccount;
        Contact newContact;
        Guest_Card__c initialGC;
        Contact initialContact;
        PageReference pageref = null;
         
        if (mode == 'edit')
        {
            pageref = new PageReference(retURL);

            if (thisGC.AVB_Associate__c == Null)
            {
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please enter the name of the assigned AVB Associate.'));
                thisGC.AVB_Associate__c.addError('Please enter the name of the assigned AVB Associate.');
                pageref = Page.EditGuestCard;
            }
            else if ((thisGC.Status__c == 'Inactive') && (thisGC.Inactive_Reason__c == Null))
            {
                //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please select an Inactive Reason.'));
                thisGC.Inactive_Reason__c.addError('Please select an Inactive Reason.');
                pageref = Page.EditGuestCard;
            }
            //cjc 06JUN12: adjust for hole in logic
            //else if (thisGC.Have_a_pet_other_than_a_service_animal__c == Null &&  thisGC.Pet_Type_Breed__c != Null)
            else if ((thisGC.Have_a_pet_other_than_a_service_animal__c == Null || thisGC.Have_a_pet_other_than_a_service_animal__c == 'No')
                        &&  thisGC.Pet_Type_Breed__c != Null)
            {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, '164: Please specify if the "' + thisGC.Pet_Type_Breed__c + '" is a Service Animal.'));
                pageref = Page.EditGuestCard;
            }
            else if (thisGC.Have_a_pet_other_than_a_service_animal__c == 'Yes' && thisGC.Pet_Type_Breed__c == Null)            
            {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, '170: Please specify a Pet Type and Breed.'));
                pageref = Page.EditGuestCard;
            }            
            else
            {
                try
                {
                    update thisGC;            
            
                    if(thisGC.Contact__c != Null)
                    {
                        thisContact = new Contact(
                            Id=thisGC.Contact__c, 
                            Email=thisGC.Email__c, 
                            HomePhone=thisGC.Home_Phone__c, 
                            Work_Phone__c=thisGC.Work_Phone__c, 
                            Fax=thisGC.Fax__c, 
                            MobilePhone=thisGC.Cell_Phone__c);
            
                        update thisContact;
                    }
                }
                catch(Exception e)
                {
                    if (e.getMessage().contains('Guest Card status can only be changed to'))
                    {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Guest Card status can only be changed to "Leased" through MRI.'));
                    }
                    else if (e.getMessage().contains('Auto Inactivated cannot be chosen manually.'))
                    {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Auto Inactivated cannot be chosen manually.'));
                    }
                    else
                    {
                        //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, '<b><font color="red">Unable to save. Remember to create a Shared Guest Card for a Lead associated to a different community.</font></b>'));
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));   
                    }                    
                    pageref = Page.EditGuestCard;
                }
            }
        }
        
        else if ((mode == 'new') || (mode == 'clone'))
        {
            if (thisGC.Initial_Lead_Type__c == 'Walk In')
            {
                thisGC.Initial_Visit_Date__c = system.now();
            }
            
            //cjc 06JUN12: adjust for hole in logic
            //if (searchGC.Have_a_pet_other_than_a_service_animal__c == Null &&  searchGC.Pet_Type_Breed__c != Null)
            
            
            /*these next two validations are duplicated in the validateFields function
            
            if ((searchGC.Have_a_pet_other_than_a_service_animal__c == Null || searchGC.Have_a_pet_other_than_a_service_animal__c == 'No')
                    &&  searchGC.Pet_Type_Breed__c != Null)
            {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, '223: Please specify if the "' + searchGC.Pet_Type_Breed__c + '" is a Service Animal.'));
                
            }
            
            if (searchGC.Have_a_pet_other_than_a_service_animal__c == 'Yes' && searchGC.Pet_Type_Breed__c == Null)            
            {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, '230: Please specify a Pet Type and Breed.'));
            }*/
            if (0 == 1){}
            else
            {
                if (validateFields())
                {
                    //create Account and Contact, allow Guest Card to be created through process
                    try 
                    {
                        Id cgrtid = [select Id 
                            from Recordtype 
                            where Name = 'Customer Group' and SOBjectType = 'Account'].Id;
                        newAccount = new Account(
                            RecordtypeId = cgrtid,
                            Name = thisContact.FirstName + ' ' + thisContact.LastName + ' and other Occupants',
                            ParentId = chosenCommunityId,//thisGC.Community__c,
                            PROSPECT_Bed__c = thisGC.Bed__c,
                            PROSPECT_Email__c = thisGC.Email__c,
                            PROSPECT_HomePhone__c = thisGC.Home_Phone__c,
                            PROSPECT_WorkPhone__c = thisGC.Work_Phone__c,
                            PROSPECT_WorkPhone2__c = thisGC.Work_Phone_2__c,
                            PROSPECT_CellPhone__c = thisGC.Cell_Phone__c,
                            PROSPECT_Fax__c = thisGC.Fax__c,
                            PROSPECT_AddressLine1__c = thisGC.Address_Street_1__c,
                            PROSPECT_AddressLine2__c = thisGC.Address_Street_2__c,
                            PROSPECT_AddressCity__c = thisGC.Address_City__c,
                            PROSPECT_AddressState__c = thisGC.Address_State__c,
                            PROSPECT_AddressZip__c = thisGC.Address_Postal_Code__c,
                            Status__c = 'Prospect'
                            );
                        GuestCard_Ext.saveObj(newAccount);
                        
                        newContact = thisContact;
                        newContact.AccountId = newAccount.Id;
                        newContact.Email = thisGC.Email__c;
                        newContact.Phone = thisGC.Home_Phone__c;
                        newContact.HomePhone = thisGC.Home_Phone__c; 
                        newContact.Work_Phone__c = thisGC.Work_Phone__c;
                        newContact.OtherPhone = thisGC.Work_Phone_2__c;
                        newContact.MobilePhone = thisGC.Cell_Phone__c;
                        newContact.Fax = thisGC.Fax__c;
                        newContact.MailingStreet = thisGC.Address_Street_1__c;
                        newContact.OtherStreet = thisGC.Address_Street_2__c;
                        newContact.MailingState = thisGC.Address_State__c;
                        newContact.MailingPostalCode = thisGC.Address_Postal_Code__c;
                        newContact.MailingCity = thisGC.Address_City__c;
                        newContact.Primary_Contact__c = True;
                        
                        GuestCard_Ext.saveObj(newContact);  
                        
                        pageref = null;                                
                    }
                     
                    catch (Exception e)
                    {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, '258 ' + e.getMessage()));
                    }       
            
system.debug('\n\n213 newAccount' + newAccount);
system.debug('\n\n214 newContact' + newContact);
            
                    //Update resulting Guest Card
                    try
                    {
                        if (thisGC.Id != null)
                        {
                            GuestCard_Ext.saveObj(thisGC);
                        }
                        else
                        {
                            //query for quest cards where prospect account equals thisGC.prospect account
                            //and populate the initial visit date on that guest card
                            
                            initialGC = [select Id, Prospect_Account__c 
                                            from Guest_Card__c 
                                            where Prospect_Account__c = :newAccount.Id];
                                            
                            initialContact = [select Id
                                                from Contact
                                                where AccountID = :initialGC.Prospect_Account__c];                
                                            
                            if (initialGC != Null)
                            {
                                initialGC.Initial_Visit_Date__c = thisGC.Initial_Visit_Date__c;
                                initialGC.Initial_Lead_Type__c = thisGC.Initial_Lead_Type__c;
                                initialGC.Secondary_Marketing_Source__c = thisGC.Secondary_Marketing_Source__c;
                                initialGC.Bed__c = thisGC.Bed__c;
                                initialGC.Bath__c = thisGC.Bath__c;
                                initialGC.Class_ID__c = thisGC.Class_ID__c;
                                initialGC.Inactive_Reason__c = thisGC.Inactive_Reason__c;
                                initialGC.Where_else_did_you_lease__c = thisGC.Where_else_did_you_lease__c;
                                initialGC.Price_Range_Desired__c = thisGC.Price_Range_Desired__c;
                                initialGC.What_is_most_important_to_you__c = thisGC.What_is_most_important_to_you__c;
                                initialGC.What_features_are_most_important__c = thisGC.What_features_are_most_important__c;
                                initialGC.When_will_you_be_moving_in__c = thisGC.When_will_you_be_moving_in__c;
                                initialGC.Guest_Card_Details__c = thisGC.Guest_Card_Details__c;
                                initialGC.Reason_for_relocating__c = thisGC.Reason_for_relocating__c;
                                initialGC.Other_communities_being_considered__c = thisGC.Other_communities_being_considered__c;
                                initialGC.How_Many_Occupants__c = thisGC.How_Many_Occupants__c;
                                initialGC.Have_a_pet_other_than_a_service_animal__c = thisGC.Have_a_pet_other_than_a_service_animal__c;
                                initialGC.Pet_Type_Breed__c = thisGC.Pet_Type_Breed__c;
                                initialGC.Other_residents__c = thisGC.Other_residents__c;
                                initialGC.Other_resident_phone__c = thisGC.Other_resident_phone__c;
                                initialGC.Other_resident_email_s__c = thisGC.Other_resident_email_s__c;
                                initialGC.Email__c = thisGC.Email__c;
                                initialGC.Home_Phone__c = thisGC.Home_Phone__c;
                                initialGC.Work_Phone__c = thisGC.Work_Phone__c;
                                initialGC.Work_Phone_2__c = thisGC.Work_Phone_2__c;
                                initialGC.Cell_Phone__c = thisGC.Cell_Phone__c;
                                initialGC.Fax__c = thisGC.Fax__c;
                                initialGC.Contact_Info_has_been_edited__c = thisGC.Contact_Info_has_been_edited__c;
                                initialGC.Address_Street_1__c = thisGC.Address_Street_1__c;
                                initialGC.Address_Street_2__c = thisGC.Address_Street_2__c;
                                initialGC.Address_City__c = thisGC.Address_City__c;
                                initialGC.Address_State__c = thisGC.Address_State__c;
                                initialGC.Address_Postal_Code__c = thisGC.Address_Postal_Code__c;
                                initialGC.Status__c = thisGC.Status__c;
                                initialGC.How_did_you_hear_about_us__c = thisGC.How_did_you_hear_about_us__c;
                                initialGC.Lease_term_desired__c = thisGC.Lease_term_desired__c; 
                                initialGC.MRI_Leasing_Associate__c = thisGC.MRI_Leasing_Associate__c;
                                initialGC.Community__c = chosenCommunityId; //thisGC.Community__c;
                                initialGC.AVB_Associate__c = thisGC.AVB_Associate__c;
                                //initialGC.Contact__c = initialContact.Id;
                                
                                // Mark original GC as shared
                                if (thisGCtoClone != null)
                                {
                                    set<Id> newset = new set<Id> { thisGCtoClone.Id };
                                    GuestCard_Ext.makeGCShared(newset);
                                    
                                    initialGC.SHARED__c = 'Yes';
                                }
                                GuestCard_Ext.saveObj(initialGC);    
                            }
                        }
                        pageref = new PageReference('/' + initialGC.Id);
                    }
                    catch (Exception e)
                    {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, '348 An error has occured, please contact your Administrator. ', e.getMessage() ));
                    }
                }
            }   
        }
       
        return pageref;
    }    
    
        // JS added cancel for new guest card page - will return user back to search page

    public PageReference cancelGC() 
    {
        PageReference pageref = new PageReference(retURL);
        pageref.setRedirect(true);
        return pageref;
    }
    
     //clone method - query for ID that was passed, find that as searchGC, then call newGuestCard()
    //clone page needs to look like new page with First and Last name seperate
    
    public void cloneGC() 
    {
        //query every field
        thisGCtoClone = [
            select ID, Bed__c, Bath__c, AVB_Associate__c, 
                //MRI_Leasing_Associate__c, Contact__c, Community__c, 
                How_did_you_hear_about_us__c, Rating__c, Contact_First_Name__c, Contact_Last_Name__c, 
                Secondary_Marketing_Source__c, Inactive_Reason__c, Class_ID__c, Where_else_did_you_lease__c,
                Level_One_Appointment_Created__c, When_will_you_be_moving_in__c, Reason_for_relocating__c, Lease_term_desired__c, 
                Other_communities_being_considered__c, Price_Range_Desired__c, How_Many_Occupants__c, What_is_most_important_to_you__c, 
                Have_a_pet_other_than_a_service_animal__c, What_features_are_most_important__c, Pet_Type_Breed__c, Guest_Card_Details__c, 
                Email__c, Contact_Info_has_been_edited__c, Home_Phone__c, Address_Street_1__c, Work_Phone__c, Address_Street_2__c, Work_Phone_2__c,
                Address_City__c, Cell_Phone__c, Address_State__c, Fax__c, Address_Postal_Code__c, Other_residents__c, Other_resident_phone__c, 
                Other_resident_email_s__c   
            from Guest_Card__c 
            where Id = :thisGCId];
        
        searchGC = thisGCtoClone.clone();
        
        //default values for clone
        //searchGC.Community__c = null;
        searchGC.OwnerId = Userinfo.getUserId();
        searchGC.SHARED__c = 'Yes';
        
        searchContact = new Contact(
            FirstName = thisGCtoClone.Contact_First_Name__c,
            LastName = thisGCtoClone.Contact_Last_Name__c);
    }
        
    
    public PageReference newGuestCard() 
    {
        //called from Add/Search page: open Edit page with new record and data from search criteria
        thisGC = searchGC;
        thisGC.Initial_Lead_Type__c = 'Walk In';
        
        //cjc 17MAY12: QB4328 - default Initial Lead Type to Email for users with a CCC role
        list<UserRole> roles = [select id, Name from UserRole where Id = :Userinfo.getUserRoleId()];
        for (UserRole role : roles)
        {
            if (role.Name.contains('CCC'))
            {
                thisGC.Initial_Lead_Type__c = 'Email';
            }
        }
        //cjc 17MAY12: QB4328 - default Initial Lead Type to Email for users with a CCC role
        
        thisGC.Name = searchContact.FirstName + ' ' + searchContact.LastName + ' and other Occupants';
        thisGC.Status__c = 'Active';
        //thisGC.Initial_Visit_Date__c = System.Now();
        
        List <MRILeasingAssociate__c> thisMRIAssociate = new List <MRILeasingAssociate__c>([
            select Id, LeasingAssociateName__c, SalesforceUserAccount__r.Name, LeasingAssociatePrimaryCommunity__c 
            from MRILeasingAssociate__c 
            where SalesforceUserAccount__c = :UserInfo.getUserId() LIMIT 1]);
  system.debug('\n\n482 mrila ' + thisMRIAssociate);     
        if (thisMRIAssociate.size() > 0)
        {
            thisGC.MRI_Leasing_Associate__c = thisMRIAssociate[0].Id;
            thisGC.AVB_Associate__c = thisMRIAssociate[0].LeasingAssociateName__c;
            
            List <Account> thisMRIAssociatePrimaryCommunity = new List<Account>([select Id, OwnerId, Account_ID__c 
                from Account 
                where Account_ID__c = :thisMRIAssociate[0].LeasingAssociatePrimaryCommunity__c LIMIT 1]);
                
            if (thisMRIAssociatePrimaryCommunity.size() > 0)
            {
                //thisGC.Community__c = thisMRIAssociatePrimaryCommunity[0].Id;
                chosenCommunityId = thisMRIAssociatePrimaryCommunity[0].Id;
                thisGC.OwnerId = thisMRIAssociatePrimaryCommunity[0].OwnerId;
            }
        }  
        else
        {
            // query for the default MRI if user does not have an MRI record
            List <MRILeasingAssociate__c> defaultMRI = new List <MRILeasingAssociate__c>([
                select Id, LeasingAssociateName__c, SalesforceUserAccount__r.Name, LeasingAssociatePrimaryCommunity__c 
                from MRILeasingAssociate__c 
                where LeasingAssociateId__c = 'sflead']);
        
            thisGC.MRI_Leasing_Associate__c = defaultMRI[0].Id;
            thisGC.AVB_Associate__c = defaultMRI[0].LeasingAssociateName__c;
        }     
        
      
system.debug('\n\n390 searchContact' + searchContact);        
        thisContact = searchContact;
        
        if (mode == 'search')
            mode = 'new';
        
        if (mode != 'clone')
            retURL = '/apex/SearchAddGuestCard'; 
        
        HasPermissionToEdit = TRUE;    
        PageReference pageref = Page.EditGuestCard;
        return pageref;
    }
    
    
    
    public PageReference doSearch()
    {
        PageReference pageref = null;
system.debug('\n\n98 searchGC ' + searchGC);  
        searchResultsSize = null;
         
        if (validateFields())
        {
            list<SearchResult> newresults = new list<SearchResult>();
            
            Boolean NeedsAND = FALSE;
            String gcquerystring = 'select Id, Name, Contact_First_Name__c, Contact_Last_Name__c, LastActivityDate,'
                + ' Email__c, Prospect_Account__c, Community__r.Name, AVB_Associate__c, Prospect_Status__c'
                + ' from Guest_Card__c'
                + ' where ';
            if (searchGC.Email__c != null)
            {
                if (NeedsAND) gcquerystring += 'AND ';
                gcquerystring += 'Email__c = \'' + searchGC.Email__c + '\'';
                NeedsAND = TRUE;
            }
            if (searchContact.LastName != null)
            {
                if (NeedsAND) gcquerystring += 'AND ';
                gcquerystring += 'Contact_Last_Name__c like \'%' + searchContact.LastName + '%\'';
                NeedsAND = TRUE;
            }            
            
            if (searchGC.Cell_Phone__c != null)
            {
                if (NeedsAND) gcquerystring += 'AND ';
                gcquerystring += 'Cell_Phone__c = \'' + searchGC.Cell_Phone__c + '\'';
                NeedsAND = TRUE;
            }
            
            if (searchContact.FirstName != null)
            {
                if (NeedsAND) gcquerystring += 'AND ';
                gcquerystring += 'Contact_First_Name__c like \'%' + searchContact.FirstName + '%\'';
                NeedsAND = TRUE;
            }
            
            if (searchGC.Home_Phone__c != null)
            {
                if (NeedsAND) gcquerystring += 'AND ';
                gcquerystring += 'Home_Phone__c = \'' + searchGC.Home_Phone__c + '\'';
                NeedsAND = TRUE;
            }
            
            if (searchGC.Address_City__c != null)
            {
                if (NeedsAND) gcquerystring += 'AND ';
                gcquerystring += 'Address_City__c like \'%' + searchGC.Address_City__c + '%\'';
                NeedsAND = TRUE;
            }
            if (searchGC.Address_State__c != null)
            {
                if (NeedsAND) gcquerystring += 'AND ';
                gcquerystring += 'Address_State__c = \'' + searchGC.Address_State__c + '\'';
                NeedsAND = TRUE;
            }
            
            //Only show on page if there are not too many results
            gcquerystring += ' limit ' + (MaxSearchResults + 1);
system.debug('\n\n213 gcquerystring ' + gcquerystring);
            list<Guest_Card__c> gcresults = database.query(gcquerystring);
            if (gcresults.size() <= MaxSearchResults)
            {
                for (Guest_Card__c gc : gcresults)
                {
                    SearchResult newSR = new SearchResult(gc);
                    newSR.contact = new Contact();
                    if (gc.Contact_First_Name__c != Null)
                    {
                        newSR.contact.FirstName = gc.Contact_First_Name__c;
                    }
                    if (gc.Contact_Last_Name__c != Null)
                    {
                        newSR.contact.LastName = gc.Contact_Last_Name__c;
                    }
                    //newSR.cgAccount = new Account();
                    //if (gc.Prospect_Account__c != null)
                    //{
                        //newSR.cgAccount.Status__c = gc.Prospect_Account__r.Status__c;
                    //}
                    newresults.add(newSR);
                    
                }   
            } //end if size <= MaxSearchResults    
            else
            {
                searchResultsSize = 'More than ' + MaxSearchResults + ' results returned.';
            } 
            searchResults = newresults; 
        }
        else //send errors to page from validation
        {
            //searchResults = new list<SearchResult>(); 
            searchResultsSize = 'Error in search. See message at top of page.';
            searchResults = null;
        }
        
        if (searchResults != null)  
        {
            if (searchResults.size() == 0)
            {
                if (searchResultsSize == null)
                    searchResultsSize = 'No Guest Cards found that match information entered.';
                searchResults = null;
                ShowCreateButton = TRUE;
            }
            else 
            {
                if (searchResultsSize == null)
                {
                    searchResultsSize = String.valueOf(searchResults.size()) 
                    + ((searchResults.size() == 1) ? ' result.' : ' results.');
                    ShowCreateButton = TRUE;
                }
            }
        }
        else
        {
            if (searchResultsSize == null)
            {
                searchResultsSize = 'More than ' + MaxSearchResults + ' results returned.';
                ShowCreateButton = FALSE;
            }
        }
    
        return pageref;
           
    }
    
    private Boolean validateFields()
    {
        Boolean passValidation = TRUE;
        Integer fieldCount = 0;
        //if (searchGC.)
        //check all necessary fields and send errors to page as necessary
        
        if (searchGC.Email__c != null)
        {
            fieldCount++;
        }
        if (searchContact.LastName != null)
        {
            fieldCount++;
        }
        
        //cjc 06JUN12: patch validation hole
        //if (searchGC.Have_a_pet_other_than_a_service_animal__c == Null &&  searchGC.Pet_Type_Breed__c != Null)
        if ((searchGC.Have_a_pet_other_than_a_service_animal__c == Null || searchGC.Have_a_pet_other_than_a_service_animal__c == 'No') 
                &&  searchGC.Pet_Type_Breed__c != Null)
        {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please specify if the "' + searchGC.Pet_Type_Breed__c + '" is a Service Animal.'));
            //pageref = Page.EditGuestCard;
            passValidation = FALSE;
            fieldCount++;
        }
        if (searchGC.Have_a_pet_other_than_a_service_animal__c == 'Yes' && searchGC.Pet_Type_Breed__c == Null)            
        {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please specify a Pet Type and Breed.'));
            //pageref = Page.EditGuestCard;
            passValidation = FALSE;
            fieldCount++;
        }
        
        if (searchGC.Cell_Phone__c != null)
        {
            fieldCount++;
            Boolean GoodNumber = TRUE;
            for (Integer i = 0; i < searchGC.Cell_Phone__c.length(); i++)
            {
                if (!('(012) 345-6789'.contains(searchGC.Cell_Phone__c.substring(i, i+1))))
                {
                    GoodNumber = FALSE;
                    break;
                }
            }
            if ((!GoodNumber)
                || (searchGC.Cell_Phone__c.length() != 14))
            {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 
                    'Cell Phone: Please enter full telephone number, numbers only.'));
                passValidation = FALSE;
            }
        }
        if (searchContact.FirstName != null)
        {
            fieldCount++;
        }
        if (searchGC.Home_Phone__c != null)
        {
            fieldCount++;
            Boolean GoodNumber = TRUE;
            for (Integer i = 0; i < searchGC.Home_Phone__c.length(); i++)
            {
                if (!('(012) 345-6789'.contains(searchGC.Home_Phone__c.substring(i, i+1))))
                {
                    GoodNumber = FALSE;
                    break;
                }
            }
            if ((!GoodNumber)
                || (searchGC.Home_Phone__c.length() != 14))
            {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 
                    'Home Phone: Please enter full telephone number in proper format.'));
                passValidation = FALSE;
            }
        }
        if (searchGC.Address_City__c != null)
        {
            fieldCount++;
        }
        if (searchGC.Address_State__c != null)
        {
            fieldCount++;
        }
        
        if (fieldCount == 0)
        {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.INFO, 
                'Please enter information into at least one of the search fields.')); 
            passValidation = FALSE;
        }
        
        return passValidation;
    }
        


}