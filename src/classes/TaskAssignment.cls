public class TaskAssignment {
/*
	Purpose: 	Assign new tasks to users with available task slots and matching task queue field
	
	Created By: 	Jeremy Nottingham (Synaptic) 12/14/2011
	
	Last Modified By: 	Jeremy Nottingham (Synaptic) 12/14/2011
	
	Current Version: 	v1.0
	
	Revision Log:		v1.0 - (JN 12/14/11) created this header and began dev.
	
	*/
	
	public static Boolean IsTestingTaskAssignment = FALSE;
	
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
			update userid2usermap.values();
		} //end if userid2usermap.size() > 0
		
		return taskstoassign;
	}
	
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
	
	public static void assignAllTasks()
	{
		//query for all open tasks without Assignment
		//query for matching users with available tasks
		//map task queue to userid, userid 2 user
		//assign tasks to users, update user fields
		//update Tasks
		//update user list
		
	}
}