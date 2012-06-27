public without sharing class GuestCard_Ext {
    /*
    Purpose:    Controller Extension to support the Printable Guest Card output page and obsolete Guest Card clone function
                    Note: This clone function is superseded by a clone controlled by Ctl_AddGuestCard.cls and SearchAddGuestCard.page
                    These methods support Ctl_AddGuestCard, by performing with system access through the "without sharing" class:
                    saveObj()
                        save any object passed
                    makeGCShared()
                        set the Shared field on any number of Guest Cards
                    getAvailableCommunities()
                        returns a list of Communities a specific user should be able to create Guest Cards for.
    Created By:     Jeremy Nottingham (Synaptic) 3/2/2011
    
    Last Modified By:   Jeremy Nottingham (Synaptic) 6/8/2011
    
    Current Version:    v1.4
    
    Revision Log:       v1.0 - (JN) Created this class and added basic info and header
                        v1.1 - (JN 040611) Added OwnerId entry on new clone: owned by current User
                        v1.2 - (JN 042011) Added support for Tasks and Events on Guest Card, for printable guest card use. Test coverage 93%
                        v1.3 - (JN 031912) Added makeGCShared() to allow for cloning of out of community GCs
                        v1.4 - (JN 060812) added saveObj and getAvailableCommunities
    */
    
    //Guest Card specified, with lists of subobjects
    public Guest_Card__c guestcard;
    public Guest_Card__c newGC { get; set; }
    public list<Quotes__c> gcQuotes;
    public list<RMAction__c> gcRMActions;
    public list<Event> gcEvents;
    public list<Task> gcTasks;
    public String todaysDate { get; set; }
    public String rightNow { get; set; }
    
    //dummy record to use the community field as a lookup
    public RMAction__c tempRMA { get; set; }
    
    public GuestCard_Ext(ApexPages.standardController stdcon)
    {
        
        if (ApexPages.CurrentPage().getParameters().get('clone') == '1') 
        {
            //Start clone
            if (this.guestcard == null) this.guestcard = (Guest_Card__c)stdcon.getRecord();
            tempRMA = new RMAction__c();
            newGC = cloneGC(guestcard.id);
        }else {
            //Prepare info for the printable Guest Card.
            //date and time
            todaysdate = system.today().format();
            
            String AMPM = 'AM';
            Integer nowHour = system.now().hour();
            if (nowHour > 11) {
                nowHour = (nowHour == 12) ? 12 : nowHour - 12;
                AMPM = 'PM';
            }
            Integer nowMinute = system.now().minute();
            String nowMinuteString = String.valueOf(nowMinute);
            if (nowMinute < 10) nowMinuteString = '0' + nowMinuteString;
            rightnow = nowHour + ':' + nowMinuteString + ' ' + AMPM;
            
            //Guest Card record
            guestcard = (Guest_Card__c)stdcon.getRecord();
            Id gcid = guestcard.id;
            if (gcid != null) {
                guestcard = [Select Work_Phone__c, Work_Phone_2__c, When_will_you_be_moving_in__c, What_is_most_important_to_you__c, 
                    What_features_are_most_important__c, Secondary_Marketing_Source__c, Reason_for_relocating__c, Rating__c, Price_Range_Desired__c, 
                    Pet_Type_Breed__c, Other_residents__c, Other_resident_phone__c, Other_resident_email_s__c, Other_communities_being_considered__c, 
                    Name, Lease_term_desired__c, Lease_Date__c, Initial_Lead_Type__c, Id, How_did_you_hear_about_us__c, Home_Phone__c, 
                    Have_a_pet_other_than_a_service_animal__c, Guest_Card_Details__c, Fax__c, Email__c, 
                    Contact_Info_has_been_edited__c, Community__c, Class_ID__c, Cell_Phone__c, Bed__c, Bath__c, Address_Street_2__c,  
                    Address_Street_1__c, Address_State__c, Address_Postal_Code__c, Address_City__c, AVB_Associate__c, AVB_Account_ID__c,  
                    (select Rent__c, Quote_Date__c, Move_In_Date__c, Legacy_Apartment_Type__c, Lease_Term__c, Apt__c from Quotes__r),
                    (select ActDescription__c, ActDate__c, ActCode__c, Account__c from RMActions__r),
                    (select Id, AVB_Type__c, Subject_Sub_Category__c, ActivityDate, Status, Description, AVB_Associate_First_Last_Name__c from Tasks),
                    (select Id, AVB_Type__c, Subject_Sub_Category__c, StartDateTime, Status__c, Description, AVB_Associate_First_Last_Name__c from Events)
                    from Guest_Card__c where id = :gcid];
                
                //Add blank lines for Quotes to allow for data entry on the printed form
                gcQuotes = guestcard.Quotes__r;
                Integer realQuoteCount = gcQuotes.size();
                if (realQuoteCount < 3) {
                    for (Integer i = 0; i < (3 - realQuoteCount) ; i++) {
    system.debug('\n\n35 adding quote');
                        gcQuotes.add(new Quotes__c(
                            Guest_Card__c = guestcard.id
                        ));
                    }
                }
                
                //If no related items in list, pass null to the form
                if (guestcard.RMActions__r.size() > 0) gcRMActions = guestcard.RMActions__r;
                if (guestcard.Events.size() > 0) gcEvents = guestcard.Events;
                if (guestcard.Tasks.size() > 0) gcTasks = guestcard.Tasks;
            }
        }
    }
    
    //get methods
    public Guest_Card__c getGuestCard() { return guestcard; }
    public list<Quotes__c> getgcQuotes() { return gcQuotes; }
    public list<RMAction__c> getgcRMActions() { return gcRMActions; }
    public list<Event> getgcEvents() { return gcEvents; }
    public list<Task> getgcTasks() { return gcTasks; }
    
    public Guest_Card__c cloneGC(Id gcid)
    {
        Boolean FirstField = true;
        String querystring = 'Select';
        map<String,Schema.SObjectField> fieldnamesmap = Schema.SObjectType.Guest_Card__c.fields.getMap();
        for (String s : fieldnamesmap.keyset()) {
            if (fieldnamesmap.get(s).getDescribe().isUpdateable()) {
                //only put a comma after there's already a field in the list
                if (FirstField) {
                    FirstField = false;
                } else {
                    querystring += ',';         
                }
                
                querystring += ' ' + fieldnamesmap.get(s).getDescribe().getName();
            }
        }
        querystring += ' from Guest_Card__c where id = \'' + gcid + '\'';

        Guest_Card__c oldgc  = (Guest_Card__c)Database.query(querystring);
        
        Guest_Card__c duplicategc = oldgc.clone(false, true);
        
        duplicategc.Community__c = null;
        duplicategc.Shared__c = 'Yes - enter into MRI';
        duplicategc.AVB_Associate__c = 'Not Yet Assigned';
        duplicategc.Status__c = 'Active';
        duplicategc.Initial_Visit_Date__c = null;
        duplicategc.Lease_Date__c = null;
        duplicategc.Contact_Info_Has_Been_Edited__c = false;
        duplicategc.OwnerId = UserInfo.getUserId(); 
        
        //default Community if this user is a Community User. 
        //Look for a Community Account owned by a User with the same role as our User. If it's not clear, leave it blank.
        map<id, User> sameroleuseridmap = new map<id, User>([select Id from User where IsActive = true and UserRoleId = :UserInfo.getUserRoleId()]);
        
        list<Account> comms = [select Id, Name 
            from Account 
            where Recordtype.Name = 'Community' 
                and OwnerId in :sameroleuseridmap.keyset()];
        if (comms.size() > 0) {
            tempRMA.Community_Do_not_use__c = comms[0].id;
        }
system.debug('\n\n123 duplicategc ' + duplicategc);     
        return duplicategc;
    }
    
    public PageReference saveClone()
    {
        PageReference pr = null;
        
        if (tempRMA.Community_Do_not_use__c != null) {
            newGC.Community__c = tempRMA.Community_Do_not_use__c;
            Account newcomm = [select OwnerId from Account where id = :newGC.Community__c];
            newGC.OwnerID = newcomm.OwnerId;
            calculategcRating(newGC);
        }
        
        try {
            insert newGC;
            pr = new PageReference('/' + newGC.id);
        } catch (Exception e) {
            //ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, e.getMessage()));
        }
        
        return pr;
    }
    
    public PageReference cancelClone()
    {
        PageReference pr = new PageReference('/' + guestcard.id);
        return pr;
    }
    
    public void calculategcRating(Guest_Card__c gctorate)
    {
        //Calculate rating
        String rating;
        Boolean MatchedUnit = false;
        
        //Find Community Account
        Account comm = [select Target_Class_IDs__c from Account where id = :gctorate.Community__c];
        
        //See if Desired Unit Type on GC matches against Target Unit Type on Community
        list<String> communits = new list<String>();
        if (comm.Target_Class_IDs__c != null) communits = comm.Target_Class_IDs__c.split(';',0);
        list<String> gcunits = new list<String>();
        if (gctorate.Class_ID__c != null) gcunits = gctorate.Class_ID__c.split(';',0);
        for (String communit : communits) {
            if (MatchedUnit) break;
            for (String gcunit : gcunits) {
                if (communit == gcunit) {
                    MatchedUnit = true;
                }
            }
        }
        
        //Calculate days until Expected Move In Date
        Integer DaysUntilMoveIn = 61; //Default to far future
        if (gctorate.When_will_you_be_moving_in__c != null) DaysUntilMoveIn = system.today().addDays(-1).daysbetween(gctorate.When_will_you_be_moving_in__c); 
        
        //Determine actual rating based on days until move in and whether there's a Unit Type match
        if ((MatchedUnit) && (DaysUntilMoveIn <= 30)) {
            rating = 'Hot';
        } else if (DaysUntilMoveIn <= 60) {
            rating = 'Warm';
        } else {
            rating = 'Future';
        }
        
        //Assign rating 
        gctorate.Rating__c = rating;        
    }
    
    public static void makeGCShared(set<Id> gcids) 
    {
        //try
        {
            list<Guest_Card__c> gcstoupdate = new list<Guest_Card__c>();
            for (Id gcid : gcids)
            {
                gcstoupdate.add(new Guest_Card__c(
                    Id = gcid, 
                    SHARED__c = 'Yes'));
            }
            update gcstoupdate;
        }
        //catch (Exception e)
        { 
            //return false;
        }
        //return true;
    }
    
    public static String saveObj(SObject objtosave)
    {
        //Return null if successful
        String returnstring;
        try
        {
            upsert objtosave;
        }
        catch (Exception e)
        {
            returnstring = 'Exception occurred during save: ' + e.getMessage();
        }
        return returnstring;
    }
    
    public static list<Account> getAvailableCommunities(Id userId)
    {
        User thisUser = [select id, Name, UserRoleId, UserRole.Name, ProfileId, Profile.Name from User where id = :userId];
        map<id, set<Id>> spodid2subrolesmap = new map<id, set<id>>(); //Id of spod Role to set of Role Ids from subordinate Roles
        map<id, id> roleid2spodroleidmap = new map<id, id>(); //Role Id to parent/top spod Role Id 
        map<id, list<User>> roleid2usersmap = new map<id, list<User>>(); //Role Id to list of users who have that role

        //Map role hierarchy, paying attention to portfolio management segmentation. populate map of Spod id to subordinate role Ids
        list<UserRole> roles = [select id, ParentRoleId, Name from UserRole];
        map<id, UserRole> roleid2rolemap = new map<id, UserRole>(roles);
        
        //initialize spodid2subrolesmap with spod role Ids
        for (UserRole role : roles) {
            roleid2spodroleidmap.put(role.Id, null);
system.debug('\n\n263 Role ' + role.Name + ' ' + role.Id + '\nParent: ' + role.ParentRoleId);   

            //cjc 26JUN12: key on REGION instead of SPOD
            if (role.Name.contains('SPOD')) 
            {
                spodid2subrolesmap.put(role.id, new set<id> { role.Id });
                system.debug('\n\n267 this is a SPOD: ' + role.Name);                
            }
            //cjc 26JUN12: key on REGION instead of SPOD
        }
        
        
        Id currentId;
        Id parentId;
        set<id> otherRoleIds = new set<id>();
        for (UserRole role : roles) {
            currentId = role.id;
            Boolean spodFound = false;
            
            //If this is a spod, go to the next record
            if ((spodid2subrolesmap.containsKey(role.id))) {
                otherRoleIds.add(role.id);  
                roleid2spodroleidmap.put(role.id, role.Id);
                    
                continue;
            }
            
            //climb the hierarchy until you find a spod, then put this role id into the set for that spod and go to the next role
            while (spodFound == false){
                //If this role has a parentId, it will be in a spod
system.debug('\n\n287 role ' + role.Name + '\nparent ' + roleid2rolemap.get(currentId).parentRoleId);              
                if (roleid2rolemap.get(currentId).parentRoleId != null) {
                    parentId = roleid2rolemap.get(currentId).parentRoleId;
                } else {
                    //if no ParentId, keep this role to use later
                    otherRoleIds.add(currentId);
                    break; 
                }
                if (spodid2subrolesmap.containsKey(parentId)) {
system.debug('\n\n297 found spod ' + role.Name + ' spod: ' + roleid2rolemap.get(parentId).Name);                    
                    spodFound = true;
                    roleid2spodroleidmap.put(role.id, parentId);
                    spodid2subrolesmap.get(parentId).add(role.id);
system.debug('\n\n301 list ids ' + spodid2subrolesmap.get(parentId));                    
                } else {
                    currentId = parentId;
                }
            }
        }
        String rolemapstr = '';
        for (Id spodid : spodid2subrolesmap.keyset())
        {
            rolemapstr += '\n\n' + roleid2rolemap.get(spodid).Name + ' ' + spodid + '\n';
            for (Id i : spodid2subrolesmap.get(spodid))
                rolemapstr += roleid2rolemap.get(i) + ' ' + i + ', ';
        }
system.debug('\n\n302 spodid2subrolesmap ' + rolemapstr);        
        //get all Role Ids that will be affected
        Id spodId = roleid2spodroleidmap.get(thisUser.UserRoleId);
        set<id> affectedRoleIds = new set<Id>(); //Role Ids to use to find Communities
        affectedRoleIds.add(thisUser.UserRoleId);
        if (spodId != null)
        {
            if (spodid2subrolesmap.get(spodId).size() > 0) {
                affectedRoleIds.add(spodId);
                affectedRoleIds.addall(spodid2subrolesmap.get(spodId));
            }
        }
system.debug('\n\n326 affectedroleids ' + affectedroleids);        
        list<User> affectedusers = [select id, Name, UserRoleId 
            from User 
            where UserRoleId in :affectedRoleIds];
        set<Id> ownerids = new set<Id>();
        for (User u : affectedusers) 
        {
            ownerids.add(u.Id);
        }
system.debug('\n\n321 ownerids ' + ownerids);       
        list<Account> accs = [select Id, Name
            from Account
            where OwnerId in :ownerids
                and Recordtype.Name = 'Community'];
String acclist = '';        
for (Account a : accs)
{
    acclist += '\n- ' + a.Id + ' ' + a.Name;
}                       
system.debug('\n\n332 acclist ' + acclist); 
        return accs;
    } 
    
/*  Testmethods for this class  */
    
    static testmethod void testPrintableGuestCard()
    {
        Id cgrtid;
        Id commrtid;
        list<Recordtype> rts = [select id, Name from Recordtype where SObjectType = 'Account'];
        for (Recordtype rt : rts) {
            if (rt.Name == 'Customer Group') cgrtid = rt.id;
            if (rt.Name == 'Community') commrtid = rt.id;
        }
        
        Account testcomm = new Account(
            Name = 'test comm account',
            RecordtypeId = commrtid,
            Target_Class_IDs__c = '2T;2Y;0'
            );
        insert testcomm;
        
        Account a = new Account(
            Name = 'test CG Account',
            RecordtypeId = cgrtid,
            PROSPECT_ClassID__c = '2T',
            ParentId = testcomm.id
            );
        insert a;
        
        a = [select id, Name, (select Id from Guest_Cards__r) from Account where id = :a.id];
        Guest_Card__c testgc;
        if (a.Guest_Cards__r.size() > 0) {
            testgc = a.Guest_Cards__r[0];
        } else {
            testgc = new Guest_Card__c(
                Prospect_Account__c = a.id,
                AVB_Associate__c = 'Not Assigned',
                Rating__c = 'Hot',
                Community__c = testcomm.id
                );
            insert testgc;
        }
        
test.startTest();
        test.setCurrentPage(Page.PrintableGuestCard);
        ApexPages.standardController stdcon = new ApexPages.standardController(testgc);
        GuestCard_Ext gce = new GuestCard_Ext(stdcon);
        
        Guest_Card__c returnGC = gce.getGuestCard();
        
test.stopTest();
        system.assertEquals(testgc.id, returnGC.id);
system.debug('\n\n84 returnGC ' + returnGC);        
        system.assertEquals(0, returnGC.Quotes__r.size());
        system.assertEquals(3, gce.getgcQuotes().size());
        
        system.assertEquals(0, returnGC.RMActions__r.size());
        system.assertEquals(null, gce.getgcRMActions());

        system.assertEquals(0, returnGC.Events.size());
        system.assertEquals(null, gce.getgcEvents());

        system.assertEquals(1, returnGC.Tasks.size());
    
    }
    
    static testmethod void testobjsave()
    {
        Account a = new Account(Name = 'testacc');
test.startTest();
        String results = GuestCard_Ext.saveObj(a);
test.stopTest();        
        system.assertEquals(null, results);
        system.assertNotEquals(null, a.Id);
        
    }
    
    static testmethod void testClone()
    {
        Id cgrtid;
        Id commrtid;
        list<Recordtype> rts = [select id, Name from Recordtype where SObjectType = 'Account'];
        for (Recordtype rt : rts) {
            if (rt.Name == 'Customer Group') cgrtid = rt.id;
            if (rt.Name == 'Community') commrtid = rt.id;
        }
        
        Account testcomm = new Account(
            Name = 'test comm account',
            RecordtypeId = commrtid,
            Target_Class_IDs__c = '2T;2Y;0'
            );
        insert testcomm;
        
        Account testcomm2 = new Account(
            Name = 'test comm account 2',
            RecordtypeId = commrtid,
            Target_Class_IDs__c = '2T;2Y;0'
            );
        insert testcomm2;
        
        Account a = new Account(
            Name = 'test CG Account',
            RecordtypeId = cgrtid,
            PROSPECT_ClassID__c = '2T',
            ParentId = testcomm.id,
            Expected_Move_In_Date__c = system.today().addDays(15)
            );
        insert a;
        
        a = [select id, Name, (select Id from Guest_Cards__r) from Account where id = :a.id];
        if (a.Guest_Cards__r.size() > 0) delete a.Guest_Cards__r;
        
        list<Guest_Card__c> testgcs = new list<Guest_Card__c>();
        Guest_Card__c hotgc = new Guest_Card__c(
            Prospect_Account__c = a.id,
            AVB_Associate__c = 'test person',
            Class_ID__c = '2T',
            Rating__c = 'Hot',
            When_will_you_be_moving_in__c = system.today().addDays(15),
            Community__c = testcomm.id
            );
        testgcs.add(hotgc);
        Guest_Card__c Warmgc = new Guest_Card__c(
            Prospect_Account__c = a.id,
            AVB_Associate__c = 'test person',
            Class_ID__c = '2T',
            Rating__c = 'Warm',
            When_will_you_be_moving_in__c = system.today().addDays(45),
            Community__c = testcomm.id
            );
        testgcs.add(Warmgc);
        Guest_Card__c Futuregc = new Guest_Card__c(
            Prospect_Account__c = a.id,
            AVB_Associate__c = 'test person',
            Class_ID__c = '2T',
            Rating__c = 'Future',
            When_will_you_be_moving_in__c = system.today().addDays(75),
            Community__c = testcomm.id
            );
        testgcs.add(Futuregc);
        insert testgcs;
        
        
test.StartTest();
        //Clone Hot GC
        Test.setCurrentPage(Page.CloneGuestCard);
        ApexPages.CurrentPage().getParameters().put('clone', '1');
        ApexPages.CurrentPage().getParameters().put('id',hotgc.id);
        ApexPages.standardController stdcon = new ApexPages.standardController(hotgc);
        GuestCard_Ext gce = new GuestCard_Ext(stdcon);
        gce.newGC.Community__c = testcomm2.id;
        gce.saveClone();
        //system.assertEquals('Hot', gce.newGC.Rating__c);
        
        //Clone Warm GC
        Test.setCurrentPage(Page.CloneGuestCard);
        ApexPages.CurrentPage().getParameters().put('clone', '1');
        ApexPages.CurrentPage().getParameters().put('id',Warmgc.id);
        stdcon = new ApexPages.standardController(Warmgc);
        gce = new GuestCard_Ext(stdcon);
        gce.newGC.Community__c = testcomm2.id;
        gce.saveClone();
        //system.assertEquals('Warm', gce.newGC.Rating__c);
        
        //Clone Future GC
        Test.setCurrentPage(Page.CloneGuestCard);
        ApexPages.CurrentPage().getParameters().put('clone', '1');
        ApexPages.CurrentPage().getParameters().put('id',Futuregc.id);
        stdcon = new ApexPages.standardController(Futuregc);
        gce = new GuestCard_Ext(stdcon);
        gce.newGC.Community__c = testcomm2.id;
        gce.saveClone();
        //system.assertEquals('Future', gce.newGC.Rating__c);
        
        //Cancel
        PageReference testpr = gce.cancelClone();
        //system.assertnotEquals(null, testpr);
        
        
        
test.StopTest();
                
    }
    
    static testmethod void testGetAvailableCommunities()
    {
        User adminuser = [select Id from User where Profile.Name = 'System Administrator' and IsActive = TRUE limit 1];
        UserRole spodrole;
        UserRole subrole;
        User spoduser;
        User subuser1;
        User subuser2;
        User independentUser;
        
        system.runAs(adminuser)
        {
            list<UserRole> roles = new list<UserRole>();
            spodrole = new UserRole(
                Name = 'REGION test Role');
            roles.add(spodrole);
            subrole = new UserRole(Name = 'sub role');
            roles.add(subrole);
            insert roles;
            
            subrole.parentRoleId = spodrole.Id;
            update subrole;
        
        
            Profile p = [select Id from Profile where Name = 'Community'];
            list<User> newusers = new list<User>();
            spoduser = new User(alias = 'test123', 
                email='test7805678442@avalonbay.com.blueberry',
                emailencodingkey='UTF-8', 
                lastname='Testing', 
                Department='Other',
                languagelocalekey='en_US',
                localesidkey='en_US', 
                profileid = p.Id, 
                UserRoleId = spodrole.Id,
                country='United States', 
                timezonesidkey='America/Los_Angeles', 
                username='1test7805a678442@avalonbay.com.blueberry'
                );
            newusers.add(spoduser);
            subuser1 = new User(alias = 'test123', 
                email='test7805678442@avalonbay.com.blueberry',
                emailencodingkey='UTF-8', 
                lastname='Testing', 
                Department='Other',
                languagelocalekey='en_US',
                localesidkey='en_US', 
                profileid = p.Id, 
                UserRoleId = subrole.Id,
                country='United States', 
                timezonesidkey='America/Los_Angeles', 
                username='1test780b5678442@avalonbay.com.blueberry'
                );
            newusers.add(subuser1);
            subuser2 = new User(alias = 'test123', 
                email='test7805678442@avalonbay.com.blueberry',
                emailencodingkey='UTF-8', 
                lastname='Testing', 
                Department='Other',
                languagelocalekey='en_US',
                localesidkey='en_US', 
                profileid = p.Id, 
                UserRoleId = subrole.Id,
                country='United States', 
                timezonesidkey='America/Los_Angeles', 
                username='1test7c805678442@avalonbay.com.blueberry'
                );
            newusers.add(subuser2);
            independentUser = new User(alias = 'test123', 
                email='test7805678442@avalonbay.com.blueberry',
                emailencodingkey='UTF-8', 
                lastname='Testing', 
                Department='Other',
                languagelocalekey='en_US',
                localesidkey='en_US', 
                profileid = p.Id, 
                country='United States', 
                timezonesidkey='America/Los_Angeles', 
                username='1test7ca805678442@avalonbay.com.blueberry'
                );
            newusers.add(independentUser);
            
            insert newusers;
        }
        
        Id commrtid = [select Id from Recordtype where SObjectType = 'Account' and Name = 'Community' limit 1].Id;
        list<Account> comms = new list<Account>();
        comms.add(new Account(
            RecordtypeId = commrtid,
            Name = 'testcomm1',
            OwnerId = spoduser.Id));
        comms.add(new Account(
            RecordtypeId = commrtid,
            Name = 'testcomm1',
            OwnerId = subuser1.Id));
        comms.add(new Account(
            RecordtypeId = commrtid,
            Name = 'testcomm1',
            OwnerId = subuser2.Id));
        comms.add(new Account(
            RecordtypeId = commrtid,
            Name = 'testcomm1',
            OwnerId = independentUser.Id));
        insert comms;
        
test.startTest();
system.debug('\n\n615 ');
        list<Account> returnedcomms = GuestCard_Ext.getAvailableCommunities(spoduser.Id);
        system.assertEquals(3,returnedcomms.size());
        returnedcomms = GuestCard_Ext.getAvailableCommunities(subuser1.Id);
        system.assertEquals(3,returnedcomms.size());
        returnedcomms = GuestCard_Ext.getAvailableCommunities(subuser2.Id);
        system.assertEquals(3,returnedcomms.size());
        returnedcomms = GuestCard_Ext.getAvailableCommunities(independentUser.Id);
        system.assertEquals(1,returnedcomms.size());
        
test.stopTest();        
    }
}