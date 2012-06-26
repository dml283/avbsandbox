trigger LitigationActivityEmail on Litigation__c (before insert,before update) 
{
	String orgId = UserInfo.getOrganizationId();
	String url;
	if(orgId == '00D6000000077L4EAI'){
		url = '<a href=https://login.salesforce.com/';
	} else {
		url = '<a href=https://test.salesforce.com/';
	}

    if(Trigger.isInsert)
    {
        if(Trigger.new[0].Status__c.tolowercase() == 'open' || Trigger.new[0].Status__c.tolowercase() == 'closed')
        {
            if(Trigger.new[0].Email_Recipients__c != null && Trigger.new[0].Email_Recipients__c != '')
            {
                String temp = Trigger.new[0].Email_Recipients__c;
                temp = temp.replace(' ', ';');
                temp = temp.replace('\n', ';');
                temp = temp.replace(',', ';');
                
                String[] email_addrs;
                
                if(temp.IndexOf(';')>0)
                	email_addrs = temp.split(';');
                else
                	email_addrs = new String[]{temp};
                	
                /*if(temp.IndexOf('\n')>0)
                    email_addrs = temp.split('\n');
                else if(temp.IndexOf(',')>0)
                    email_addrs = temp.split(',');
                else if(temp.IndexOf(';')>0)
                    email_addrs = temp.split(';');
                else
                    email_addrs = new String[]{temp};
                    
                   */
                String[] toaddr = new List<String>();
    			
                for(Integer j=0;j<email_addrs.size();j++)
                {
                    //if(email_addrs[j].trim().IndexOf(',')>0)
                        //email_addrs[j] = email_addrs[j].trim().replace(',','');
                    if(email_addrs[j].trim().IndexOf(';')>0)
                        email_addrs[j] = email_addrs[j].trim().replace(';','');
                    
                    if(email_addrs[j]!='' || email_addrs[j]!=' ')  
                        toaddr.add(email_addrs[j].trim());
                }
                
                try{
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                Account acc = [select Name,Account_ID__c from Account where Id =: Trigger.new[0].Account__c];
                 
                mail.setToAddresses(toaddr);
                mail.setBccSender(false);
                mail.setUseSignature(false);
                mail.setSenderDisplayName('Salesforce.com Alert');
                String strstatus = Trigger.new[0].Status__c;
                if(strstatus.toLowerCase() == 'open')
                    strstatus = 'opened';           
                mail.setSubject('Litigation activity has been '+strstatus+' for '+acc.Name+' (# '+acc.Account_ID__c+')');
                String strbody = 'Litigation activity has been '+strstatus+' for '+acc.Name+'.<br><br>';
                System.debug('Auto'+Trigger.new[0].Auto_Response_Email__c);
                if(Trigger.new[0].Auto_Response_Email__c!=null)
                {
                    if(Trigger.new[0].Auto_Response_Email__c == 'Litigation Activity Opened: "If applicable, please send any necessary paperwork..."')
                    {
                        
                        strbody += 'If applicable, please send any necessary paperwork(Legal Notice, Lease Documents, etc.) to the CCC, Attn: Landlord Tenant Team, as soon as possible to avoid any delays in filing this case.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Court Date: "The associate who signed the proof of service will need to appear at court..."')
                    {
                        
                        strbody += 'The associate who signed the proof of service will need to appear at court and bring with them the entire resident file. The Landlord Tenant Specialist will provide our attorney with an updated ledger the day prior to court.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Court Date: "An associate will need to be on-call to appear at court..."')
                    {
                        
                        strbody += 'An associate will need to be on-call to appear at court with the entire resident file if necessary. Please provide the name and contact number for the on-call associate and we will forward this information to the attorney.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Court Date: "An associate is required to be present at court..."')
                    {
                        
                        strbody += 'An associate is required to be present at court to represent AvalonBay and bring with them the entire resident file.<br>Please let us know the name of the associate who will be attending court and we will forward this information to the attorney.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "Please be sure to have the appropriate amount of petty cash available to pay..."')
                    {
                        
                        strbody += 'Please be sure to have the appropriate amount of petty cash available to pay the Constable/Marshall/Sheriff. Be prepared to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "Please remember it is very important to wait for the Constable/Marshall/Sheriff..."')
                    {
                        
                        strbody += 'Please remember it is very important to wait for the Constable/Marshall/Sheriff to arrive before entering the apartment.Be prepare to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "It is very important the actual date and time of the lock-out is not known by the resident..."')
                    {
                        
                        strbody += 'It is very important the actual date and time of the lock-out is not known by the resident. Be prepared to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "Please have the appropriate number of associates available to perform the lock-out..."')
                    {
                        
                        strbody += 'Please have appropriate number of associates available to perform the lock-out. Be prepared to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "Please be prepared to change the locks once the Constable/Marshall/Sheriff has returned..."')
                    {
                        
                        strbody += 'Please be prepared to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                }
                
                strbody += 'For more information, please log-in to Salesforce.com using the below link<br>';
                strbody += url+Trigger.new[0].Id+' >Litigation Activity</a>';
                
                mail.setHtmlBody(strbody);
                
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }catch(EmailException ex){
                    Trigger.new[0].addError('An error occurred during sending the email.Details are as followes\n'+ex.getMessage());
                }
            }
        }
        
    }
    else if(Trigger.isUpdate)
    {
    	
        Litigation__c la_old = Trigger.old[0];
        Litigation__c la_new = Trigger.new[0];
        if((la_old.Status__c != la_new.Status__c) || (la_old.Court_Date__c != la_new.Court_Date__c) || (la_old.Scheduled_Lock_Out_Date__c != la_new.Scheduled_Lock_Out_Date__c) || (la_old.Default_Date__c != la_new.Default_Date__c))
        {
            if(la_new.Email_Recipients__c != null && la_new.Email_Recipients__c != '')
            {
                String temp = la_new.Email_Recipients__c;
                System.debug('Email='+temp);
                temp = temp.replace(' ', ';');
                temp = temp.replace('\n', ';');
                temp = temp.replace(',', ';');
                System.debug(temp);
                String[] email_addrs;
                
                if(temp.IndexOf(';')>0)
                	email_addrs = temp.split(';');
                else
                	email_addrs = new String[]{temp};
                
                System.debug(email_addrs);	
                /*if(temp.IndexOf('\n')>0)
                    email_addrs = temp.split('\n');
                else if(temp.IndexOf('; ')>0)
                	email_addrs = temp.split('; ');
                else if(temp.IndexOf(';')>0)
                    email_addrs = temp.split(';');
                else if(temp.IndexOf(', ')>0)
                    email_addrs = temp.split(', ');
                else if(temp.IndexOf(',')>0)
                    email_addrs = temp.split(',');
                else
                    email_addrs = new String[]{temp};
                    */
                String[] toaddr = new List<String>();
    
                for(Integer j=0;j<email_addrs.size();j++)
                {
                	System.debug('Email addr = '+email_addrs[j]);
                    //if(email_addrs[j].trim().IndexOf(',')>0)
                        //email_addrs[j] = email_addrs[j].trim().replace(',','');
                    if(email_addrs[j].trim().IndexOf(';')>0)
                        email_addrs[j] = email_addrs[j].trim().replace(';','');
                    
                    if(email_addrs[j]!='' || email_addrs[j]!=' ')
                    	toaddr.add(email_addrs[j].trim());
                    
                }
                System.debug(toaddr);
                System.debug('Send Mail');
                try{
                    DateTime dt_courtdate;
                    Date dt_lockoutdate;
                    Date dt_defaultdate;
                Account acc = [Select Id,Account_ID__c,Name from Account where ID =: la_new.Account__c];    
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                
                mail.setToAddresses(toaddr);
                mail.setBccSender(false);
                mail.setUseSignature(false);
                mail.setSenderDisplayName('Salesforce.com Alert');
                String sub = 'Litigation activity for '+acc.Name+' (# '+acc.Account_ID__c+') has been updated';           
                
                String temp_body='';
                String cond = '';
                if(la_old.Status__c != la_new.Status__c)
                {
                    temp_body = ' Status is now '+la_new.Status__c+'<br>';
                    cond += ' with Status';
                }
                if(la_old.Default_Date__c != la_new.Default_Date__c)
                {
                    if(la_new.Default_Date__c != null)
                        dt_defaultdate = Date.newinstance(la_new.Default_Date__c.year(),la_new.Default_Date__c.month(),la_new.Default_Date__c.day());
                    
                    temp_body += ' Default Date is now '+dt_defaultdate+'<br>';
                    if(cond!='')
                        cond += ' and Default Date';
                    else
                        cond += ' with Default Date';
                }
                if(la_old.Court_Date__c != la_new.Court_Date__c)
                {
                    Date tempdate;
                    if(la_new.Court_Date__c != null)
                    {
                        dt_courtdate = DateTime.newinstance(la_new.Court_Date__c.year(),la_new.Court_Date__c.month(),la_new.Court_Date__c.day());
                        tempdate = Date.newInstance(dt_courtdate.year(), dt_courtdate.month(), dt_courtdate.day());
                        
                        temp_body += ' Court Date is now '+tempdate.format()+' at '+la_new.Court_Time__c+'<br>';
                        if(cond!='')
	                        cond += ' and Court Date';
	                    else
	                        cond += ' with Court Date';
                    }
                    //temp_body += ' Court Date is now '+tempdate.format().substring(0,9)+' at '+dt_courtdate.format('h:mm a')+'<br>';
                    
                    
                }
                if(la_old.Scheduled_Lock_Out_Date__c != la_new.Scheduled_Lock_Out_Date__c)
                {
                    if(la_new.Scheduled_Lock_Out_Date__c != null)
                        dt_lockoutdate = Date.newinstance(la_new.Scheduled_Lock_Out_Date__c.year(),la_new.Scheduled_Lock_Out_Date__c.month(),la_new.Scheduled_Lock_Out_Date__c.day());
                    
                    temp_body += ' Scheduled Lock Out Date is now '+dt_lockoutdate+'<br>';
                    if(cond!='')
                        cond += ' and Scheduled Lock Out Date';
                    else
                        cond += ' with Scheduled Lock Out Date';
                }
                /*if(la_old.Vacated_Locked_Out__c != la_new.Vacated_Locked_Out__c)
                {
                    if(la_new.Vacated_Locked_Out__c != null)
                        temp_body += ' Vacated Locked Out is now '+la_new.Vacated_Locked_Out__c;
                     
                }
                */
                String acc_name = '';
                if(acc!= null)
                    acc_name = acc.Name;
                String strbody = 'Please note for '+acc_name+'<br>'+temp_body;
                strbody += '<br>';
                
                
                if(Trigger.new[0].Auto_Response_Email__c!=null)
                {
                    if(Trigger.new[0].Auto_Response_Email__c == 'Litigation Activity Opened: "If applicable, please send any necessary paperwork..."')
                    {
                        
                        strbody += 'If applicable, please send any necessary paperwork(Legal Notice, Lease Documents, etc.) to the CCC, Attn: Landlord Tenant Team, as soon as possible to avoid any delays in filing this case.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Court Date: "The associate who signed the proof of service will need to appear at court..."')
                    {
                        
                        strbody += 'The associate who signed the proof of service will need to appear at court and bring with them the entire resident file. The Landlord Tenant Specialist will provide our attorney with an updated ledger the day prior to court.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Court Date: "An associate will need to be on-call to appear at court..."')
                    {
                        
                        strbody += 'An associate will need to be on-call to appear at court with the entire resident file if necessary. Please provide the name and contact number for the on-call associate and we will forward this information to the attorney.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Court Date: "An associate is required to be present at court..."')
                    {
                        
                        strbody += 'An associate is required to be present at court to represent AvalonBay and bring with them the entire resident file.<br>Please let us know the name of the associate who will be attending court and we will forward this information to the attorney.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "Please be sure to have the appropriate amount of petty cash available to pay..."')
                    {
                        
                        strbody += 'Please be sure to have the appropriate amount of petty cash available to pay the Constable/Marshall/Sheriff. Be prepared to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "Please remember it is very important to wait for the Constable/Marshall/Sheriff..."')
                    {
                        
                        strbody += 'Please remember it is very important to wait for the Constable/Marshall/Sheriff to arrive before entering the apartment.Be prepare to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "It is very important the actual date and time of the lock-out is not known by the resident..."')
                    {
                        
                        strbody += 'It is very important the actual date and time of the lock-out is not known by the resident. Be prepare to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "Please have the appropriate number of associates available to perform the lock-out..."')
                    {
                        
                        strbody += 'Please have appropriate number of associates available to perform the lock-out. Be prepare to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                    else if(Trigger.new[0].Auto_Response_Email__c == 'Lock-out: "Please be prepared to change the locks once the Constable/Marshall/Sheriff has returned..."')
                    {
                        
                        strbody += 'Please be prepare to change the locks once the Constable/Marshall/Sheriff has returned posession of the apartment to AvalonBay.<br><br>';
                        strbody += 'If you have any questions or concerns, please contact the CCC by email or phone.<br>';
                    }
                } 
                else if(Trigger.new[0].Auto_Response_Email__c==null && Trigger.new[0].Status__c=='closed'){
                	strbody += 'Litigation activity for '+acc.Name+' (# '+acc.Account_ID__c+') has been closed.<br><br>';
                }
                
                if(Trigger.new[0].Status__c.tolowercase()=='closed')
                {
                	sub = 'Litigation activity for '+acc.Name+' (# '+acc.Account_ID__c+') has been closed';
                	cond = '';
                }		
                
                strbody += 'For more information, please log-in to Salesforce.com using the below link<br>';
                strbody += url+Trigger.new[0].Id+' >Litigation Activity</a>';
                
                mail.setSubject(sub+cond);
                mail.setHtmlBody(strbody);
            
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }catch(EmailException ex){
                    la_new.addError('An error occurred during sending the email.Details are as followes\n'+ex.getMessage());
                }
            }
        }
    	}
    for(Integer i=0;i<Trigger.new.size();i++)
	{
		Trigger.new[i].Auto_Response_Email__c = null;
	}
      
}