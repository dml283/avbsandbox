global class Email_Prospects implements Messaging.InboundEmailHandler {
    /*
        Purpose:        Receive Lead emails from websites based on forms filled in.


        Created By:     Jeremy Nottingham (Synaptic) 2/3/12
        
        Last Modified By:       Jeremy Nottingham (Synaptic) 2/3/12
        
        Current Version:        v1.0
        
        Revision Log:           v1.0 - (JN 2/3/12) Created this class
                                                
    */
    String rawPhone;
    String newPhone;
    
    public String fromDomain;
    public map<String, String> fieldMap;
    public String lineSeparator = '\n';
    public map<String, Integer> monthMap = new map<String, Integer>
    {
        'January' => 1,
        'February' => 2,
        'March' => 3,
        'April' => 4,
        'May' => 5,
        'June' => 6,
        'July' => 7,
        'August' => 8,
        'September' => 9,
        'October' => 10,
        'November' => 11,
        'December' => 12
    };
    
    public Messaging.InboundEmail email;
    public String emailBody;
    map<String, list<String>> emailAsMap = new map<String, list<String>>(); //general "fieldname" to value(s)
    public String communityName;
    public String debuglog = '';
    
    public Account newProspectAccount;
    public Contact newProspectContact;
    
    public class NoDomainException extends Exception {}
    public class CommunityNotFoundException extends Exception {}
    public class RecordCreationException extends Exception {}
    public class DebugEmailException extends Exception {}
    
    //Email addresses to send success email to
    public list<String> SuccessEmailReceivers = new list<String> { 'chris_camp@avalonbay.com' };
    
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) 
    {
        this.email = email;
        Messaging.InboundEmailResult result = null;
        
        try
        {
            //determine source of this email
            determineFromDomain();
            
system.debug('\n\n38 fromDomain ' +fromDomain);
            
            //commented 042312 JN
            /*
            //  Send Debug Email  
            try 
            {
                //Notify Synaptic on every lead
                list<Messaging.EmailFileAttachment> attachments = new list<Messaging.EmailFileAttachment>();
                
                if ((email.HTMLBody != null) && (email.HTMLBody.length() > 0))
                {
system.debug('\n\nHTMLBody found: \n-' + email.HTMLBody + '-');
                    Messaging.EmailFileAttachment htm = new Messaging.EmailFileAttachment();
                    htm.setFileName('HtmlBody.txt');
                    htm.setBody(Blob.valueOf(email.HTMLBody));
                    attachments.add(htm);
                }
                if ((email.plainTextBody != null) && (email.plainTextBody.length() > 0))
                {
system.debug('\n\nplainTextBody found: \n-' + email.plainTextBody + '-');
                    Messaging.EmailFileAttachment plain = new Messaging.EmailFileAttachment();
                    plain.setFileName('plainTextBody.txt');
                    plain.setBody(Blob.valueOf(email.plainTextBody));
                    attachments.add(plain);
                }
system.debug('\n\nattachments ' + attachments);             
                
                //send message to admin
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setSubject(fromDomain + ' lead email received');
                mail.setToAddresses(new list<String>{ 'salesforce@synapticap.com' });
                mail.setReplyTo('donotreply@salesforce.com');
                mail.setSenderDisplayName('Salesforce website lead creation');
                mail.setPlainTextBody('See attached. <br/>' + debuglog);
                if (attachments.size() > 0)
                    mail.setFileAttachments(attachments);
                else
                    mail.setPlainTextBody('There was no identified body in the received email.');
                list<Messaging.SendEmailResult> res = Messaging.sendEmail(new list<Messaging.SingleEmailMessage> { mail });
                
                if (!res[0].IsSuccess())
                {
system.debug('\n\nerror sending: ' + res[0].getErrors()[0].getMessage());                   
                }
            }
            catch (Exception e)
            {
                debuglog += '<br/>problem sending debug email:<br/>' + e.getMessage();
                 //send message to admin
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setSubject(fromDomain + ' lead email received');
                mail.setToAddresses(new list<String>{ 'salesforce@synapticap.com' });
                mail.setReplyTo('donotreply@salesforce.com');
                mail.setSenderDisplayName('Salesforce website lead creation');
                mail.setPlainTextBody('Problem with debug email. <br/>' + e.getMessage() + '<br/><br/>plain text<br/>' + email.plainTextBody + '<br/><br/>HTML<br/>' + email.HTMLBody);
                
                Messaging.sendEmail(new list<Messaging.SingleEmailMessage> { mail });
                throw new DebugEmailException('Problem sending debug email: ' + e.getMessage());
            }
            */
            if (fromDomain == null)
                throw new NoDomainException();
            
            //get proper field mapping based on domain it's coming from
            initFieldMap();
            
            //turn email into a map
            emailBody = email.plainTextBody;
            if ((emailBody == null) || (emailBody.length() == 0) || (email.Subject.contains('kumquat')))
            {
                //remove all tags from the HTML body and use that for parsing
                String contentWithoutHTML = email.HTMLBody.replace('&nbsp;',' ').replace('&#160;',' ').replace('<br>','');
                
                Pattern htmlPattern = Pattern.compile('</?[a-z][a-z0-9]*[^<>]*>'); 
                contentWithoutHTML = htmlPattern.matcher(contentWithoutHTML).replaceAll(''); 
System.debug('\n\n### Stripped HTML body:\n'+contentWithoutHTML);
                
                emailBody = contentWithoutHTML;
            }
            
            parseEmail();
                
            //create records
            makeAccount();
            
            if (newProspectAccount.parentId == null)
                throw new CommunityNotFoundException();
                
system.debug('\n\n45 prospectaccount\n' + newProspectAccount + '\nprospectcontact\n' + newProspectContact);
            
            insert newProspectAccount;
            
            newProspectContact.AccountId = newProspectAccount.Id;
            newProspectContact.Primary_Contact__c = TRUE;
            
            insert newProspectContact;
            
            //add original email as Task to Guest Card created
            Guest_Card__c initialGC = [select Id from Guest_Card__c where Prospect_Account__c = :newProspectAccount.Id];
            
            //AVB lead
            if (newProspectAccount.Created_From_ILS__c == FALSE)
            {
                //change owner to queue for CCC
                Group q =[select Id from Group where Type = 'Queue' and Name = 'CCC Web Leads' limit 1][0];
                if (q != null)
                {
                    initialGC.OwnerId = q.Id;
                }
                //check box to keep this in the CCC queue
                initialGC.Needs_Contact__c = TRUE;
            }
            else
            {
            }
            
            initialGC.Initial_Lead_Type__c = 'Email';
            update initialGC;
            
            //Add original email as a Task to the created Guest Card
            String textBody = 'From: ' + email.fromAddress
                + '\nTo: ' + email.toAddresses
                + '\nSubject: ' + email.subject
                + '\nBody:\n'
                + emailBody;
                
            Task emailTask = new Task(
                whatId = initialGC.Id,
                WhoId = newProspectContact.Id,
                OwnerId = newProspectAccount.OwnerId,
                Subject = 'Email from website: ' + email.subject,
                Description = textBody,
                ActivityDate = system.today(),
                Status = 'Complete');
            insert emailTask;
            
            //Code to send debug email containing original email body commented JN
            
            String plaincontent = 'Account, Contact, Guest Card, Task created.'
                + '<br/>Guest Card: https://cs4.salesforce.com/' + initialGC.Id
                + '<br/><br/>Subject: ' + this.email.subject
                + '<br/>log:<br/>' + debuglog
                + '<br/><br/>Body:<br/>' 
                + ((this.email.htmlBody == null) ? this.email.plainTextBody : this.email.htmlBody);
            
            //send success message to admin
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setSubject('Customer Group Created from ' + fromDomain);
            mail.setToAddresses(SuccessEmailReceivers);
            mail.setReplyTo('donotreply@salesforce.com');
            mail.setSenderDisplayName('Salesforce website lead creation');
            mail.setHtmlBody(plaincontent);
            mail.setPlainTextBody(plaincontent);
            Messaging.sendEmail(new list<Messaging.SingleEmailMessage> { mail });
        }
        
        catch (NoDomainException e)
        {
            throw new NoDomainException('\n\nThis message is not recognized as a website lead.');
        }
        catch (CommunityNotFoundException e)
        {
            throw new CommunityNotFoundException('Community not found: "' + communityName + '"');
        }
        catch (DMLException e)
        {
            throw new RecordCreationException('Problem inserting Account and Contact: "' + e.getMessage() + '"');
        }
        catch (Exception e)
        {
            throw e;
        }
        
        return result;
    }
    
    public void parseEmail()
    {
        //take raw email body and parse into a map for reference
        for (String keystring : fieldMap.keyset())
        {
            String searchString = fieldMap.get(keystring);
            
            //first occurrence of searchString
            Integer thisIndex = emailBody.indexOf(searchString);
            Integer lastIndex = emailBody.lastIndexOf(searchString);
system.debug('\n\n70 keystring ' + keystring + '\nsearchString ' + searchString + '\nthisIndex ' + thisIndex + '\nlastIndex ' + lastIndex);         
            //init list in map
            emailAsMap.put(keystring, new list<String>());
            
            while (thisIndex != -1)
            {
                //starting after keystring, grab the end of this line and the next line in one string, 
                //to make sure we get the whole value.
                Integer startOfValuestring = thisIndex + searchString.length();
                String restOfEmail = emailBody.substring(startOfValuestring);
                list<String> lines = restOfEmail.trim().split(lineSeparator, 3);
//system.debug('\n\n100 lines ' + lines.size() + '\n' + lines);             
                String valuestring = lines[0] + ((lines.size() == 1) ? '' : '\n' + lines[1]); 
                //add into list of values in map. If this is detail, get the rest of the email
                String stringToAdd = ((keystring != 'detail') && (keystring != 'details'))
                    ? valuestring
                    : restOfEmail;
                emailAsMap.get(keystring).add(stringToAdd);
                
                //look again
                thisIndex = emailBody.indexOf(searchString, thisIndex + 1);
            }
            
            
        }
        
    }
    
    private void makeAccount()
    {
        Id cgrtid = [select Id from Recordtype where Name = 'Customer Group' and SOBjectType = 'Account'].Id;
        Account communityAccount;
        Boolean CreatedFromILS = TRUE;
        String FirstName = '';
        String LastName = '';
        
        newProspectAccount = new Account();
        newProspectAccount.RecordTypeId = cgrtid;
        newProspectAccount.Status__c = 'Prospect';
        
        newProspectContact = new Contact();
        
        if (fromDomain == 'avb.com')
        {
            newProspectAccount.Marketing_Source__c = 'AVB Company Website';
            
            //This came from AVB, not some third-party website, darn it!
            CreatedFromILS = FALSE;
system.debug('\n\n198 raw commname ' + emailAsMap.get('communityName'));            
            if (emailAsMap.get('communityName').size() > 0)
            {
                communityName = emailAsMap.get('communityName')[0].split('Phone:',2)[0].trim();
system.debug('\n\ncommunityName = -' + communityName + '-');            
                list<Account> comm = [select Id, OwnerId, Account_ID__c
                    from Account 
                    where Name = :communityName limit 1];
                if (comm.size() == 1)
                {
                    communityAccount = comm[0];
                }
            }
            
            if (emailAsMap.get('prospectName').size() > 0)
            {
                list<String> names = emailAsMap.get('prospectName')[0].split(',',2);
                LastName = names[0].trim();
                FirstName = names[1].split('Property',2)[0].trim();
            }
            
            if (emailAsMap.get('homePhone').size() > 0)
            {
                rawPhone = emailAsMap.get('homePhone')[0].substring(0,14).trim();
                newPhone = emailAsMap.get('homePhone')[0].replace('-','').replace('(','').replace(' ','').substring(0,10);
                newProspectAccount.PROSPECT_HomePhone__c = emailAsMap.get('homePhone')[0].replace('-','').replace(')','').replace('(','').replace(' ','').substring(0,10);
            }
            
            if (emailAsMap.get('Email').size() > 0)
                //cjc 11JUL12: strip html line feeds
                //newProspectAccount.PROSPECT_Email__c = emailAsMap.get('Email')[0].split(' ',2)[0].split('<',2)[0].split('Desired',2)[0].trim();
                newProspectAccount.PROSPECT_Email__c = emailAsMap.get('Email')[0].split(' ',2)[0].split('<',2)[0].split('Desired',2)[0].trim().replace('<br>','');
                //cjc 11JUL12: strip html line feeds
            
            if (emailAsMap.get('moveDate').size() > 0)
            {
                list<String> mmddyyyy = emailAsMap.get('moveDate')[0].split('/',3);
                newProspectAccount.Expected_Move_in_Date__c = 
                    Date.newInstance(
                        Integer.valueOf(mmddyyyy[2].trim().substring(0,4)),
                        Integer.valueOf(mmddyyyy[0].trim()), 
                        Integer.valueOf(mmddyyyy[1].trim()) 
                        );
            }

            if (emailAsMap.get('leaseTerm').size() > 0)
                newProspectAccount.Lease_Term__c = emailAsMap.get('leaseTerm')[0].split('month',2)[0].trim();
            
            if (emailAsMap.get('bedSlashBath').size() > 0)
            {
                list<String> bedbath = emailAsMap.get('bedSlashBath')[0].split('-',2);
                newProspectAccount.PROSPECT_Bed__c = Decimal.valueOf(bedbath[0].trim());
                newProspectAccount.PROSPECT_Bath__c = Decimal.valueOf(bedbath[1].substring(0,2).trim());
            }
            //cjc 22MAR12
            if (emailAsMap.get('details').size() > 0)
                newProspectAccount.Description = emailAsMap.get('details')[0].trim();
            //cjc 22MAR12
                
        } //end avb.com
        
        else if (fromDomain == 'rent.com')
        {
            newProspectAccount.Marketing_Source__c = 'INT-Rent.com';
            
            if (emailAsMap.get('communityName').size() > 0)
            {
                communityName = emailAsMap.get('communityName')[0].split('!',2)[0].trim();
system.debug('\n\ncommunityName = -' + communityName + '-');            
                list<Account> comm = [select Id, OwnerId, Account_ID__c
                    from Account 
                    where Name = :communityName limit 1];
                if (comm.size() == 1)
                {
                    communityAccount = comm[0];
                }
            }
            
            if (emailAsMap.get('prospectName').size() > 0)
            {
                list<String> names = emailAsMap.get('prospectName')[0].split('Phone Number:',2)[0].trim().split(' ',2);
                FirstName = names[0].trim();
                LastName = names[1].split('\n',2)[0].trim();
            }
            
            if (emailAsMap.get('homePhone').size() > 0)
                newProspectAccount.PROSPECT_HomePhone__c = emailAsMap.get('homePhone')[0].split('Email address:',2)[0].trim();

system.debug('\n\n260 email ' + emailAsMap.get('email'));
            if (emailAsMap.get('email').size() > 0)
                newProspectAccount.PROSPECT_Email__c = emailAsMap.get('email')[0].split('<',2)[0].trim();
            
            
            if (emailAsMap.get('moveDate').size() > 0)
            {
                list<String> mmddyyyy = emailAsMap.get('moveDate')[0].split('/',3);
                newProspectAccount.Expected_Move_in_Date__c = 
                    Date.newInstance(
                        Integer.valueOf(mmddyyyy[2].trim().substring(0,4)),
                        Integer.valueOf(mmddyyyy[0].trim()), 
                        Integer.valueOf(mmddyyyy[1].trim()) 
                        );
            }

            if (emailAsMap.get('bed').size() > 0)
            {
                try {
                    newProspectAccount.PROSPECT_Bed__c = Decimal.valueOf(emailAsMap.get('bed')[0].split('MESSAGE',2)[0].trim().substring(0,2).trim());
                } catch (Exception e)
                {
                    debuglog += '<br/> Bed not understood: ' + emailAsMap.get('bed')[0] + '<br/>' + e.getMessage();
                }
            }
            
            
            if (emailAsMap.get('details').size() > 0)
                newProspectAccount.Description = emailAsMap.get('details')[0].trim();
            
        } //end rent.com
        
        else if (fromDomain == 'apartmentguide.com')
        {
            newProspectAccount.Marketing_Source__c = 'INT-AptGuide.com';
            
            if (emailAsMap.get('communityName').size() > 0)
            {
                communityName = emailAsMap.get('communityName')[0].split('Property',2)[0].trim();
                list<Account> comm = [select Id, OwnerId, Account_ID__c
                    from Account 
                    where Name = :communityName limit 1];
                if (comm.size() == 1)
                {
                    communityAccount = comm[0];
                }
            }
            
            if (emailAsMap.get('prospectFirstName').size() > 0)
                FirstName = emailAsMap.get('prospectFirstName')[0].split('Last Name')[0].trim();
            if (emailAsMap.get('prospectLastName').size() > 0)
                LastName = emailAsMap.get('prospectLastName')[0].split('City:')[0].trim();
            
            if (emailAsMap.get('homePhone').size() > 0)
                newProspectAccount.PROSPECT_HomePhone__c = emailAsMap.get('homePhone')[0].split('Unit')[0].substring(0,14).trim();
            
            if (emailAsMap.get('Email').size() > 0)
                newProspectAccount.PROSPECT_Email__c = emailAsMap.get('Email')[0].split('Phone',2)[0].trim();
            
            if (emailAsMap.get('moveDate').size() > 0)
            {
                list<String> yymmdd = emailAsMap.get('moveDate')[0].split('City Moving',2)[0].trim().split('-',3);
system.debug('\n\n389 yymmdd ' + yymmdd + '\nraw ' + emailAsMap.get('moveDate')[0]);
                if (yymmdd.size() == 3)
                    newProspectAccount.Expected_Move_in_Date__c = 
                        Date.newInstance(Integer.valueOf(yymmdd[0]), Integer.valueOf(yymmdd[1]), Integer.valueOf(yymmdd[2].substring(0,2).trim()));
            }
            
            if (emailAsMap.get('city').size() > 1)
                newProspectAccount.PROSPECT_AddressCity__c = emailAsMap.get('city')[1].split('Email:')[0].trim();
            if (emailAsMap.get('bed').size() > 0)
            {
                try 
                {   
                    newProspectAccount.PROSPECT_Bed__c = Decimal.valueOf(emailAsMap.get('bed')[0].substring(0,2).trim());
                } catch (Exception e)
                {
                    debuglog += '<br/> Bed not understood: ' + emailAsMap.get('bed')[0] + '<br/>' + e.getMessage();
                }
            }
            if (emailAsMap.get('bath').size() > 0)
            {
                try 
                {   
                    newProspectAccount.PROSPECT_Bed__c = Decimal.valueOf(emailAsMap.get('bath')[0].substring(0,2).trim());
                } catch (Exception e)
                {
                    debuglog += '<br/> Bath not understood: ' + emailAsMap.get('bath')[0] + '<br/>' + e.getMessage();
                }
            }
            if (emailAsMap.get('details').size() > 0)
                newProspectAccount.Description = emailAsMap.get('details')[0];
            
        }
        
        else if (fromDomain == 'apartments.com')
        {
            newProspectAccount.Marketing_Source__c = 'INT-Apartments.com';
            
            if (emailAsMap.get('communityName').size() > 0)
            {
system.debug('\n\nraw ' + emailAsMap.get('communityName')[0]);          
                communityName = emailAsMap.get('communityName')[0].split('/Leasing',2)[0].trim();
system.debug('\n\ncommunityName = -' + communityName + '-');            
                list<Account> comm = [select Id, OwnerId, Account_ID__c
                    from Account 
                    where Name = :communityName limit 1];
                if (comm.size() == 1)
                {
                    communityAccount = comm[0];
                }
            }
            
            if (emailAsMap.get('prospectLastName').size() > 0)
                LastName = emailAsMap.get('prospectLastName')[0].split('First Name')[0].trim();
            if (emailAsMap.get('prospectFirstName').size() > 0)
                FirstName = emailAsMap.get('prospectFirstName')[0].split('Address')[0].trim();
            
            if (emailAsMap.get('homePhone').size() > 0)
            {
system.debug('\n\nphone ' + emailAsMap.get('homePhone')[0].trim());
                String tempstr = emailAsMap.get('homePhone')[0].split('E-mail Address',2)[0].trim();
                if (tempstr.length() >= 12)
                    newProspectAccount.PROSPECT_HomePhone__c = tempstr.substring(0,12);
            }
            if (emailAsMap.get('email').size() > 0)
                newProspectAccount.PROSPECT_Email__c = emailAsMap.get('email')[0].split('<',2)[0].trim();
            
            
            if ((emailAsMap.get('moveDateMonth').size() > 0)
                && (emailAsMap.get('moveDateDay').size() > 0)
                && (emailAsMap.get('moveDateYear').size() > 0))
            {
                newProspectAccount.Expected_Move_in_Date__c = 
                    Date.newInstance(
                        Integer.valueOf(emailAsMap.get('moveDateYear')[0].split('Comments',2)[0].trim()),
                        Integer.valueOf(emailAsMap.get('moveDateMonth')[0].split('Day =',2)[0].trim()), 
                        Integer.valueOf(emailAsMap.get('moveDateDay')[0].split('Year =',2)[0].trim()) 
                        );
            }
            
            //cjc 16MAR12: default bed and bath if empty
            if(emailAsMap.get('bed').size() > 0)  
            {
                if (!emailAsMap.get('bed')[0].contains('Any Bedroom Size'))
                {    
                    try 
                    {
                        newProspectAccount.PROSPECT_Bed__c = Decimal.valueOf(emailAsMap.get('bed')[0].trim().substring(0,2).trim());
                    } 
                    catch (Exception e)
                    {
                        debuglog += '<br/> Bed not understood: ' + emailAsMap.get('bed')[0] + '<br/>' + e.getMessage();
                    }
                }
            }
            else
            {
                newProspectAccount.PROSPECT_Bed__c = 1;
            }
            
            if (emailAsMap.get('bath').size() > 0)
            {
                if (!emailAsMap.get('bath')[0].contains('Any Bathroom Size'))
                {
                    try 
                    {
                        newProspectAccount.PROSPECT_Bath__c = Decimal.valueOf(emailAsMap.get('bath')[0].trim().substring(0,2));
                    } 
                    catch (Exception e)
                    {
                    }
                }
            }
            else
            {
                newProspectAccount.PROSPECT_Bath__c = 1;
            }
            //cjc 16MAR12: default bed and bath if empty
            
            if (emailAsMap.get('city').size() > 0)
                newProspectAccount.PROSPECT_AddressCity__c = emailAsMap.get('city')[0].split('State =',2)[0].trim();
            if (emailAsMap.get('state').size() > 0)
                newProspectAccount.PROSPECT_AddressState__c = emailAsMap.get('state')[0].split('Zip =',2)[0].trim();
            if (emailAsMap.get('zip').size() > 0)
                newProspectAccount.PROSPECT_AddressCity__c = emailAsMap.get('zip')[0].split('DayPhone =',2)[0].trim();
            if (emailAsMap.get('details').size() > 0)
                newProspectAccount.Description = emailAsMap.get('details')[0].trim();
            
        } //end apartments.com
        
        else if (fromDomain == 'mynewplace.com')
        {
            newProspectAccount.Marketing_Source__c = 'INT-MyNewplace.com';
            
            if (emailAsMap.get('communityName').size() > 0)
            {
                communityName = emailAsMap.get('communityName')[0].split('!',2)[0].trim();
system.debug('\n\ncommunityName = -' + communityName + '-');            
                list<Account> comm = [select Id, OwnerId, Account_ID__c, Name
                    from Account 
                    where Name = :communityName 
                    limit 1];
                if (comm.size() == 1)
                {
                    communityAccount = comm[0];
                    communityName = communityAccount.Name;
                }
            }
            
            if (emailAsMap.get('prospectName').size() > 0)
            {
                list<String> names = emailAsMap.get('prospectName')[0].split('Move Date:',2)[0].trim().split(' ',2);
                FirstName = names[0].trim();
                if (names.size() > 1) LastName = names[1].trim();
            }
            
            if (emailAsMap.get('homePhone').size() > 0)
                newProspectAccount.PROSPECT_HomePhone__c = emailAsMap.get('homePhone')[0].split('Source:',2)[0].trim();

            if (emailAsMap.get('Email').size() > 0)
                newProspectAccount.PROSPECT_Email__c = emailAsMap.get('Email')[0].split('<',2)[0].split('Personal',2)[0].trim();
            
            
            if (emailAsMap.get('moveDate').size() > 0)
            {
                try 
                {
                    list<String> movedate = emailAsMap.get('moveDate')[0].split('Email:',2)[0].trim().split(',',2);
                    Integer month = monthMap.get(movedate[0].split(' ',2)[0].trim());
                    Integer day = Integer.valueOf(movedate[0].split(' ',2)[1].trim());
                    Integer year = Integer.valueOf(movedate[1].trim().substring(0,4));
                    newProspectAccount.Expected_Move_In_Date__c = Date.newInstance(year, month, day);
                }
                catch (Exception e)
                {
                    debuglog += '<br/>Unable to process move in date: ' + emailAsMap.get('moveDate'); 
                }
                /* Changed format 3/7/12 JN
                list<String> yyyymmdd = emailAsMap.get('moveDate')[0].trim().split('-',3);
                newProspectAccount.Expected_Move_in_Date__c = 
                    Date.newInstance(
                        Integer.valueOf(yyyymmdd[0].trim()),
                        Integer.valueOf(yyyymmdd[1].trim()), 
                        Integer.valueOf(yyyymmdd[2].trim().substring(0,2).trim()) 
                        );
                */
            }
            
            if (emailAsMap.get('details').size() > 0)
                newProspectAccount.Description = emailAsMap.get('details')[0].split('Phone',2)[0].trim();
            
        } //end mynewplace.com

        else if (fromDomain == 'move.com')
        {
            newProspectAccount.Marketing_Source__c = 'INT-Move.com';
            
            if (emailAsMap.get('communityName').size() > 0)
            {
                communityName = emailAsMap.get('communityName')[0].split('at www.move.com',2)[0].trim();
system.debug('\n\ncommunityName = -' + communityName + '-');            
                list<Account> comm = [select Id, OwnerId, Account_ID__c
                    from Account 
                    where Name = :communityName limit 1];
                if (comm.size() == 1)
                {
                    communityAccount = comm[0];
                }
            }
            
            if (emailAsMap.get('prospectName').size() > 0)
            {
                list<String> names = emailAsMap.get('prospectName')[0].split('My phone number',2)[0].trim().split(' ',2);
                FirstName = names[0].trim();
                LastName = (names.size() > 1) ? names[1].trim() : names[0].trim();
            }
            
            if (emailAsMap.get('homePhone').size() > 0)
                newProspectAccount.PROSPECT_HomePhone__c = emailAsMap.get('homePhone')[0].split('My email address',2)[0].trim();

            if (emailAsMap.get('Email').size() > 0)
                newProspectAccount.PROSPECT_Email__c = emailAsMap.get('Email')[0].split('\n',2)[0].split('<',2)[0].split(' ',2)[0].trim();
            
            
            if (emailAsMap.get('moveDate').size() > 0)
            {
                list<String> mmddyyyy = emailAsMap.get('moveDate')[0].split('/',3);
                newProspectAccount.Expected_Move_in_Date__c = 
                    Date.newInstance(
                        Integer.valueOf(mmddyyyy[2].trim().substring(0,4)),
                        Integer.valueOf(mmddyyyy[0].trim()), 
                        Integer.valueOf(mmddyyyy[1].trim()) 
                        );
            }
            /*
            if (!emailAsMap.get('bed').size() > 0)
            {
                try {
                    newProspectAccount.PROSPECT_Bed__c = Decimal.valueOf(emailAsMap.get('bed')[0].trim().substring(0,2));
                } catch (Exception e)
                {
                }
            }
            */
            if (emailAsMap.get('details').size() > 0)
                newProspectAccount.Description = emailAsMap.get('details')[0].trim();
                
        } //end move.com
        
        //Account information same for all sources
        if (communityAccount != null) 
        {
system.debug('\n\n254 communityAccount ' + communityAccount);           
            newProspectAccount.ParentId = communityAccount.Id;
            newProspectAccount.Community_ID__c = communityAccount.Account_ID__c;
            newProspectAccount.OwnerId = communityAccount.OwnerId;
            newProspectAccount.Community_Name__c = communityName;
        }
        
system.debug('\n\nFirstName = -' + FirstName + '- LastName = -' + LastName + '-');    
system.debug('\n\nHomePhone -' + newProspectAccount.PROSPECT_HomePhone__c + '-');
system.debug('\n\nemail -' + newProspectAccount.PROSPECT_Email__c + '-');
system.debug('\n\ndate > ' + newProspectAccount.Expected_Move_in_Date__c);          
system.debug('\n\nnewProspectAccount.Lease_Term__c = -' + newProspectAccount.Lease_Term__c + '-');
system.debug('\n\nmarketing source = -' + newProspectAccount.Marketing_Source__c + '-');
system.debug('\n\nnewProspectAccount.bed ='  + newProspectAccount.PROSPECT_Bed__c + ' bath = ' + newProspectAccount.PROSPECT_Bath__c);
        
        if ((LastName == null) || (LastName.length() == 0)) LastName = 'No Last Name';
        if ((FirstName == null) || (FirstName.length() == 0)) FirstName = 'No First Name';
        
        newProspectAccount.Name = FirstName + ' ' + LastName + ' and other Occupants';
        newProspectAccount.Created_From_ILS__c = CreatedFromILS;
        newProspectAccount.Phone = newProspectAccount.PROSPECT_HomePhone__c;
        newProspectAccount.Type = 'Non-Corporate';
        
        Boolean GoodNumber = TRUE;
        if (newProspectAccount.PROSPECT_HomePhone__c != null)
        {
            for (Integer i = 0; i < newProspectAccount.PROSPECT_HomePhone__c.length(); i++)
            {
                if (!('(012) 345-6789'.contains(newProspectAccount.PROSPECT_HomePhone__c.substring(i, i+1))))
                {
                    GoodNumber = FALSE;
                    break;
                }
            }
        }
        if (!GoodNumber)
            newProspectAccount.PROSPECT_HomePhone__c = null;
        newProspectAccount.Phone = newProspectAccount.PROSPECT_HomePhone__c;
        newProspectAccount.CommunityBrand__c = null;
        newProspectAccount.MRI_Leasing_Associate__c = [
            select Id 
            from MRILeasingAssociate__c
            where LeasingAssociateID__c = 'sflead' limit 1].Id; 
        
 
        //Contact Fields
        newProspectContact.FirstName = FirstName;
        newProspectContact.LastName = LastName;
        newProspectContact.Email = newProspectAccount.PROSPECT_Email__c;
        newProspectContact.HomePhone = newProspectAccount.PROSPECT_HomePhone__c;
        
    }
    
    private void determineFromDomain()
    {
system.debug('\n\n273 determine domain subject: ' + email.subject);     
        if (this.email.subject != null)
        {
            if (this.email.subject.contains('Rent.com'))
            {
                fromDomain = 'rent.com';
            }
            else if (this.email.subject.contains('ApartmentGuide.com'))
            {
                fromDomain = 'apartmentguide.com';
            }
            else if (this.email.subject.contains('Online Guest Card Received'))
            {
                fromDomain = 'avb.com';
            }
            else if (this.email.subject.contains('MyNewPlace'))
            {
                fromDomain = 'mynewplace.com';
            }
            else if (this.email.subject.contains('MOVE(R)'))
            {
                fromDomain = 'move.com';
            }
            else if (this.email.subject.contains('Apartments.com'))
            {
                fromDomain = 'apartments.com';
            }
            /*
            --cjc 11JUL12: default unidentified domains to avb.com
            else
                fromDomain = 'avb.com';
            */
        }
    }
    private void initFieldMap()
    {
        if (fromDomain == 'avb.com')
        { 
            lineSeparator = '\r';
            fieldMap = new map<String, String>
            {
                'communityName' => 'Property:',
                'prospectName' => 'Prospect Name:',
                'homePhone' => 'Phone:',
                'Email' => 'Email:',
                'moveDate' => 'Desired Move-in Date:',
                'leadSource' => 'Lead Source:',
                'bedSlashBath' => 'Bed-Bath:',
                'leaseTerm' => 'Desired Lease Term:',
                'details' => 'Guest Card Questions or Comments:'
            };
        }
        else if (fromDomain == 'rent.com')
        { 
            fieldMap = new map<String, String>
            {
                'communityName' => 'A Rent.com renter is interested in',
                'prospectName' => 'Renter name:',
                'homePhone' => 'Phone number:',
                'email' => 'Email address:',
                'moveDate' => 'RENTER WILL BE MOVING:',
                'bed' => 'PREFERRED UNIT TYPE:', 
                'details' => 'MESSAGE FROM'
            };
        }
        else if (fromDomain == 'apartmentguide.com')
        { 

            fieldMap = new map<String, String>
            {
                'communityName' => 'Property Name:',
                'prospectFirstName' => 'First Name:',
                'prospectLastName' => 'Last Name:',
                'homePhone' => 'Phone:',
                'Email' => 'Email:',
                'moveDate' => 'Date of Move:',
                'city' => 'City:',
                'bed' => 'Unity Type:',
                'bath' => 'Number of Bathrooms:',
                'details' => 'Comments:'
            };
        }
        else if (fromDomain == 'mynewplace.com')
        { 
            fieldMap = new map<String, String>
            {
                'communityName' => 'wants to know more about',
                'prospectName' => 'Name:',
                'homePhone' => 'Phone:',
                'Email' => 'Email:',
                'moveDate' => 'Move Date:',
                'leadSource' => 'Source:',
                'details' => 'Personal Message:'
            };
        }
        else if (fromDomain == 'apartments.com')
        { 
            fieldMap = new map<String, String>
            {
                'communityName' => 'To: ',
                'prospectFirstName' => 'First Name =',
                'prospectLastName' => 'Renter Last Name =',
                'homePhone' => 'EveningPhone =',
                'email' => 'E-mail Address =',
                'moveDateMonth' => 'Month =',
                'moveDateDay' => 'Day =',
                'moveDateYear' => 'Year =',
                'bed' => 'Bedrooms =',
                'bath' => 'Bathrooms =',
                'city' => 'City =', 
                'state' => 'State =',
                'zip' => 'zip =',
                'details' => 'Comments'
                
            };
        }
        else if (fromDomain == 'move.com')
        { 
            fieldMap = new map<String, String>
            {
                'communityName' => 'I\'ve seen',
                'prospectName' => 'My name is:',
                'homePhone' => 'My phone number is:',
                'Email' => 'My email address is:',
                'moveDate' => 'I plan to move on',
                'details' => 'love to speak with your leasing professionals about:'
            };
        }
        
    } 
    
    static testmethod void testAVBEmail()
    {
        Id commrtid = [select Id from Recordtype where Name = 'Community' and SOBjectType = 'Account'].Id;
        Account testcomm = new Account(
            RecordtypeId = commrtid,
            Name = 'Avalon Bay Apex Test Community',
            Community_ID__c = 'TEST9x9');
        insert testcomm;
        
        Messaging.InboundEmail testibe = new Messaging.InboundEmail();
        testibe.fromAddress = 'joe@avb.com';
        testibe.subject = 'Online Guest Card Received';
        testibe.plainTextBody = 
            + '\nProspect Name:'
            + '\ntestprospect, testname'
            + '\nProperty:'
            + '\nAvalon Bay Apex Test Community'
            + '\nPhone:'
            + '\n123 456 7890'
            + '\nEmail:'
            + '\nx@example.com<mailto:x@example.com'
            + '\nDesired Move-in Date:'
            + '\n12/13/1971'
            + '\nCity '
            + '\nIndianpolis'
            + '\nBed-Bath:'
            + '\n3-4'
            + '\nDesired Lease Term:'
            + '\n15 months'
            + '\nComments'
            + '\nnice website you have here.'
            + '\nLead Source:'
            + '\nother lead source'
            + '\nFloor Plan'
            + '\nB3T'
            ;
            
        
        Messaging.InboundEnvelope testenv = new Messaging.InboundEnvelope();
        
test.startTest();
        Email_Prospects testep = new Email_Prospects();
        Messaging.Inboundemailresult testresult = testep.handleInboundEmail(testibe, testenv);

test.stopTest();    
        system.assertEquals(null, testresult);
        String summary = '';
        for (String i : testep.emailAsMap.keyset())
        {
            summary += '\n' + i + ' => ' + testep.emailAsMap.get(i);
        }
system.debug('\n\nSummary: \n' + summary);
system.debug('\n\nemailAsMap ' + testep.emailAsMap);  
system.debug('\n\nplaintextbody ' + testibe.plainTextBody);

    }
    
    static testmethod void testapartmentscomEmail()
    {
        Id commrtid = [select Id from Recordtype where Name = 'Community' and SOBjectType = 'Account'].Id;
        Account testcomm = new Account(
            RecordtypeId = commrtid,
            Name = 'Avalon Bay Apex Test Community',
            Community_ID__c = 'TEST9x9');
        insert testcomm;
        
        Messaging.InboundEmail testibe = new Messaging.InboundEmail();
        testibe.fromAddress = 'joe@example.com';
        testibe.subject = 'New lead from Apartments.com';
        testibe.plainTextBody = 'Apartments.com Hot Lead'
            + '\nTo: Avalon Bay Apex Test Community/Leasing Office'
            + '\nPropid: 10102736083'
            + '\n2/12/2012 11:03:08 PM'
            + '\nApartments.com is pleased to send you this Hot Lead!'
            + '\nThis prospective resident used'
            + '\nApartments.com to view your apartment community. So you know they are already interested in renting! It is'
            + '\nbest to respond to them immediately, while their interest is high, via phone or email. We look forward to'
            + '\nsending you many more Hot Leads in the future!'
            + '\nRenter Last Name = Fredette'
            + '\nFirst Name = jolie'
            + '\nAddress = 123 Main St'
            + '\nCity = Appleton'
            + '\nState = MD'
            + '\nZip = 12345'
            + '\nDayPhone = (606) 555-1212'
            + '\nEveningPhone = (606) 555-1212'
            + '\nE-mail Address = test@example.com<mailto:test@example.com>'
            + '\nPreferred contact method ='
            + '\nMove Date'
            + '\nMonth = 3'
            + '\nDay = 25'
            + '\nYear = 2012'
            + '\nComments Specify a unit type, or ask a general question. Search Criteria'
            + '\nRent = 0 - 0'
            + '\nBedrooms = Any Bedroom Size'
            + '\nBathrooms = Any Bathroom Size'
            + '\nRespond to this lead in style (and in seconds)'
            + '\nwith a MyMedia Digital Brochure. Please copy and paste this link into your browser: http://mymedia.apartments.com'
            + '\nasking for. -Do not enter into an agreement that requires you to wire money to the renter.'
            + '\nReport fraud at feedback@apartments.com. For more information visit our Fraud Tips.'; 
            
        
        Messaging.InboundEnvelope testenv = new Messaging.InboundEnvelope();
        
test.startTest();
        Email_Prospects testep = new Email_Prospects();
        Messaging.Inboundemailresult testresult = testep.handleInboundEmail(testibe, testenv);

test.stopTest();    
        system.assertEquals(null, testresult);
        String summary = '';
        for (String i : testep.emailAsMap.keyset())
        {
            summary += '\n' + i + ' => ' + testep.emailAsMap.get(i);
        }
system.debug('\n\nSummary: \n' + summary);
system.debug('\n\nemailAsMap ' + testep.emailAsMap);  
system.debug('\n\nplaintextbody ' + testibe.plainTextBody);

    }
    
    static testmethod void testMoveComEmail()
    {
        Id commrtid = [select Id from Recordtype where Name = 'Community' and SOBjectType = 'Account'].Id;
        Account testcomm = new Account(
            RecordtypeId = commrtid,
            Name = 'Avalon Bay Apex Test Community',
            Community_ID__c = 'TEST9x9');
        insert testcomm;
        
        Messaging.InboundEmail testibe = new Messaging.InboundEmail();
        testibe.fromAddress = 'joe@example.com';
        testibe.subject = 'Another Prospective Resident for Avalon Bay Apex Test Community from MOVE(R)';
        testibe.plainTextBody = 'Avalon Bay Apex Test Community'
            + '4 - 75 48TH Avenue'
            + 'LONG ISLAND CITY, NY 11109'
            + 'Prop ID: 486080'
            + '1/21/12'
            + 'THIS MOVE(R) PROSPECT JUST REQUESTED INFORMATION ABOUT YOUR COMMUNITY!'
            + 'Please have your community representatives follow up with this prospect.'
            + 'I\'ve seen Avalon at Media Center at www.move.com and I may be interested in your'
            + 'community!'
            + 'My name is: Christine Jiang'
            + 'My phone number is:'
            + 'My email address is: test@example.com<mailto:test@example.com>'
            + 'My preferred method of contact is: e-mail'
            + 'I\'d love to speak with your leasing professionals about:'
            + 'Plan name: A11'
            + 'I plan to move on 3/3/2012';
        Messaging.InboundEnvelope testenv = new Messaging.InboundEnvelope();
        
test.startTest();
        Email_Prospects testep = new Email_Prospects();
        Messaging.Inboundemailresult testresult = testep.handleInboundEmail(testibe, testenv);

test.stopTest();    
        system.assertEquals(null, testresult);
        String summary = '';
        for (String i : testep.emailAsMap.keyset())
        {
            summary += '\n' + i + ' => ' + testep.emailAsMap.get(i);
        }
system.debug('\n\nSummary: \n' + summary);
system.debug('\n\nemailAsMap ' + testep.emailAsMap);  
system.debug('\n\nplaintextbody ' + testibe.plainTextBody);

    }
    
    static testmethod void testApartmentGuideComEmail()
    {
        Id commrtid = [select Id from Recordtype where Name = 'Community' and SOBjectType = 'Account'].Id;
        Account testcomm = new Account(
            RecordtypeId = commrtid,
            Name = 'Avalon Bay Apex Test Community',
            Community_ID__c = 'TEST9x9');
        insert testcomm;
        
        Messaging.InboundEmail testibe = new Messaging.InboundEmail();
        testibe.fromAddress = 'joe@example.com';
        testibe.subject = 'Another qualified lead from ApartmentGuide.com';
        testibe.plainTextBody = '2012-01-30'
            + 'Property ID: 86283'
            + 'A prospective renter is ready to fill your vacancy!'
            + 'Property Name: Avalon Bay Apex Test Community'
            + 'Property City: McLean'
            + 'Property State: VA'
            + 'Avalon Crescent'
            + 'Housing Type: Apartments'
            + 'First Name: Tom'
            + 'Last Name: Baker'
            + 'City: Los Alamos'
            + 'Email: anita.christian64@gmail.com'
            + 'Phone: (407) 516-7788'
            + 'Unity Type:'
            + 'Date of Move: 2012-01-30'
            + 'City Moving to:'
            + 'Comments: I am moving from Stafford, VA after driving 2.5 years after driving down I-95.  Its time to get closer to work at Tysons Corner.'
            + '------------------------------------------------------------';
        Messaging.InboundEnvelope testenv = new Messaging.InboundEnvelope();
        
test.startTest();
        Email_Prospects testep = new Email_Prospects();
        Messaging.Inboundemailresult testresult = testep.handleInboundEmail(testibe, testenv);

test.stopTest();    
        system.assertEquals(null, testresult);
        String summary = '';
        for (String i : testep.emailAsMap.keyset())
        {
            summary += '\n' + i + ' => ' + testep.emailAsMap.get(i);
        }
system.debug('\n\nSummary: \n' + summary);
system.debug('\n\nemailAsMap ' + testep.emailAsMap);  
system.debug('\n\nplaintextbody ' + testibe.plainTextBody);

    }
    
    static testmethod void testMyNewPlaceComEmail()
    {
        Id commrtid = [select Id from Recordtype where Name = 'Community' and SOBjectType = 'Account'].Id;
        Account testcomm = new Account(
            RecordtypeId = commrtid,
            Name = 'Apex Test Community',
            Community_ID__c = 'TEST9x9');
        insert testcomm;
        
        Messaging.InboundEmail testibe = new Messaging.InboundEmail();
        testibe.fromAddress = 'joe@example.com';
        testibe.subject = 'New lead from MyNewPlace';
        testibe.plainTextBody = 'They Want to Hear More!'
            + '\nMyNewPlace Delivers for You'
            + '\nAnother potential renter, HIRA ANEES, wants to know more about Apex Test Community! Learn the details to follow up:'
            + '\nName:  HIRA ANEES '
            + '\nMove Date:     2012-03-01'
            + '\nEmail:     test@example.com<mailto://test@example.com>'
            + '\nPersonal Message:  how much rent n deposit ..and garbg and water include or not?'
            + '\nPhone:     (510) 610-9893'
            + '\nSource:    MyNewPlace'
            + '\nWant More Details?';
        Messaging.InboundEnvelope testenv = new Messaging.InboundEnvelope();
        
test.startTest();
        Email_Prospects testep = new Email_Prospects();
        Messaging.Inboundemailresult testresult = testep.handleInboundEmail(testibe, testenv);

test.stopTest();    
        system.assertEquals(null, testresult);
        String summary = '';
        for (String i : testep.emailAsMap.keyset())
        {
            summary += '\n' + i + ' => ' + testep.emailAsMap.get(i);
        }
system.debug('\n\nSummary: \n' + summary);
system.debug('\n\nemailAsMap ' + testep.emailAsMap);  
system.debug('\n\nplaintextbody ' + testibe.plainTextBody);

    }
    
    static testmethod void testRentComEmail()
    {
        Id commrtid = [select Id from Recordtype where Name = 'Community' and SOBjectType = 'Account'].Id;
        Account testcomm = new Account(
            RecordtypeId = commrtid,
            Name = 'Avalon at Apex Test Community',
            Community_ID__c = 'TEST9x9');
        insert testcomm;
        
        Messaging.InboundEmail testibe = new Messaging.InboundEmail();
        testibe.fromAddress = 'joe@example.com';
        testibe.subject = 'Message from a Rent.com renter';
        testibe.plainTextBody = 'A Rent.com renter is interested in Avalon at Apex Test Community!'
            + '\nKanwar Fagoora found your listing on Rent.com and would like'
            + '\nto know more about Avalon at Mission Bay North.'
            + '\nCONTACT INFORMATION'
            + '\nRenter name:  Kanwar Fagoora'
            + '\nPhone number:  (559) 917-7008'
            + '\nEmail address: test@example.com<mailto://test@example.com>'
            + '\nRENTER WILL BE MOVING:'
            + '\n01/22/2012'
            + '\nPREFERRED UNIT TYPE:'
            + '\n1 Bedroom'
            + '\n2 Bedroom'
            + '\nMESSAGE FROM KANWAR'
            + '\nHi, '
            + '\nI\'m looking for a 1 or 2 bedroom unit with good square footage priced under $2500/month; do you have anything immediately available?'
            + '\nProperty ID: 464053'
            + '\nID=lead-VIVAPROD-688402602';
        Messaging.InboundEnvelope testenv = new Messaging.InboundEnvelope();
        
test.startTest();
        Email_Prospects testep = new Email_Prospects();
        Messaging.Inboundemailresult testresult = testep.handleInboundEmail(testibe, testenv);

test.stopTest();    
        system.assertEquals(null, testresult);
        String summary = '';
        for (String i : testep.emailAsMap.keyset())
        {
            summary += '\n' + i + ' => ' + testep.emailAsMap.get(i);
        }
system.debug('\n\nSummary: \n' + summary);
system.debug('\n\nemailAsMap ' + testep.emailAsMap);  
system.debug('\n\nplaintextbody ' + testibe.plainTextBody);

    }
}