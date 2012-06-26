@isTest
private class CGU_MoveInMoveOutTrigTest {
/* Jeremy Nottingham 2010 */
    
//Move OUT
  
    static testMethod void testNewMoveOut() {
        // NTV date blank to populated, Expected move out date blank to populated
        //Find a CGU to use, reset to blank. 
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        User u = [select id from User where IsActive = true limit 1];
        list<Account> accs = [select id, OwnerID, (select id from Cases), 
        	(select id from Contacts where Primary_Contact__c = true) 
        	from Account where Owner.IsActive = true and RecordTypeID = :rtid limit 3];
        set<id> accids = new set<Id>();
        for ( Account a : accs) {
        	delete a.Cases;
        	accids.add(a.id);
        }
        delete accs[1].Contacts; //remove Primary Contacts from one Account (Customer Group)
        
        list<Customer_Group_to_Unit_Relationships__c> newcgus = new list<Customer_Group_to_Unit_Relationships__c>();
        for ( Account a : accs) {
        	newcgus.add(new Customer_Group_to_Unit_Relationships__c(
        		OwnerID = u.id,
        		Customer_Group__c = a.id,
        		Move_In_Date__c = system.today().addDays(30)
        		));
    	}
        
        insert newcgus;
        
        //get other cases out of the way
        list<Case> cases = [select id, AccountID from Case where AccountID in :accids and Status = 'Open'];
        delete cases;
        
		for (Customer_Group_to_Unit_Relationships__c newcgu : newcgus) {
	        newcgu.NTV_Date__c = system.today().addDays(-1);
	        newcgu.Expected_Move_Out_Date__c = system.today().addDays(10);
	        newcgu.Preliminary_Inspection_Date__c = system.now().addDays(5);
		}
		
		//Should be no Case created for this one.
		newcgus[2].Move_Out_Reason__c = 'Evict/Skip/Non-renewal';

test.StartTest();
        update newcgus;

test.StopTest();   
        
        cases = [select id, Status, Reason, NTV_Date__c, Move_Out_Date__c, OwnerID, Preliminary_Inspection_Date__c, AccountID from Case where AccountID in :accids and Status = 'Open'];
        
        system.assertEquals(2,cases.size()); // There should be only one open case
        system.assertEquals('Open',cases[0].Status);     
        //system.assertEquals('Notice To Vacate',cases[0].Reason);
        system.assertEquals('Open',cases[0].Status);
        system.assertEquals(system.today().addDays(-1),cases[0].NTV_Date__c);
        system.assertEquals(system.today().addDays(10),cases[0].Move_Out_Date__c);
        system.assertEquals(system.now().date().addDays(5),cases[0].Preliminary_Inspection_Date__c.date());
        for (Case c : cases) {
        	for (Account a : accs) {
        		if (c.AccountID == a.Id) system.assertEquals(a.OwnerID, c.OwnerID);
        	}
        }
    }

    static testMethod void testNewMoveOutNoPrelimDate() {
        // NTV date blank to populated, Expected move out date blank to populated
        //Find a CGU to use, reset to blank. 
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        User u = [select id from User where IsActive = true limit 1];
        Account a = [select id, OwnerID, (select id from Cases) from Account where Owner.IsActive = true and RecordTypeID = :rtid limit 1];
        delete a.Cases;
        
        Customer_Group_to_Unit_Relationships__c newcgu = new Customer_Group_to_Unit_Relationships__c();
        newcgu.Customer_Group__c = a.id;
        newcgu.NTV_Date__c = null;
        newcgu.OwnerID = u.id;
        newcgu.Move_In_Date__c = system.today().addDays(5);
        
        insert newcgu;
        
        //get other cases out of the way
        list<Case> cases = [select id, AccountID from Case where AccountID = :a.id and Status = 'Open'];
        delete cases;
        
test.StartTest();
        newcgu.NTV_Date__c = system.today().addDays(-1);
        newcgu.Expected_Move_Out_Date__c = system.today().addDays(10);
        //newcgu.Preliminary_Inspection_Date__c = system.now().addDays(5);
        update newcgu;

test.StopTest();   
        
        cases = [select id, Status, Reason, NTV_Date__c, Move_Out_Date__c, OwnerID, Preliminary_Inspection_Date__c from Case where AccountID = :a.id and Status = 'Open'];
        
        system.assertEquals(1,cases.size()); // There should be only one open case
        system.assertEquals('Open',cases[0].Status);     
        //system.assertEquals('Notice To Vacate',cases[0].Reason);
        system.assertEquals('Open',cases[0].Status);
        system.assertEquals(system.today().addDays(-1),cases[0].NTV_Date__c);
        system.assertEquals(system.today().addDays(10),cases[0].Move_Out_Date__c);
system.debug('\n\nsystemnow ' + system.now() + '\n\npredate ' + cases[0].Preliminary_Inspection_Date__c);        
        system.assertEquals(newcgu.Expected_Move_Out_Date__c.addDays(-14),cases[0].Preliminary_Inspection_Date__c.dateGMT());
        system.assertEquals(a.OwnerID, cases[0].OwnerID);
    }

