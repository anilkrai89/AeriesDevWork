/*
* Class that enables scheduling of the Batch job for Customer Asset Transaction Status updates. Only processes record which have the 'Process for Manual Run' as set to true.
*
* @see Schedulable
*/
global class CA2_CustomerAssetDetailStatusSchedule implements Schedulable {
    
    global void execute(SchedulableContext sc) {
        QS_Console__mdt cASettings = [select Id,QS_Enable_Manual_Batch_Run__c from QS_Console__mdt where MasterLabel=:System.Label.QS_Console_Master_Label];
        CA2_CustomerAssetDetailBatchable_Manual bManual = new CA2_CustomerAssetDetailBatchable_Manual();
        CA2_CustomerAssetDetailStatusbatchable b = new CA2_CustomerAssetDetailStatusBatchable();
        if (cASettings.QS_Enable_Manual_Batch_Run__c)
        {
            database.executeBatch(bManual);
        }else
        {
            database.executeBatch(b);
        }
        
        
    }
}