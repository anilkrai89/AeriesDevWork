//Contains functionality to copy over Quote Data to Opportunity data. 
//Similar to the field twinning process. Uses Custom Metadata information to 
//identify the fields whose value needs to be moved


public class TwinField {

    public String sourceObjectType {
        get
        {
            return sourceObjectType;
        }
        set{
            sourceObjectType = value;
        }
        
    }    
    public String targetObjectType {
        get
        {
            return targetObjectType;
        }
        set{
            targetObjectType = value;
        }
        
    }
    public Map<String,String> mapOfSourceToTargetField
    {
        get
        {
            return mapOfSourceToTargetField;
        }
        set{
            mapOfSourceToTargetField = value;
        }
    }
    public List<QS_Field_Twinning_List__mdt> metadataTwinList
    {
        get {
            return metadataTwinList;
        }
        set{
            
            metadataTwinList = [select Id,DeveloperName,QS_Source_Field_Name__c,QS_Field_Name__c,QS_Source_Object__c,QS_Target_Object__c,QS_Exclude_Field__c from QS_Field_Twinning_List__mdt 
                                                          where QS_Exclude_Field__c =: false AND QS_Source_Object__c =: sourceObjectType AND QS_Target_Object__c =: targetObjectType] ; 
        }
        
    }
        
    public void initializeFieldTwinner(Id sourceId, Id targetId)
    {
        
        this.sourceObjectType = getSobjectType(sourceId);
        this.targetObjectType = getSobjectType(targetId);
       
        
        this.metadataTwinList = [select Id,DeveloperName,QS_Source_Field_Name__c,
                                 QS_Field_Name__c,QS_Source_Object__c,
                                 QS_Target_Object__c,QS_Exclude_Field__c 
                                 FROM QS_Field_Twinning_List__mdt 
                                 WHERE QS_Exclude_Field__c =: false 
                                 AND QS_Source_Object__c =: sourceObjectType 
                                 AND QS_Target_Object__c =: targetObjectType] ; 
        
        System.debug('VCG Debug metadataTwinList' + metadataTwinList.size());
        
        
        
    }
    
    @TestVisible
    public String getSobjectType(Id currentRecordId)
    {
        if(currentRecordId != null)
        {
            return String.valueOf(currentRecordId.getsobjecttype());
        }else
        {
            return null;
        }
        
    }
    @TestVisible
    public SObject transferValuesToTargetObject(SObject sourceObject, SObject targetObject)
    {
        
        Map<String,String> mapOfSourceToDestinationFields = new Map<String,String>();
        for(QS_Field_Twinning_List__mdt currentRecord : this.metadataTwinList)
        {
            mapOfSourceToDestinationFields.put(currentRecord.QS_Source_Field_Name__c,currentRecord.QS_Field_Name__c);
        }
		
        System.debug('VCG debug metadataTwinList -->' + metadataTwinList.size());
        System.debug('VCG debug mapOfSourceToDestinationFields -->' + mapOfSourceToDestinationFields.size());
        for(String fieldName : mapOfSourceToDestinationFields.keySet())
        {
            
            System.debug('VCG debug Target Object Contains Field --->' + targetObject.getSobjectType().getDescribe().fields.getMap().keySet().contains(mapOfSourceToDestinationFields.get(fieldName).toLowerCase()));
            System.debug('VCG debug Source Object Contains Field--->' + sourceObject.getSobjectType().getDescribe().fields.getMap().keySet().contains(fieldName.toLowerCase()));
            
            
            System.debug('VCG debug Target Field Value--->' + mapOfSourceToDestinationFields.get(fieldName));
            System.debug('VCG debug Source Field Value--->' + sourceObject.get(fieldName));
            
            
            if(sourceObject.getSobjectType().getDescribe().fields.getMap().keySet().contains(fieldName.toLowerCase())
               && targetObject.getSobjectType().getDescribe().fields.getMap().keySet().contains(mapOfSourceToDestinationFields.get(fieldName).toLowerCase()))
            {
                if(sourceObject.get(fieldName) != null && sourceObject.get(fieldName) != '')
                {
                    targetObject.put(mapOfSourceToDestinationFields.get(fieldName),sourceObject.get(fieldName));
                }
            }
        }
        return targetObject;
    }
}