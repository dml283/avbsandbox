trigger CaseIssue_Trigger on Case_Issue__c (before insert,before update,after insert) 
{
	/*
	Purpose:  	Before
					Insert/Update
						For all Resident Referral recordtype Case Issues:
							validate that this is an allowable resident to refer. If not valid, forward case to Revenue Collections queue
	 					If this Case Issue requires approval, set Requires Approval = TRUE
				After	
	 				Insert/Update
	 					submit case for approval
	Created By:  Jeremy Nottingham (Synaptic) 8/6/12
	  
	Last Modified By:  Jeremy Nottingham (Synaptic) 8/6/12
	 
	Current Version:  v1.2
	 
	Revision Log:  
	 			v1.0 - (JN 8/6/12) Created this Trigger
	 
	*/

    if(Trigger.isBefore)
    {
        //deal with Resident Referrals
        
        Group sodaGroup = [select Id from Group where Type='Queue' and Name='OSFA Team leads - SODA'];
	    Group revenueCollectionsGroup = [select Id from Group where Type='Queue' and Name='OSFA Team leads - Revenue Collections'];
	    RecordType rectype = [select Id from RecordType where IsActive=true and SObjectType='Case_Issue__c' and Name='Resident Referral'];
	                    
        //only run this check if the approval has not been submitted yet
        Boolean chk = AVBCheckApproval.SubmittedApproval();
        
        if(chk == false)
        {
            
            List<Case_Issue__c> workingissues = new List<Case_Issue__c>();
            
            List<Case_Issue__c> res_ref_issues = new List<Case_Issue__c>();
            Set<Id> residentconids = new Set<Id>();
            Set<Id> caseids = new Set<Id>();
            
            if(rectype != null)
            {
                for(Case_Issue__c issue : Trigger.new)
                {
                    //if Resident Referral recordtype, collect ids
                    if(issue.RecordTypeId == rectype.Id)
                    {
                        res_ref_issues.add(issue);
                        residentconids.add(issue.Referred_Resident__c);
                        caseids.add(issue.Case__c);
                    }   
                }
                
                if(res_ref_issues.size()>0)
                {
                    map<Id, Case> caseid2casemap = new map<Id, Case>([select Id, OwnerId from Case where Id in :caseids]);
                    set<Id> caseidstoupdate = new set<Id>();
                    
                    //Look for any previous Resident Referral Case Issues that already referred this Contact
                    map<Id,Case_Issue__c> conid2issuemap = new Map<Id,Case_Issue__c>();
                    if(residentconids.size() > 0)
                    {
                        List<Case_Issue__c> previousissues = [select Referred_Resident__c, Case__c, Case__r.ContactId, Case__r.Contact.Name,
                        	Case__r.Contact.AccountId 
                        	from Case_Issue__c 
                        	where RecordTypeId =: rectype.Id 
                        		and Referred_Resident__c in: residentconids];
system.debug('\n\n66 previousissues ' + previousissues);
                        for(Case_Issue__c issue : previousissues)
                        {
                            conid2issuemap.put(issue.Referred_Resident__c,issue);
                        } 
                    }            
                    
                    //query for contacts that are referred residents on these issues
                    List<Contact> residentcons = [select Id,Name,AccountId from Contact where Id in:residentconids];
                    Map<Id,Contact> conid2conmap = new Map<Id,Contact>(residentcons);
                    
                    //get Customer Group Account Ids
                    Set<Id> accids = new Set<Id>();
                    for(Integer i=0;i<residentcons.size();i++)
                        accids.add(residentcons[i].AccountId);
                    
                    //Find out Move Out Dates for any Contacts found to have a CGU
                    Map<ID,Date> accid2MOdatemap = new Map<Id,Date>();
                    if(accids.size()>0)
                    {
                        Customer_Group_to_Unit_Relationships__c[] cus = [select Move_Out_Date__c, Customer_Group__c 
                        	from Customer_Group_to_Unit_Relationships__c 
                        	where Customer_Group__c in:accids ];
                        
                        if(cus.size()>0)
                        {
                            for(Integer j=0;j<cus.size();j++)
                            {   
                                if(cus[j].Move_Out_Date__c != null)                    
                                    accid2MOdatemap.put(cus[j].Customer_Group__c,cus[j].Move_Out_Date__c);
                            }
                        }
                    }
system.debug('\n\n98 conid2issuemap ' + conid2issuemap);                    
                    //If there were previous resident referral issues found in query
                    if(conid2issuemap.size() > 0)
                    {       
                        
                        for(Integer i=0;i<Trigger.new.size();i++)
                        { 
                            Case_Issue__c issue = Trigger.new[i];
                            Case thisCase = caseid2casemap.get(issue.Case__c);
                            
                            //if this issue has a previous issue on this contact, send it to the collections group with a warning message
                            if(conid2issuemap.containsKey(issue.Referred_Resident__c))
                            {
                                Contact con = conid2conmap.get(issue.Referred_Resident__c);
                                String casecontactname = conid2issuemap.get(con.Id).Case__r.Contact.Name;
                                if(con != null)
                                {
                                    thisCase.Warning_Message__c = 'Applicant already referred by ' + casecontactname;
                                    
                                    if ((thisCase.OwnerId != sodaGroup.Id)
                                    	&& (revenueCollectionsGroup != null))
                                    {
                                    	thisCase.OwnerId = revenueCollectionsGroup.Id;
                                    }
                                    
                                    caseidstoupdate.add(thisCase.Id);
                                }
                            }
                        }
                    }//end if conid2issuemap.size() > 0
                    
                    for(Integer j=0;j<Trigger.new.size();j++)
                    {
                        Case_Issue__c issue = Trigger.new[j];
                        Case thisCase = caseid2casemap.get(issue.Case__c);
                        
                        if(thisCase.OwnerId != sodaGroup.Id)
                        {
                            if(issue.Expected_Move_in_Date__c < System.Date.today())
                            {
                                thisCase.Warning_Message__c = 'Applicant moved in prior to request';
                                if(revenueCollectionsGroup != null)
                                    thisCase.OwnerId = revenueCollectionsGroup.Id;
                            	caseidstoupdate.add(thisCase.Id);
                            }
                            Contact referredrescon = conid2conmap.get(issue.Referred_Resident__c);
                            if(accid2MOdatemap.containskey(referredrescon.AccountId))
                            {
                                Date moveout = accid2MOdatemap.get(referredrescon.AccountId);
system.debug('\n\n149 moveout ' + moveout + ' issue date ' + issue.Expected_Move_in_Date__c);                                    
                                if(moveout + 30 > issue.Expected_Move_in_Date__c)
                                {
                                    thisCase.Warning_Message__c = 'Prior Resident is not eligible for a referral bonus';
                                    if(revenueCollectionsGroup != null)
                                        thisCase.OwnerId = revenueCollectionsGroup.Id;
                                	caseidstoupdate.add(thisCase.Id);
                                } 
                            }
                        }//if case is not owned by Team Leads Queue
                    }//end for j = 0 to trigger.new.size()
                    
                    //update Cases if necessary
                    if (caseidstoupdate.size() > 0)
                    {
                    	list<Case> casestoupdate = new list<Case>();
                    	for (Id caseid : caseidstoupdate)
                    	{
                    		casestoupdate.add(caseid2casemap.get(caseid));
                    	}
system.debug('\n\n170 casestoupdate ' + casestoupdate);                    	
                    	update casestoupdate;
                    }//if caseidstoupdate.size() > 0
                }//if res_ref_issues.size() > 0
            }
        }
        
        //Determine if these Case Issue needs to be approved
        CaseApproval.checkNeedsApprovalOnIssues(Trigger.new); 
    }//before
    
    
    else if(Trigger.isAfter)
    {
        set<Id> caseids = new set<id>();
        for (Case_Issue__c issue : Trigger.new)
        {
        	caseids.add(issue.Case__c);
        
        }
        
        //send this case for approval
        
        //get existing approval processes for these cases that are Pending, if there are any
        ProcessInstance[] procins = [select ID, TargetObjectID 
        	from ProcessInstance 
        	where TargetObjectID in :caseids and Status='Pending'];
        
        //if there are as many processinstances as cases, they're all submitted. do this if that's not the case.
        if (procins.size() < caseids.size())
        {
	        set<Id> submittedCaseIds = new set<Id>();
	        for (ProcessInstance pi : procins)
	        {
	        	submittedCaseIds.add(pi.TargetObjectId);
	        }
	        
	        //only submit cases if they haven't been submitted already
	        Boolean chk = AVBCheckApproval.SubmittedApproval();
	        
	        if(chk == false)
	        {
	            list<Approval.Processsubmitrequest> psrs = new list<Approval.Processsubmitrequest>();
	            for (Id caseid : caseids)
	            {
	                //if this case has not yet been submitted, submit it.
	                if (!submittedCaseIds.contains(caseid))
	                {
	                    Approval.Processsubmitrequest req = new Approval.Processsubmitrequest();
	                    req.setComments('Submitting Case for Approval');
	                    req.setObjectId(caseid);
	                    psrs.add(req);
	                }
	            }
	            AVBCheckApproval.setapprovalset();
system.debug('\n\n214 process ' + psrs);	            
	            list<Approval.Processresult> res = Approval.process(psrs, false);
	            AVBCheckApproval.setapprovalfalse();
	            
	        }
        }
    }//after
    
}