/**
* Description: Handles the trigger operations on the Customer Asset object.Includes logic to apply/clear out the decommission dates and also apply the end dates on the Customer Asset record.

*
* Functions:
* Name: processStatuses
* Description: Identifies all the CADs that are linked to an Customer Asset and determines the Status of the CA. 
* --If there is atleast one CAD that is Active, then the Status of the Asset remains Active. 
* --If it has a Quantity of 0 and has a decommissioned CAD record, then it is set to Decommissioned 
* --If it has Expired CADs and none Pending Activation or Renewal, then its set to Expired.
*/

public without sharing class CA2_CustomerAssetTriggerHandler extends CA2_TriggerHandler {
    
    protected override void beforeInsert() {
        updateName(Trigger.new);
    }
    
    protected override void beforeUpdate() {
        
        updateName(Trigger.new);
        processStatuses(Trigger.new, (Map<Id, QS_Customer_Asset__c>)Trigger.oldMap);
    }
    
    
    private void updateName(List<QS_Customer_Asset__c> newList) {
        for(QS_Customer_Asset__c ca: newList) {
            if(ca.QS_Customer_Asset_Name_Value__c != null)
                ca.Name = ca.QS_Customer_Asset_Name_Value__c.abbreviate(80);
            
        }
        
        
    }
    
    private void processStatuses(List<QS_Customer_Asset__c> newList, Map<Id, QS_Customer_Asset__c> oldMap) {
        //update the CAD that had been manually update
        Map<Id, QS_Customer_Asset__c> caMap = new Map<Id, QS_Customer_Asset__c>([SELECT Id,QS_Quantity__c,QS_Dynamic_Current_Date__c, 
                                                                                 (SELECT Id,QS_Quantity__c , QS_New_Asset_Status__c,
                                                                                  QS_Terminated_Date__c,CreatedDate, 
                                                                                  QS_Customer_Asset__c, QS_End_Date__c,
                                                                                  QS_Start_Date__c FROM QS_Customer_Asset_Details__r)
                                                                                 
                                                                                 FROM QS_Customer_Asset__c WHERE Id IN: newList]);
        for(QS_Customer_Asset__c ca: newList) {
            Boolean hasDecommission = false;
            Date effectiveEndDate;
            
            
            QS_Customer_Asset_Detail__c cadWithTheMostRecentServiceLevelAgreement;
            for(QS_Customer_Asset_Detail__c cad: caMap.get(ca.Id).QS_Customer_Asset_Details__r) {
                System.debug('VCG Debug Conditions:' + cad.QS_New_Asset_Status__c +' | '+ cad.QS_Quantity__c + ' | ' + cad.QS_End_Date__c + '|' + ca.QS_Dynamic_Current_Date__c);
                if(((cad.QS_New_Asset_Status__c == 'Decommissioned' || 
                     cad.QS_New_Asset_Status__c == 'Pending Decommission') 
                    && cad.QS_Quantity__c == 0 
                    && cad.QS_End_Date__c == ca.QS_Dynamic_Current_Date__c
                   ) || 
                   (cad.QS_Terminated_Date__c !=null && cad.QS_New_Asset_Status__c != 'Reduced' && cad.QS_New_Asset_Status__c != 'Expired' )) {
                       hasDecommission = true;
                       if(cad.QS_Terminated_Date__c !=null)
                           effectiveEndDate = cad.QS_Terminated_Date__c;
                       else
                           effectiveEndDate = cad.QS_Start_Date__c;
                   } 
            }
            if (hasDecommission && ca.QS_Quantity__c == 0) {
                ca.QS_Effective_Decommision_Date__c = effectiveEndDate;
            }
            QS_Customer_Asset__c oldCA = oldMap.get(ca.Id);
            if(oldCA.QS_New_Asset_Status__c == 'Decommissioned' && ca.QS_New_Asset_Status__c != 'Decommissioned')
            {
                ca.QS_Effective_Decommision_Date__c = null;
            }
            
            
        } 
    }   
}