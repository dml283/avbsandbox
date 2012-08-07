trigger User_Trigger on User (after insert, after update) {
	/*
	Purpose: 	Manage Task Queues
					If User is removed from a Task Queue
					If User is added to a Task Queue
	
	Created By: 	Jeremy Nottingham (Synaptic) 7/5/12
	
	Last Modified By: 	Jeremy Nottingham (Synaptic) 7/5/12
	
	Current Version: 	v1.0
	
	Revision Log:		v1.0 - (JN) Created this trigger and header. Begin dev.
						
	*/ 
	
	if (Trigger.IsAfter)
	{
		list<User> taskQueueUsers = new list<User>();
		set<String> taskQueuestoCheck = new set<String>();
		set<Id> useridstocheckQueues = new set<Id>();
		for (User u : Trigger.new)
		{
			User olduser;
			if (Trigger.IsUpdate)
				olduser = Trigger.oldmap.get(u.Id);
				
			if ((!TaskAssignment.IsRunningTaskAssignment)
				&& ((Trigger.IsInsert) 
				|| (u.IsActive != olduser.IsActive)
				|| (u.Assigned_Task_Queues__c != olduser.Assigned_Task_Queues__c)))
			{
				//get all Task Queues that may be affected
				if (u.Assigned_Task_Queues__c != null)
				{
					taskQueuestoCheck.addall(u.Assigned_Task_Queues__c.split(';'));
					useridstocheckQueues.add(u.Id);
				}
				if ((Trigger.IsUpdate) && (olduser.Assigned_Task_Queues__c != null))
				{
					taskQueuestoCheck.addall(olduser.Assigned_Task_Queues__c.split(';'));
					useridstocheckQueues.add(u.Id);
				}
			}  
		}
		
		//if ((taskQueuestoCheck.size() > 0) && (!TaskAssignment.IsRunningTaskAssignment))
		//	TaskAssignment.manageTaskQueues(taskQueuestoCheck);
		if (useridstocheckQueues.size() > 0)
			TaskAssignment.manageTaskQueuesonUser(useridstocheckQueues);
		
		
	}
	
}