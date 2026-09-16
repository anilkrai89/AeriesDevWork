/* this batch will be called when AE_Covering flag is changed in sales-territory__c record thru a flow bridged here from ivocable class AccountOwnerChangeBridge */
public class UpdateAccountOwnerBatch implements Database.Batchable<sObject> {
    
    private String oldOwnerId;
    private String newOwnerId;
    private Boolean coverae;
    private List<String> successfulRecordIds;
    private List<String> errorRecordIds;
    
    public UpdateAccountOwnerBatch(String oldOwnerId, String newOwnerId, Boolean coverae) {
        this.oldOwnerId = oldOwnerId;
        this.newOwnerId = newOwnerId;
        this.coverae = coverae;
        this.successfulRecordIds = new List<String>();
        this.errorRecordIds = new List<String>();
    }
    
 // start method to Retrieve query locator
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, OwnerId FROM Account WHERE OwnerId = :oldOwnerId';
        return Database.getQueryLocator(query);
    }
 //execute method to update the owner of all owned accounts   
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Account acc : scope) {
            acc.OwnerId = newOwnerId;
            acc.Covering_AE__c = coverae;
            accountsToUpdate.add(acc);
        }
        
        if (!accountsToUpdate.isEmpty()) {
            
            Database.SaveResult[] SRlist = Database.update(accountsToUpdate, false);
        
        
        for(integer i = 0; i < accountsToUpdate.size(); i++){
            String msg = '';
            if(!SRlist[i].isSuccess()){
                msg += SRlist.get(i).id + '\n' + 'Error: "';
                for(Database.Error er: SRlist[i].getErrors()){
                    msg += er.getmessage()+'"\n\n';
                }
                system.debug(msg);
                errorRecordIds.add(SRlist.get(i).id);
            }
            else {
                successfulRecordIds.add(SRlist.get(i).id);
            }
        }
            }
// logic for logging AE covering.                   
        Date today = System.today();
        List<AE_Covering_Log__c> logObjects = new List<AE_Covering_Log__c>();
         // Error Records
          if (!errorRecordIds.isEmpty()) {
            for (String recordId : errorRecordIds) {
                AE_Covering_Log__c errorObj = new AE_Covering_Log__c();
               errorObj.AccountId__c = recordId;
               errorObj.AE_Name__c = oldOwnerId;
               errorObj.Proxy_AE_Name__c = newOwnerId;
               errorObj.Log_Date__c = today;
               errorObj.Log_Message__c = 'Error';
                logObjects.add(errorObj);
            }       }
         // successful Records
     if (!successfulRecordIds.isEmpty()) {
        for (String recordId : successfulRecordIds) {
                AE_Covering_Log__c logObj = new AE_Covering_Log__c();
               logObj.AccountId__c = recordId;
               logObj.AE_Name__c = oldOwnerId;
               logObj.Proxy_AE_Name__c = newOwnerId;
               logObj.Log_Date__c = today;
               logObj.Log_Message__c = 'Success';
              logObjects.add(logObj);
        } }
   if (!logObjects.isEmpty()) {   
     insert logObjects;
     system.debug(logObjects);
}

    }
    
    public void finish(Database.BatchableContext bc) {

    }
}