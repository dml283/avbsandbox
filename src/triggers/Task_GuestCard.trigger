trigger Task_GuestCard on Task (before insert, after insert, after update) {
/*
	Purpose: 	- For Tasks on a Guest Card
					Before
						If Task AVB_Associate_First_Last_Name__c is blank
							update to value from parent Guest Card
					After
						If this is a sent Email, 
							update 'Needs Contact' to false on parent Guest Card
					REMOVED 032912 JN
						If Task AVB_Associate_First_Last_Name__c != Guest Card AVB_Associate__c 
							Update Guest Card to correct value
						
	Created By: 	Jeremy Nottingham (Synaptic) 9/23/2011
	
	Last Modified By: 	Jeremy Nottingham (Synaptic) 3/29/11
	
	Current Version: 	v1.1
	
	Revision Log:		v1.0 - (JN 9/23/11) Created this trigger
						v1.1 - (JN 3/29/11) removed function to update AVB Associate on Guest Card if Task associate value changes
	
	*/
	
	String GCPreFix = Guest_Card__c.sObjectType.getDescribe().getKeyPrefix();
	
	//Guest Card IDs from Task WhatIds
	set<Id> gcids = new set<id>();	
	
	//Collect WhatIds
	for (Task t : Trigger.new)
	{
		String prefix;
		if (t.WhatId != null) 
			prefix = (String.valueOf(t.whatId)).substring(0,3);
		
		//Guest Card
		if (prefix == GCPreFix)
		{
			gcids.add(t.WhatId);
		}
	}
	
	if (Trigger.IsBefore)
	{
		map<Id, Guest_Card__c> gcid2gcmap = new map<Id, Guest_Card__c>([select Id, AVB_Associate__c, Initial_Visit_Date__c
			from Guest_Card__c 
			where Id in :gcids]);
		for (Task t : Trigger.new)
		{
			//If this Task has no AVB Associate at all, fill in from the Guest Card
			if ((gcid2gcmap.containsKey(t.WhatId))
				&& (t.AVB_Associate_First_Last_Name__c == null)
				&& (gcid2gcmap.get(t.WhatId).AVB_Associate__c != null))
			{
				t.AVB_Associate_First_Last_Name__c = gcid2gcmap.get(t.WhatId).AVB_Associate__c;		
			}
		}
	}
	
	
	if (Trigger.IsAfter)
	{
		
		if (gcids.size() > 0)
		{
			//Get Guest Cards to compare AVB Associate names and update if necessary
			map<Id, Guest_Card__c> gcid2gcmap = new map<Id, Guest_Card__c>([
				select Id, AVB_Associate__c, Initial_Visit_Date__c, Needs_Contact__c
				from Guest_Card__c 
				where Id in :gcids]);
			map<Id, Task> gcid2taskmap = new map<Id, Task>();
			map<Id, Guest_Card__c> gcstoupdatemap = new map<Id, Guest_Card__c>();
			for (Task t : Trigger.new)
			{
				if (t.WhatId != null)
				{
					if (gcid2gcmap.containsKey(t.WhatId))
					{
						//Find correct Guest Card to work with
						Guest_Card__c gc = gcid2gcmap.get(t.WhatId);
						if (gcstoupdatemap.containskey(t.WhatId))
							gc = gcstoupdatemap.get(t.WhatId);
							
						/* commented 3/29/12 JN
						//Only update if different name AND no Initial Visit Date
						if ((gc.AVB_Associate__c != t.AVB_Associate_First_Last_Name__c)
							&& (t.AVB_Associate_First_Last_Name__c != null)
							&& (gc.Initial_Visit_Date__c == null))
						{
							gc.AVB_Associate__c = t.AVB_Associate_First_Last_Name__c;
							gcstoupdatemap.put(gc.Id, gc);
							gcid2taskmap.put(gc.Id, t);
						}
						*/
						
						//If Email, update Contact Needed on GC
						if ((t.Subject != null)
							&& (t.Subject.startsWith('Email:'))
							&& (gc.Needs_Contact__c == TRUE))
						{
							
							gc.Needs_Contact__c = FALSE;
							gcstoupdatemap.put(gc.Id, gc);
							gcid2taskmap.put(gc.Id, t);
						}
						
					}
				
				} //end if WhatId != null
			}
			
			if (gcstoupdatemap.size() > 0)
			{
				list<Database.SaveResult> results = Database.update(gcstoupdatemap.values());
				
				// Iterate through the Save Results
				for(Integer i = 0; i < results.size(); i++)
				{
system.debug('\n\n74 gcs ' + gcstoupdatemap.values());
					Database.SaveResult sr = results[i];
					if(!sr.isSuccess())
				   	{
				   		Id gcid = gcstoupdatemap.values()[i].Id;
				   		gcid2taskmap.get(gcid).addError('Unable to update Guest Card ' + gcid + ': ' + sr.getErrors()[0].getMessage());
				   	}
				}
					
			}
		}
	} //end if IsAfter
}