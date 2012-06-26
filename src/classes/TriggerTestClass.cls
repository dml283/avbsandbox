public class TriggerTestClass
{
    static testmethod void testDoTests()
    {
        //try{
        //Resident Account Task Test
        RecordType[] rectype = [select Id from RecordType where SObjectType='Account' and Name in ('Customer Group','Community')];
        User userrec = [select Id,Email from User where IsActive=true and Email!='' limit 1];
        Account accparent = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[1].Id,Account_ID__c='007',Name='AccTestParent',Unique_Record_Id__c = '007');
        insert accparent;       
        Account acc1 = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[0].Id,Account_ID__c='009',Name='AccTest1',Unique_Record_Id__c = '009',ParentId=accparent.Id);
        Account acc2 = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[1].Id,Account_ID__c='008',Name='AccTest2',Unique_Record_Id__c = '008');
        Account[] acc = new Account[]{acc1,acc2};
        insert acc;
        Contact con1 = new Contact(AccountID=acc[0].Id,Lastname='contest',Email='test@abc.com');
        insert con1;
        Contact con2 = new Contact(AccountID=acc[0].Id,Lastname='con new',Email='new@abc.com');
        insert con2;
        Task accTask1 = new Task(Whatid=acc[0].Id,Subject='Call',ActivityDate=System.today()+1,WhoId = con1.Id,Email_Recipients__c = 'new82@gmail.com',Description='123',Update_Community_On_Progress__c = true);
        //Task accTask2 = new Task(Whatid=acc[1].Id,Subject='Meeting',ActivityDate=System.today()+2,WhoId = con1.Id,Email_Recipients__c = 'test@abc.com',Description='123');
        //Task[] accTask = new Task[]{accTask1,accTask2};
        insert accTask1;
        accTask1.Update_Community_On_Progress__c = true;
        //accTask[1].Update_Community_On_Progress__c = true;
        //update accTask1;
        
        
        
        //Resident Account Adjustment Case email
        Customer_Group_to_Unit_Relationships__c cusgrp = new Customer_Group_to_Unit_Relationships__c(Customer_Group__c=acc[0].Id,Move_Out_Date__c = System.today()+2);
        insert cusgrp;
        RecordType[] rec = [select Id from RecordType where SObjectType='Case' and Name in('Adjustment - Other')];
        Case[] refcase = [select Applicant_Name__c from Case where Applicant_Name__c!=null limit 1];
        System.debug('refcase '+refcase);
        if(refcase.size()>0)
        {
        	Case case2 = new Case(RecordTypeId=rec[0].Id,AccountID=acc[0].Id,Type='Other',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today()+2,Subject='Test Case for script',Description='new case description',Describe_Security_Requirements__c='security re 1',Email_recipients__c ='new@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Applicant_Name__c=refcase[0].Applicant_Name__c,Actual_Movein_Date__c = System.today()-2,ContactId=con2.Id);
        	insert case2;
        }
        
        Case case1 = new Case(RecordTypeId=rec[0].Id,AccountID=acc[0].Id,Type='Other',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today()+2,Subject='Test Case for script',Description='new case description',Describe_Security_Requirements__c='security re 1',Email_recipients__c ='new@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Applicant_Name__c=con1.Id,Actual_Movein_Date__c = System.today()-2,ContactId=con2.Id);
        
        //Case case2 = new Case(RecordTypeId=rec[0].Id,AccountID=acc[1].Id,Type='Field',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today(),Subject='New Test Case for script',Description='new case description 123',Describe_Security_Requirements__c='security requirement 2',Email_recipients__c ='newabc@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Applicant_Name__c=con1.Id,Actual_Movein_Date__c = System.today()-2,ContactId=con2.Id);
        Case case3 = new Case(Email_Recipients__c='test@123.com new@test.com;123@test.com',RecordTypeId=rec[0].Id,AccountID=acc[1].Id,Type='Field',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today(),Subject='New Test Case for script',Description='new case description 123',Describe_Security_Requirements__c='security requirement 2',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Applicant_Name__c=con1.Id,Actual_Movein_Date__c = System.today()-2,ContactId=con2.Id);
        //Case[] casenew = new Case[]{case1,case2,case3};
        Case[] casenew = new Case[]{case1,case3};
        insert casenew;
        casenew[0].Status = 'Ready To Submit';
        casenew[1].Status = 'Ready To Submit';
        
        //casenew[2].Status = 'Ready To Submit';
        update casenew;
        //User usr = [select Id from user where IsActive=true limit 1];
        //casenew[0].OwnerId = usr.Id;
        casenew[0].Status = 'Closed';
        casenew[1].Status = 'Closed';
        //casenew[0].RecordTypeId = rec[1].Id;
        casenew[1].RecordTypeId = rec[0].Id;
        update casenew;
        
        
        //casenew[1].Status = 'Closed';
        //casenew[2].Status = 'Closed';
        //casenew[2].Email_Recipients__c = 'test@avb.com';
        //update casenew;
        CaseComment casecom1 = new CaseComment(ParentId=casenew[0].Id,CommentBody='this is closed'); 
        CaseComment casecom2 = new CaseComment(ParentId=casenew[1].Id,CommentBody='case is closed');
        //CaseComment casecom3 = new CaseComment(ParentId=casenew[2].Id,CommentBody='case is closed');
        //CaseComment[] casecom = new CaseComment[]{casecom1,casecom2,casecom3};
        CaseComment[] casecom = new CaseComment[]{casecom1,casecom2};
        insert casecom;
        //update casenew;
        /*
 		Case case1 = new Case(AccountID=acc[0].Id,Type='Other',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today()+2,Subject='Test Case for script',Description='new case description',Describe_Security_Requirements__c='security re 1',Email_recipients__c ='new@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Applicant_Name__c=con1.Id,Actual_Movein_Date__c = System.today()-2,ContactId=con2.Id);
		insert case1;
		case1.Status = 'Ready To Submit';
		update case1;
		case1.Status = 'Closed';
		update case1;
		 */		       
        //Referral Case Email
        /*RecordType rec1 = [select Id from RecordType where SObjectType='Case' and Name = 'Adjustment - Resident Referral'];
        Case caseA = new Case(RecordTypeId=rec1.Id,AccountID=acc[0].Id,Type='Other',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today()+2,Subject='Test Case for script',Description='new case description',Describe_Security_Requirements__c='security re 1',Email_recipients__c ='new@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Expected_Movein_Date__c = System.today()-3,Applicant_Name__c=con1.Id,ContactId=con2.id,Referred_Resident__c=con1.Id);
        System.debug(caseA);
        insert caseA;
        //Case caseB = new Case(RecordTypeId=rec1.Id,AccountID=acc[1].Id,Type='Field',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today(),Subject='New Test Case for script',Description='new case description 123',Describe_Security_Requirements__c='security requirement 2',Email_recipients__c ='newabc@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Expected_Movein_Date__c = System.today()+60,Applicant_Name__c = con1.Id,ContactId=con2.id);
        //Case[] caseAB = new Case[]{caseA,caseB};
        //insert caseAB;
        caseA.Status = 'Ready To Submit';
        //caseAB[1].Status = 'Ready To Submit';
        //update caseA;
        caseA.Status = 'Closed';
        caseA.Applicant_Name__c = con1.Id;
        //caseAB[1].Status = 'Closed';
        update caseA;*/
        /*CaseComment casecomA = new CaseComment(ParentId=caseAB[0].Id,CommentBody='this is closed'); 
        CaseComment casecomB = new CaseComment(ParentId=caseAB[1].Id,CommentBody='case is closed');
        CaseComment[] casecomAB = new CaseComment[]{casecomA,casecomB};
        insert casecomAB;*/
        //update caseAB;
        
        /*}catch(Exception ex){
            System.debug(ex.getMessage());
        }*/
    }
    static testmethod void testDoTests2()
  	{
  		RecordType[] rectype = [select Id from RecordType where SObjectType='Account' and Name in ('Customer Group','Community')];
        User userrec = [select Id,Email from User where IsActive=true and Email!='' limit 1];
        Account accparent = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[1].Id,Account_ID__c='007',Name='AccTestParent',Unique_Record_Id__c = '007');
        insert accparent;       
        Account acc1 = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[0].Id,Account_ID__c='009',Name='AccTest1',Unique_Record_Id__c = '009',ParentId=accparent.Id);
        Account acc2 = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[1].Id,Account_ID__c='008',Name='AccTest2',Unique_Record_Id__c = '008');
        Account[] acc = new Account[]{acc1,acc2};
        insert acc;
        Contact con1 = new Contact(AccountID=acc[0].Id,Lastname='contest',Email='test@abc.com');
        insert con1;
        Contact con2 = new Contact(AccountID=acc[0].Id,Lastname='con new',Email='new@abc.com');
        insert con2;
        
        //Litigation Activity test
        Litigation__c liti1 = new Litigation__c(Default_Date__c=System.today(),Account__c = acc[0].Id,Status__c='Open',Litigation_Type__c = 'Breach of Lease',Law_Firm__c='BH Law',Date__c=System.today(),Original_Amount__c=1000,Email_Recipients__c='test82@gmail.com',Auto_Response_Email__c='Litigation Activity Opened: "If applicable, please send any necessary paperwork..."');
        insert liti1; 
        Litigation__c liti2 = new Litigation__c(Default_Date__c=System.today(),Account__c = acc[0].Id,Status__c='Open',Litigation_Type__c = 'Non Payment',Law_Firm__c='BH Law',Date__c=System.today(),Original_Amount__c=150,Email_Recipients__c='test123@gmail.com;abc@test.com',Auto_Response_Email__c = 'Court Date: "The associate who signed the proof of service will need to appear at court..."');
        insert liti2;
        Litigation__c liti3 = new Litigation__c(Default_Date__c=System.today(),Account__c = acc[0].Id,Status__c='Open',Litigation_Type__c = 'Breach of Lease',Law_Firm__c='BH Law',Date__c=System.today(),Original_Amount__c=1000,Email_Recipients__c='test82@gmail.com,nom@tes.com',Auto_Response_Email__c='Court Date: "An associate will need to be on-call to appear at court..."');
        insert liti3; 
        Litigation__c liti4 = new Litigation__c(Default_Date__c=System.today(),Account__c = acc[0].Id,Status__c='Open',Litigation_Type__c = 'Non Payment',Law_Firm__c='BH Law',Date__c=System.today(),Original_Amount__c=150,Email_Recipients__c='test123@gmail.com;abc@test.com',Auto_Response_Email__c = 'Court Date: "An associate is required to be present at court..."');
        insert liti4;
        Litigation__c liti5 = new Litigation__c(Default_Date__c=System.today(),Account__c = acc[0].Id,Status__c='Open',Litigation_Type__c = 'Non Payment',Law_Firm__c='BH Law',Date__c=System.today(),Original_Amount__c=150,Email_Recipients__c='test123@gmail.com',Auto_Response_Email__c = 'Lock-out: "Please be sure to have the appropriate amount of petty cash available to pay..."');
        insert liti5;
        Litigation__c liti6 = new Litigation__c(Default_Date__c=System.today(),Account__c = acc[0].Id,Status__c='Open',Litigation_Type__c = 'Non Payment',Law_Firm__c='BH Law',Date__c=System.today(),Original_Amount__c=150,Email_Recipients__c='test123@gmail.com',Auto_Response_Email__c = 'Lock-out: "Please be prepared to change the locks once the Constable/Marshall/Sheriff has returned..."');
        insert liti6;
        //Litigation__c[] liti = new Litigation__c[]{liti1,liti2,liti3,liti4};
        //insert liti;
        //liti1.Court_Date__c = System.now()+2;
        liti1.Scheduled_Lock_Out_Date__c = System.today()+4;
        liti1.Default_Date__c=System.today()+2;
        liti1.Status__c='closed';
        liti1.Email_Recipients__c = 'nom@test.com;123@test.com;new@123.com';
        /*liti2.Court_Date__c = System.now();
        liti2.Scheduled_Lock_Out_Date__c = System.today()+1;
        liti2.Default_Date__c=System.today()+2;
        liti2.Status__c='closed';*/
        update liti1;
        //update liti2;
        
        
        
        //Resident Account Adjustment Case email
        Customer_Group_to_Unit_Relationships__c cusgrp = new Customer_Group_to_Unit_Relationships__c(Customer_Group__c=acc[0].Id,Move_Out_Date__c = System.today()+2);
        insert cusgrp;
        
        RecordType rec = [select Id from RecordType where SObjectType='Case' and Name in('Adjustment - Other')];
        Case case1 = new Case(RecordTypeId=rec.Id,AccountID=acc[0].Id,Type='Other',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today()+2,Subject='Test Case for script',Description='new case description',Description__c = 'new',Describe_Security_Requirements__c='security re 1',Email_recipients__c ='new@test123.com',Notify_When_Closed__c=true,Applicant_Name__c=con1.Id,Actual_Movein_Date__c = System.today()-2,Expected_MoveIn_Date__c=System.today()-1,ContactId=con2.Id,Case_Primary_Type__c = 'Correction of Fees');
        //Case case2 = new Case(RecordTypeId=rec[0].Id,AccountID=acc[1].Id,Type='Field',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today(),Subject='New Test Case for script',Description='new case description 123',Describe_Security_Requirements__c='security requirement 2',Email_recipients__c ='newabc@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Applicant_Name__c=con1.Id,Actual_Movein_Date__c = System.today()-2,ContactId=con2.Id);
        //Case case3 = new Case(Email_Recipients__c='test@123.com new@test.com\n123@test.com',RecordTypeId=rec[1].Id,AccountID=acc[1].Id,Type='Field',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today(),Subject='New Test Case for script',Description='new case description 123',Describe_Security_Requirements__c='security requirement 2',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Applicant_Name__c=con1.Id,Actual_Movein_Date__c = System.today()-2,ContactId=con2.Id);
        //Case[] casenew = new Case[]{case1,case2,case3};
        //Case[] casenew = new Case[]{case1,case3};
        insert case1;
        case1.Status = 'Ready To Submit';
        //casenew[1].Status = 'Ready To Submit';
        
        //casenew[2].Status = 'Ready To Submit';
        update case1;
        CaseComment casecomA = new CaseComment(ParentId=case1.Id,CommentBody='this is closed');
        insert casecomA;
        User[] usr = [select Id from user where IsActive=true limit 3];
        case1.OwnerId = usr[2].Id;
        case1.Status = 'Closed';
        case1.Adjustment_Type_2__c = 'Other';
        case1.Original_Billing_Amount_2__c = 100;
        case1.Adjusted_Amount_2__c = 50;
        case1.Bonus_Amount__c = '100';
        //casenew[1].Status = 'Closed';
        //casenew[0].RecordTypeId = rec[1].Id;
        //casenew[1].RecordTypeId = rec[1].Id;
        update case1;
        
        
  	}
  	
  	static testmethod void testDoTests3()
  	{
  		RecordType[] rectype = [select Id from RecordType where SObjectType='Account' and Name in ('Customer Group','Community')];
        User userrec = [select Id,Email from User where IsActive=true and Email!='' limit 1];
        Account accparent = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[1].Id,Account_ID__c='007',Name='AccTestParent',Unique_Record_Id__c = '007');
        insert accparent;  
        Account acc1 = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[0].Id,Account_ID__c='009',Name='AccTest1',Unique_Record_Id__c = '009',ParentId=accparent.Id);
        Account acc2 = new Account(OwnerId = userrec.Id,RecordTypeId=rectype[1].Id,Account_ID__c='008',Name='AccTest2',Unique_Record_Id__c = '008');
        Account[] acc = new Account[]{acc1,acc2};
        insert acc;
        Contact con1 = new Contact(AccountID=acc[0].Id,Lastname='contest',Email='test@abc.com');
        insert con1;
        Contact con2 = new Contact(AccountID=acc[0].Id,Lastname='con new',Email='new@abc.com');
        insert con2;
        Customer_Group_to_Unit_Relationships__c cusgrp = new Customer_Group_to_Unit_Relationships__c(Customer_Group__c=acc[0].Id,Move_Out_Date__c = System.today()+2);
        insert cusgrp;
  		RecordType rec1 = [select Id from RecordType where SObjectType='Case' and Name = 'Adjustment - Resident Referral'];
        Case caseA = new Case(RecordTypeId=rec1.Id,AccountID=acc[0].Id,Type='Other',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today()+2,Subject='Test Case for script',Description='new case description',Describe_Security_Requirements__c='security re 1',Email_recipients__c ='new@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Expected_Movein_Date__c = System.today()-3,Applicant_Name__c=con1.Id,ContactId=con2.id,Referred_Resident__c=con1.Id);
        System.debug(caseA);
        insert caseA;
        AVBCheckApproval.setapprovalfalse();
        //Case caseB = new Case(RecordTypeId=rec1.Id,AccountID=acc[1].Id,Type='Field',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today(),Subject='New Test Case for script',Description='new case description 123',Describe_Security_Requirements__c='security requirement 2',Email_recipients__c ='newabc@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Expected_Movein_Date__c = System.today()+60,Applicant_Name__c = con1.Id,ContactId=con2.id);
        //Case[] caseAB = new Case[]{caseA,caseB};
        //insert caseAB;
        caseA.Status = 'Ready To Submit';
        //caseAB[1].Status = 'Ready To Submit';
        //update caseA;
        caseA.Status = 'Closed';
        caseA.Applicant_Name__c = con1.Id;
        //caseAB[1].Status = 'Closed';
        update caseA;
        System.debug(caseA);
        Case caseB = new Case(RecordTypeId=rec1.Id,AccountID=acc[0].Id,Type='Other',Updating_Existing_SF_Object__c='No',Date_Needed__c=System.today()+2,Subject='Test Case for script',Description='new case description',Describe_Security_Requirements__c='security re 1',Email_recipients__c ='new@test123.com',Notify_When_Closed__c=true,Case_Primary_Type__c='Renewal',Expected_Movein_Date__c = System.today()-3,Applicant_Name__c=con1.Id,ContactId=con2.id,Referred_Resident__c=con1.Id);
        insert caseB;
        System.debug(caseB);
        
        /*CaseComment casecomA = new CaseComment(ParentId=caseAB[0].Id,CommentBody='this is closed'); 
        CaseComment casecomB = new CaseComment(ParentId=caseAB[1].Id,CommentBody='case is closed');
        CaseComment[] casecomAB = new CaseComment[]{casecomA,casecomB};
        insert casecomAB;*/
  	}
  	
  	
}