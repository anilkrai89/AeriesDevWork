/**
* Util class that contains static methods and holds
* static sets with all the relevant fields that are maintained
* across Vista Asset handler classes.
* 
*/
public without sharing class CA2_CustomerAssetUtil {
    public static Boolean Create_CA_On_Update;
    public static Boolean ByPassTrigger;
    public static Boolean NoCADCreationFromOpp;
    public static Boolean ActivateTwinFielding;
    public static Decimal daysFromExpiration;
    static
    {
        QS_Console__mdt currentConsoleSettings = [select Id, QS_Generate_CA_on_Update__c,QS_Expiration_Days__c,
                                                  QS_Contracting_Opp_No_CAD_Creation__c,QS_Enable_Twin_Fielding__c,
                                                  QS_ByPass_Trigger__c 
                                                  from QS_Console__mdt where MasterLabel =: System.Label.QS_Console_Master_Label LIMIT 1 ];
        System.debug('VCG Debug CA2_CustomerAssetUtil' + currentConsoleSettings);
        Create_CA_On_Update = currentConsoleSettings.QS_Generate_CA_on_Update__c;
		ByPassTrigger = currentConsoleSettings.QS_ByPass_Trigger__c;      
        NoCADCreationFromOpp = currentConsoleSettings.QS_Contracting_Opp_No_CAD_Creation__c;
        ActivateTwinFielding = currentConsoleSettings.QS_Enable_Twin_Fielding__c;
        daysFromExpiration = currentConsoleSettings.QS_Expiration_Days__c;
    }
    
    public static Map<Id, Product2> queryProductsById(Set<Id> setProdIds) {
        if(setProdIds == null || setProdIds.isEmpty()) {
            return new Map<Id, Product2>();
        }
        return new Map<Id, Product2>([SELECT Id, SBQQ__PricingMethod__c, SBQQ__SubscriptionPricing__c
                                      FROM Product2 
                                      WHERE QS_Generate_Asset__c = true AND Id IN :setProdIds]);
    }
    
    public static List<QS_Customer_Asset__c> queryCAByUniqueId(Set<String> uniqueIdSet) {
        if(uniqueIdSet == null || uniqueIdSet.isEmpty()) {
            return new List<QS_Customer_Asset__c>();
        } 
        return [SELECT Id, QS_Product__c, QS_Customer_Asset_Unique_Id__c, QS_Quantity__c, QS_Product__r.QS_Generate_Asset__c 
                FROM QS_Customer_Asset__c 
                WHERE QS_Customer_Asset_Unique_Id__c IN :uniqueIdSet];
    }
    /**
* Private set that holds all the relevant fields for Subscriptions.
*/     
    public static Set<String> Subscription_CAUniqueId(List<SBQQ__Subscription__c> Subscriptions){         
        //Find the QS_Customer_Asset_Unique_Id__c from the Subscriptions
        List<SBQQ__Subscription__c> SubscriptionWithCustomerAsset = [SELECT id,QS_Customer_Asset_Unique_Id__c,QS_Booking_Date__c,QS_Parent_Customer_Asset_Id__c,QS_Customer_Asset_Account_Id__c FROM SBQQ__Subscription__c
                                                                     where id in :Subscriptions];       
        //Create the set of Id who have CustomerId
        Set<String> mapCustomerAsset = new Set<String>();
        for(SBQQ__Subscription__c s: SubscriptionWithCustomerAsset){
            mapCustomerAsset.add(s.QS_Customer_Asset_Unique_Id__c);
            
        }
        
        return mapCustomerAsset;
        
    }
    
    public static Set<String> getMatchingKeys(List<Asset> assets){
        //Find the QS_Customer_Asset_Unique_Id__c from the Assets
        //Create the set of Id who have CustomerId
        Set<String> uniqueIdSet = new Set<String>();
        for(Asset a: assets){
            if(!String.IsBlank(a.QS_Customer_Asset_Unique_Id__c)) {
                uniqueIdSet.add(a.QS_Customer_Asset_Unique_Id__c);
            }
        }
        return uniqueIdSet;
        
    }
    public static Set<String> getMatchingKeys(List<SBQQ__SubscribedAsset__c> subAssets){
        Set<String> uniqueIdSet = new Set<String>();
        for(SBQQ__SubscribedAsset__c a: subAssets){
            if(!String.IsBlank(a.QS_Customer_Asset_Unique_Id__c)) {
                uniqueIdSet.add(a.QS_Customer_Asset_Unique_Id__c);
            }
        }
        
        //Return the Customer Asset Id list                                                         
        return uniqueIdSet;                                                
        
    }
    
    public static QS_Customer_Asset_Detail__c CustomerAssetDetailStatus(QS_Customer_Asset_Detail__c cad, QS_Customer_Asset__c ca, Product2 product,Map<String,Decimal> mapCaIdToQuantity ){
        return CustomerAssetDetailStatus(null, cad, ca, product,mapCaIdToQuantity);
    }
    public static QS_Customer_Asset_Detail__c CustomerAssetDetailStatus(SBQQ__Subscription__c sub, QS_Customer_Asset_Detail__c cad, QS_Customer_Asset__c ca, Product2 product,Map<String,Decimal> mapCaIdToQuantity ){
        
        cad.QS_Currently_Active__c = getCurrentlyActiveflagFromCAD(cad); 
        return cad;
    }
    
    public static Boolean getCurrentlyActiveflagFromCAD(QS_Customer_Asset_Detail__c cad)
    {
        Date currentDate = System.today();
        if(cad.QS_New_Asset_Status__c == 'Expired')
        {
            return false;
        }
        else if(cad.QS_End_Date__c < currentDate)
        {
            return false;
        }    
        else if(cad.QS_End_Date__c >= currentDate && cad.QS_Start_Date__c <= currentDate)
        {
            return true;
        }
        else if(cad.QS_End_Date__c > currentDate && cad.QS_Start_Date__c > currentDate)
        {
            return false;
        }
        if(cad.QS_End_Date__c == null){
            return true;
        }
        else
        {
            return false;
        }
        
        
        
    }
    
    
}