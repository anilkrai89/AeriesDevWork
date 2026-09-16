public class CaseMaskingBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    public Integer totalProcessed = 0;
    public Integer totalUpdated = 0;
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Description 
            FROM Case 
            WHERE CreatedDate >= YESTERDAY
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<Case> scope) {
        List<Case> toUpdate = new List<Case>();
        
        for(Case c : scope) {
            if(String.isBlank(c.Description)) continue;
            
            String original = c.Description;
            String masked = maskSensitiveData(original);
            
            if(masked != original) {
                c.Description = masked;
                toUpdate.add(c);
            }
        }
        
        if(!toUpdate.isEmpty()) {
            update toUpdate;
            totalUpdated += toUpdate.size();
        }
        totalProcessed += scope.size();
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('🏁 COMPLETED: Processed=' + totalProcessed + ', Updated=' + totalUpdated);
    }
    
    private String maskSensitiveData(String text) {
        if(String.isBlank(text)) return text;
        
        // Credit Cards
        Pattern cc = Pattern.compile('(?i)\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\\b');
        text = cc.matcher(text).replaceAll('****');
        
        // US Mobile
        Pattern us = Pattern.compile('\\b(?:(?:\\(?[2-9][0-9]{2}\\)?[-\\.\\s]?)?[2-9][0-9]{2}[-\\.\\s]?[0-9]{4})\\b');
        text = us.matcher(text).replaceAll('[US_MOBILE]');
        
        // India Mobile
        Pattern ind = Pattern.compile('\\b(?:(\\+?91|0)?[6-9]\\d{9})\\b');
        text = ind.matcher(text).replaceAll('[IN_MOBILE]');
        
        // API Keys (20+ chars)
        Pattern api = Pattern.compile('\\b(?:sk-|ak-|x-api-)?[A-Za-z0-9_\\-]{20,}\\b');
        text = api.matcher(text).replaceAll('[MASKED_APIKEY]');
        
        return text;
    }
}