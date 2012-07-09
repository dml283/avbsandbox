trigger Task_Queues on Task (before insert, before update) {
	/*
	Purpose: 	Manage Task Queues
					Before Insert
						If Task has a Task Queue assigned
							If it has been assigned to a User already
							If Status has changed to 'Complete'
					Before Update
						If Task has had Task Queue field changed
						
	
	Created By: 	Jeremy Nottingham (Synaptic) 7/5/12
	
	Last Modified By: 	Jeremy Nottingham (Synaptic) 7/5/12
	
	Current Version: 	v1.0
	
	Revision Log:		v1.0 - (JN) Created this trigger and header. Begin dev.
						
	*/
 
}