    static testMethod void testCancelMoveOut() {
        // NTV_Date__c was populated, now blank
        //Find a CGU to use, reset to blank. 
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        Account a = [select id, OwnerID, (select id from Cases) from Account where RecordTypeID = :rtid and Owner.IsActive = true limit 1];
        delete a.Cases;
        
        Customer_Group_to_Unit_Relationships__c newcgu = new Customer_Group_to_Unit_Relationships__c();
        newcgu.Customer_Group__c = a.id;
        newcgu.NTV_Date__c = null;
        newcgu.Move_In_Date__c = system.today().addDays(40);
        newcgu.OwnerID = a.OwnerID;
        insert newcgu;
        
        //get other cases out of the way
        list<Case> cases = [select id, AccountID from Case where AccountID = :a.id and Status = 'Open'];
        system.assertEquals(1, cases.size());
        delete cases;
        
        //start Move Out on this one.
        newcgu.NTV_Date__c = system.today().addDays(-1);
        newcgu.Expected_Move_Out_Date__c = system.today().addDays(20);
        newcgu.Preliminary_Inspection_Date__c = system.now().addDays(5);
        update newcgu;
        
        cases = [select id, AccountID from Case where AccountID = :a.id and Status = 'Open'];
        system.assertEquals(1,cases.size()); // There should be only one new case
        
test.StartTest();
        newcgu.NTV_Date__c = null;
        newcgu.Expected_Move_Out_Date__c = null;
        update newcgu;
        
test.StopTest();   
        Case testcase = [select Status from Case where id = :cases[0].id];
        system.assertEquals('Closed', testcase.Status); // The open case should be closed now.
    }

    static testMethod void testReschedMoveOut() {
        // NTV_Date__c changed
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        Account a = [select id, OwnerID, (select id from Cases) from Account where RecordTypeID = :rtid and Owner.IsActive = true limit 1];
        delete a.Cases;
        
        Customer_Group_to_Unit_Relationships__c newcgu = new Customer_Group_to_Unit_Relationships__c();
        newcgu.Customer_Group__c = a.id;
        newcgu.Move_In_Date__c = system.today().addDays(5);
        newcgu.NTV_Date__c = null;
        newcgu.OwnerID = a.OwnerID;
        insert newcgu;
        
        list<Case> cases = [select id from Case where AccountID = :a.id];
        delete cases;
        
        newcgu.NTV_Date__c = system.today().addDays(-4);
        newcgu.Expected_Move_Out_Date__c = system.today().addDays(10);
        newcgu.Preliminary_Inspection_Date__c = system.now().addDays(5);
        update newcgu;
        
        cases = [select id from Case where AccountID = :a.id and Status = 'Open'];
    
        system.assertEquals(1,cases.size()); // There should be only one open case
        
test.StartTest();
        newcgu.NTV_Date__c = system.today().addDays(10);
        newcgu.Expected_Move_Out_Date__c = system.today().addDays(40);
        update newcgu;
test.StopTest(); 
        cases = [select id, Status, Reason, NTV_Date__c, Move_Out_Date__c from Case where Owner.IsActive = true and AccountID = :a.id and Status = 'Open'];
        system.assertEquals(1,cases.size());
        system.assertEquals('Open',cases[0].Status);     
        //system.assertEquals('Notice To Vacate',cases[0].Reason);
        system.assertEquals('Open',cases[0].Status);
        system.assertEquals(system.today().addDays(10),cases[0].NTV_Date__c);
        system.assertEquals(system.today().addDays(40),cases[0].Move_Out_Date__c);
    }
  
//Move IN
 
