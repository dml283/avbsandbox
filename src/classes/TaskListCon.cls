public with sharing class TaskListCon {
	list<Task> tasklist; //main list for Task view
	list<xtask> xtasklist; //wrapper class list for Task view, includes info from attached object records
	
	list<SelectOption> viewoptions; //filter picklist values
	Integer datefilter; //number from viewoptions
	public String AVBAssociateFilter {get; set; } //from page
	public String SubCategoryFilter {get; set; } //from page
	String listType; //from URL parameter: determines if this is a MIMO list, lead list, etc
	Task_View_Settings__c currentprefs; //personal view preferences
	
	set<id> communityProfileIds = new set<id>();
	
	set<String> mimotypes = new set<String>{'Move In Process','Move In Process-Manual','Move Out Process','Move Out Process-Manual'};
	
	//Sorting
	AP_SortHelper sorter = new AP_SortHelper(); //open source utility class. See SortBy()
	String SortedBy = 'ActivityDate'; //Default
	Boolean sortAscending = true;
	
	//Pagination
	public Boolean Pagination { get; private set; }
	Integer MaxLinesPerPage = 5; //optimized for paginated Home Page component
	public Integer TotalPages { get; set; } 
	public Integer CurrentPage { get; set; }
	//map<Integer, list<Task>> pagelistmap = new map<Integer, list<Task>>();
	map<Integer, list<xtask>> pagextasklistmap = new map<Integer, list<xtask>>();
	
	public class xtask
	{
		public Task task { set; get; }
		public Guest_Card__c gc { get; set; }
		public ID AccountID { get; set; }
		public String AccountName { get; set; }
		public String gcRating { get; set; }
		
		public xtask(Task t) { 
			this.task = t; 
		}
			
	}
	
	public TaskListCon()
	{
		//What kind of tasks are we pulling?
		if (ApexPages.CurrentPage().getParameters().get('listtype') != null)
			listType = ApexPages.CurrentPage().getParameters().get('listtype');
			
		//Should we be paginating our list?
		if ((ApexPages.CurrentPage().getParameters().get('paginate') != null)
			&& (ApexPages.CurrentPage().getParameters().get('paginate') == '1'))
		{
			Pagination = True;
		} else {
			Pagination = false;
		}
			
		list<Profile> communityProfiles = [select id, Name from Profile 
			where Name = 'Community' or Name = 'Pilot Community' or Name = 'Pilot Community Management'];
system.debug('\n\n45 profiles ' + communityProfiles);
		for (Profile p : communityProfiles) 
			communityProfileIds.add(p.id);
	
		refreshprefs();
		refreshviewoptions(); 
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
		if (sortedBy == 'Rating') {
			//sort xtasklist in place
			list<xtask> newxtasklist = new list<xtask>();
			list<String> sortorder = new list<String>();
			if (!sortAscending) {
				sortorder.add('Hot');
				sortorder.add('Warm');
				sortorder.add('Future');
			} else {
				sortorder.add('Future');
				sortorder.add('Warm');
				sortorder.add('Hot');
			}
			
			for (String s : sortorder) {
				for (xtask xt : xtasklist) {
					if (xt.gcRating == s) newxtasklist.add(xt);
				}
			}
system.debug('\n\n113 ');		
			xtasklist = newxtasklist;
		} else {
			//add accountIDs and Names
			tasklist = (List<Task>) sorter.getSortedList(tasklist,SortedBy, sortAscending);
			tasklist2xtasklist();
		}
		
		
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
		
		if (Pagination) {
			Paginate();
			//reset to first page on sort
			CurrentPage = 1;
		}
	}
	
	public String getfilter() { return String.valueof(datefilter); }
	public void setfilter(String df) { 
		datefilter = Integer.valueof(df); 
		refreshtasklist();
	}
	
	public list<Task> gettasklist() { return tasklist; }
	
	public list<SelectOption> getviewoptions() { return viewoptions; }
	
	public void refreshprefs()
	{
		currentprefs = Task_View_Settings__c.getvalues(System.UserInfo.getUserId());
		//if no prefs already, create new
        if(currentprefs == null) currentprefs = new Task_View_Settings__c(setupOwnerId = System.Userinfo.getUserId());
        //set to "all open tasks"(8) by default if not already set 
        datefilter = (currentprefs.View_Filter__c == null) ? 8 : currentprefs.View_Filter__c.intValue(); 
        
        AVBAssociateFilter = currentprefs.AVB_Associate_Filter__c; 
        
        /* Removed 040611. This will put the same filter on both kinds of task lists if we save it with the user. JN
        SubCategoryFilter = currentprefs.SubCategory_Filter__c; 
        */
    }
	
	public void refreshtasklist()
	{
		String RoleId = '';
		if (UserInfo.getUserRoleId() != null) RoleId = UserInfo.getUserRoleId();
		
		//Added query for only users with same UserRole as current user 040611 JN.
		String query = 'select Who.Email, Who.Phone, Who.Name, WhoId, Owner.Alias, Owner.Name, Subject_Sub_Category__c, Status, ActivityDate, AVB_Type__c,' 
			+ ' AVB_Associate_First_Last_Name__c, AVB_Account_ID__c, AccountID, Account.Name, What.Name, What.Type from Task'
			+ ' where IsClosed = false and Owner.UserRoleId = \'' + RoleId + '\'';
		
		if (listType != null) {
			if (listType.equalsignoreCase('mimo')) {
				//Modified 5/4/11 JN
				//query += ' and AVB_Type__c in :mimotypes';
				query += ' and What.Type != \'Guest_Card__c\'';
			} else if (listType.equalsignoreCase('lead')) {
				query += ' and What.Type = \'Guest_Card__c\'';
			}
		}
		
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
		
		if ((AVBAssociateFilter != null) && (AVBAssociateFilter.length() > 0)) {
			query += ' and AVB_Associate_First_Last_Name__c like \'%' + AVBAssociateFilter + '%\'';
		}
		
		if ((SubCategoryFilter != null) && (SubCategoryFilter.length() > 0)) {
			query += ' and Subject_Sub_Category__c like \'%' + SubCategoryFilter + '%\'';
		}
		
		query += ' limit 100';
system.debug('\n\nquery string ' + query);		
		
		//get list from query
		tasklist = Database.query(query);
		
system.debug('\n\nafterquery jeremy ' + tasklist);		
		//sort list as necessary
		Sort();
		
		//make full xtask list
		tasklist2xtasklist();
		
		if (Pagination) Paginate();
		
		//save current preferences
		currentprefs.View_Filter__c = datefilter; 
		/* Removed 040611 JN
		currentprefs.SubCategory_Filter__c = SubCategoryFilter;
        */ 
        currentprefs.AVB_Associate_Filter__c = AVBAssociateFilter; 
        
	}
	
	private void tasklist2xtasklist()
	{
		//build a list of xtasks from tasklist
		xtasklist = new list<xtask>();
		
		//get WhatIDs here. we'll report AccountName and AccountID whichever kind of Case it is.
		set<id> caseids = new set<id>();
		set<id> accids = new set<id>();
		set<id> gcids = new set<id>();
		
		//collect ID sets and populate xtasklist
		for (Task t : tasklist) {
			if (t.What.Type == 'Case') caseids.add(t.What.ID);
			if (t.What.Type == 'Account') accids.add(t.What.ID);
			if (t.What.Type == 'Guest_Card__c') gcids.add(t.What.Id);
			xtasklist.add(new xtask(t));
		}
		
		//go through and get What records in handy maps
		map<id, Case> idcasemap = new map<id, Case>();
		map<id, Account> idaccmap = new map<id, Account>();
		map<id, Guest_Card__c> idgcmap = new map<id, Guest_Card__c>();
		
		if (caseids.size() > 0) idcasemap = new map<id, Case>([select id, AccountID, Account.Name from Case where ID in :caseids limit 200]);
		if (accids.size() > 0) 	idaccmap = new map<id, Account>([select id, Name from Account where ID in :accids limit 200]);
		if (gcids.size() > 0)	idgcmap = new map<id, Guest_Card__c>([select id, Name, Prospect_Account__c, Prospect_Account__r.Name, 
			Rating__c, Class_ID__c, Community__c, Community__r.Name, Level_One_Appointment_Created__c
			from Guest_Card__c where ID in :gcids limit 200]);
		
		//Fill in AccountID and AccountName in xtasklist
		for (xtask xt : xtasklist) {
			//Case
			if (idcasemap.get(xt.task.WhatID) != null) {
				xt.AccountID = idcasemap.get(xt.task.WhatID).AccountID;
				xt.AccountName = idcasemap.get(xt.task.WhatID).Account.Name;
			}
			//Account
			else if (idaccmap.get(xt.task.WhatID) != null) {
				xt.AccountID = idaccmap.get(xt.task.WhatID).ID;
				xt.AccountName = idaccmap.get(xt.task.WhatID).Name;
			}
			//Guest Card. Notice that Account Id actually points to the Guest Card Id
			else if (idgcmap.get(xt.task.WhatID) != null) {
				xt.AccountID = xt.task.WhatID;
				
				xt.gc = idgcmap.get(xt.task.WhatID);
				xt.AccountName = xt.gc.Name;
				xt.gcRating = xt.gc.Rating__c;
			}
		}//for xt
	}
	
	public PageReference changefilter()
	{
		refreshtasklist();
		
		//save filter preferences
		if (currentprefs.id == null) { 
			//Check to see if there are preferences out there for this user, even though there weren't at the beginning of this session.
			Task_View_Settings__c otherprefs = Task_View_Settings__c.getvalues(System.UserInfo.getUserId());
			if (otherprefs == null) {
				insert currentprefs;
			} else {
				otherprefs.AVB_Associate_Filter__c = currentprefs.AVB_Associate_Filter__c;
				otherprefs.View_Filter__c = currentprefs.View_Filter__c;
				update otherprefs;
			}
		} else {
			update currentprefs;
		}
		PageReference pr = null;
		return pr;
	}
	
	public PageReference clearfilters()
	{
		//Clear AVB Associate and Sub Category Filters, then refresh the page
		AVBAssociateFilter = null;
		SubCategoryFilter = null;
		changefilter();
		
		PageReference pr = null;
		return pr;
	}

	private void Paginate()
	{
		//initialize map and indexes
		pagextasklistmap = new map<Integer, list<xtask>>();
		Integer page = 1;
		pagextasklistmap.put(page,new list<xtask>());
		Integer linesthispage = 0;
system.debug('\n\n308 xtasklist size ' + xtasklist.size());	
		for (Integer i = 0; i < xtasklist.size(); i++) {
			//add task to this page's list
			pagextasklistmap.get(page).add(xtasklist[i]);
			
			linesthispage++;
			if (linesthispage == MaxLinesPerPage) { //That was the last line on this page
				linesthispage = 0;
				page++;
				pagextasklistmap.put(page,new list<xtask>());
			}
		}
		TotalPages = (linesthispage == 0) ? (page - 1) : page; //if there aren't any lines on this page, don't count it.
	}
	
	public list<xtask> getxtasklistpage() { 
		if (Pagination) {
			if (!(CurrentPage > 0)) CurrentPage = 1;
			
			return pagextasklistmap.get(CurrentPage);
		} else {
			return xtasklist;
		} 
	}
	
	public PageReference PrevPage() { 
		if (CurrentPage > 1) CurrentPage--; 
		return null;
	}
	
	public PageReference NextPage() {
		if (CurrentPage < TotalPages) CurrentPage++;
		return null;
	}
	
	public Boolean getIsLastPage() { return (CurrentPage == TotalPages); }
	public Boolean getIsFirstPage() { return (CurrentPage == 1); }
	
	public PageReference SortbyDate()
	{
		SortBy('ActivityDate');
		return null;
	}
	
	public PageReference SortbyStatus() 
	{
		SortBy('Status');
		return null;
	}
	
	public PageReference SortbyAssoc()
	{
		SortBy('AVB_Associate_First_Last_Name__c');
		return null;
	}
	
	public PageReference SortbyOwner()
	{
		SortBy('Owner.Alias');
		return null;
	}
	
	public PageReference SortbyAVBAcct()
	{
		SortBy('AVB_Account_ID__c');
		return null;
	}
	
	public PageReference SortbyType()
	{
		SortBy('AVB_Type__c');
		return null;
	}
	
	public PageReference SortbySubCat()
	{
		SortBy('Subject_Sub_Category__c');
		return null;
	}
	
	public PageReference SortByRating()
	{
		SortBy('Rating');
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
	  
	
	/*
		Unit Testing Section
	*/	
	
	static testmethod void testtasklistcon()
	{
		Date testdate1 = Date.newInstance(2010, 6, 22);
		Date testdate2 = Date.newInstance(2010, 11, 3);
		User u = [select id, UserRoleId from User where IsActive = true limit 1];
		if (u.UserRoleId == null) {
			u.UserRoleId = [select id from UserRole limit 1].id;
			update u;
		}
		map<id, User> allusermap = new map<id, User>([select id from User where UserRoleId = :u.UserRoleId]);
		Integer comparecount = [select count() from Task where IsClosed = false and OwnerId in :allusermap.keyset() limit 100]; //Id to OwnerId
		
test.startTest();		
		System.runAs(u) {
			TaskListCon t = new TaskListCon();
			
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
			system.assertEquals(comparecount, fulllist.size());//got full tasklist
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
	            Department = 'RS Community'
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
			Subject_Sub_Category__c = 'Avalon Access' 
			));
		sorttasks.add(new Task(
			whoid = sortcontacts[1].id, 
			WhatId = c.id, 
			ActivityDate = system.today().addDays(1), 
			Status = 'Not Started', 
			AVB_Associate_First_Last_Name__c = 'Assoc Z', 
			OwnerID = testusers[1].id, 
			AVB_Type__c = 'Move In Process', 
			Subject_Sub_Category__c = 'Send Letter' 
			));
		insert sorttasks;
		
		PageReference ref;		
test.starttest();
		TaskListCon tc = new TaskListCon();
		
system.debug('\n\ntasklist ' + tc.gettasklist());
		
		
		//starts out sorted by date ascending
		//system.assert(tc.gettasklist()[0].ActivityDate <= tc.gettasklist()[1].ActivityDate);
		ref = tc.SortByDate(); //should be descending
		//system.assert(tc.gettasklist()[0].ActivityDate >= tc.gettasklist()[1].ActivityDate);
		ref = tc.SortByStatus();
		//system.assert(tc.gettasklist()[0].Status <= tc.gettasklist()[1].Status);
		ref = tc.SortByAssoc();
		//system.assert(tc.gettasklist()[0].AVB_Associate_First_Last_Name__c <= tc.gettasklist()[1].AVB_Associate_First_Last_Name__c);
		ref = tc.SortByOwner();
		//system.assert(tc.gettasklist()[0].Owner.alias <= tc.gettasklist()[1].Owner.alias);
		ref = tc.SortByAVBAcct();
		//system.assert(tc.gettasklist()[0].AVB_Account_ID__c <= tc.gettasklist()[1].AVB_Account_ID__c);
		ref = tc.SortByType();
		//system.assert(tc.gettasklist()[0].AVB_Type__c <= tc.gettasklist()[1].AVB_Type__c);
		ref = tc.SortBySubCat();
		//system.assert(tc.gettasklist()[0].Subject_Sub_Category__c <= tc.gettasklist()[1].Subject_Sub_Category__c);
		ref = tc.SortBySubCat(); //reverse sort
		//system.assert(tc.gettasklist()[0].Subject_Sub_Category__c >= tc.gettasklist()[1].Subject_Sub_Category__c);
		ref = tc.SortByRating(); //forward sort
		//system.assert(tc.gettasklist()[0].Subject_Sub_Category__c >= tc.gettasklist()[1].Subject_Sub_Category__c);
		ref = tc.SortByRating(); //reverse sort
		//system.assert(tc.gettasklist()[0].Subject_Sub_Category__c >= tc.gettasklist()[1].Subject_Sub_Category__c);
		
test.stoptest();
		
	}
	
	static testmethod void testprefs()
	{
		User u = [select id from User where IsActive = true limit 1];
		Task_View_Settings__c testprefs = Task_View_Settings__c.getvalues(u.id);
    	if(testprefs != null) delete testprefs; //make sure there are no settings currently

test.StartTest();	
		system.runas(u) {
			TaskListCon tc = new TaskListCon();
			tc.setfilter('1');
			tc.changefilter();
			
			testprefs = Task_View_Settings__c.getvalues(u.id); //there should be settings now
			system.assert(testprefs.View_Filter__c == 1); 
			
			tc.setfilter('4');
			tc.changefilter();
			
			testprefs = Task_View_Settings__c.getvalues(u.id); //settings should be changed.
			system.assert(testprefs.View_Filter__c == 4);
			
			//make sure we remember this user's settings next time
			tc = new TaskListCon();
			testprefs = Task_View_Settings__c.getvalues(u.id); //settings should be changed.
			system.assert(testprefs.View_Filter__c == 4);
			
		}
		
test.stopTest();		
	}
	
	static testmethod void testpaging()
	{
		Integer testtotalpages;
		
		Profile commprof = [select id from Profile where Name = 'Pilot Community'];
		
		//get Community Profile user
		Id uroleid = [select Id from UserRole limit 1].id;
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
            username='testuser7844584552@example.com',
            Department = 'RS Community'
            );
		User adminuser = [select Id from User where Profile.Name = 'System Administrator' and IsActive = true limit 1];
		system.runAs(adminuser)
		{
			insert u;
		}
		
		map<id, User> sameroleusermap = new map<id, User>([select id from User where IsActive = true and UserRoleId = :u.UserRoleId]);
		
		Integer taskcount = [select count() from Task 
			where IsClosed = false 
				and AVB_Type__c = 'Lead Pursuit Process' 
				and OwnerId in :sameroleusermap.keyset() 
			limit 100];
		
		Account acc = new Account(
			Name = 'testacc',
			RecordtypeId = [select id from Recordtype where SOBjectType = 'Account' and Name = 'Customer Group' limit 1].id,
			Type = 'Prospect');
		insert acc;
		
		list<Guest_Card__c> gcs = new list<Guest_Card__c>();
		for (Integer i = 0; i < 2; i++) {
			gcs.add(new Guest_Card__c(
				Prospect_Account__c = acc.id,
				Name = 'testgc',
				AVB_Associate__c = 'test person',
				OwnerId = u.id
				));
		}
		insert gcs;
		
test.StartTest();
		system.runas(u) {
			TaskListCon t = new TaskListCon();
			
system.debug('\n\nmaxlinesperpage ' + t.MaxLinesPerPage);		
			if (taskcount <= t.MaxLinesPerPage) {
				list<Task> newtasks = new list<Task>();
				for (Integer i = taskcount; i < (t.MaxLinesPerPage + 3); i++) {
					Task tk = new Task(
						Subject = 'Test Task ' + i, 
						OwnerID = u.id, 
						WhatID = gcs[0].id, 
						AVB_Type__c = 'Lead Pursuit Process', 
						AVB_Associate_First_Last_Name__c = 'Not Assigned',
						Subject_Sub_Category__c = 'Visit'
						);
					newtasks.add(tk);
					tk = new Task(
						Subject = 'Test Task ' + i, 
						OwnerID = u.id, 
						WhatID = gcs[1].id,
						AVB_Associate_First_Last_Name__c = 'Not Assigned',
						AVB_Type__c = 'Lead Pursuit Process', 
						Subject_Sub_Category__c = 'Visit'
						);
					newtasks.add(tk);
					
				}
				insert newtasks;
system.debug('\n\nnewtasks ' + newtasks);		
			}
			
			Test.setCurrentPage(Page.LeadMgmtTaskList);
			ApexPages.currentPage().getParameters().put('listtype','lead');		
			ApexPages.currentPage().getParameters().put('paginate','1');		
			t = new TaskListCon();
			
			taskcount = [select count() from Task where IsClosed = false and OwnerId in :sameroleusermap.keyset() limit 100];
			testtotalpages = Decimal.valueof(taskcount).divide(t.MaxLinesPerPage, 0, System.RoundingMode.UP).intValue(); //divide total list by perpage and round up
			
			//if it comes out even
			if ( ((taskcount / t.MaxLinesPerPage) * t.MaxLinesPerPage) == taskcount) {
				t.refreshtasklist();
				Task deletetask = t.gettasklist()[0];
				delete deletetask;
				t.refreshtasklist();
			}
			
			system.assertEquals(null,t.CurrentPage);
			
			t.refreshtasklist();
			
			list<xtask> firstpage = t.getxtasklistpage();
			system.assertEquals(1,t.CurrentPage);
			Id firstrecordId = firstpage[0].task.Id;
			t.SortByDate();
			
			firstpage = t.getxtasklistpage();
			system.assertEquals(1,t.CurrentPage);
			system.assertNotEquals(firstrecordId, firstpage[0].task.Id);
			
			Pagereference pr = t.NextPage();
			if (t.TotalPages > 1) {
				system.assertEquals(2, t.CurrentPage);
			} else { 
				system.assertEquals(1, t.CurrentPage);
			}
			list<xtask> secondpage = t.getxtasklistpage();
			
			pr = t.PrevPage();
			system.assertEquals(1,t.CurrentPage);
			
			system.assertEquals(true, t.getIsFirstPage());
			t.CurrentPage = t.TotalPages;
			system.assertEquals(true, t.getIsLastPage());
	test.stopTest();
			
			//system.assertequals(testtotalpages, t.TotalPages); //counted pages right
			system.assertNotEquals(firstpage, secondpage); //gives different lists for pages	
		}
	}
	
	static testmethod void testpagingMIMO()
	{
		Integer testtotalpages;
		
		//get Community Profile user
		Profile commprof = [select id from Profile where Name = 'Pilot Community'];
		
		Id uroleid = [select Id from UserRole limit 1].id;
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
            username='testuser7844584552@example.com',
            Department = 'RS Community'
            );
		User adminuser = [select Id from User where Profile.Name = 'System Administrator' and IsActive = true limit 1];
		system.runAs(adminuser)
		{
			insert u;
		}
		
		map<id, User> sameroleusermap = new map<id, User>([select id from User where UserRoleId = :u.UserRoleId]);
		set<String> mimotypes = new set<String>{'Move In Process','Move In Process-Manual','Move Out Process','Move Out Process-Manual'};
		
		//get task recordtypes
		Id miId;
		Id moId;
		for (Recordtype r : [select id, Name from Recordtype where SOBjectType = 'Task']) {
			if (r.Name == 'Move In Follow Up') miId = r.Id;
			if (r.Name == 'Move Out Follow Up') moId = r.Id;
		}
		
		Integer taskcount = [select count() from Task 
			where IsClosed = false 
				and AVB_Type__c in :mimotypes 
				and OwnerId in :sameroleusermap.keyset() 
			limit 100];
		
		Case c = new Case(Subject = 'testcase', OwnerId = u.id);
		insert c;
		
		Account acc = new Account(
			Name = 'testacc',
			RecordtypeId = [select id from Recordtype where SOBjectType = 'Account' and Name = 'Customer Group' limit 1].id,
			Type = 'Prospect');
		insert acc;
		
