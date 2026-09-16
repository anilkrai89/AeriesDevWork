//Description: Utility class which functions to retrieve record Id or name based on the object.


public class SP_RecordTypeManager{

    private static map<String,list<sObject>> rtsByObject = SP_sCollection.stringListMap([select Id, Name, DeveloperName, sObjectType, Description, BusinessProcessId 
                                                    from RecordType 
                                                    where isActive = true],RecordType.sObjectType);

   
    
    public static String getNameById(String rtId, String sObj) {
      map<String,sObject> rtsById = stringMap(rtsByObject.get(sObj), RecordType.Id);
      RecordType rt = (RecordType)rtsById.get((Id)rtId);
      System.debug(rt.Name);
      return rt.Name;
    }

    
    public static map<String,sObject> stringMap(list<sObject> sObjs,sObjectField stringField){
        map<String,sObject> stringMap = new map<String,sObject>();
        for(sObject sObj:sObjs){
            stringMap.put((String) sObj.get(stringField),sObj);
        }
        return stringMap;
    }
}