public class Ext_CaseAssociate {

/*
  Purpose:   - Option to copy associates on any case created.  
  - A button will be displayed on the case record. When pressed, a user can select multiple users.
  - The users selected will be added to the Case Associated object related to the Case
  - A workflow will be tied to alert these users upon creation.              
            
  Created By:   Jeremy Scott (Synaptic) 11/30/2011
  
  Last Modified By: Jeremy Scott (Synaptic) 12/2/2011
  
  Current Version:   v1.0
  
  Revision Log: v1.0 - Jeremy Scott (Synaptic) 12/2/2011 - changed class name - added cancel method
  
  */

    public Ext_CaseAssociate(ApexPages.StandardController controller) {

    }
    
    //Our collection of the class/wrapper objects cUser 
    public List<cUser> userList {get; set;}



    //This method uses a simple SOQL query to return a List of Users that are active and profile name contains CCC
   
    public List<cUser> getUsers() {
        if(userList == null) {
            set<Id> excludeduserids = new set <Id>();
            List <Case_Associate__c> caseexlist = [select Id, User__c from Case_Associate__c where Case__c = :ApexPages.currentPage().getParameters().get('id')];
            for (Case_Associate__c ca: caseexlist)
            {
                excludeduserids.add(ca.User__c);
            }
            userList = new List<cUser>();
            for(User u: [select Id, Name, IsActive, Email, Profile.Name, Phone from User where IsActive = True and Id not in :excludeduserids and Profile.Name like 'CCC%' Order By LastName]) {
                // As each user is processed we create a new cUser object and add it to the userList
                userList.add(new cUser(u));
            }
        }
        return userList;
    }

    public PageReference processSelected() {

                //We create a new list of Users that we be populated only with Users if they are selected
                
        List<User> selectedUsers = new List<User>();
        
        //We will cycle through our list of cUsers and will check to see if the selected property is set to true, if it is we add the User to the selectedUsers list
        
        for(cUser cUse: getUsers()) {
        
             if(cUse.selected == true){
                selectedUsers.add(cUse.use);
            }
        }

        // Now we have our list of selected users and can add them to the Case Association object on Cases, which will trigger an email alert to the user
       
    
      for(User us : selectedUsers) 
           {
             // Create new Case Associate Record and Insert
         Case_Associate__c newCaseAssociateRecord = new Case_Associate__c();
         newCaseAssociateRecord.User__c =  us.ID;
         newCaseAssociateRecord.Case__c = (''+ApexPages.currentPage().getParameters().get('id'));
         newCaseAssociateRecord.Name = us.Name;
         
         insert newCaseAssociateRecord;  
   
      }
       // Redirect back to case record   
              
      return new PageReference('/'+ApexPages.currentPage().getParameters().get('id'));
        
    }
    
     // takes user back to main record on cancel
   public PageReference cancel() {
     return new PageReference('/'+ApexPages.currentPage().getParameters().get('id'));
 }

    // This is our wrapper/container class. A container class is a class, a data structure, or an abstract data type whose instances are collections of other objects. 
    // In this example a wrapper class contains both the standard salesforce object Contact and a Boolean value
    
    public class cUser {
        public User use {get; set;}
        public Boolean selected {get; set;}

        //This is the contructor method. When we create a new cUser object we pass a User that is set to the 'use' property. We also set the selected value to false
        public cUser(User u) {
            use = u;
            selected = false;
        }
    }
    
  
    
}