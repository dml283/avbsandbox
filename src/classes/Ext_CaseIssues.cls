public class Ext_CaseIssues {

	Case thisCase;
	Account thisAcc;
	User thisUser;
	Contact thisCon;
	
	//public list<Case_Issue__c> issues { get; set; }
	public list<extIssue> xissues { get; set; }
	
	//Can this user copy associates?
	public Boolean CanCopyAssociates { get; private set; }
	
	//Can we create a case on this Account?
	public Boolean CanCreateCase { get; private set; }
	
	//show escalated queue checkbox on page
	public Boolean ShowEscalatedQueue { get; private set; }
	
	//number of Case Issues to display on combined page
	Integer NumIssuesOnPage = 5;
	
	//Department to Case Origin settings
	map<String, String> userdept2caseoriginmap = new map<String, String>
	{
		'CCC' => 'CSO',
		'RS Community' => 'Community',
		'RS Overhead' => 'Regional/Corporate Office',
		'Marketing' => 'Regional/Corporate Office'
	};
	
	public CaseComment newComment { get; set; }
	public Boolean CreateCaseTask { get; set; }
	public Task newCaseTask { get; set; }
	public list<SelectOption> addresseeOptions { get; private set; }
	public list<SelectOption> ownerOrQueueOptions { get; private set; }
	
	public Ext_CaseIssues(ApexPages.standardController stdcon)
	{
		thisUser = [select Id, Department, Profile.Name from User where Id = :Userinfo.getUserId()];
		
		//show escalated queue only for 'CCC' Profiles
		ShowEscalatedQueue = FALSE;
		if (thisUser.Profile.Name.contains('CCC'))
		{
			ShowEscalatedQueue = TRUE;
		}
		
		if (thisCase == null)
		{
			thisCase = (Case)stdcon.getRecord();
		}
		
		//populate case origin
		thisCase.Origin = userdept2caseoriginmap.get(thisUser.Department);
		
		//check to see if this is a Prospect Account
		checkCanCreate();
		
		makeCaseIssues();
		makeAddresseeOptions();
		makeOwnerOrQueueOptions();
		
		newComment = new CaseComment();
		CreateCaseTask = FALSE;
		newCaseTask = new Task();
		
		//Make CanCopyAssociates selective wrt the user's Development_Settings__c Custom Setting
		CanCopyAssociates = FALSE;
		if (Development_Settings__c.getInstance().Can_Copy_Associates_on_Cases__c == TRUE)
			CanCopyAssociates = TRUE;
			
	}
	
	public class extIssue
	{
		public Case_Issue__c issue { get; set; }
		
		public Boolean WillSendEmail { get; set; } //whether to send email on this case issue
		public list<String> addresseeIds { get; set; } //user Ids to address email
		public String additionalEmails { get; set; } //additional email addresses to use
		
		public Boolean WillCreateTask { get; set; } //whether to create new task
		public String OwnerOrQueue { get; set; } //who to assign new task to
		public Task NewTask { get; set; }
		
		public Boolean IsEditable { get; set; }
		
		public extIssue(Case_Issue__c ci)
		{
			this.issue = ci;
			this.NewTask = new Task(OwnerId = Userinfo.getUserId());
			this.OwnerOrQueue = 'Queue';
			this.WillSendEmail = FALSE;
			this.WillCreateTask = FALSE;
		}
	}
	
	private void checkCanCreate()
	{
		Id accid = (Id)ApexPages.CurrentPage().getParameters().get('accid');
		CanCreateCase = TRUE;
		if (accid != null)
		{
			try
			{
				thisAcc = [select Id, Name, Status__c, AccountNumber, Account_ID__c
					from Account
					where Id = :accid];
				thisCase.Account_Number__c = thisAcc.Account_ID__c;
				
				if ((thisAcc.Status__c == 'Prospect') && (thisCase.Id == null))
				{
					CanCreateCase = FALSE;
					ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You may not create a Case on a Prospect Account.'));
				}
			} catch (Exception e)
			{
				ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Supplied Account Id not found.'));
			}
		}
	}
	
	private void popCaseOrigin()
	{
	}
	
	private void makeOwnerOrQueueOptions()
	{
		ownerOrQueueOptions = new list<SelectOption>
		{
			new SelectOption('Queue', 'Queue'),
			new SelectOption('Owner', 'Person')
		};
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
			Case_Issue__c newissue = new Case_Issue__c(Case__c = thisCase.Id);
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
		
		Savepoint sp = Database.setSavepoint();

		try
		{
			thisCon = [select AccountId, FirstName, LastName 
				from Contact 
				where Id = :thisCase.ContactId];
			thisCase.AccountId = thisCon.AccountId;
			
			database.upsert(new list<Case> { thisCase });
			
			//Create Task on Case if necessary
			if (CreateCaseTask)
			{
				newCaseTask.WhoId = thisCase.ContactId;
				newCaseTask.WhatId = thisCase.Id;
				
				insert newCaseTask;
			}
			//save case issues
			saveIssues();
			
			//make Tasks on case issues
			makeTasks();
			
			//send emails on case issues (copy associates)
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
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to save: ' + e.getMessage()));
			Database.rollback(sp);
		}
		
		return pageref;
	}
	
	private void makeTasks()
	{
		//go through case issues
		list<Task> taskstoinsert = new list<Task>();
		for (extIssue xi : xissues)
		{
			if ((xi.WillCreateTask) && (xi.IsEditable) && (xi.issue.Id != null))
			{
				//Only accept Owner or Queue determination. The other choice gets blanked out on the new task.
				if (xi.ownerOrQueue == 'Owner')
				{
					xi.NewTask.Task_Queue__c = null;
				}
				else if (xi.ownerOrQueue == 'Queue')
				{
					xi.NewTask.OwnerId = UserInfo.getUserId();
				}
				
				xi.NewTask.ActivityDate = system.today();
				xi.NewTask.WhatId = thisCase.Id;
				xi.NewTask.WhoId = thisCase.ContactId;
				//xi.NewTask.Status = 'Not Started';
				xi.NewTask.ActivityDate = system.today();
				xi.NewTask.AVB_Type__c = 'Other';
				xi.NewTask.Subject = 'Task Created through Case page';
				xi.NewTask.Subject_Sub_Category__c = 'Other';
				xi.NewTask.Description = 'Task Created on Case ' + thisCase.CaseNumber + ' and Case Issue ' + xi.issue.Category__c;
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
				if ((xi.WillSendEmail) && (xi.IsEditable) && (xi.issue.Id != null))
					userids.addall((list<Id>)xi.addresseeIds);
			}
			map<Id, User> userid2usermap = new map<Id, User>([select Id, FirstName, LastName, Email 
				from User 
				where Id in :userids]);
				
			//Construct email messages (one for each checked Case Issue)
			list<Messaging.SingleEmailMessage> emailstosend = new list<Messaging.SingleEmailMessage>();
			list<Task> taskstoinsert = new list<Task>();
			for (extIssue xi : xissues)
			{
				String namelist = '';
				if ((xi.WillSendEmail) && (xi.IsEditable) && (xi.issue.Id != null))
				{
					list<String> emailaddresses = new list<String>();
					Boolean firstEmail = TRUE;
					for (Id userid : xi.addresseeIds)
					{
						User u = userid2usermap.get(userid);
						emailaddresses.add(u.Email);
						if (firstEmail)
						{
							FirstEmail = FALSE;
						} else
						{
							namelist += ', ';
						}
						namelist += ((u.FirstName != null) ? u.FirstName : '') + ' ' + u.LastName;
							
							
					}
					if (xi.additionalEmails.length() > 0)
						emailaddresses.addAll(xi.additionalEmails.split(';'));
					
					for (String em : emailaddresses)
					{
						if (firstEmail)
						{
							FirstEmail = FALSE;
						} else
						{
							namelist += ', ';
						}
						namelist += em;
					}
					
					String baseUrl = 'na4';
					
					String emailBody = thisUser.FirstName + ' ' + thisUser.LastName
						+ ' wants to make you aware of the following case:'
						+ '<br/><br/>Subject: ' + thisCase.Subject
						+ '<br/>Contact: ' + thisCon.FirstName + ' ' + thisCon.LastName
						+ '<br/>Account: ' + thisAcc.Name
						+ '<br/>Feedback Level: ' + thisCase.Feedback_Level__c
						+ '<br/>Priority: ' + thisCase.Priority
						+ '<br/>Status: ' + thisCase.Status
						+ '<br/>Comments:<br/>' + thisCase.Description
						+ '<br/><br/>For more details, click the following link:'
						+ '<br/>' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + thisCase.Id 
						+ '<br/>Associates copied on this case include: ' + namelist;
						
					Messaging.SingleEmailMessage newemail = new Messaging.SingleEmailMessage();
					newemail.setToAddresses(emailaddresses);
					newemail.setWhatId(thisCase.Id);
					//newemail.setTemplateId(templates[0].Id);
					newemail.setHTMLBody(emailBody);
					newemail.setSubject('Copy Associate on Case');
					emailstosend.add(newemail);
				
					//save Email as Completed Task on Case
					String descrip = 'Copy Associate email sent on Case  Sent to: ' + namelist + system.today().format() + '.';
					
					Task newtask = new Task(
						WhatId = thisCase.Id,
						WhoId = thisCase.ContactId,
						Status = 'Complete',
						ActivityDate = system.today(),
						Subject = 'Email: ' + newemail.getSubject(),
						Description = descrip);
					taskstoinsert.add(newtask);
				}
				
			}
			
			//send email list
			if (emailstosend.size() > 0)
				Messaging.sendEmail(emailstosend);
			
			//save email tasks
			if (taskstoinsert.size() > 0)
				insert taskstoinsert;
			
			
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
					cistoupsert.add(ci);
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
		Case_Issue__c newissue = new Case_Issue__c(Case__c = thisCase.Id);
		//issues.add(newissue);
		extIssue newxissue = new extIssue(newissue);
		newxissue.IsEditable = TRUE;
		xissues.add(newxissue);
	
		return pageref;
	}
}