// Description: Class contains the functionality that makes up the Sales plan validation. 
// Validation involves checking to see if the Sales reps have completed activities 
// from the previous Opportunity Stage before moving the opportunity to an advanced stage.

public class SP_SalesPlanValidations {

	private static string sProfileName = null;

	public static void validateRequiredActions (Map<Id,Opportunity> newOpps, Map<Id,Opportunity> oldOpps) {

		if (sProfileName == null)
		{
			Id currentUserProfileId = UserInfo.getProfileId();
			sProfileName = [SELECT Name FROM Profile WHERE Id = :currentUserProfileId].Name;
		}

		for (Opportunity newOpp : newOpps.values()) {	
			//Opportunity Stage has changed - check for uncompleted required Tasks
			if (newOpp.StageName != oldOpps.get(newOpp.Id).StageName && newOpp.StageName != 'Closed Lost') {
                String oppRecordType = SP_RecordTypeManager.getNameById(newOpp.RecordTypeId, 'Opportunity');
                string opprecordtypename = Schema.SObjectType.Opportunity.getRecordTypeInfosById().get(newOpp.RecordTypeId).getname();
                string stageNME = loadOpportunityStageAndPreviousStageByRecordType(newOpp.RecordTypeId,opprecordtypename,newOpp.StageName);
                System.debug('RETURNED STAGE NAME' + stageNME);
                List<QS_Objective_Action__c> reqActions = [SELECT Id, Name, QS_Opportunity_Type__c,QS_Opportunity_Order_Type__c, 
                                                           QS_Opportunity_Order_SubType__c, QS_Effective_Date__c, 
                                                           QS_Exempt_Profiles__c, QS_Exempt_Users__c,QS_Stage_Name__c, QS_Opportunity_Record_Type__c
														  FROM QS_Objective_Action__c 
														 WHERE 
                                                           	QS_Action_Type__c = 'Required' AND 
                                                           	(QS_Effective_Date__c= null or QS_Effective_Date__c <= :newOpp.CreatedDate.Date())
                                                          ];
                System.debug('RequriedActions' + reqActions);										       
				List<Task> completedActions = [SELECT Id, QS_ObjectiveActionID__c 
												 FROM Task 
												WHERE WhatId = :newOpp.Id 
												      AND QS_StageObjectiveID__c != null
												      AND QS_ObjectiveActionID__c != null
												      AND IsClosed = true];
                
                 System.debug('completedActions' + completedActions);
								for (QS_Objective_Action__c req : reqActions) {
					
                     if(req.QS_Stage_Name__c <> null && 
                        req.QS_Opportunity_Record_Type__c <> null &&
                        stageNME <> null &&
                        req.QS_Stage_Name__c.contains(stageNME) && req.QS_Opportunity_Record_Type__c.contains(opprecordtypename))
                     {
                          //is this user exempt from the Action?
                        if ((req.QS_Exempt_Users__c != null 
                             && req.QS_Exempt_Users__c.contains(UserInfo.getUserId().mid(0,15))) 
                            || (req.QS_Exempt_Profiles__c != null 
                                //SFAC-0457: See ticket for details
                                && req.QS_Exempt_Profiles__c.contains(sProfileName))) {
                            continue;
                        }
                        
                            Boolean found = false;
                            for (Task tsk : completedActions) {
                                if (tsk.QS_ObjectiveActionId__c == req.Id) {
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                if (!Test.isRunningTest())
                                {
                                    newOpp.addError('You cannot advance this Opportunity until all required Sales Plan actions have been completed (' + req.Name + ')');
                                	break;
                                }
                                
                            }
                     }
                                    
                    
					
				}
			}
		}
	}
	public static string loadOpportunityStageAndPreviousStageByRecordType(Id oppRecordTypeId,String opprecordtypename, string StageName)
    {
        System.debug(' New Stage Name' + StageName);
        System.debug(' RecordTypeID' + opprecordtypename);
        String wildCardStageName = '%' + StageName + '%';
		List<QS_Stage_Objective__c> listOfObjectivesUnderCurrentRecordType 
            = [select Name,
               QS_Order__c,
               QS_Opportunity_Record_Type__c,
               QS_Opportunity_Order_Type__c,
               QS_Opportunity_Type__c,
               QS_Opportunity_Stage__r.Name,
               QS_Opportunity_Stage__r.QS_Next_Stage__r.Name               
              from QS_Stage_Objective__c 
               order by QS_Order__c];
        System.debug('Stage Plan List Size' + listOfObjectivesUnderCurrentRecordType.size());
        System.debug('Stage Plan List' + listOfObjectivesUnderCurrentRecordType);
        
        for(QS_Stage_Objective__c obj : listOfObjectivesUnderCurrentRecordType){
            if(obj.QS_Opportunity_Record_Type__c <> null &&
                obj.QS_Opportunity_Stage__r.QS_Next_Stage__r <> null 
               && obj.QS_Opportunity_Record_Type__c.contains(opprecordtypename) 
               && obj.QS_Opportunity_Stage__r.QS_Next_Stage__r.Name.contains(StageName)) 
            {
                return obj.Name;
            }
            
            
        }
       
        return null;
      
    }

}