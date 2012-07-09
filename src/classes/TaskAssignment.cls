public class TaskAssignment {
/*
	Purpose: 	Assign new tasks to users with available task slots and matching task queue field
	
	Created By: 	Jeremy Nottingham (Synaptic) 12/14/2011
	
	Last Modified By: 	Jeremy Nottingham (Synaptic) 12/14/2011
	
	Current Version: 	v1.0
	
	Revision Log:		v1.0 - (JN 12/14/11) created this header and began dev.
	
	*/
	
	//public static Boolean IsTestingTaskAssignment = FALSE;
	public static Boolean IsRunningTaskAssignment = FALSE;
	
@future	
	public static void manageTaskQueues(set<String> taskQueuestoManage)
	{
		list<String> taskqueueList = new list<String> (taskQueuestoManage);
		list<Task> applicableTasks = [select Id, Task_Queue__c 
			from Task 
			where IsClosed = FALSE 
				and Task_Queue__c in :taskQueuestoManage 
				and Task_Assigned__c = FALSE];
		map<Id, Task> taskid2taskmap = new map<Id, Task>( applicableTasks);
		map<String, list<Task>> queue2tasklistmap = new map<String, list<Task>>();
		
		for (Task t : applicableTasks)
		{
			if (queue2tasklistmap.containsKey(t.Task_Queue__c))
			{
				queue2tasklistmap.get(t.Task_Queue__c).add(t);
			}
			else
			{
				queue2tasklistmap.put(t.Task_Queue__c, new list<Task> { t });
			}
		}
system.debug('\n\n131 queue2tasklistmap ' + queue2tasklistmap);		
		String userQuery = 'select Id, Assigned_Task_Queues__c, Max_Assigned_Tasks__c, Current_Assigned_Tasks__c, Available_Assigned_Tasks__c'
			+ ' from User where IsActive = TRUE and Assigned_Task_Queues__c includes (';
			
		for (Integer i = 0; i < taskqueueList.size() ; i++)
		{
			userQuery += '\'' + taskqueueList[i] + '\'';
			if (i < taskqueueList.size() - 1)
				userQuery += ', ';	
		}
		userQuery += ')';
system.debug('\n\n119 userQuery ' + userQuery);		
		list<User> applicableUsers = Database.query(userQuery);
		map<Id, User> userid2usermap = new map<Id, User>(applicableUsers);
		map<String, list<User>> queue2userlistmap = new map<String, list<User>>();
		
		//get accurate totals on open assigned queue tasks for these users
		list<Task> existingTasks = [select Id, OwnerId
			from Task
			where Task_Queue__c != null
				and Task_Assigned__c = TRUE
				and IsClosed = FALSE
				and OwnerId in :userid2usermap.keyset()];
		
		for (Task t : existingTasks)
		{
			User u = userid2usermap.get(t.OwnerId);
			//count up how many tasks are for this particular user
			if (u.Current_Assigned_Tasks__c == null)
				u.Current_Assigned_Tasks__c = 1;
			else
				u.Current_Assigned_Tasks__c ++;
		}
		
		//make lists of which users are for each queue		
		
		for (User u : applicableUsers)
		{
			for (String qname : u.Assigned_Task_Queues__c.split(';'))
			{
				if (queue2userlistmap.containsKey(qname))
				{
					queue2userlistmap.get(qname).add(u);
				}
				else
				{
					queue2userlistmap.put(qname, new list<User> { u });
				}
			}
			
			//update task assignment fields if necessary
			if (u.Current_Assigned_Tasks__c == null)
				u.Current_Assigned_Tasks__c = 0;
			if (u.Max_Assigned_Tasks__c == null)
				u.Max_Assigned_Tasks__c = 0;
			u.Available_Assigned_Tasks__c = u.Max_Assigned_Tasks__c - u.Current_Assigned_Tasks__c;
		}
		
		//Assign tasks out
		set<Id> taskidstoupdate = new set<Id>();
		
		for (String tq : taskQueuestoManage)
		{
			//get tasks for this queue. If none, move on.
			list<Task> queueTasks = queue2tasklistmap.get(tq);
			if (queueTasks.size() > 0)
			{
				//get Users for this queue. If none, move on.
				list<User> queueUsers = queue2userlistmap.get(tq);
				Boolean OutOfUsers = FALSE;
				
				if (queueUsers.size() > 0)
				{
system.debug('\n\n114 queue ' + tq + ' users ' + queueUsers + '\nqueue Tasks ' + queueTasks);				
					Integer userIndex = 0;
					User u; 
					
					for (Task t : queueTasks)
					{
						//assign each task to a new user in the list
						Boolean FoundUser = FALSE;
						Boolean RestartedList = TRUE;
system.debug('\n\n123 t ' + t);						
						//keep looping until we either found a user, or there are no more qualifying users in the list
						while ((FoundUser == FALSE) && (OutOfUsers == FALSE))
						{
system.debug('\n\n127 founduser ' + FoundUser + ' OutOfUsers ' + OutOfUsers + ' restartedlist ' + RestartedList);
							u = queueUsers[userIndex];
system.debug('\n\n129 u ' + u);							
							if (u.Max_Assigned_Tasks__c != null)
							{
								u.Available_Assigned_Tasks__c = u.Max_Assigned_Tasks__c - u.Current_Assigned_Tasks__c;
								
					
								if (u.Available_Assigned_Tasks__c > 0) 
								{
									t.OwnerId = u.Id;
									t.Task_Assigned__c = TRUE;
									taskidstoupdate.add(t.Id);
									
									u.Current_Assigned_Tasks__c  ++;
									u.Available_Assigned_Tasks__c --;
									
									FoundUser = TRUE;
									RestartedList = FALSE;
									break;
								}
							}
							userIndex ++;
							if (userIndex >= queueUsers.size())
							{
								userIndex = 0;
								if (RestartedList = TRUE)
								{
									OutOfUsers = TRUE;
								}
								RestartedList = TRUE;
							}
						} //end while
						
						//if no users available for this task, skip processing the rest of the tasks from this queue 
						if (OutOfUsers)
							break;
					} //end for Task 
				}//end if queueUsers.size() > 0 
			}//end if queueTasks.size() > 0
		}//end for tq : task queues (string)
		
		if (taskidstoupdate.size() > 0)
		{	
			list<Task> taskstoupdate = new list<Task>();
			for (Id taskid : taskidstoupdate)
				taskstoupdate.add(taskid2taskmap.get(taskid));
			IsRunningTaskAssignment = TRUE;
			update taskstoupdate;
		}
		if (applicableUsers.size() > 0)
		{
			IsRunningTaskAssignment = TRUE;
			update applicableUsers;
		}
	}
	
/*	
	public static void closeAssignedTasks(list<Task> tasksclosed)
	{
		//called After Update
		//collect userid set from tasks
		set<Id> userids = new set<Id>();
		for (Task t : tasksclosed)
		{
			userids.add(t.WhoId);
		}
		
		
		//query for Users with Open Tasks
		map<Id, User> usermap = new map<Id, User>([select Max_Assigned_Tasks__c, Current_Assigned_Tasks__c, Available_Assigned_Tasks__c
			from User
			where Id in :userids
				and IsActive = TRUE]);
		
		//get task counts for users
		list<AggregateResult> ars = [select OwnerId, count(Id) taskcount
			from Task
			where OwnerId in :userids
				and IsClosed = FALSE
			group by OwnerId];
		map<Id, Decimal> userid2taskcount = new map<Id, Decimal>();
		//fill map with zeros
		for (Id thisuserid : userids)
		{
			userid2taskcount.put(thisuserid, 0);
		}
		
		//populate map with any non-zero values
		for (AggregateResult ar : ars)
		{
			Id thisuserId = (Id)ar.get('OwnerId');
			userid2taskcount.put(thisuserId, (Decimal)ar.get('taskcount'));		
		}
		
		//Update user current assigned and available fields
		list<User> userstoupdate = new list<User>();
		for (Id userid : userid2taskcount.keyset())
		{
			User queriedUser = usermap.get(userid);
			if (queriedUser != null) 
			{
				queriedUser.Current_Assigned_Tasks__c = userid2taskcount.get(userid);
				queriedUser.Available_Assigned_Tasks__c = queriedUser.Max_Assigned_Tasks__c - queriedUser.Current_Assigned_Tasks__c;
				userstoupdate.add(queriedUser);
			}
		}
		
		//update user list
		if (userstoupdate.size() > 0)
			update userstoupdate;
	}
	
	public static list<Task> assignTasks(list<Task> taskstoassign)
	{
		//Called Before Update
		//collect task queue strings
		set<String> taskqueueset = new set<String>();
		for (Task t : taskstoassign)
		{
			taskqueueset.add(t.Task_Queue__c); 
		}
		
		//query for applicable users with matching queues assigned
		map<Id, User> userid2usermap = new map<Id, User>([select Id, Assigned_Task_Queues__c, Max_Assigned_Tasks__c, Current_Assigned_Tasks__c, Available_Assigned_Tasks__c
			from User
			where Assigned_Task_Queues__c != null
				and Max_Assigned_Tasks__c > 0
				and (Available_Assigned_Tasks__c > 0 or Available_Assigned_Tasks__c = null)
			order by Available_Assigned_Tasks__c desc]);
		list<AggregateResult> ars = [select OwnerId, count(Id) taskcount
			from Task
			where OwnerId in :userid2usermap.keyset()
				and IsClosed = FALSE
			group by OwnerId];
		map<Id, Decimal> userid2taskcount = new map<Id, Decimal>();
		//fill map with zeros
		for (Id thisuserid : userid2usermap.keyset())
		{
			userid2taskcount.put(thisuserid, 0);
		}
		
		//populate map with any non-zero values
		for (AggregateResult ar : ars)
		{
			Id thisuserId = (Id)ar.get('OwnerId');
			userid2taskcount.put(thisuserId, (Decimal)ar.get('taskcount'));		
		}
		
		if (userid2usermap.size() > 0)
		{
			//map task queue to userid, userid 2 user
			map<String, list<Id>> taskQ2userIdsmap = new map<String, list<Id>>();
			for (User u : userid2usermap.values())
			{
				list<String> taskQueues = u.Assigned_Task_Queues__c.split(';');
				for (String qstring : taskQueues)
				{
					//skip this queue if it's not in our tasks
					if (!taskqueueset.contains(qstring)) continue;
					
					if (taskQ2userIdsmap.containsKey(qstring))
					{
						taskQ2userIdsmap.get(qstring).add(u.Id);
					}
					else
					{
						taskQ2userIdsmap.put(qstring,new list<Id>{u.Id});
					}
				}
				
				//make sure user fields are up to date
				u.Current_Assigned_Tasks__c = userid2taskcount.get(u.Id);
				u.Available_Assigned_Tasks__c = u.Max_Assigned_Tasks__c - u.Current_Assigned_Tasks__c;
			}
system.debug('\n\n79 userid2usermap ' + userid2usermap);	
			//assign tasks to users (update WhoId, Assigned Task = TRUE), update user fields (Current Assigned, Available Tasks)
			for (Task t : taskstoassign)
			{
				list<Id> userids = taskQ2userIdsmap.get(t.Task_Queue__c);
				if (userids != null)
				{
					for (Id userid : userids)
					{
						User thisuser = userid2usermap.get(userid);
						if (thisuser.Available_Assigned_Tasks__c > 0)
						{
							t.OwnerId = thisuser.Id;
							t.Task_Assigned__c = TRUE;
							thisuser.Current_Assigned_Tasks__c ++;
							thisuser.Available_Assigned_Tasks__c --;
							continue; //go to next Task
						}
					}
				}
			}
			
			//update user list
			IsRunningTaskAssignment = TRUE;
			update userid2usermap.values();
		} //end if userid2usermap.size() > 0
		
		return taskstoassign;
	}
*/	
}