public class Ext_CaseIssues {

	Case thisCase;
	//public list<Case_Issue__c> issues { get; set; }
	public list<extIssue> xissues { get; set; }
	
	//Can this user copy associates?
	public Boolean CanCopyAssociates { get; private set; }
	
	//number of Case Issues to display on combined page
	Integer NumIssuesOnPage = 5;
	
	public CaseComment newComment { get; set; }
	public list<SelectOption> addresseeOptions { get; private set; }
	
	public Ext_CaseIssues(ApexPages.standardController stdcon)
	{
		if (thisCase == null)
		{
			thisCase = (Case)stdcon.getRecord();
		}
		makeCaseIssues();
		makeAddresseeOptions();
		newComment = new CaseComment();
		
		//Make CanCopyAssociates selective wrt the user's Development_Settings__c Custom Setting
		CanCopyAssociates = FALSE;
		if (Development_Settings__c.getInstance().Can_Copy_Associates_on_Cases__c == TRUE)
			CanCopyAssociates = TRUE;
			
	}
	
	public class extIssue
	{
		public Case_Issue__c issue { get; set; }
		
		public Boolean WillCreateTask { get; set; }
		public Boolean WillSendEmail { get; set; }
		public Task NewTask { get; set; }
		public list<Id> addresseeIds { get; set; } //user Ids to address email
		public String additionalEmails { get; set; } //additional email addresses to use
		public Boolean IsEditable { get; set; }
		
		public extIssue(Case_Issue__c ci)
		{
			this.issue = ci;
			this.NewTask = new Task();
			this.WillSendEmail = FALSE;
			this.WillCreateTask = FALSE;
		}
	}
	
	private void makeAddresseeOptions()
	{
		addresseeOptions = new list<SelectOption>();
		
		//set of user role ids for this user and anyone directly above them in the hierarchy
		set<id> roleidsUserAndAbove = new set<Id>();
		
		//get all user roles
		map<Id, UserRole> allRolemap = new map<Id, UserRole>([
			select Id, ParentRoleId 
			from UserRole]);
		Id parentId;
		if (Userinfo.getUserRoleId() != null)
		{
			UserRole thisUserRole = allRolemap.get(Userinfo.getUserRoleId());
			parentId = thisUserRole.parentRoleId;
			
			//add the user's own role to the set of roleids to query on	
			roleidsUserAndAbove.add(thisUserRole.Id);
		}
		
		//collect all user roles up the tree until there's a role with no parent role
		while (parentId != null)
		{
			//save the parentId we have
			roleidsUserAndAbove.add(parentId);
			
			//move up the tree one step
			parentId = allRolemap.get(parentId).parentRoleId;
		}
		
		//query for all users that are either in roles above this user, or have CSO or Legal in their title
		list<User> addresseeUsers = [select Id, FirstName, LastName, Title 
			from User 
			where UserRoleId in :roleidsUserAndAbove
				or Title like '%CSO%'
				or Title like '%Legal%'];
		
		//construct addresseeOptions list
		for (User u : addresseeUsers)
		{
			String optionName = '';
			
			if (u.FirstName != null) optionName += u.FirstName + ' ';
			optionName += u.LastName;
			if (u.Title != null) optionName += ', ' + u.Title;
			
			addresseeOptions.add(new SelectOption(u.Id, optionName));
		}		
	}
	
	private void makeCaseIssues()
	{
		Id caseid;
		list<Case_Issue__c> issues = new list<Case_Issue__c>();
		xissues = new list<extIssue>();
		
		if (thisCase.Id != null)
		{
			caseid = thisCase.Id;
			issues = [select Id, Category__c, Subcategory__c, Amount__c, Type__c, Charge_Type__c, Notes__c
				from Case_Issue__c
				where Case__c = :thisCase.Id];
			
			for (Case_Issue__c ci : issues)
			{
				extIssue newxissue = new extIssue(ci);
				newxissue.IsEditable = FALSE;
				xissues.add(newxissue);
			}
		}
		
		//how many blank lines to add to page? Depends on how many issues there are already
		Integer NumBlankIssues = NumIssuesOnPage - issues.size();
		
		//add at least one no matter what
		if (NumBlankIssues < 1)
			NumBlankIssues = 1;
			
		//populate list up to max
		Integer counter = 0;
		for (Integer i = 0; i < NumBlankIssues; i++)
		{
			Case_Issue__c newissue = new Case_Issue__c();
			issues.add(newissue);
			extIssue newxissue = new extIssue(newissue);
			newxissue.IsEditable = TRUE;
			xissues.add(newxissue);
			counter++;
		}
	}
	
