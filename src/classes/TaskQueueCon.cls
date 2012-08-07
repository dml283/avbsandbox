public with sharing class TaskQueueCon {
	list<Task> tasklist; //main list for Task view
	public list<xtask> xtasklist { get; private set; } //wrapper class list for Task view, includes info from attached object records
	
	public list<SelectOption> queueoptions { get; private set; } //filter picklist values
	public String queue { get; set; }
	list<SelectOption> viewoptions; //filter picklist values 
	Integer datefilter; //number from viewoptions
	
	//Sorting
	AP_SortHelper sorter = new AP_SortHelper(); //open source utility class. See SortBy()
	String SortedBy = 'ActivityDate'; //Default
	Boolean sortAscending = true;
	
	public class xtask
	{
		public Task task { set; get; }
		
		public xtask(Task t) { 
			this.task = t; 
		}
	}
	
	public TaskQueueCon()
	{
		//get date view options
		refreshviewoptions();
		datefilter = 8; //all open by default
		
		//get all queues for option list
		refreshqueueoptions(); 
		
		//query for applicable tasks
		refreshtasklist();
	}
	
	private String date2string(Date d)
	{
		String daystr = (d.day() < 10) ? '0' + String.valueof(d.day()) : String.valueof(d.day());
		String monthstr = (d.month() < 10) ? '0' + String.valueof(d.month()) : String.valueof(d.month());
		String properdate = String.valueof(d.year()) + '-' + monthstr + '-' + daystr ;
		return properdate;
	}
	
	
	private void Sort()
	{
		//add accountIDs and Names
		tasklist = (List<Task>) sorter.getSortedList(tasklist,SortedBy, sortAscending);
		tasklist2xtasklist();
	}
	
	private void SortBy(String value) 
	{        
		if (sortedBy == value) {             
			sortAscending = !sortAscending;        
		} else {            
			sortAscending = true;        
		}        
		sortedBy = value;   
		
		Sort();
	}
	
	public String getfilter() { return String.valueof(datefilter); }
	public void setfilter(String df) { 
		datefilter = Integer.valueof(df); 
		refreshtasklist();
	} 
	
	public list<Task> gettasklist() { return tasklist; }
	
	public list<SelectOption> getviewoptions() { return viewoptions; }
	
	public void refreshtasklist()
	{
		String RoleId = '';
		if (UserInfo.getUserRoleId() != null) RoleId = UserInfo.getUserRoleId();
		
		//Added query for only users with same UserRole as current user 040611 JN.
		String query = 'select OwnerId, Owner.Alias, Owner.Name, Subject_Sub_Category__c, Status, ActivityDate, CreatedDate, AVB_Type__c,' 
			+ ' AVB_Associate_First_Last_Name__c, AVB_Account_ID__c, AccountID, Account.Name, What.Name, What.Type, Task_Queue__c, Subject, Task_Assigned__c'
			+ ' from Task'
			+ ' where isClosed = FALSE and Task_Queue__c != null';

		if (datefilter == 1) { //Overdue
			query += ' and ActivityDate < ' + date2string(system.today());
		} else if (datefilter == 2) { //Today
			query += ' and ActivityDate = ' + date2string(system.today());
		}else if (datefilter == 3) { //Today + Overdue
			query += ' and ActivityDate <= ' + date2string(system.today());
		}else if (datefilter == 4) { //Tomorrow
			query += ' and ActivityDate = ' + date2string(system.today().addDays(1));
		}else if (datefilter == 5) { //Next 7 Days
			query += ' and ActivityDate < ' + date2string(system.today().addDays(7)) + ' and ActivityDate >= ' + date2string(system.today());
		}else if (datefilter == 6) { //Next 7 Days + Overdue
			query += ' and ActivityDate < ' + date2string(system.today().addDays(7));
		}else if (datefilter == 7) { //This Month
			query += ' and ActivityDate >= ' + date2string(system.today().toStartOfMonth()) + ' and ActivityDate <= ' + date2string(system.today().addMonths(1).toStartOfMonth());
		}
		
		if ((queue != 'All') && (queue != null))
		{
			query += ' and Task_Queue__c = \'' + queue + '\'';
		}
		
		//get list from query
		tasklist = Database.query(query);
		
		//sort list as necessary
		Sort();
		
		//make full xtask list
		tasklist2xtasklist();
	}
	
	private void tasklist2xtasklist()
	{
		//build a list of xtasks from tasklist
		xtasklist = new list<xtask>();
		
		//populate xtasklist
		for (Task t : tasklist) {
			xtasklist.add(new xtask(t));
		}
	}
	
	public PageReference changefilter()
	{
		refreshtasklist();
		PageReference pr = null;
		return pr;
	}
	
	public PageReference clearfilters()
	{
		changefilter();
		
		PageReference pr = null;
		return pr;
	}

	public PageReference SortbyDate()
	{
		SortBy('ActivityDate');
		return null;
	}
	
	public PageReference SortbyCreatedDate()
	{
		SortBy('CreatedDate');
		return null;
	}
	
	public PageReference SortbyOwner()
	{
		SortBy('Owner.Name');
		return null;
	}
	
	public PageReference SortbyStatus()
	{
		SortBy('Status');
		return null;
	}
	
	public PageReference SortbyQueue()
	{
		SortBy('Task_Queue__c');
		return null;
	}
	
	public PageReference SortbyAssigned()
	{
		SortBy('Task_Assigned__c');
		return null;
	}
	
	public PageReference SortbySubCat()
	{
		SortBy('Subject_Sub_Category__c');
		return null;
	}
	
	public PageReference SortbySubject()
	{
		SortBy('Subject');
		return null;
	}

	private void refreshviewoptions()
	{
		viewoptions = new list<SelectOption>();
		viewoptions.add(new SelectOption('1','Overdue'));
		viewoptions.add(new SelectOption('2','Today'));
		viewoptions.add(new SelectOption('3','Today + Overdue'));
		viewoptions.add(new SelectOption('4','Tomorrow'));
		viewoptions.add(new SelectOption('5','Next 7 Days'));
		viewoptions.add(new SelectOption('6','Next 7 Days + Overdue'));
		viewoptions.add(new SelectOption('7','This Month'));
		viewoptions.add(new SelectOption('8','All Open'));
	}
	  
	private void refreshqueueoptions()
	{
		queueoptions = new list<SelectOption>();
		set<String> queueset = new set<String>();
		user thisUser = [select Id, Managed_Task_Queues__c, Profile.Name from User where Id = :Userinfo.getUserId()];
		for (AggregateResult ar : [select Task_Queue__c 
			from Task 
			where Task_Queue__c != null 
				and IsClosed = FALSE 
			group by Task_Queue__c])
		{
			queueset.add((String)ar.get('Task_Queue__c'));
		}
		
		list<String> queuelist = new list<String>(queueset);
		queuelist.sort();
		
		queueoptions.add(new SelectOption('All', 'All'));
		for (String q : queuelist) 
		{
			if ((thisUser.Profile.Name == 'System Administrator')
				|| ((thisUser.Managed_Task_Queues__c != null) && (thisUser.Managed_Task_Queues__c.contains(q))))
			{
				queueoptions.add(new SelectOption(q, q));
			}
		}
		queue = 'All';
	}
	
	/*
		Unit Testing Section
	*/	
	
	static testmethod void testTaskQueueCon()
	{
		Date testdate1 = Date.newInstance(2010, 6, 22);
		Date testdate2 = Date.newInstance(2010, 11, 3);
		User adminUser = [select Id from User where IsActive = TRUE and Profile.Name = 'System Administrator' limit 1];
		User u = [select id, UserRoleId from User where IsActive = true limit 1];
		system.runAs(adminUser)
		{
			if (u.UserRoleId == null) {
				u.UserRoleId = [select id from UserRole limit 1].id;
				update u;
			}
		}
		map<id, User> allusermap = new map<id, User>([select id from User where UserRoleId = :u.UserRoleId]);
		Integer comparecount = [select count() from Task where IsClosed = false and OwnerId in :allusermap.keyset() limit 100]; //Id to OwnerId
		
		list<Task> testtasks = new list<Task>();
		testtasks.add(new Task(
			ActivityDate = system.today().addDays(-1), 
			Status = 'In Progress', 
			AVB_Associate_First_Last_Name__c = 'Assoc A', 
			OwnerID = u.id, 
			AVB_Type__c = 'Move In Process', 
			Subject_Sub_Category__c = 'Avalon Access',
			Task_Queue__c = 'Task Queue 1' 
			));
		testtasks.add(new Task(
			ActivityDate = system.today().addDays(1), 
			Status = 'Not Started', 
			AVB_Associate_First_Last_Name__c = 'Assoc Z', 
			OwnerID = u.id, 
			AVB_Type__c = 'Move In Process', 
			Subject_Sub_Category__c = 'Send Letter',
			Task_Queue__c = 'Task Queue 2'  
			));
		insert testtasks;
		
test.startTest();		
		System.runAs(u) {
			TaskQueueCon t = new TaskQueueCon();
			
			String datestring1 = t.date2string(testdate1);
			String datestring2 = t.date2string(testdate2);
			system.assertEquals('2010-06-22', datestring1);//test single digit month
			system.assertEquals('2010-11-03', datestring2);//test single digit day
			
			list<SelectOption> testviewoptions = t.getviewoptions();
			system.assertEquals(8,testviewoptions.size());//got list of options
			
			t.setfilter('1');
			t.setfilter('2');
			t.setfilter('3');
			String testfilter = t.getfilter();
			t.setfilter('4');
			t.setfilter('5');
			t.setfilter('6');
			t.setfilter('7');
			t.setfilter('8');
			system.assertEquals('3',testfilter);//storing filter properly
			
			list<Task> fulllist = t.gettasklist();
			system.assertEquals(2, fulllist.size());//got full tasklist
			
			t.queue = 'Task Queue 1';
			t.refreshtasklist();
			
			fulllist = t.gettasklist();
			system.assertEquals(1, fulllist.size());//got full filtered tasklist
			
			t.tasklist = new list<Task>();
			Task newt = new Task(Subject = 'newtask');
			t.tasklist.add(newt);
			t.tasklist2xtasklist();
			system.assertEquals(newt.Subject, t.xtasklist[0].task.Subject);
			
			system.assertEquals(null, t.changefilter());
			system.assertEquals(null, t.clearfilters());
			
		} //end runAs
			
	test.stopTest();
	}
	
	static testmethod void testsorts()
	{
		Profile commprof = [select id from Profile where Name = 'Pilot Community' limit 1];
		Id uroleid = [select Id from UserRole limit 1].id;
		list<User> testusers = new list<User>();
		for (Integer i = 1; i < 3; i++) {
			//get Community Profile user
			user u = new User(
				alias = 'tuser', 
	        	email='standarduser@example.com', 
	            emailencodingkey='UTF-8', 
	            lastname='Testing', 
	            languagelocalekey='en_US', 
	            localesidkey='en_US', 
	            ProfileId = commprof.id,
			    timezonesidkey='America/Los_Angeles', 
			    UserRoleId = uroleid,
	            username='testuser7844584552' + i + '@example.com',
	            Department = 'RS Community',
	            Managed_Task_Queues__c = 'Task Queue 1;Task Queue 2'
	            );
			testusers.add(u);
		} 
		
		User adminuser = [select Id from User where Profile.Name = 'System Administrator' and IsActive = true limit 1];
		system.runAs(adminuser)
		{
			insert testusers;
		}
		//[select id from User where IsActive = true and ProfileId = :commprof.id limit 2];
		
		Account acc = new Account(Name = 'testacc', OwnerID = testusers[0].id);
		insert acc;
		Case c = new Case(Subject = 'testcase', OwnerId = testusers[0].id);
		insert c;
		
		list<Contact> sortcontacts = new list<Contact>();
		sortcontacts.add(new Contact(AccountID = acc.id, LastName = 'testcontacta'));
		sortcontacts.add(new Contact(AccountID = acc.id, LastName = 'testcontactz'));
		insert sortcontacts;
		
		list<Task> sorttasks = new list<Task>();
		sorttasks.add(new Task(
			whoid = sortcontacts[0].id, 
			WhatId = acc.id, 
			ActivityDate = system.today().addDays(-1), 
			Status = 'In Progress', 
			AVB_Associate_First_Last_Name__c = 'Assoc A', 
			OwnerID = testusers[0].id, 
			AVB_Type__c = 'Move In Process', 
			Subject_Sub_Category__c = 'Avalon Access',
			Task_Queue__c = 'Task Queue 1' 
			));
		sorttasks.add(new Task(
			whoid = sortcontacts[1].id, 
			WhatId = c.id, 
			ActivityDate = system.today().addDays(1), 
			Status = 'Not Started', 
			AVB_Associate_First_Last_Name__c = 'Assoc Z', 
			OwnerID = testusers[1].id, 
			AVB_Type__c = 'Move In Process', 
			Subject_Sub_Category__c = 'Send Letter',
			Task_Queue__c = 'Task Queue 2'  
			));
		insert sorttasks;
		
		PageReference ref;		
test.starttest();
		TaskQueueCon tc = new TaskQueueCon();
		
system.debug('\n\ntasklist ' + tc.gettasklist());
		
		
		//starts out sorted by date ascending
		system.assertEquals(null, tc.SortByDate()); //should be descending
		system.assertEquals(null, tc.SortByOwner());
		system.assertEquals(null, tc.SortByCreatedDate());
		system.assertEquals(null, tc.SortbyStatus());
		system.assertEquals(null, tc.SortbyQueue());
		system.assertEquals(null, tc.SortbySubject());
		system.assertEquals(null, tc.SortBySubCat()); //reverse sort
		
test.stoptest();
		
	}
	
}