trigger CaseValidations on Case (before insert,before update,after insert,after update) 
{
    List<Case> chk_case_updold = Trigger.old;
    List<Case> chk_case_updnew = Trigger.new;
    if(Trigger.isBefore)
    {
        if(Trigger.isInsert)
        {
            Boolean chk = AVBCheckApproval.SubmittedApproval();
            System.debug('setvalue'+chk); 
            if(chk == false)
            {
            Group queue_grp_chk = [select Id from Group where Type='Queue' and Name='OSFA Team leads - SODA'];
            System.debug(queue_grp_chk);
            List<Case> workingcase = new List<Case>();
            
            //if(workingcase.size()>0)
            //{
                System.debug('Inside');
                RecordType rectype = [select Id from RecordType where IsActive=true and SObjectType='Case' and Name='Adjustment - Resident Referral'];
                Set<Id> con_id = new Set<Id>();
                List<Case> res_ref_case = new List<Case>();
                Map<Id,Case> chk_case = new Map<Id,Case>();
                Set<Id> appli_name_id = new Set<Id>();
                Set<Id> caseid = new Set<ID>();
                if(rectype != null)
                {
                    for(Case case_val : Trigger.new)
                    {
                        if(case_val.RecordTypeId == rectype.Id)
                        {
                            if(case_val.Referred_Resident__c==null)
                                case_val.Referred_Resident__c.addError('Please enter Referred Resident Name');
                            
                            res_ref_case.add(case_val);
                            //con_id.add(case_val.Referred_Resident__c);
                            appli_name_id.add(case_val.Referred_Resident__c);
                            caseid.add(case_val.id);
                        }   
                    }
                    //System.debug('con_id'+con_id);
                    if(res_ref_case.size()>0)
                    {
                        system.debug('CaseHere');
                        Map<Id,Case> map_case = new Map<Id,Case>();
                        //if(con_id.size() > 0)
                        if(appli_name_id.size() > 0)
                        {
                            //List<Case> list_case = [select Referred_Resident__c from Case where RecordTypeId =: rectype.Id and Referred_Resident__c in: con_id and id not in: caseid];
                            List<Case> list_case = [select Referred_Resident__c,Contact.Name from Case where RecordTypeId =: rectype.Id and Referred_Resident__c in: appli_name_id and id not in: caseid];
                            System.debug('ReferredRes Case'+list_case);
                            //Map<String,String> mapconname= new Map<ID,String>();
                            for(Case temp_case : list_case)
                            {
                                //mapconname.put(temp_case.Referred_Resident__c,);
                                map_case.put(temp_case.Referred_Resident__c,temp_case);
                            } 
                            System.debug('ReferredRes Map'+map_case);
                        }            
                         
                        System.debug(map_case);
                        List<Contact> appl_con = [select Id,Name,AccountId from Contact where Id in:appli_name_id];
                        //Map<Id,Contact> map_con = new Map<Id,Contact>([select Id,Name from Contact where Id in:appli_name_id]);
                        Map<Id,Contact> map_con = new Map<Id,Contact>();
                        
                        System.debug('map_con'+map_con);
                        Group queue_grp = [select Id from Group where Type='Queue' and Name='OSFA Team leads - Revenue Collections'];
                        //System.debug(queue_grp);
                        
                        //List<Contact> appl_con = [select Id,Name,AccountId from Contact where Id in:appli_name_id];
                        Map<Id,Id> con_acc_map = new Map<Id,Id>();
                        Set<Id> accids = new Set<Id>();
                        for(Integer i=0;i<appl_con.size();i++)
                        {
                            map_con.put(appl_con[i].Id,appl_con[i]);
                            con_acc_map.put(appl_con[i].AccountId,appl_con[i].Id);
                            accids.add(appl_con[i].AccountId);
                        }
                        Map<ID,Date> date_map = new Map<Id,Date>();
                        
                        if(accids.size()>0)
                        {
                            Customer_Group_to_Unit_Relationships__c[] cus = [select Move_Out_Date__c,Customer_Group__c from Customer_Group_to_Unit_Relationships__c where Customer_Group__c in:accids ];
                            System.debug('cus'+cus);
                            if(cus.size()>0)
                            {
                                for(Integer j=0;j<cus.size();j++)
                                {   
                                    if(cus[j].Move_Out_Date__c != null)                    
                                        date_map.put(con_acc_map.get(cus[j].Customer_Group__c),cus[j].Move_Out_Date__c);
                                }
                            }
                        }
                        //System.debug('Datemap'+date_map);
                        System.debug('map_case size'+map_case.size());
                        System.debug('Trigger values'+Trigger.new[0]);
                        if(map_case.size() > 0)
                        {       
                            System.debug('1');
                            //System.debug('mapcase '+map_case);      
                            for(Integer i=0;i<Trigger.new.size();i++)
                            { 
                                //System.debug(cs.Referred_Resident__c);
                                if(map_case.containsKey(Trigger.new[i].Referred_Resident__c))
                                {
                                    Contact con = map_con.get(Trigger.new[i].Referred_Resident__c);
                                    String casecontactname = map_case.get(Trigger.new[i].Referred_Resident__c).Contact.Name;
                                    System.debug('con is'+con);
                                    if(con != null)
                                    {
                                        if(Trigger.old != null)
                                        {
                                            if(Trigger.new[i].OwnerId != queue_grp_chk.Id)
                                            {
                                                system.debug('A');
                                                Trigger.new[i].Warning_Message__c = 'Applicant already referred by '+casecontactname;
                                                if(queue_grp != null)
                                                    Trigger.new[i].OwnerId = queue_grp.Id;      
                                            }
                                            
                                        }
                                        else
                                        {
                                            system.debug('C');
                                            Trigger.new[i].Warning_Message__c = 'Applicant already referred by '+casecontactname;
                                            if(queue_grp != null)
                                                Trigger.new[i].OwnerId = queue_grp.Id;
                                        }
                                        System.debug(Trigger.new[i].Warning_Message__c);
                                        
                                    }
                                }
                                //System.debug(cs.Warning_Message__c+ ' '+Trigger.new[i].Owner);
                            }
                            
                        }
                        for(Integer j=0;j<Trigger.new.size();j++)
                        {
                            //if(Trigger.old != null)
                            //{
                                if(Trigger.new[j].OwnerId != queue_grp_chk.Id)
                                {
                                    if(Trigger.new[j].Expected_MoveIn_Date__c < System.Date.today())
                                    {
                                        Trigger.new[j].Warning_Message__c = 'Applicant moved in prior to request';
                                        if(queue_grp != null)
                                            Trigger.new[j].OwnerId = queue_grp.Id;
                                    }
                                    for(Integer k=0;k<date_map.size();k++)
                                    {
                                        if(date_map.containskey(Trigger.new[j].Referred_Resident__c))
                                        {
                                            System.debug('True');
                                            Date moveout = date_map.get(Trigger.new[j].Referred_Resident__c);
                                            if(moveout +30 < Trigger.new[j].Expected_MoveIn_Date__c)
                                            {
                                                Trigger.new[j].Warning_Message__c = 'Prior Resident is not eligible for a referral bonus';
                                                if(queue_grp != null)
                                                    Trigger.new[j].OwnerId = queue_grp.Id;
                                            }
                                        }
                                    }
                                }
                                                            
                            //}
                            
                        }
                        
                        
                    }
                    
                }
                
            //}
            System.debug('Trigger new values'+Trigger.new[0]);
            //Trigger.new[0].addError('Testing code....');
            }
        }
        else if(Trigger.isUpdate)
        {
            Boolean chk = AVBCheckApproval.SubmittedApproval();
            System.debug('setvalue'+chk); 
            if(chk == false)
            {
            Group queue_grp_chk = [select Id from Group where Type='Queue' and Name='OSFA Team leads - SODA'];
            System.debug(queue_grp_chk);
            List<Case> workingcase = new List<Case>();
            
            //if(workingcase.size()>0)
            //{
                System.debug('Inside');
                RecordType rectype = [select Id from RecordType where IsActive=true and SObjectType='Case' and Name='Adjustment - Resident Referral'];
                Set<Id> con_id = new Set<Id>();
                List<Case> res_ref_case = new List<Case>();
                Map<Id,Case> chk_case = new Map<Id,Case>();
                Set<Id> appli_name_id = new Set<Id>();
                Set<Id> caseid = new Set<ID>();
                if(rectype != null)
                {
                    for(Case case_val : Trigger.new)
                    {
                        if(case_val.RecordTypeId == rectype.Id)
                        {
                            if(case_val.Referred_Resident__c==null)
                                case_val.Referred_Resident__c.addError('Please enter Referred Resident');
                            
                            res_ref_case.add(case_val);
                            //con_id.add(case_val.Referred_Resident__c);
                            appli_name_id.add(case_val.Referred_Resident__c);
                            caseid.add(case_val.id);
                        }   
                    }
                    //System.debug('con_id'+con_id);
                    if(res_ref_case.size()>0)
                    {
                        system.debug('CaseHere');
                        Map<Id,Case> map_case = new Map<Id,Case>();
                        //if(con_id.size() > 0)
                        if(appli_name_id.size() > 0)
                        {
                            //List<Case> list_case = [select Referred_Resident__c from Case where RecordTypeId =: rectype.Id and Referred_Resident__c in: con_id and id not in: caseid];
                            List<Case> list_case = [select Referred_Resident__c,Contact.Name from Case where RecordTypeId =: rectype.Id and Referred_Resident__c in: appli_name_id and id not in: caseid];
                            System.debug('ReferredRes Case'+list_case);
                            //Map<String,String> mapconname= new Map<ID,String>();
                            for(Case temp_case : list_case)
                            {
                                //mapconname.put(temp_case.Referred_Resident__c,);
                                map_case.put(temp_case.Referred_Resident__c,temp_case);
                            } 
                            System.debug('ReferredRes Map'+map_case);
                        }            
                         
                        System.debug(map_case);
                        List<Contact> appl_con = [select Id,Name,AccountId from Contact where Id in:appli_name_id];
                        //Map<Id,Contact> map_con = new Map<Id,Contact>([select Id,Name from Contact where Id in:appli_name_id]);
                        Map<Id,Contact> map_con = new Map<Id,Contact>();
                        
                        System.debug('map_con'+map_con);
                        Group queue_grp = [select Id from Group where Type='Queue' and Name='OSFA Team leads - Revenue Collections'];
                        //System.debug(queue_grp);
                        
                        //List<Contact> appl_con = [select Id,Name,AccountId from Contact where Id in:appli_name_id];
                        Map<Id,Id> con_acc_map = new Map<Id,Id>();
                        Set<Id> accids = new Set<Id>();
                        for(Integer i=0;i<appl_con.size();i++)
                        {
                            map_con.put(appl_con[i].Id,appl_con[i]);
                            con_acc_map.put(appl_con[i].AccountId,appl_con[i].Id);
                            accids.add(appl_con[i].AccountId);
                        }
                        Map<ID,Date> date_map = new Map<Id,Date>();
                        
                        if(accids.size()>0)
                        {
                            Customer_Group_to_Unit_Relationships__c[] cus = [select Move_Out_Date__c,Customer_Group__c from Customer_Group_to_Unit_Relationships__c where Customer_Group__c in:accids ];
                            System.debug('cus'+cus);
                            if(cus.size()>0)
                            {
                                for(Integer j=0;j<cus.size();j++)
                                {   
                                    if(cus[j].Move_Out_Date__c != null)                    
                                        date_map.put(con_acc_map.get(cus[j].Customer_Group__c),cus[j].Move_Out_Date__c);
                                }
                            }
                        }
                        //System.debug('Datemap'+date_map);
                        System.debug('map_case size'+map_case.size());
                        System.debug('Trigger values'+Trigger.new[0]);
                        if(map_case.size() > 0)
                        {       
                            System.debug('1');
                            //System.debug('mapcase '+map_case);      
                            for(Integer i=0;i<Trigger.new.size();i++)
                            { 
                                //System.debug(cs.Referred_Resident__c);
                                if(map_case.containsKey(Trigger.new[i].Referred_Resident__c))
                                {
                                    Contact con = map_con.get(Trigger.new[i].Referred_Resident__c);
                                    String casecontactname = map_case.get(Trigger.new[i].Referred_Resident__c).Contact.Name;
                                    System.debug('con is'+con);
                                    if(con != null)
                                    {
                                        if(Trigger.old != null)
                                        {
                                            if(Trigger.new[i].OwnerId != queue_grp_chk.Id)
                                            {
                                                system.debug('A');
                                                Trigger.new[i].Warning_Message__c = 'Applicant already referred by '+casecontactname;
                                                if(queue_grp != null)
                                                    Trigger.new[i].OwnerId = queue_grp.Id;      
                                            }
                                            
                                        }
                                        else
                                        {
                                            system.debug('C');
                                            Trigger.new[i].Warning_Message__c = 'Applicant already referred by '+casecontactname;
                                            if(queue_grp != null)
                                                Trigger.new[i].OwnerId = queue_grp.Id;
                                        }
                                        System.debug(Trigger.new[i].Warning_Message__c);
                                        
                                    }
                                }
                                //System.debug(cs.Warning_Message__c+ ' '+Trigger.new[i].Owner);
                            }
                            
                        }
                        for(Integer j=0;j<Trigger.new.size();j++)
                        {
                            //if(Trigger.old != null)
                            //{
                                if(Trigger.new[j].OwnerId != queue_grp_chk.Id)
                                {
                                    if(Trigger.new[j].Expected_MoveIn_Date__c < System.Date.today())
                                    {
                                        Trigger.new[j].Warning_Message__c = 'Applicant moved in prior to request';
                                        if(queue_grp != null)
                                            Trigger.new[j].OwnerId = queue_grp.Id;
                                    }
                                    for(Integer k=0;k<date_map.size();k++)
                                    {
                                        if(date_map.containskey(Trigger.new[j].Referred_Resident__c))
                                        {
                                            System.debug('True');
                                            Date moveout = date_map.get(Trigger.new[j].Referred_Resident__c);
                                            if(moveout +30 < Trigger.new[j].Expected_MoveIn_Date__c)
                                            {
                                                Trigger.new[j].Warning_Message__c = 'Prior Resident is not eligible for a referral bonus';
                                                if(queue_grp != null)
                                                    Trigger.new[j].OwnerId = queue_grp.Id;
                                            }
                                        }
                                    }
                                }
                                                            
                            //}
                            
                        }
                        
                        
                    }
                    
                }
                
            //}
            System.debug('Trigger new values'+Trigger.new[0]);
            //Trigger.new[0].addError('Testing code....');
            }
        }
        
    }
    else if(Trigger.isAfter)
    {
        if(Trigger.isInsert)
        {
            ProcessInstance[] procins = [select ID from ProcessInstance where TargetObjectID=:Trigger.new[0].ID and Status='Pending'];
            if(procins.size()==0)
            {
                Boolean chk = AVBCheckApproval.SubmittedApproval();
                System.debug('setvalue'+chk); 
                if(chk == false)
                {
                    Case testcase = Trigger.new[0];
                    System.debug('approval');
                    Approval.Processsubmitrequest req = new Approval.Processsubmitrequest();
                    req.setComments('Submitting Case for Approval');
                    req.setObjectId(testcase.Id);
                    AVBCheckApproval.setapprovalset();
                    Boolean chk1 = AVBCheckApproval.SubmittedApproval();
                    System.debug('setvalue1'+chk1);
                    try{
                    Approval.Processresult res = Approval.process(req);
                    }catch(Exception ex){
                        System.debug('Failure'+ex.getMessage());
                    }
                } 
            
            }
            else
            {
                System.debug('Process already submitted');
            }
        }
        //Updated on 22 March 2010 by Nomit.
        // Submit for approval not required on case update.
        /*else if(Trigger.isUpdate && (Trigger.new[0].Status!='Closed' && Trigger.old[0].Status!='Approved' && Trigger.new[0].Status!='Approved' && Trigger.old[0].Status!='Rejected' && Trigger.new[0].Status!='Rejected'))
        {
            ProcessInstance[] procins = [select ID from ProcessInstance where TargetObjectID=:Trigger.new[0].ID and Status='Pending'];
            if(procins.size()==0)
            {
                Boolean chk = AVBCheckApproval.SubmittedApproval();
                System.debug('setvalue'+chk); 
                if(chk == false)
                {
                    Case testcase = Trigger.new[0];
                    System.debug('approval');
                    Approval.Processsubmitrequest req = new Approval.Processsubmitrequest();
                    req.setComments('Submitting Case for Approval');
                    req.setObjectId(testcase.Id);
                    AVBCheckApproval.setapprovalset();
                    Boolean chk1 = AVBCheckApproval.SubmittedApproval();
                    System.debug('setvalue1'+chk1);
                    try{
                    Approval.Processresult res = Approval.process(req);
                    }catch(Exception ex){
                        System.debug('Failure'+ex.getMessage());
                    }
                } 
            
            }
            else
            {
                System.debug('Process already submitted');
            }
        }*/
    }
    
}