public with sharing class MoveInMoveOut { 
/* Jeremy Nottingham 2010  
    Supporting Class for Triggers on CGU, Case and Task associated with Move In and Move Out processes.
*/
    public list<Messaging.SingleEmailMessage> emailstosend = new list<Messaging.SingleEmailMessage>(); //list of emails to send out
    public map<id, Case> accidcasemap = new map<id, Case>(); //Customer Group to relevant case
    
    public static map<String, id> casertmap()
    {
        //This is a handy map to have here and there. RecordType IDs are stored in Custom Settings unless they aren't.
        map<String, ID> rtmap = new map<String, ID>();
        list<RecordTypes__c> rtsettings = RecordTypes__c.getall().values();  
        for (RecordTypes__c r : rtsettings) {
            if (r.SObjectType__c == 'Case') {
                if ((r.Name == 'Move In Tracking Process') 
                    || (r.Name == 'Move Out Tracking Process')) rtmap.put(r.Name, r.Id__c);
            }
            if (r.SobjectType__c == 'Task') {
                if ((r.Name == 'Move In Confirmation')
                    || (r.Name == 'Move In Follow Up')
                    || (r.Name == 'Move Out Follow Up')
                    || (r.Name == 'Notice to Vacate Follow Up')
                    || (r.Name == 'Pre Inspection Follow Up')
                    || (r.Name == 'Prepare Apartment')
                    || (r.Name == 'Remove NTV')
                    || (r.Name == 'Send Move Out Packet')) rtmap.put(r.Name, r.Id__c);
            }
        }
        
        //If the custom settings are not populated, requery. Should only run after a change or deployment
        if (rtmap.keyset().size() < 8) { 
            //clear out whatever custom settings exist already, if any
            delete rtsettings;
            rtsettings.clear();
            
            //get new list of RecordTypes and populate the map and custom settings.
            list<RecordType> rts = [select Name, ID, sObjectType from RecordType where (sObjectType = 'Case' or sObjectType = 'Task')];
            for (RecordType rt : rts) {
                rtmap.put(rt.Name, rt.ID);
                RecordTypes__c newrt = new RecordTypes__c();
                newrt.Name = rt.Name;
                newrt.ID__c = rt.ID;
                newrt.sObjectType__c = rt.sObjectType;
                insert newrt;
                
                if (newrt.SObjectType__c == 'Case') {
                    if ((newrt.Name == 'Move In Tracking Process') 
                        || (newrt.Name == 'Move Out Tracking Process')) rtmap.put(newrt.Name, newrt.Id__c);
                }
                if (newrt.SobjectType__c == 'Task') {
                    if ((newrt.Name == 'Move In Confirmation')
                        || (newrt.Name == 'Move In Follow Up')
                        || (newrt.Name == 'Move Out Follow Up')
                        || (newrt.Name == 'Notice to Vacate Follow Up')
                        || (newrt.Name == 'Pre Inspection Follow Up')
                        || (newrt.Name == 'Prepare Apartment')
                        || (newrt.Name == 'Remove NTV')
                        || (newrt.Name == 'Send Move Out Packet')) rtmap.put(newrt.Name, newrt.Id__c);
                }
            }//for RecordType rt
            
        }//if rtmap not fully populated (requery)
        
        return rtmap;
    }
    
    public void emailCaseUpdate(String emailreason, Case WorkingCase)
    {
        String htmlcontent; 
        String plaincontent;
        String subject;

        if (emailreason == 'Cancel Move Out') {
            htmlcontent = '<h1>Move Out Cancelled</h1>'
                + '<p>Status: ' + WorkingCase.Status + '</p>'
                + '<p>Reason: ' + WorkingCase.Reason + '</p>';
            plaincontent = 'Move Out Cancelled\r\n\r\n'
                + 'Status: ' + WorkingCase.Status + '\r\n'
                + 'Reason: ' + WorkingCase.Reason + '\r\n';
            subject = 'Update: Move Out Cancelled';
        }
        
        if (emailreason == 'Reschedule Move Out') {
            htmlcontent = '<h1>Move Out Rescheduled</h1>'
                + '<p>Updated Expected Move Out Date: ' + WorkingCase.Move_Out_Date__c + '</p>' 
                + '<p>Status: ' + WorkingCase.Status + '</p>'
                + '<p>Reason: ' + WorkingCase.Reason + '</p>';
            plaincontent = 'Move Out Rescheduled\r\n\r\n'
                + 'Original Expected Move Out Date: TK\r\n'
                + 'Updated Expected Move Out Date: ' + WorkingCase.Move_Out_Date__c + '\r\n' 
                + 'Status: ' + WorkingCase.Status + '\r\n'
                + 'Reason: ' + WorkingCase.Reason + '\r\n';
            subject = 'Update: Move Out Rescheduled';
        }
        
        if (emailreason == 'Cancel Move In') {
            htmlcontent = '<h1>Move In Cancelled</h1>' 
                + '<p>Status: ' + WorkingCase.Status + '</p>'
                + '<p>Reason: ' + WorkingCase.Reason + '</p>';
            plaincontent = 'Move In Cancelled\r\n\r\n' 
                + 'Status: ' + WorkingCase.Status + '\r\n'
                + 'Reason: ' + WorkingCase.Reason + '\r\n';
            subject = 'Update: Move In Cancelled';
        }
        
        if (emailreason == 'Reschedule Move In') {
            htmlcontent = '<h1>Move In Rescheduled</h1>'
                + '<p>Current Move In Date: ' + WorkingCase.Expected_MoveIn_Date__c + '</p>' 
                + '<p>Status: ' + WorkingCase.Status + '</p>'
                + '<p>Reason: ' + WorkingCase.Reason + '</p>';
            plaincontent = 'Move In Rescheduled\r\n'
                + 'Current Move In Date: ' + WorkingCase.Expected_MoveIn_Date__c + '\r\n' 
                + 'Status: ' + WorkingCase.Status + '\r\n'
                + 'Reason: ' + WorkingCase.Reason + '\r\n';
            subject = 'Update: Move In Rescheduled';
        }
        
        String htmlbody = '<p>Your Case <a href="/' + WorkingCase.ID + '">' + WorkingCase.CaseNumber + '</a> has been Updated.</p>'
            + htmlcontent
            + '<p>Date Updated: ' + WorkingCase.LastModifiedDate + '</p>';
            
        String plainbody = 'Your Case ' + WorkingCase.CaseNumber + ' has been Updated.'
            + plaincontent
            + 'Date Updated: ' + WorkingCase.LastModifiedDate + '\r\n';
        
        Messaging.SingleEmailMessage casemail = new Messaging.SingleEmailMessage();
        casemail.setSubject(subject);
        casemail.setTargetObjectId(WorkingCase.OwnerID);
        casemail.setCCAddresses(new list<String> { 'jeremy.nottingham@synapticap.com' }); //debugging only
        casemail.setReplyTo('donotreply@example.com');
        casemail.setSenderDisplayName('Salesforce Case Management');
        casemail.setHtmlBody(htmlbody);
        casemail.setPlainTextBody(plainbody);
        
        emailstosend.add(casemail);
    }
    
    private void emailTaskEscalation(Task t)
    {
        String htmlcontent; 
        String plaincontent;
        String subject;
        
        htmlcontent = '<h1>Task Escalation</h1>'
            + '<p>Type: ' + t.AVB_Type__c + '</p>'
            + '<p>SubCategory: ' + t.Subject_Sub_Category__c + '</p>'
            + '<p><a href="/' + t.ID + '">' + t.Subject_Sub_Category__c + ' Task</a>.</p>';
        plaincontent = 'Move Out Cancelled\r\n\r\n'
            + 'Type: ' + t.AVB_Type__c + '\r\n'
            + 'SubCategory: ' + t.Subject_Sub_Category__c + '\r\n'
            + 'TaskID: ' + t.ID + '\r\n';
        subject = t.AVB_Type__c + ' Task Escalation';
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject(subject);
        mail.setTargetObjectId(t.OwnerID);
        mail.setCcAddresses(new list<String> { 'jeremy.nottingham@synapticap.com' }); //debugging
        mail.setReplyTo('donotreply@example.com');
        mail.setSenderDisplayName('Salesforce Task Management');
        mail.setHtmlBody(htmlcontent);
        mail.setPlainTextBody(plaincontent);
        
        emailstosend.add(mail);
    }
    
    public String SendEmails()
    {
        String returnmessage = '';
        //send out that list of emails
        if (emailstosend.size() > 0) {
            list<Messaging.SendEmailResult> results = Messaging.sendEmail(emailstosend, false);
            for (Integer i = 0; i < results.size() ; i++) {
                if (!results[i].isSuccess()) {
                    returnmessage += 'Sending Failure on email message\r\n'
                        + 'ToAddress: ' + EmailsToSend[i].getToAddresses() + '\r\n'
                        + 'Subject: ' + EmailsToSend[i].getSubject() + '\r\n'
                        + 'Errors Reported: ' + results[i].getErrors() + '\r\n\r\n';
                } 
            }//for
            return returnmessage;
        } else {
            //No emails in list
            return 'No Emails To Send';
        }
    }
    
    public void checkOpenMoveTasks() //daily check on open tasks. Called by MonitorMoveTasks
    {
        list<Task> taskstocheck = [select id, WhatID, ActivityDate, AVB_Type__c, Subject_Sub_Category__c, OwnerID from Task 
            where AVB_Type__c = 'Move Out Process' 
            and IsClosed = false 
            and ActivityDate = :system.today().addDays(-1)];
system.debug('\n\ncheckopenmovetasks ' + taskstocheck);     
        //escalate Move Out tasks past their Due Dates
        for (Task t : taskstocheck) {
            if  ((t.Subject_Sub_Category__c == 'Notice To Vacate Follow-up') 
                || (t.Subject_Sub_Category__c == 'Final Move Out Inspection/Estimates Inquiry')
                || (t.Subject_Sub_Category__c == 'Move Out Packet/Process Inquiry')
                || (t.Subject_Sub_Category__c == 'Schedule Final Move Out')
                || (t.Subject_Sub_Category__c == 'Move Out Complete Follow Up'))
            {
system.debug('\n\nfound ' + t);             
                t.Outcome__c = 'Escalated - Do Not Close';
                emailTaskEscalation(t);
            }
        }
        
        update taskstocheck;
        String Results = sendEmails();
                
    } 
    /*// removed 092711 JN 
    public void createMoveTasks() //scheduled logic for Move Out called by MonitorMoveTasks
    {
        list<Task> taskstoinsert = new list<Task>();
        ID rtid = casertmap().get('Move Out Tracking Process');
        list<Case> casesmovingout = [select id, Move_Out_Date__c, OwnerID, AVB_Contact_Name__c, AccountID, ContactID, Preliminary_Inspection_Date__c
            from Case where RecordTypeID = :rtid and Status = 'Open' and Move_Out_Date__c = :system.today().addDays(-1)];
        
        map<id, id> cgidcontactidmap = new map<id, id>(); 
        set<id> cgids = new set<Id>(); //Customer Group IDs for cases
        
        for (Case c : casesmovingout) {
            cgids.add(c.AccountID);
        }
        
        
        //Create Task for Move Out Complete Follow Up for 3 days after actual move out date
        for (Case c : casesmovingout) {
        
            taskstoinsert.add(new Task(
                WhatID = c.id,
                WhoID = c.ContactID,
                RecordTypeID = casertmap().get('Move Out Follow Up'),
                OwnerID = c.OwnerID,
                AVB_Associate_First_Last_Name__c = c.AVB_Contact_Name__c,
                AVB_Type__c = 'Move Out Process',
                Outcome__c = null,
                Subject = 'Move Out Complete Follow Up',
                Subject_Sub_Category__c = 'Move Out Complete Follow Up',
                ActivityDate = c.Move_Out_Date__c.addDays(3)
                ));
        
        }
        insert taskstoinsert;
        
        //This is just to send me a note as a debugging step when the schedule job runs.
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject('automated email reporting');
        mail.setToAddresses(new list<String> { 'chris_camp@avalonbay.com'});
        mail.setReplyTo('donotreply@example.com');
        mail.setSenderDisplayName('Salesforce Task Management');
        mail.setHtmlBody('Note! createMoveTasks ran at ' + system.now());
        mail.setPlainTextBody('Note! createMoveTasks ran at ' + system.now());
        
        emailstosend.add(mail);
        SendEmails();
        
    } 
    */

}