trigger Task_Queues on Task (after insert, after update, after delete) {
	/*
	Purpose: 	Manage Task Queues
					After 
						If Task has a Task Queue assigned and has not been assigned already and is not closed
							run manageTaskQueues in future						
	
	Created By: 	Jeremy Nottingham (Synaptic) 7/11/12
	
	Last Modified By: 	Jeremy Nottingham (Synaptic) 7/11/12
	
	Current Version: 	v1.0
	
	Revision Log:		v1.0 - (JN) Created this trigger and header. Begin dev.
						
	*/
	
	if (Trigger.IsAfter)
	{
		set<String> taskqueuestomanage = new set<String>();
		list<Task> triggertasks = (Trigger.IsDelete) ? Trigger.old : Trigger.new;
		for (Task t : triggertasks)
		{
			Task oldtask = (Trigger.IsUpdate) ? Trigger.oldmap.get(t.Id) : new Task();
			//if this is an open queue task requiring assignment, or an assigned queue task that is closed, manage the queue
			if ((t.Task_Queue__c != null)
				&& ((t.Task_Assigned__c == FALSE) && (t.IsClosed == FALSE))
					|| ((t.Task_Assigned__c == TRUE) && (t.IsClosed == TRUE))) 
			{
				taskqueuestomanage.add(t.Task_Queue__c);
			}
		}
		
		if ((taskqueuestomanage.size() > 0) && (TaskAssignment.IsRunningTaskAssignment == FALSE))
			TaskAssignment.manageTaskQueues(taskqueuestomanage);
	}
}