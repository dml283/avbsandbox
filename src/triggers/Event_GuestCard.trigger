trigger Event_GuestCard on Event (before insert, before update, after insert, after update) {
/*
    Purpose:    -For all Events, date version of StartDateTime will be copied to the custom field StartDate__c for validation processing.
                REMOVED 032912
                    -For Updated Events on a Guest Card where the AVB_Associate_First_Last_Name__c field is changed
                        Change AVB_Associate__c on the parent Guest Card to match
                -For specific Events associated with a Guest Card, the Guest Card "Initial Visit" field will be updated to the ActivityDate
                    on the triggering event
                    Criteria for triggering event:
                        Guest Card is parent object
                        Subject_Sub_Category__c == 'Initial Visit'
                        Status__c has just been changed to 'Completed'
                    Criteria for Guest Card:
                        Initial Visit Date = null
                -Also for Completed Initial Visit Events:   
                    Create a new Task
                        same information as triggering Event
                        ActivityDate = TODAY + 2 days
                        Subject_Sub_Category__c = 'Visit Follow up'
    
    Created By:     Jeremy Nottingham (Synaptic) 3/18/2011
    
    Last Modified By:   Jeremy Nottingham (Synaptic) 3/18/2011
    
    Current Version:    v1.0
    
    Revision Log:       v1.0 - (JN 3/18/11) created this header and began dev.
                        v1.1 - (JN 040611) Added StartDate__c copy process and made trigger before insert, before update
                        v1.2 - (JN 032912) Removed logic to change AVB Associate on Guest Card if changed on Event
    
    */
    
    if (Trigger.IsBefore) {
        for (Event e : Trigger.new) {
            if (e.StartDateTime != null) e.StartDate__c = e.StartDateTime.date();
        }
    }
    
    if (Trigger.IsAfter) 
    {
        String GCPreFix = Guest_Card__c.sObjectType.getDescribe().getKeyPrefix();
        
        set<Id> gcids = new set<id>();
        list<Event> affectedevents = new list<Event>();
        list<Event> AVBAssocevents = new list<Event>();
        list<Guest_Card__c> gcstoupdate = new list<Guest_Card__c>();
        map<Id, Guest_Card__c> gcstoupdatemap = new map<Id, Guest_Card__c>();
        
        //Find the Guest Cards to operate on
        for (Event e : Trigger.new) 
        {
            if (e.whatId == null) continue;
            
            Event newevent = Trigger.newmap.get(e.Id);
            Event oldevent;
            if (Trigger.IsUpdate) oldevent = Trigger.oldmap.get(e.Id);
            
            String prefix = (String.valueOf(e.whatId)).substring(0,3);

            if (prefix == GCPreFix)
            {
                gcids.add(e.WhatId);
                
                if ((e.Subject_Sub_Category__c == 'Initial Visit')
                    && (e.Status__c == 'Complete'))
                {
                    if ((Trigger.IsInsert) 
                        || ((Trigger.IsUpdate) 
                            && (newevent.Status__c != oldevent.Status__c) ))
                    {
                        affectedevents.add(e);
                    }
                }
                
                //cjc 11APR12; 
                if ((e.Subject_Sub_Category__c == 'Return Visit')
                    && (e.Status__c == 'Complete'))
                {
                    if ((Trigger.IsInsert) 
                        || ((Trigger.IsUpdate) 
                            && (newevent.Status__c != oldevent.Status__c) ))
                    {
                        affectedevents.add(e);
                    }
                }
                //cjc 11APR12; 
                
            }
        }
        
        if (gcids.size() > 0) 
        {
            map<id, Guest_Card__c> gcid2gcmap = new map<id, Guest_Card__c>([select id, Initial_Visit_Date__c, AVB_Associate__c, ReturnVisitDate__c 
                from Guest_Card__c where Id in :gcids]);
            Id leadrtId = [select Id, Name from Recordtype where SOBjectType = 'Task' and Name = 'Pilot Lead Process' limit 1].id;
            map<Id, Event> gcid2eventmap = new map<Id, Event>();
            list<Task> taskstoinsert = new list<Task>();
            
            /* commented 032912 JN
            for (Event e : Trigger.New) 
            {
                Guest_Card__c gc = gcid2gcmap.get(e.WhatId);
                //Copy changed AVB Associate to GC if no Initial Visit Date on GC
                if ((e.AVB_Associate_First_Last_Name__c != gc.AVB_Associate__c)
                    && (gc.Initial_Visit_Date__c == null))
                {
                    gc.AVB_Associate__c = e.AVB_Associate_First_Last_Name__c;
                    gcstoupdatemap.put(gc.Id, gc);
                    
                    //keep track of list of events for this gc
                    gcid2eventmap.put(gc.Id, e);
                }
                
            }   
            */
            
            //Set Initial Visit Date on GC
            for (Event e : affectedevents) 
            {
                Guest_Card__c gc = gcid2gcmap.get(e.WhatId);
                if (gc.Initial_Visit_Date__c == null) 
                {
                    gc.Initial_Visit_Date__c = e.StartDateTime; //e.StartDate__c; ActivityDate;
                    //gcstoupdate.add(gc);
                    gcstoupdatemap.put(gc.Id, gc);
                
                    //keep track of list of events for this gc
                    gcid2eventmap.put(gc.Id, e);
                    
                    Task followuptask = new Task(
                        RecordtypeId = leadrtId,
                        WhatId = e.WhatId,
                        OwnerId = e.OwnerId,
                        AVB_Associate_First_Last_Name__c = e.AVB_Associate_First_Last_Name__c,
                        ActivityDate = system.today().addDays(2),
                        AVB_Type__c = 'Lead Pursuit Process',
                        Subject_Sub_Category__c = 'Follow-up',
                        Status = 'Not Started');
                    taskstoinsert.add(followuptask);
                        
                }
                
                //cjc 11APR12; default return visit date
                if ((gc.ReturnVisitDate__c == null) && (e.Subject_Sub_Category__c == 'Return Visit'))
                {
                    gc.ReturnVisitDate__c = e.StartDateTime;
                    gcstoupdatemap.put(gc.Id, gc);
                }
                //cjc 11APR12; default return visit date
            }
            
            //Update Database
            if (gcstoupdatemap.size() > 0)
            {
                list<Database.SaveResult> results = Database.update(gcstoupdatemap.values(), false);
                
                // Iterate through the Save Results
                for(Integer i = 0; i < results.size(); i++)
                {
                    Database.SaveResult sr = results[i];
                    if(!results[i].isSuccess())
                    {
                        Id gcid = gcstoupdatemap.values()[i].Id;
                        gcid2eventmap.get(gcid).addError('Unable to update Guest Card: ' + gcid + ': ' + sr.getErrors()[0].getMessage());
                    }
                }
            }
            if (taskstoinsert.size() > 0)
            {
                list<Database.SaveResult> results = Database.insert(taskstoinsert,false);
                
                // Iterate through the Save Results
                for(Integer i = 0; i < results.size(); i++)
                {
                    Database.SaveResult sr = results[i];
                    Task thistask = taskstoinsert[i];
                    if(!sr.isSuccess())
                    {
                        gcid2eventmap.get(thistask.WhatId).addError('Unable to create followup task: ' + sr.getErrors()[0].getMessage());
                    }
                }
            }
            
        } //end if gcids.size() > 0
    } //end if Trigger.IsAfter
}