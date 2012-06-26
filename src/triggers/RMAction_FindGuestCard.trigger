trigger RMAction_FindGuestCard on RMACTION__c (before insert, after insert) {
	/*
	Purpose: 	When a new RMAction__c record is created, 
					Before:
						it will be associated with the MRI (non-Shared) Guest Card record on the parent Customer Group Account
					After:
						Fields will be modified on the associated Guest Card according to the RMAction Type field:
							If ActCode__c = guest card details (GC)		then	enter comments into Guest_Card_Details__c on guest card
							if ActCode__c = appointment (AT)			then	create "Initial Visit" event to schedule event for appointment
							if ActCode__c = Walk In (WI	)				then	create Complete "Initial Visit" event for system.now() for walk in visit
							
							else									 	add description into Initial_Lead_Type__c on Guest Card
	
	Created By: 	Jeremy Nottingham (Synaptic) 3/15/11
	
	Last Modified By: 	Jeremy Nottingham (Synaptic) 5/3/11
	
	Current Version: 	v1.4
	
	Revision Log:		v1.0 - (JN) Created this trigger and header. Begin dev.
						v1.1 - (JN 4/20/11) Added complex logic functions for field updates and task creation on parent GC
							 - New logic runs in "After Insert"
						v1.2 - (JN 5/3/11) Change Initial Follow Up Task to Initial Visit Event being created
						v1.3 - (JN 6/6/11) Add updating the "Level One Appointment Created" checkbox on Guest Card
						v1.4 - (JN 9/28/11) Add walk in function
	*/
	
	if (Trigger.IsBefore) {
		//Get Accounts for these RMActions
		set<id> accids = new set<id>();
		
		for (RMAction__c rma : Trigger.New) {
			//Always skip if there is no Account value
			if (rma.Account__c != null) {
				accids.add(rma.Account__c);
			}
		}
		map<id, Account> cgid2cgmap = new map<id, Account>([select id,
			(select id, Level_One_Appointment_Created__c from Guest_Cards__r where Shared__c = 'No')
			from Account 
			where id in :accids]);
		
		//Assign Guest Card ids to RMActions		
		for (RMAction__c rma : Trigger.new) {
			if (rma.Account__c != null) {
				//Make sure there is a Guest Card to use
				if (cgid2cgmap.get(rma.Account__c).Guest_Cards__r.size() > 0)
					rma.Guest_Card__c = cgid2cgmap.get(rma.Account__c).Guest_Cards__r[0].id;
			}
		}
	} // end IsBefore
	
	if (Trigger.IsAfter) {
		list<Event> newevs = new list<Event>();
		
		//Get Guest Cards
		set<id> gcids = new set<id>();
		for (RMAction__c rma : Trigger.new) {
			if (rma.Guest_Card__c != null) gcids.add(rma.Guest_Card__c);
		}
		map<id, Guest_Card__c> gcid2gcmap = new map<id, Guest_Card__c>([
			select Id, Level_One_Appointment_Created__c, Initial_Lead_Type__c, Guest_Card_Details__c, OwnerId, AVB_Associate__c 
			from Guest_Card__c 
			where id in :gcids]);
		
		//Go through RMAs and perform field updates as necessary and keep track of necessary tasks to close.
		set<id> gcidstoupdate = new set<Id>();
		set<id> emailgcids = new set<Id>();
		
		for (RMAction__c rma : Trigger.new) {
			//skip if we don't have the guest card for this rma
			if ((rma.Guest_Card__c == null) || (!gcid2gcmap.containsKey(rma.Guest_Card__c))) continue;
			
			Guest_Card__c thisgc = gcid2gcmap.get(rma.Guest_Card__c);
			if (rma.ActCode__c == 'GC') {
				String details = rma.ActDescription__c;
				if (thisgc.Guest_Card_Details__c != null) 
					details = thisgc.Guest_Card_Details__c + ' ' + details;
				
				gcid2gcmap.get(rma.Guest_Card__c).Guest_Card_Details__c = details;
				gcidstoupdate.add(rma.Guest_Card__c);
			} 
			else if (rma.ActCode__c == 'AT') {
			//Make a Salesforce Event to correspond to the MRI Appointment RM Action
				Guest_Card__c gc = gcid2gcmap.get(rma.Guest_Card__c);
				newevs.add(new Event(
					OwnerId = gc.OwnerId,
					AVB_Type__c = 'Lead Pursuit Process',
					Subject_Sub_Category__c = 'Initial Visit',
					StartDateTime = rma.ActDate__c,
					EndDateTime = rma.ActDate__c.addHours(1),
					AVB_Associate_First_Last_Name__c = gc.AVB_Associate__c,
					WhatId = rma.Guest_Card__c
					));
				
				//Level One Appointment checkbox checked
				gc.Level_One_Appointment_Created__c = True;
				gcidstoupdate.add(gc.id);
			} 
			else if (rma.ActCode__c == 'EM'){
				thisgc.Initial_Lead_Type__c = 'Email';
				thisgc.Rating__c = 'Warm';
				gcidstoupdate.add(rma.Guest_Card__c);
			} 
			else if (rma.ActCode__c == 'PH'){
				thisgc.Initial_Lead_Type__c = 'Call';
				gcidstoupdate.add(rma.Guest_Card__c);
			} 
			else if (rma.ActCode__c == 'IT'){
				thisgc.Initial_Lead_Type__c = 'Internet';
				gcidstoupdate.add(rma.Guest_Card__c);
			} 
			else if (rma.ActCode__c == 'WI'){
				//Make a Salesforce Event to correspond to the walk-in visit
				Guest_Card__c gc = gcid2gcmap.get(rma.Guest_Card__c);
				newevs.add(new Event(
					OwnerId = gc.OwnerId,
					AVB_Type__c = 'Lead Pursuit Process',
					Subject_Sub_Category__c = 'Initial Visit',
					Status__c = 'Complete',
					StartDateTime = system.now().addHours(-1),
					EndDateTime = system.now(),
					AVB_Associate_First_Last_Name__c = gc.AVB_Associate__c,
					WhatId = rma.Guest_Card__c
					));
			
				thisgc.Initial_Lead_Type__c = 'Walk In';
				gcidstoupdate.add(rma.Guest_Card__c);
			}
		}
		
		//Update Guest Cards that had field updates
		list<Guest_Card__c> gcstoupdate = new list<Guest_Card__c>();
		for (Id gcid : gcidstoupdate) {
			gcstoupdate.add(gcid2gcmap.get(gcid));
		}
		if (gcstoupdate.size() > 0) update gcstoupdate;
		
		//Insert new Events as necessary
		if (newevs.size() > 0) insert newevs;
		
	} //end IsAfter
}