    static testMethod void testNewMoveIn() {
        // insert new CGU
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        User u = [select id from User where IsActive = true limit 1];
        list<Account> accs = [select id, OwnerID, (select id from Cases), 
        	(select id from Contacts where Primary_Contact__c = true) 
        	from Account where Owner.IsActive = true and RecordTypeID = :rtid limit 2];
        set<id> accids = new set<Id>();
        for ( Account a : accs) {
        	delete a.Cases;
        	accids.add(a.id);
        }
        if ((accs[1].Contacts != null) && (accs[1].Contacts.size() > 0)) delete accs[1].Contacts; //remove Primary Contacts from one Account (Customer Group)
        
        list<Customer_Group_to_Unit_Relationships__c> newcgus = new list<Customer_Group_to_Unit_Relationships__c>();
        for ( Account a : accs) {
        	newcgus.add(new Customer_Group_to_Unit_Relationships__c(
        		OwnerID = u.id,
        		Customer_Group__c = a.id,
        		Move_In_Date__c = system.today().addDays(30)
        		));
    	}
        
test.startTest();
        insert newcgus;
test.StopTest();  
        list<Case> cases = [select id, Status, Reason, Expected_MoveIn_Date__c, OwnerID, AccountID from Case where AccountID in :accids and Status = 'Open'];
        system.assertEquals(2,cases.size()); // There should be two open cases
        system.assertEquals(system.today().addDays(30), cases[0].Expected_MoveIn_Date__c);
        
        for (Case c : cases) {
        	for (Account a : accs) {
        		if (c.AccountID == a.Id) system.assertEquals(a.OwnerID, c.OwnerID);
        	}
        }
             
        
    }
   
    static testMethod void testCancelMoveIn() {
        // criteria: cgu.Cancelled__c = true
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        Account a = [select id, OwnerID, (select id from Cases) from Account where RecordTypeID = :rtid and Owner.IsActive = true limit 1];
        delete a.Cases;
        
        Customer_Group_to_Unit_Relationships__c newcgu = new Customer_Group_to_Unit_Relationships__c();
        newcgu.Customer_Group__c = a.id;
        newcgu.Move_In_Date__c = system.today().addDays(30);
        newcgu.OwnerID = a.OwnerID;
        insert newcgu;
            
        list<Case> cases = [select id, AccountID from Case where AccountID = :a.id and Status = 'Open'];
        system.assertEquals(1,cases.size());
        
test.startTest();        
        newcgu.Cancelled__c = true;
        update newcgu;
test.stopTest();  
        
        Case testcase = [select Status from Case where id = :cases[0].id];
        system.assertEquals('Closed', testcase.Status); // Closed now
              
        
    }
      
    static testMethod void testReschedMoveIn() {
        // Move_In_Date__c changed, Current_LBD__c changed
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        Account a = [select id, OwnerID, (select id from Cases) from Account where RecordTypeID = :rtid and Owner.IsActive = true limit 1];
        delete a.Cases;
        
        Customer_Group_to_Unit_Relationships__c newcgu = new Customer_Group_to_Unit_Relationships__c();
        newcgu.Customer_Group__c = a.id;
        newcgu.Move_In_Date__c = system.today().addDays(30);
        newcgu.Current_LBD__c = system.today().addDays(20);
        newcgu.OwnerID = a.OwnerID;
        insert newcgu;
        
        list<Case> cases = [select id, AccountID from Case where AccountID = :a.id and Status = 'Open'];
        system.assertEquals(1, cases.size());
test.startTest();
        newcgu.Move_In_Date__c = system.today().addDays(40);
        newcgu.Current_LBD__c = system.today().addDays(30);
        update newcgu;
test.stopTest();  
        cases = [select id, Status, Reason from Case where AccountID = :a.id and Status = 'Open'];
        
        system.assertEquals(1,cases.size()); // There should be only one open case
              
        
    }
    
    static testMethod void testPastNewMoveIn() {
        // insert new CGU with Move In Date in the past (existing CGU import)
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        Account a = [select id, OwnerID, (select id from Cases) from Account where RecordTypeID = :rtid and Owner.IsActive = true  limit 1];
        delete a.Cases;
        
        Customer_Group_to_Unit_Relationships__c newcgu = new Customer_Group_to_Unit_Relationships__c();
        newcgu.OwnerID = a.OwnerID;
        newcgu.Customer_Group__c = a.id;
        newcgu.Move_In_Date__c = system.today().addDays(-30);
        
test.startTest();
        insert newcgu;
test.StopTest();  
        list<Case> cases = [select id, Status, Reason from Case where AccountID = :a.id];
        
        system.assertEquals(0,cases.size()); // There should be no cases
             
        
    }
   
    static testMethod void testBadNewMoveIn() {
        // insert new CGU with Move In Date blank
        ID rtid = [select id from RecordType where Name = 'Customer Group' limit 1].id;
        Account a = [select id, OwnerID, (select id from Cases) from Account where RecordTypeID = :rtid and Owner.IsActive = true limit 1];
        delete a.Cases;
        
        Customer_Group_to_Unit_Relationships__c newcgu = new Customer_Group_to_Unit_Relationships__c();
        newcgu.OwnerID = a.OwnerID;
        newcgu.Customer_Group__c = a.id;
        newcgu.Move_In_Date__c = null;
        
test.startTest();
        insert newcgu;
test.StopTest();  
        list<Case> cases = [select id, Status, Reason from Case where AccountID = :a.id];
        
        system.assertEquals(0,cases.size()); // There should be no cases
             
        
    } 
}