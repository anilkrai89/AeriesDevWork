public class SP_sCollection {

/*
    This class provides static methods to convert sObject lists into maps and
    sets that are keyed to any String or Id field value from that sObject. 
    There are methods to accept the field argument as either a string or an
    sObjectField token.
*/
    
    public static set<Id> idSet(list<sObject> sObjs,sObjectField field){
        set<Id> fieldSet = new set<Id>();
        for(sObject sObj:sObjs){
            fieldSet.add((Id) sObj.get(field));
        }
        return fieldSet;
    }
    
    public static set<Id> idSet(list<sObject> sObjs,String field){
        set<Id> fieldSet = new set<Id>();
        for(sObject sObj:sObjs){
            fieldSet.add((Id) sObj.get(field));
        }
        return fieldSet;
    }

public static map<Id,list<sObject>> idListMap (list<sObject> sObjs,sObjectField idField){
        map<Id,list<sObject>> listMap = new map<Id,list<sObject>>();
        for(sObject sObj:sObjs){
            Id sObjId = (Id) sObj.get(idField);
            list<sObject> temp = listMap.get(sObjId)==null ? new list<sObject>() : listMap.get(sObjId);
            temp.add(sObj);
            listMap.put(sObjId,temp);
        }
        return listMap;
    }
    
    public static map<Id,list<sObject>> idListMap (list<sObject> sObjs,String idField){
        map<Id,list<sObject>> listMap = new map<Id,list<sObject>>();
        for(sObject sObj:sObjs){
            Id sObjId = (Id) sObj.get(idField);
            list<sObject> temp = listMap.get(sObjId)==null ? new list<sObject>() : listMap.get(sObjId);
            temp.add(sObj);
            listMap.put(sObjId,temp);
        }
        return listMap;
    }

        public static map<String,list<sObject>> stringListMap (list<sObject> sObjs,sObjectField StringField){
        map<String,list<sObject>> listMap = new map<String,list<sObject>>();
        for(sObject sObj:sObjs){
            String sObjId = (String) sObj.get(StringField);
            list<sObject> temp = listMap.get(sObjId)==null ? new list<sObject>() : listMap.get(sObjId);
            temp.add(sObj);
            listMap.put(sObjId,temp);
        }
        return listMap;
    }
    
    public static map<String,list<sObject>> stringListMap (list<sObject> sObjs,String StringField){
        map<String,list<sObject>> listMap = new map<String,list<sObject>>();
        for(sObject sObj:sObjs){
            String sObjId = (String) sObj.get(StringField);
            list<sObject> temp = listMap.get(sObjId)==null ? new list<sObject>() : listMap.get(sObjId);
            temp.add(sObj);
            listMap.put(sObjId,temp);
        }
        return listMap;
    }


    public static map<Id,sObject> idMap(list<sObject> sObjs, sObjectField idField){
        map<Id,sObject> idMap = new map<Id,sObject>();
        for(sObject sObj:sObjs){
            idMap.put((Id) sObj.get(idField),sObj);
        }
        return idMap;
    }
    
    public static map<Id,sObject> idMap(list<sObject> sObjs,String idField){
        map<Id,sObject> idMap = new map<Id,sObject>();
        for(sObject sObj:sObjs){
            idMap.put((Id) sObj.get(idField),sObj);
        }
        return idMap;
    }
    
    

   
}