	public PageReference saveCase()
	{
		PageReference pageref = null;
		//save case
		//fulfill requirement for this field in sandbox environment
		Case eblastCase = new Case();
		if (thisCase.Id != null)
		{
			eblastCase = [select Eblast_Audience_Distribution_list__c
				from Case
				where Id = :thisCase.Id];
		}
		if (eblastCase.Eblast_Audience_Distribution_list__c == null)
			thisCase.Eblast_Audience_Distribution_list__c = 'required text';
		
		try
		{
			database.upsert(new list<Case> { thisCase });
			
			//save case issues
			saveIssues();
			
			//make Tasks
			makeTasks();
			
			//send emails (copy associates)
			sendEmails();
			
			//save case comment
			if (newComment.CommentBody != null)
			{
				CaseComment commenttoinsert = new CaseComment(
					ParentId = thisCase.Id,
					CommentBody = newComment.CommentBody);
				insert commenttoinsert;
			}
			
			pageref = new PageReference('/' + thisCase.Id);
		}
		catch (Exception e)
		{
			ApexPages.addMessages(e);
		}
		
		return pageref;
	}
	
	private void makeTasks()
	{
		//go through case issues
		list<Task> taskstoinsert = new list<Task>();
		for (extIssue xi : xissues)
		{
			if (xi.WillCreateTask)
			{
				xi.NewTask.ActivityDate = system.today();
				xi.NewTask.WhatId = thisCase.Id;
				taskstoinsert.add(xi.NewTask);
			}
		}
		
		if (taskstoinsert.size() > 0)
		{
			insert taskstoinsert;
		}
	}
	
	private void sendEmails()
	{
		//get Email Template
		list<EmailTemplate> templates = [select Id 
			from EmailTemplate 
			where Name != null 
			limit 1];
		if (templates.size() > 0)
		{
			//collect email addresses for selected Users
			set<Id> userids = new set<Id>();
			for (extIssue xi : xissues)
			{
				if (xi.WillSendEmail)
					userids.addall(xi.addresseeIds);
			}
			map<Id, User> userid2usermap = new map<Id, User>([select Id, Email 
				from User 
				where Id in :userids]);
				
			//Construct email messages (one for each checked Case Issue)
			list<Messaging.SingleEmailMessage> emailstosend = new list<Messaging.SingleEmailMessage>();
			list<Task> taskstoinsert = new list<Task>();
			for (extIssue xi : xissues)
			{
				String namelist = '';
				if (xi.WillSendEmail)
				{
					list<String> emailaddresses = new list<String>();
					for (Id userid : xi.addresseeIds)
					{
						User u = userid2usermap.get(userid);
						emailaddresses.add(u.Email);
						namelist += u.FirstName + ' ' + u.LastName + ', ';
					}
					emailaddresses.addAll(xi.additionalEmails.split(';'));
					
					Messaging.SingleEmailMessage newemail = new Messaging.SingleEmailMessage();
					newemail.setToAddresses(emailaddresses);
					newemail.setWhatId(thisCase.Id);
					newemail.setTemplateId(templates[0].Id);
					
					emailstosend.add(newemail);
				
					//save Email as Completed Task on Case
					String descrip = 'Copy Associate email sent on Case  Sent to: ' + namelist + system.today().format() + '.';
					
					Task newtask = new Task(
						WhatId = thisCase.Id,
						Status = 'Complete',
						ActivityDate = system.today(),
						Subject = 'Email',
						Description = descrip);
					taskstoinsert.add(newtask);
				}
				
			}
			
			//send email list
			Messaging.sendEmail(emailstosend);
			
			
			
		} //end if templates size > 0
	}
	
	public PageReference saveIssues()
	{
		PageReference pageref = null;
		if ((thisCase != null)
			&& (thisCase.Id != null))
		{
			list<Case_Issue__c> cistoupsert = new list<Case_Issue__c>();
			
			for (extIssue xi : xissues)
			{
				Case_Issue__c ci = xi.issue;
				if (ci.Category__c != null)
				{
					Case_Issue__c newci = new Case_Issue__c(
						Id = ci.Id,
						Case__c = thisCase.Id,
						Category__c = ci.Category__c,
						Subcategory__c = ci.Subcategory__c,
						Type__c = ci.Type__c,
						Notes__c = ci.Notes__c,
						Charge_Type__c = ci.Charge_Type__c);
					cistoupsert.add(newci);
				}
			}
			if (cistoupsert.size() > 0)
			{
system.debug('\n\n87 cistoupsert ' + cistoupsert);			
				database.upsert(cistoupsert);
			}
			pageref = new PageReference('/' + thisCase.Id);
		}
		return pageref;
	}
	
	public PageReference addRow()
	{
		PageReference pageref = null;
		Case_Issue__c newissue = new Case_Issue__c();
		//issues.add(newissue);
		extIssue newxissue = new extIssue(newissue);
		newxissue.IsEditable = TRUE;
		xissues.add(newxissue);
	
		return pageref;
	}
}