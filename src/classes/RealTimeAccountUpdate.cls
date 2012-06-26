global class RealTimeAccountUpdate {
	
	static boolean writeLog(String avbAccID, String code, String message) {
    	try {
	      	Real_Time_Sync_Log__c log = new Real_Time_Sync_Log__c();
	        log.Account_Number__c = avbAccID;
	        log.Error_Code__c = code;
	        log.Error_Message__c = message;

	        insert log;
	        return true;
		} catch (Exception e) {
			return false;
		}
    }
    
    webService static boolean upsertData(String avbAccID, Account acc, Contact[] contacts, Customer_Group_to_Unit_Relationships__c[] custGroupUnits) {
    	try {
	    	updateAccount(acc);
	    	if (contacts.size() > 0) {
	    		upsert contacts;
	    	}
	    	if (custGroupUnits.size() > 0) {
	    		upsert custGroupUnits;
	    	}
    	} catch (Exception e) {
            writeLog(avbAccID,'','Failed to upsert data' + e.getMessage());
			return false; 
        }
        return true;
    }
    
   	webService static boolean upsertLtData(String avbAccID,Litigation_Data__c[] litigationData) {
    	try {
    		System.debug('creating litigation data ' + avbAccID + litigationData.size());
	    	if (litigationData.size() > 0) {
	    		List<Database.upsertResult> uResults = Database.upsert(litigationData, false);
				List<Litigation_Data__c> ltIds = new List<Litigation_Data__c>();
				for (Database.upsertResult result:uResults) {
					System.debug('ids for delete ' + result.isSuccess() + result.getId());
					if (result.isSuccess()) {
         				ltIds.add(new Litigation_Data__c(Id=result.getId()));
					}
     			}
     			if (ltIds.size() > 0) {
     				delete ltIds;
     			}
	    	}
    	} catch (Exception e) {
            writeLog(avbAccID,'','Failed to upsert litigation data' + e.getMessage());
			return false; 
        }
        return true;
    }   	
	    
	webService static String[] upsertUnits(String avbAccID, Unit__c[] units) {
		String[] ids = new String[]{};
        try {
        	List<Database.upsertResult> uResults = Database.upsert(units, true);
        	for(Database.upsertResult result:uResults) {
         		 ids.add(result.getId());
      		}
        } catch (Exception e) {
            writeLog(avbAccID,'','Failed to Upsert Units:'+e.getMessage());
        }
        return ids;
    }
			
	webService static boolean updateRefreshFlag(Account acct) {
		try {
			Account newAcc = new Account(Id = acct.Id, Refresh_Flag__c = acct.Refresh_Flag__c);
        	update newAcc;
        } catch (Exception e) {
        	writeLog(acct.Account_ID__c,'','Failed to update Refresh flag:'+e.getMessage());
            return false;
	   	}
	    return true;
	}

	static boolean updateAccount(Account acct) {
		try {
			Account newAcc = new Account(Id = acct.Id, Status__c=acct.Status__c, Affordable_Housing__c=acct.Affordable_Housing__c,
							Associate_Housing__c=acct.Associate_Housing__c, Community_Name__c=acct.Community_Name__c,
							Community_ID__c=acct.Community_ID__c, Late_Count__c=acct.Late_Count__c, NSF_Count__c=acct.NSF_Count__c,
							ParentId=acct.ParentId, Amount_Due_Next_FOM__c=acct.Amount_Due_Next_FOM__c, 
							Current_Balance__c=acct.Current_Balance__c, 
							Name=acct.Name, Type=acct.Type,
							Account_ID__c=acct.AccountNumber,
							Forwarding_Address_Line_1__c=acct.Forwarding_Address_Line_1__c,
							Forwarding_Address_Line_2__c=acct.Forwarding_Address_Line_2__c,
							Forwarding_Address_City__c=acct.Forwarding_Address_City__c,
							Forwarding_Address_State__c=acct.Forwarding_Address_State__c,
							Forwarding_Address_Zip__c=acct.Forwarding_Address_Zip__c,
							Forwarding_Address_Country__c=acct.Forwarding_Address_Country__c,
							Block_E_Payment__c=acct.Block_E_Payment__c,
							Write_Offs__c=acct.Write_Offs__c,
							Date_Sent_To_Collections__c=acct.Date_Sent_To_Collections__c,
							Date_Collections_Updated__c=acct.Date_Collections_Updated__c);
			if (acct.Unique_Record_ID__c != null) {
				newAcc.Unique_Record_ID__c = acct.Unique_Record_ID__c;
			}				
        	update newAcc;
        } catch (Exception e) {
        	writeLog(acct.Account_ID__c,'','Failed to update Acc:'+e.getMessage());
            return false;
	   	}
	    return true;
	}

	webService static Account[] queryCommunity(String communityID) {
		//Account acc = new Account();
		Account[] comm = [select Id, Court_Date__c from Account where RecordTypeId=:'012600000000n1g' and Community_ID__c=:communityID];		
		return comm;
	}
	
	webService static Contact[] queryContacts(String accountId) {
		Contact[] contacts = [select Id, Customer_ID__c,Prior_Resident__c from contact where AccountId =:accountId];
		return contacts;
	}
	
	webService static List<Unit__c[]> queryUnits(String commId) {
		List<Unit__c[]> units = new List<Unit__c[]>();
		for (Unit__c[] u : [select Id, Unit_ID__c from unit__c where Community__c = :commId]) {
			units.add(u);
		}
		return units;
	}
	
	webService static Customer_Group_to_Unit_Relationships__c[] queryCGUnits(String accID) {
		Customer_Group_to_Unit_Relationships__c[] cgus = [select Id,Unit__c,Customer_Group__c,Unique_Record_Id__c from Customer_Group_to_Unit_Relationships__c where (Customer_Group__c=:accID)];
		return cgus;
	}
	
	//Starting test methods//
	static testMethod void test_writeLog() {
		System.assertEquals(true, writeLog('AVB_Test_001','1','Error occurred.'));
	}
	
	static testMethod void test_upsertData() {
		Account acc = [select Id, Account_ID__c from Account limit 1];
		Id aid = acc.Id;
		Contact[] contacts = [select Id from Contact limit 2];
		Customer_Group_to_Unit_Relationships__c[] cgUnits = [select Id from Customer_Group_to_Unit_Relationships__c limit 2];
		Litigation_Data__c[] ltData = [select Id from Litigation_Data__c limit 2];
		System.assertEquals(true, upsertData('AVB_Test_001', acc, contacts, cgUnits));
	}
		
	static testMethod void test_upsertLitigationData() {
		Litigation_Data__c t = new Litigation_Data__c();
        t.Litigation_Flag_FND__c = true;
        t.Law_Firm__c = 'Mallios, Rider, & Goley, LLP';
        t.Account_ID__c = [select Id,Community_ID__c,Account_ID__c from Account where RecordTypeId=:'012600000000n1b' limit 1].Id;
        t.Original_Amount__c = 1000.00;
        t.Litigation_Notes__c = 'test';

		Litigation_Data__c[] ltData = new Litigation_Data__c[]{};
		ltData.add(t);
		System.assertEquals(true, upsertLtData('AVB_Test_001', ltData));

		//Litigation_Data__c t2 = new Litigation_Data__c();//[select Id, Account_ID__c, Litigation_Flag_FND__c,Litigation_Notes__c,Litigation_Closure_Reason__c from Litigation_Data__c limit 1];
        t.Litigation_Flag_FND__c = false;
        t.Litigation_Notes__c = 'test';
        t.Litigation_Closure_Reason__c = 'paid';
        t.Law_Firm__c = 'Mallios, Rider, & Goley, LLP';
		t.Original_Amount__c = 100.00;
		t.Last_Modified_Date_Time_in_Foundation__c = System.now();
		t.Last_Modified_By_Foundation_User__c = 'test';
		//t.Account_ID__c = [select Id,Community_ID__c,Account_ID__c from Account where RecordTypeId=:'012600000000n1b' limit 1].Id;

		Litigation_Data__c[] ltData2 = new Litigation_Data__c[]{};
		ltData2.add(t);
		System.assertEquals(true, upsertLtData('AVB_Test_001', ltData2));
	}
		
	static testMethod void test_updateAcc() {		
		Account acc = new Account(name='Testing Account');
		
		test.startTest();
		insert acc;
		
		Account acc1 = [select Id, Account_ID__c, Status__c, Affordable_Housing__c,
							Associate_Housing__c, Community_Name__c,
							Community_ID__c, Late_Count__c, NSF_Count__c,
							ParentId, Amount_Due_Next_FOM__c, 
							Current_Balance__c, Unique_Record_ID__c, 
							Name, Type,
							Forwarding_Address_Line_1__c,
							Forwarding_Address_Line_2__c,
							Forwarding_Address_City__c,
							Forwarding_Address_State__c,
							Forwarding_Address_Zip__c,
							Forwarding_Address_Country__c,
							Block_E_Payment__c/*,
							Write_Offs__c,
							Date_Sent_To_Collections__c,
							Date_Collections_Updated__c */
							from Account where id = :acc.id];	

		System.assertEquals(true, updateAccount(acc));
	}
	
	static testMethod void test_updateAccount() {
		Account acc = [select Id, Refresh_Flag__c from Account limit 1];
		System.debug('acc flag ' + acc.Refresh_Flag__c);
		acc.Refresh_Flag__c=false;
		System.assertEquals(true, updateRefreshFlag(acc));		
	}
	
	static testMethod void test_upsertUnits() {
		Unit__c[] units = [select Id from Unit__c limit 2];
		String[] ids = upsertUnits('AVB_Test_001', units);
		System.assert(2 == ids.size());
	}
	
	static testMethod void queryCommunity() {
		String commId = [select Id,Community_ID__c from Account where RecordTypeId =: '012600000000n1g' limit 1].Community_ID__c;
		Account[] comm = queryCommunity(commId);
		System.assert(1 == comm.size());

		if (comm.size() == 1) {
			String accId = comm[0].Id;
			Contact[] contacts = queryContacts(accId);
			System.assert(contacts.size() == contacts.size());
			
			List<Unit__c[]> units = queryUnits(commId);
			System.assert(units.size() == units.size());
			
			String cgId = [select Id from Account where RecordTypeId=:'012600000000n1b' limit 1].Id;
			Customer_Group_to_Unit_Relationships__c[] cgus = queryCGUnits(cgId);
			System.assert(cgus.size() == cgus.size());
		}
	}
}