trigger ValidateParentAccount on Account (before insert, before update) {
	
	List<Id> pIds = new List<Id>();

	for (Account newAcc : Trigger.new) {
		Id recordTypeId = newAcc.RecordTypeId;
		if (recordTypeId == '012600000000n1b') {
			Id parentId = newAcc.ParentId;
			pIds.add(parentId);		
		}
	}	
	
	if (pIds.size() > 0) {
		Account[] acc = [select RecordTypeId from Account where Id in : pIds];
		for (Integer i=0; i<acc.size(); i++) {
			if (acc[i].RecordTypeId != '012600000000n1g') {
				Trigger.new[i].ParentId.addError('Parent Account is not of Type Community.');	
			}
		}
	}
}