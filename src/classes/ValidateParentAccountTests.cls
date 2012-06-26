public class ValidateParentAccountTests {

    static testMethod void testValidateParentAccount() {
    	Account acc1 = new Account(Account_ID__c='Test1',Name='Test1',RecordTypeId='012600000000n1b');
    	Account acc2 = new Account(Account_ID__c='Test2',Name='Test2',RecordTypeId='012600000000n1g'); 
    	try {
            insert acc1;
            insert acc2;                       
          	System.assert(true);
        } catch (System.DmlException e) {
        	System.assert(false);
    	}
    }
}