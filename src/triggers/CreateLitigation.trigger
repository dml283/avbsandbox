trigger CreateLitigation on Litigation_Data__c (after insert, after update) {
  String[] ids = new String[]{};
    Map <String,Litigation_Data__c> accLookup = new Map <String,Litigation_Data__c>();
    for (Litigation_Data__c acc : Trigger.new) {
    /*  if (acc.Refresh_Flag__c != null) {*/
            ids.add(acc.Account_ID__c); 
            system.debug('>>>Refresh Flag'+acc.Account_ID__c);
            accLookup.put(acc.Account_ID__c, acc);
    /*  }*/
    }
    //Real_Time_Sync_Log__c log = new Real_Time_Sync_Log__c();
    
    //system.debug('>>>Refresh Flag'+acc.Account_ID__c); 
    Litigation__c[] insLitigationList = new Litigation__c[]{};
    Litigation__c[] updLitigationList = new Litigation__c[]{};
    Litigation_Notes__c[] litigationNotesList = new Litigation_Notes__c[]{};
    String[] commentsList = new String[]{};
    
    Map<String,Litigation__c[]> litigationLookup = new Map<String,Litigation__c[]>();
    
    if (ids.size() > 0) {   
        Litigation__c[] litigationRecs = [SELECT Id, Account__c, Status__c FROM Litigation__c WHERE Account__c IN :ids and Status__c = 'Open']; 
        //Litigation__c[] litigationArr = new Litigation__c[]{};
        for (Integer i=0 ; i<litigationRecs.size(); i++) {
            if (litigationLookup.get(litigationRecs[i].Account__c) == null) {
                Litigation__c[] litigationArr = new Litigation__c[]{};
                litigationArr.add(litigationRecs[i]);
                litigationLookup.put(litigationRecs[i].Account__c, litigationArr);
            } else {
                Litigation__c[] litigationArr = litigationLookup.get(litigationRecs[i].Account__c);
                litigationArr.add(litigationRecs[i]);
                litigationLookup.put(litigationRecs[i].Account__c, litigationArr);
            }       
        }
    }       
        
    System.debug('>>>Litigation ids'+ ids.size());
    //log.Error_Message_Long__c = 'litigation data size ' + accLookup.size();
    for (Integer i=0 ; i<ids.size(); i++) {
        //log.Error_Message_Long__c += 'litigation acc id ' + ids[i];
        String accountId = ids[i]; 
        Litigation_Data__c acc = accLookup.get(accountId); 
        //if (acc.Refresh_Flag__c == true) {
            //Integer iCount = litigationLookup.get(accountId).size();
            System.debug('flag ' + acc.Litigation_Flag_FND__c);
            System.debug('accountId: ' + accountId);
            System.debug('lookup acc'+ litigationLookup.get(accountId));
            //log.Account_Number__c = accountId;
            //log.Error_Message_Long__c += 'flag' + acc.Litigation_Flag_FND__c + 'lookup acc'+ litigationLookup.get(accountId);
            if (acc.Litigation_Flag_FND__c == true) { 
                if (litigationLookup.get(accountId) == null) { 
                    /*Create a new Litigation__c record for the accountId. */
//                    DateTime courtdatetime = DateTime.newInstance(acc.Court_Date__c.year(),acc.Court_Date__c.month(),acc.Court_Date__c.day());
                    
                    Litigation__c rNewLitigation = new Litigation__c(Litigation_Type__c = 'Non Payment',
                        Date__c = System.today(),
                        Status__c = 'Open',
                        Law_Firm__c = acc.Law_Firm__c,
                        Account__c = acc.Account_ID__c,
                        Original_Amount__c = acc.Original_Amount__c,
                        Last_Modified_Date_Time_in_Foundation__c = acc.Last_Modified_Date_Time_in_Foundation__c,
                        Last_Modified_By_Foundation_User__c = acc.Last_Modified_By_Foundation_User__c);/*,
                        Court_Date__c = courtdatetime);*/

                    
                    //insert rNewLitigation;
                    insLitigationList.add(rNewLitigation);
                    
                    commentsList.add(acc.Litigation_Notes__c);                  
                }
            } else {
                /*Create a new Litigation_Notes__c for the "Open" Litigation Activity.*/
                Litigation__c[] litigationRecs = litigationLookup.get(accountId);   
                //log.Error_Message_Long__c += 'flag is false ' + acc.Litigation_Flag_FND__c + 'lookup acc'+ litigationLookup.get(accountId);
                //System.debug('>>>litigationRecs.size()'+litigationRecs.size());
                if ( litigationRecs != null && litigationRecs.size() == 1) {
                    Litigation__c litigationRec = litigationRecs[0];//[select Id, Status__c from Litigation__c where Account__c IN (:ids) and Status__c='Open'];
                    /* Get the Litigation__c value for the accountId record*/                   
                    if (litigationRec.Status__c =='Open') {
                        /* Then create a comment record for the existing "Open" Litigation activity record.*/
                        Litigation_Notes__c rNewLitigationNotes = new Litigation_Notes__c(Litigation_Activity__c = litigationRec.Id,
                            Litigation_Notes__c = acc.Litigation_Notes__c,
                            Status__c = acc.Litigation_Closure_Reason__c);
                        //insert rNewLitigationNotes;
                        litigationNotesList.add(rNewLitigationNotes);
                    
                        /*Close the Litigation Activity*/
                        litigationRec.Status__c = 'Closed';
                        //litigationRec.Law_Firm__c = acc.Law_Firm__c;
                        //litigationRec.Original_Amount__c = acc.Original_Amount__c;
                        litigationRec.Last_Modified_Date_Time_in_Foundation__c = acc.Last_Modified_Date_Time_in_Foundation__c;
                        litigationRec.Last_Modified_By_Foundation_User__c = acc.Last_Modified_By_Foundation_User__c;
                        //litigationRec.Court_Date__c = acc.Court_Date__c; //The Court Date should be pulled from the Community Account only at the time the Litigation Activity is created.  
                        //update litigationRec;
                        updLitigationList.add(litigationRec);
                    } 
                }               
            }
        //}
    } 
    
    //log.Error_Message_Long__c += 'ins lit size'+insLitigationList.size() + ' upd size ' + updLitigationList.size() + ' notes size '+ litigationNotesList.size();  
    if (insLitigationList.size() > 0) {
        System.debug('creating litigation notes ' + insLitigationList.size());
        //insert insLitigationList;
        Database.SaveResult[] saveResult = Database.Insert(insLitigationList, true);
        for (Integer i=0; i<saveResult.size(); i++) {
            if (saveResult[i].isSuccess()) {
                String litigationId = saveResult[i].getId();
                if (commentsList[i] != null) {
                    Litigation_Notes__c rNewLitigationNotes = new Litigation_Notes__c(Litigation_Activity__c = litigationId,
                                Litigation_Notes__c = commentsList[i],
                                Status__c = 'Autocreated Comments');
                    litigationNotesList.add(rNewLitigationNotes);
                }               
            }
        }
    }
    if (updLitigationList.size() > 0) {
        System.debug('updating litigation ' + updLitigationList.size());
        update updLitigationList;
    } 
    if (litigationNotesList.size() > 0) {
        System.debug('inserting litigation ' + litigationNotesList.size());
        insert litigationNotesList;
    }
    //insert log;
    //Litigation_Data__c[] litigationData = [select id from Litigation_Data__c where id in : ids];
    //delete litigationData;


}