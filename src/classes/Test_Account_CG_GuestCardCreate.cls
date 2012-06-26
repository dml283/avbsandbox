@isTest
private class Test_Account_CG_GuestCardCreate {
    /*
    Purpose:    Test Account_CG_GuestCardCreate Trigger.
                Scenarios:
                    Insert:
                        CG Account Inserted
                            Verify Guest Card created
                            Verify Guest Card data correct
                            Verify Guest Card Rating calculated properly for Hot, Warm and Future cases
                    Update
                        CG Account changed to Resident Status__c
                            Verify all Guest Cards changed Status = Leased and Lease Date = YESTERDAY
                            
    
    Created By:     Jeremy Nottingham (Synaptic) 1/31/2011
    
    Last Modified By:   Jeremy Nottingham (Synaptic) 3/10/2011
    
    Current Version:    v1.1
    
    Revision Log:       v1.0 - 1/31/2011 - (JN) Created trigger and basic test class
                        v1.1 - 3/10/11 - (JN) Brought trigger test coverage up to 100%, including adding Resident test code
    
    */
    
    static testmethod void testCGinsertandResidentUpdate()
    {
    /*  
        Tests all three possible ratings.
        Tests that CG Account changing to Resident will update Guest Card Status and Lease Date values 
    */
        Id cgrtid = [select id from Recordtype where SObjectType = 'Account' and Name = 'Customer Group'].id;
        Id commrtid = [select id from Recordtype where SObjectType = 'Account' and Name = 'Community'].id;
        
        Account testcomm = new Account(
            Name = 'test community',
            RecordtypeId = commrtid,
            Target_Class_IDs__c = '1Y;2A;2AM'
            );
        insert testcomm;
        
        list<Account> testaccs = new list<Account>();
        Account testhotcg = new Account(
            Name = 'testacc',
            RecordtypeId = cgrtid,
            Expected_Move_In_Date__c = system.today().addDays(15),
            Status__c = 'Prospect',
            PROSPECT_ClassID__c = '1Y',
            PROSPECT_LeasingAgent__c = 'Internet',
            ParentId = testcomm.id
            );
        testaccs.add(testhotcg);
        Account testwarmcg = new Account(
            Name = 'testacc',
            RecordtypeId = cgrtid,
            Expected_Move_In_Date__c = system.today().addDays(15),
            Status__c = 'Prospect',
            PROSPECT_ClassID__c = '3A',
            PROSPECT_LeasingAgent__c = 'OnlineLease',
            ParentId = testcomm.id
            );
        testaccs.add(testwarmcg);
        Account testfuturecg = new Account(
            Name = 'testacc',
            RecordtypeId = cgrtid,
            Expected_Move_In_Date__c = system.today().addDays(75),
            Status__c = 'Prospect',
            PROSPECT_ClassID__c = '1Y',
            PROSPECT_LeasingAgent__c = 'oneword',
            ParentId = testcomm.id
            );
        testaccs.add(testfuturecg);
        Account testresident = new Account(
            Name = 'testresident',
            RecordtypeId = cgrtid,
            Expected_Move_In_Date__c = system.today().addDays(-15),
            Status__c = 'Resident',
            PROSPECT_ClassID__c = 'RES',
            PROSPECT_LeasingAgent__c = 'OnlineLease',
            ParentId = testcomm.id
            );
        testaccs.add(testresident);
        
test.StartTest();       
        insert testaccs;
        
        //Verify values for new Guest Cards
        testaccs = [select id, Expected_Move_In_Date__c, PROSPECT_ClassID__c, ParentIsLiveOnLM__c, 
            (select id, Rating__c, Shared__c, Status__c, Lease_Date__c from Guest_Cards__r) 
            from Account where id in :testaccs];
        Integer signoff = 1;
        for (Account a : testaccs) {
            system.assertEquals(1, a.Guest_Cards__r.size());
            system.assertEquals('No', a.Guest_Cards__r[0].Shared__c);
            
            if (a.PROSPECT_ClassID__c.contains('1Y')) {
                system.assertEquals('Active', a.Guest_Cards__r[0].Status__c);
                system.assertEquals(null, a.Guest_Cards__r[0].Lease_Date__c);
                if (a.Expected_Move_In_Date__c <= system.today().addDays(30)) {
                    signoff *= 5;
                    system.assertEquals('Hot',a.Guest_Cards__r[0].Rating__c);
                }
                if (a.Expected_Move_In_Date__c > system.today().addDays(60)) {
                    signoff *= 3;
                    system.assertEquals('Future',a.Guest_Cards__r[0].Rating__c);
                }
            } else if (a.PROSPECT_ClassID__c.contains('3A')){
                signoff *= 7;
                system.assertEquals('Warm', a.Guest_Cards__r[0].Rating__c);
                system.assertEquals('Active', a.Guest_Cards__r[0].Status__c);
                system.assertEquals(null, a.Guest_Cards__r[0].Lease_Date__c);
            } else if (a.PROSPECT_ClassID__c.contains('RES'))
            {
                signoff *= 11;
                system.assertEquals('Leased', a.Guest_Cards__r[0].Status__c);
                system.assertEquals(system.today().addDays(-1), a.Guest_Cards__r[0].Lease_Date__c);
            }
            
        }
        //prime numbers multiplied to confirm each of the signoff lines got hit once.
        system.assertEquals(3 * 5 * 7 * 11, signoff);
        
        //Test Resident update now
        for (Account a : testaccs) {
            a.Status__c = 'Resident';
        }
system.debug('\n\n105 update');
        update testaccs;
test.stopTest();        

        testaccs = [select id,
            (select id, Status__c, Lease_Date__c, Rating__c from Guest_Cards__r where Shared__c = 'No')
            from Account where id in :testaccs];
        for (Account a : testaccs) {
            
            system.assertEquals(1, a.Guest_Cards__r.size());
            system.assertEquals('Leased', a.Guest_Cards__r[0].Status__c);
            system.assertEquals(system.today().addDays(-1), a.Guest_Cards__r[0].Lease_Date__c);
        }   
        
    }
    
        static testmethod void testCGinsertfieldUpdate()
    {
    /*  
        Create in MRI
        Unique_Record_ID__c
    */
        Id cgrtid = [select id from Recordtype where SObjectType = 'Account' and Name = 'Customer Group'].id;
        Id commrtid = [select id from Recordtype where SObjectType = 'Account' and Name = 'Community'].id;
        
        Account testcomm = new Account(
            Name = 'test community',
            RecordtypeId = commrtid,
            Target_Class_IDs__c = '1Y;2A;2AM'
            );
        insert testcomm;
        
        list<Account> testaccs = new list<Account>();
        Account testresident = new Account(
            Name = 'testacc',
            RecordtypeId = cgrtid,
            Status__c = 'Prospect',
            PROSPECT_ClassID__c = 'RES',
            PROSPECT_LeasingAgent__c = 'OnlineLease',
            ParentId = testcomm.id
            );
        testaccs.add(testresident);
        
test.StartTest();       
        insert testaccs;
         
        //Verify values for new Guest Cards
        testaccs = [select id, Unique_Record_ID__c, Create_In_MRI__c
            from Account 
            where id in :testaccs];
        system.assertEquals(1, testaccs.size());
        system.assertEquals(testaccs[0].Id, testaccs[0].Unique_Record_Id__c);
        system.assert(testaccs[0].Create_In_MRI__c);
        
test.stopTest();        

        
    }
  
}