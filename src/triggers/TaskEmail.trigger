trigger TaskEmail on Task (after insert,after update) 
{
    if(Trigger.new[0].Update_Community_On_Progress__c == true)
    {
        if(Trigger.new[0].Email_Recipients__c != null && Trigger.new[0].Email_Recipients__c != '')
        {
            String temp = Trigger.new[0].Email_Recipients__c;
            
            String[] email_addrs = temp.split('\n');
            System.debug(email_addrs);
            String[] toaddr = new List<String>();

            for(Integer j=0;j<email_addrs.size();j++)
            {
                System.debug(email_addrs[j].trim().IndexOf(','));
                if(email_addrs[j].trim().IndexOf(',')>0)
                    email_addrs[j] = email_addrs[j].trim().replace(',','');
                
                System.debug(email_addrs[j].trim());
                toaddr.add(email_addrs[j].trim());
            }
            System.debug(Trigger.new[0]);
            Task tsk = [select Who.Name,What.Name,What.Id,LastModifiedBy.Name from Task where id =: Trigger.new[0].Id];
            Account[] acctask = [select Account_ID__c from Account where Id =: Trigger.new[0].WhatId];
            String acctaskstr = '';
            if(acctask.size()>0)
                acctaskstr = acctask[0].Account_ID__c;
            //System.debug(tsk);
            try{
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
             
            mail.setToAddresses(toaddr);
            mail.setBccSender(false);
            mail.setUseSignature(false);
            mail.setSenderDisplayName('Salesforce.com Alert');
            String strbody = '';
            if(Trigger.isInsert)
            {
                mail.setSubject('Task has been created for '+tsk.what.name+' (# '+acctaskstr+')');
                strbody = tsk.LastModifiedBy.Name +' has created a '+Trigger.new[0].Subject+' task on '+Trigger.new[0].LastModifiedDate+'<br>';
            }
            else
            {
                if(Trigger.new[0].Status.tolowercase() == 'completed')
                {
                    mail.setSubject('Task has been Closed for '+tsk.what.name+' (# '+acctaskstr+')');
                    strbody = tsk.LastModifiedBy.Name +' has closed '+Trigger.new[0].Subject+' task on '+Trigger.new[0].LastModifiedDate+'<br>';
                }
                else
                {   
                    mail.setSubject('Task has been Updated for '+tsk.what.name+' (# '+acctaskstr+')');
                    strbody = tsk.LastModifiedBy.Name +' has updated a '+Trigger.new[0].Subject+' task on '+Trigger.new[0].LastModifiedDate+'<br>';
                }
                
            }
                        
            
            
            strbody += '<b>Status : </b>'+Trigger.new[0].Status+'<br>';
            strbody += '<b>Contact : </b>'+tsk.Who.Name+'<br>';
            strbody += '<b>Account : </b>'+tsk.What.Name+' (# '+acctaskstr+') <br>';
            //String[] strdesc = Trigger.new[0].Description.split('\n');
            //for(integer i=0;i<strdesc.size();i++)
            //{
                //strdesc[i] = strdesc[i].replace(',','<br>');
            //}
            //System.debug('strdesc='+strdesc);
            //strdesc = strdesc.replace(',','<br>');
            if(Trigger.new[0].Description!=null)
                strbody += '<b>Comments : </b>'+Trigger.new[0].Description.replace('\n','<br>');
            //strbody += 'Comments : '+strdesc;
            //System.debug('Description Array is '+strdesc);
            System.debug('Description is '+Trigger.new[0].Description);
            mail.setHTMLBody(strbody);
            System.debug(mail);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }catch(EmailException ex){
                Trigger.new[0].addError('An error occurred while sending the email.Please check te email address.More details are as :'+ex.getMessage());
            }
                        
        }

    }
}