test.StartTest();
		system.runas(u) {
			TaskListCon t = new TaskListCon();
			
system.debug('\n\nmaxlinesperpage ' + t.MaxLinesPerPage);		
			if (taskcount <= t.MaxLinesPerPage) {
				list<Task> newtasks = new list<Task>();
				for (Integer i = taskcount; i < (t.MaxLinesPerPage + 3); i++) {
					Task tk = new Task(
						Subject = 'Test Task ' + i, 
						OwnerID = u.id, 
						RecordtypeId = miId,
						WhatID = c.id, 
						AVB_Type__c = 'Move In Process', 
						AVB_Associate_First_Last_Name__c = 'Not Assigned',
						Subject_Sub_Category__c = 'MI Follow Up'
						);
					newtasks.add(tk);
					tk = new Task(
						Subject = 'Test Task ' + i, 
						OwnerID = u.id, 
						RecordtypeId = miId,
						WhatID = c.id,
						AVB_Associate_First_Last_Name__c = 'Not Assigned',
						AVB_Type__c = 'Move Out Process', 
						Subject_Sub_Category__c = 'Change in NTV'
						);
					newtasks.add(tk);
					
				}
				insert newtasks;
system.debug('\n\nnewtasks ' + newtasks);		
			}
			
			Test.setCurrentPage(Page.MIMOTaskList);
			ApexPages.currentPage().getParameters().put('listtype','mimo');		
			ApexPages.currentPage().getParameters().put('paginate','1');		
			t = new TaskListCon();
			
			taskcount = [select count() from Task where IsClosed = false and OwnerId in :sameroleusermap.keyset() limit 100];
			testtotalpages = Decimal.valueof(taskcount).divide(t.MaxLinesPerPage, 0, System.RoundingMode.UP).intValue(); //divide total list by perpage and round up
			
			//if it comes out even
			if ( ((taskcount / t.MaxLinesPerPage) * t.MaxLinesPerPage) == taskcount) {
				t.refreshtasklist();
				Task deletetask = t.gettasklist()[0];
				//Removed temporarily to avoid an error received in production. 6/3/11 JN
				//delete deletetask;
				t.refreshtasklist();
			}
			
			system.assertEquals(null,t.CurrentPage);
			
			t.refreshtasklist();
			
			list<xtask> firstpage = t.getxtasklistpage();
			system.assertEquals(1,t.CurrentPage);
			Id firstrecordId = firstpage[0].task.Id;
			t.SortByDate();
			
			firstpage = t.getxtasklistpage();
			system.assertEquals(1,t.CurrentPage);
			system.assertNotEquals(firstrecordId, firstpage[0].task.Id);
			
			Pagereference pr = t.NextPage();
			if (t.TotalPages > 1) {
				system.assertEquals(2, t.CurrentPage);
			} else { 
				system.assertEquals(1, t.CurrentPage);
			}
			list<xtask> secondpage = t.getxtasklistpage();
			
			pr = t.PrevPage();
			system.assertEquals(1,t.CurrentPage);
			
			system.assertEquals(true, t.getIsFirstPage());
			t.CurrentPage = t.TotalPages;
			system.assertEquals(true, t.getIsLastPage());
	test.stopTest();
			
			system.assertequals(testtotalpages, t.TotalPages); //counted pages right
			system.assertNotEquals(firstpage, secondpage); //gives different lists for pages	
		}
	}
}