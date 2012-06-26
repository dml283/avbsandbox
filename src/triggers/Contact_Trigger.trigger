trigger Contact_Trigger on Contact (after insert) {
	/*
	Purpose: 	When a Contact is inserted with Primary_Contact__c == TRUE
					Look for Guest Card on Account. If found
						Populate Guest Card with Contact ID
	
	Created By: 	Jeremy Nottingham (Synaptic) 9/30/11
	
	Last Modified By: 	Jeremy Nottingham (Synaptic) 9/30/11
	
	Current Version: 	v1.0
	
	Revision Log:		v1.0 - (JN) Created this trigger and header. Begin dev.
						
	*/
	
	if (Trigger.IsAfter)
	{
		set<id> primarycgids = new set<Id>();
		system.debug(primarycgids);
		
		map<Id, Contact> accid2conmap = new map<Id, Contact>();
		map<Id, Contact> gcid2conmap = new map<Id, Contact>();
		
		for (Contact con : Trigger.new)
		{
			if (con.Primary_Contact__c)
			{
				primarycgids.add(con.AccountId);
				accid2conmap.put(con.AccountId, con);
			}
		}
		system.debug(primarycgids);
		if (primarycgids.size() > 0)
		{
			list<Guest_Card__c> gcs = [select Id, Prospect_Account__c, Contact__c
				from Guest_Card__c
				where Prospect_Account__c in :primarycgids];
			for (Guest_Card__c gc : gcs)
			{
				gc.Contact__c = accid2conmap.get(gc.Prospect_Account__c).Id;
				gcid2conmap.put(gc.Id, accid2conmap.get(gc.Prospect_Account__c));
			}
			
			list<Database.saveResult> results = database.update(gcs);
			
			for(Integer i = 0; i < results.size(); i++)
			{ 
				Database.saveResult sr = results[i];
				if(!sr.isSuccess())
			   	{
			   		gcid2conmap.get(gcs[i].Id).addError('Unable to update Guest Card: ' + gcs[i].Id + ': ' + sr.getErrors()[0].getMessage());
			   	}
			}
		}
		
	} //end if IsAfter
}