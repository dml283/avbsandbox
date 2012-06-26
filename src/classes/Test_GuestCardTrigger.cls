@isTest
private class Test_GuestCardTrigger {
    
    //test Managed Sharing
    static testmethod void testGCInsert()
    {
        Id cgrtid = [select id from Recordtype where Name = 'Customer Group' and SObjectType = 'Account'].id;
        Id commrtid = [select id from Recordtype where Name = 'Community' and Sobjecttype = 'Account'].id;
        
        User adminuser = [select Id from User where Profile.Name = 'System Administrator' and IsActive = true limit 1];
        
        system.runAs(adminuser)
        {
	        list<UserRole> SPODroles = new list<UserRole>();
	        SPODroles.add(new UserRole(
	            Name = 'Test SPOD A'));
	        SPODroles.add(new UserRole(
	            Name = 'Test SPOD B'));
	        insert SPODroles;
	        
	        list<UserRole> commroles = new list<UserRole>();
	        UserRole rolea = new UserRole(
	            Name = 'Community A',
	            ParentRoleId = SPODroles[0].id);
	        commroles.add(rolea);
	        UserRole roleb = new UserRole(
	            Name = 'Community B',
	            ParentRoleId = SPODroles[0].id);
	        commroles.add(roleb);
	        UserRole rolex = new UserRole(
	            Name = 'Community X',
	            ParentRoleId = SPODroles[1].id);
	        commroles.add(rolex);
	        insert commroles;
	        
	        list<User> users = [select id, UserRoleId from User where IsActive = true limit 4];
	        User commuser1 = users[0];
	        User commuser2 = users[1];
	        User SPODuser = users[2];
	        User otheruser = users[3];
	        commuser1.UserRoleId = rolea.id;
	        commuser2.UserRoleId = rolea.id;
	        SPODuser.UserRoleId = roleb.id;
	        otheruser.UserRoleId = rolex.id;
	        update users;
	        
	        list<Account> testaccs = new list<Account>();
	        Account testacc1 = new Account(
	            Name = 'testacc1',
	            Status__c = 'Prospect',
	            RecordtypeId = cgrtid);
	        Account testacc2 = new Account(
	            Name = 'testacc2',
	            Status__c = 'Resident',
	            RecordtypeId = cgrtid);
	        testaccs.add(testacc1);
	        testaccs.add(testacc2);
	        
	        insert testaccs;
	        
	        Account testcomm = new Account(
	            Name = 'testcomm',
	            RecordtypeId = commrtid);
	        insert testcomm;
	        
	        testaccs = [select id, (select id from Guest_Cards__r) from Account where id in :testaccs];
	        delete testacc1.Guest_Cards__r;
	        delete testacc2.Guest_Cards__r;
	        
	        list<Guest_Card__c> testgcs = new list<Guest_Card__c>();
	        testgcs.add(new Guest_Card__c(
	            Name = 'testgc1',
	            Prospect_Account__c = testacc1.id,
	            Status__c = 'Active',
	            OwnerId = commuser1.id,
	            AVB_Associate__c = 'test associate',
	            Community__c = testcomm.id));
	        testgcs.add(new Guest_Card__c(
	            Name = 'testgc2',
	            Prospect_Account__c = testacc2.id,
	            Status__c = 'Leased',
	            OwnerId = commuser1.id,
	            AVB_Associate__c = 'test associate',
	            Community__c = testcomm.id));
	        
	        
	        
	test.startTest(); 
	        insert testgcs;
	        
	        //Make sure tasks are created properly
	        testgcs = [Select Id, Status__c, Lease_Date__c, (Select Subject_Sub_Category__c from Tasks)
	            from Guest_Card__c
	            where Id in :testgcs];
	        system.assertEquals(2, testgcs.size());
	        Integer checknum = 1;
	        for (Guest_Card__c gc : testgcs)
	        {
	            if (gc.Status__c == 'Active')
	            {
	                checknum *= 2;
	                system.assertEquals(1, gc.Tasks.size());
	            } else if (gc.Status__c == 'Leased')
	            {
	                checknum *= 3;
	                system.assertEquals(0, gc.Tasks.size());
	            }
	        }
	        system.assertEquals(2 * 3, checknum);
	        
	        Boolean ExceptionFlag = false;
	        try {
	            Guest_Card__c testgc2 = new Guest_Card__c(
	                Name = 'testgc2', 
	                Prospect_Account__c = testacc1.id, 
	                OwnerId = commuser1.id,
	                Community__c = testcomm.id);
	            insert testgc2;
	        } catch (Exception e) {
	            system.assert(e.getMessage().contains('There is already a Guest Card for this Customer Group at this Community.'));
	            ExceptionFlag = true;
	            
	        }
	test.stopTest();    
	        system.assertEquals(true, ExceptionFlag);
	        
	        list<Guest_Card__Share> gcshares = [select id, RowCause, ParentId, UserOrGroupId 
	            from Guest_Card__Share 
	            where ParentId in :testgcs];
	        for (Guest_Card__Share gcs : gcshares) {
	            if (gcs.RowCause == Schema.Guest_Card__Share.RowCause.Owner) {
	                system.assert(gcs.UserOrGroupId == commuser1.id);
	            } 
	            else if (gcs.RowCause == Schema.Guest_Card__Share.RowCause.Community__c) {
	                system.assert((gcs.UserOrGroupId == commuser1.id)
	                || (gcs.UserOrGroupId == commuser2.id));
	            }
	            else if (gcs.RowCause == Schema.Guest_Card__Share.RowCause.POD__c) {
	                system.assert((gcs.UserOrGroupId == commuser1.id)
	                    || (gcs.UserOrGroupId == commuser2.id)
	                    || (gcs.UserOrGroupId == SPODuser.id));
	            }
	            
	            if (gcs.UserOrGroupId == otheruser.id) {
	                system.assert(false, 'Rule created for inappropriate user.');
	            }
	        }
        }
        
    }

//test Email close task
    static testmethod void testGCUpdate()
    {
        Id cgrtid = [select id from Recordtype where Name = 'Customer Group' and SObjectType = 'Account'].id;
        Id commrtid = [select id from Recordtype where Name = 'Community' and Sobjecttype = 'Account'].id;
        
        
        list<Account> testaccs = new list<Account>();
        Account testacc1 = new Account(
            Name = 'testacc1',
            Status__c = 'Prospect',
            RecordtypeId = cgrtid);
        Account testacc2 = new Account(
            Name = 'testacc2',
            Status__c = 'Resident',
            RecordtypeId = cgrtid);
        testaccs.add(testacc1);
        testaccs.add(testacc2);
        insert testaccs;
        
        Account testcomm = new Account(
            Name = 'testcomm',
            RecordtypeId = commrtid);
        insert testcomm;
        
        testaccs = [select id, (select id from Guest_Cards__r) from Account where id in :testaccs];
        delete testacc1.Guest_Cards__r;
        delete testacc2.Guest_Cards__r;
        
        list<Guest_Card__c> testgcs = new list<Guest_Card__c>();
        testgcs.add(new Guest_Card__c(
            Name = 'testgc1',
            Prospect_Account__c = testacc1.id,
            Rating__c = 'Hot',
            Status__c = 'Active',
            AVB_Associate__c = 'test associate',
            Community__c = testcomm.id));
        insert testgcs;
        
        
        
        
        //Make sure tasks are created properly
        testgcs = [Select Id, Status__c, Lease_Date__c, Rating__c,
            (Select Subject_Sub_Category__c from Tasks where Status != 'Complete')
            from Guest_Card__c
            where Id in :testgcs];
        system.assertEquals(1, testgcs.size());
        system.assertEquals(1, testgcs[0].Tasks.size());
        
        testgcs[0].Initial_Lead_Type__c = 'Email';
test.startTest(); 
        update testgcs;

test.stopTest();    
        
        //Make sure task is closed and rating set to Warm
        testgcs = [Select Id, Status__c, Lease_Date__c, Rating__c,
            (Select Subject_Sub_Category__c from Tasks where Status != 'Complete')
            from Guest_Card__c
            where Id in :testgcs];
        system.assertEquals(1, testgcs.size());
        system.assertEquals(0, testgcs[0].Tasks.size());
        
        
    }

//test AVB Associate copy
    static testmethod void testGCUpdate2()
    {
        Id cgrtid = [select id from Recordtype where Name = 'Customer Group' and SObjectType = 'Account'].id;
        Id commrtid = [select id from Recordtype where Name = 'Community' and Sobjecttype = 'Account'].id;
        
        list<MRILeasingAssociate__c> testmris = new list<MRILeasingAssociate__c>();
        MRILeasingAssociate__c testmri1 = new MRILeasingAssociate__c(
        	LeasingAssociatePrimaryCommunity__c = 'xxxx',
			LeasingAssociateName__c = 'test name',
			LeasingAssociateID__c = 'testMRI1',
			IsLeasingAssociateActive__c = TRUE);
		MRILeasingAssociate__c testmri2 = new MRILeasingAssociate__c(
        	LeasingAssociatePrimaryCommunity__c = 'xxxx',
			LeasingAssociateName__c = 'second name',
			LeasingAssociateID__c = 'testMRI2',
			IsLeasingAssociateActive__c = TRUE);
		testmris.add(testmri1);
		testmris.add(testmri2);
		insert testmris;
        
        list<Account> testaccs = new list<Account>();
        Account testacc1 = new Account(
            Name = 'testacc1',
            Status__c = 'Prospect',
            RecordtypeId = cgrtid);
        testaccs.add(testacc1);
        insert testaccs;
        
        Account testcomm = new Account(
            Name = 'testcomm',
            RecordtypeId = commrtid);
        insert testcomm;
        
        testaccs = [select id, (select id from Guest_Cards__r) from Account where id in :testaccs];
        delete testacc1.Guest_Cards__r;
        
        list<Guest_Card__c> testgcs = new list<Guest_Card__c>();
        testgcs.add(new Guest_Card__c(
            Name = 'testgc1',
            Prospect_Account__c = testacc1.id,
            Rating__c = 'Hot',
            Status__c = 'Active',
            MRI_Leasing_Associate__c = testmri1.Id,
            Community__c = testcomm.id,
            Initial_Visit_Date__c = system.today()));

test.startTest(); 
        insert testgcs;
        
        list<Task> testtasks = new list<Task>();
        list<Event> testevents = new list<Event>();
        for (Guest_Card__c gc : testgcs)
        {
            testtasks.add(new Task(
                WhatId = gc.Id,
                Status = 'Not Started',
                AVB_Type__c = 'Lead Pursuit Process',
                AVB_Associate_First_Last_Name__c = 'test associate'
                ));
            testevents.add(new Event(
                WhatId = gc.Id,
                StartDateTime = system.now(),
                DurationInMinutes = 60,
                AVB_Type__c = 'Lead Pursuit Process',
                Subject_Sub_Category__c = 'Visit',
                AVB_Associate_First_Last_Name__c = 'test associate'
                ));
        }
        
        insert testtasks;
        insert testevents;
        
        //Make sure Guest Card and tasks are created with proper AVB Associate
        testgcs = [Select Id, AVB_Associate__c, MRI_Leasing_Associate__c,
            (Select AVB_Associate_First_Last_Name__c from Tasks),
            (Select AVB_Associate_First_Last_Name__c from Events)
            from Guest_Card__c
            where Id in :testgcs];
        system.assertEquals(1, testgcs.size());
        system.assertEquals(testmri1.Id, testgcs[0].MRI_Leasing_Associate__c);
        system.assertEquals(testmri1.LeasingAssociateName__c, testgcs[0].AVB_Associate__c);
        system.assertnotEquals(0, testgcs[0].Tasks.size());
        system.assertnotEquals(0, testgcs[0].Events.size());
        
		//change MRI Leasing Associate
      	testgcs[0].MRI_Leasing_Associate__c = testmri2.Id;
        update testgcs;

test.stopTest();    
        
        //Make sure Guest Card, tasks and events are all changed on AVB Associate
        testgcs = [Select Id, AVB_Associate__c, MRI_Leasing_Associate__c, 
            (Select AVB_Associate_First_Last_Name__c from Tasks),
            (Select AVB_Associate_First_Last_Name__c from Events)
            from Guest_Card__c
            where Id in :testgcs];
        system.assertEquals(1, testgcs.size());
        system.assertEquals(testmri2.Id, testgcs[0].MRI_Leasing_Associate__c);
        system.assertEquals(testmri2.LeasingAssociateName__c, testgcs[0].AVB_Associate__c);
        
        for (Guest_Card__c gc : testgcs)
        {
            for (Task t : gc.Tasks)
            {
                system.assertEquals(gc.AVB_Associate__c, t.AVB_Associate_First_Last_Name__c);
            }
            for (Event e : gc.Events)
            {
                system.assertEquals(gc.AVB_Associate__c, e.AVB_Associate_First_Last_Name__c);
            }
        }
        
    }

}