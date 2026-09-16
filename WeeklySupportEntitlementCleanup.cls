/********************************************************************************* 
ClassName : WeeklySupportEntitlementCleanup
Test Class: WeeklySupportEntitlementCleanup_Test
==================================================================================
Req:Confirm Removal of Tech Support High Level of Support with Services Upon Cancellation/Non-Renewal.
Sol :When all entitled Product Accounts for an Account are cancelled (and not exceptions),
it removes support tier entitlement, clears related support fields on Contacts, and emails a CSV audit report
==================================================================================
History
---------------------------------------------------------------------------------
APIVERSION	  AUTHOR	     DATE	       Jira Ticket No
   62       Anil Kumar    17-Feb-2026     TEAMS-6009


*********************************************************************************/ 

global class WeeklySupportEntitlementCleanup implements Schedulable {
    @TestVisible static Set<Id> TEST_paIdsChanged;
    @TestVisible static Datetime TEST_cutoff;
    
    private static List<String> getReportRecipients() {
        String raw = System.Label.EmailRecipients;
        if (String.isBlank(raw)) return new List<String>();
        
        List<String> recipients = new List<String>();
        for (String s : raw.split('[,;\\s]+')) { // comma, semicolon, or whitespace
            if (String.isNotBlank(s)) recipients.add(s.trim());
        }
        return recipients;
    }
    
    private static final Boolean SET_TIER_TO_CORE_INSTEAD_OF_NULL = false;
    
    global void execute(SchedulableContext sc) {
        
        //Datetime cutoff = Datetime.newInstance(2026, 2, 12, 0, 0, 0);
        Datetime cutoff = (Test.isRunningTest() && TEST_cutoff != null)
            ? TEST_cutoff
            : Datetime.newInstance(2026, 2, 12, 0, 0, 0);
        
        Set<String> fromStatuses = new Set<String>{ 'Active', 'Active Trial' };
            Set<String> toStatuses   = new Set<String>{ 'Pending Cancel', 'Cancelled' };
                
                // -------------------------------------------------------
                // 0) Get Status__c history rows since cutoff, filter transitions in Apex
                //    (No SOQL filter on OldValue/NewValue)
                // -------------------------------------------------------
                Map<Id, Product_Account__History> paIdToStatusChange = new Map<Id, Product_Account__History>();
        Set<Id> paIdsChanged = new Set<Id>();
        if (Test.isRunningTest() && TEST_paIdsChanged != null) {
            paIdsChanged.addAll(TEST_paIdsChanged);
        }
        
        for (Product_Account__History h : [
            SELECT ParentId, Field, OldValue, NewValue, CreatedDate
            FROM Product_Account__History
            WHERE Field = 'Status__c'
            AND CreatedDate >= :cutoff
            ORDER BY CreatedDate DESC
        ]) {
            if (h.ParentId == null) continue;
            if (paIdToStatusChange.containsKey(h.ParentId)) continue; // keep latest per PA
            
            String oldS = (h.OldValue == null) ? null : String.valueOf(h.OldValue);
            String newS = (h.NewValue == null) ? null : String.valueOf(h.NewValue);
            
            if (oldS != null && newS != null && fromStatuses.contains(oldS) && toStatuses.contains(newS)) {
                paIdToStatusChange.put(h.ParentId, h);
                paIdsChanged.add(h.ParentId);
            }
        }
        
        if (paIdsChanged.isEmpty()) return;
        
        
        // -------------------------------------------------------
        // 1) Impacted accounts: only from NON-exception Product_Account__c rows
        // -------------------------------------------------------
        Set<Id> acctIds = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Account__c a
            FROM Product_Account__c
            WHERE Id IN :paIdsChanged
            AND EntitlementException__c = false
            AND Support_Tier__c IN ('Advanced','Signature','Core')
            AND Status__c ='Cancelled'
            GROUP BY Account__c
        ]) {
            acctIds.add((Id) ar.get('a'));
        }
        if (acctIds.isEmpty()) return;
        
        // Remove any accounts that still have an entitled ACTIVE/ACTIVE TRIAL row
        // (also respect exception flag here: exception rows should not keep an account "entitled")
        Set<Id> stillEntitled = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Account__c a
            FROM Product_Account__c
            WHERE Account__c IN :acctIds
            AND EntitlementException__c = false
            AND Support_Tier__c IN ('Advanced','Signature','Core')
            AND Status__c IN ('Active','Active Trial')
            GROUP BY Account__c
        ]) {
            stillEntitled.add((Id) ar.get('a'));
        }
        acctIds.removeAll(stillEntitled);
        if (acctIds.isEmpty()) return;
        
        // -------------------------------------------------------
        // 2) Update ONLY the changed NON-exception Product_Account__c rows + build CSV report
        // -------------------------------------------------------
        List<Product_Account__c> pasToUpdate = [
            SELECT Id, Account__c, Support_Tier__c, Status__c,
            Previous_SupportTierVal__c, EntitlementException__c
            FROM Product_Account__c
            WHERE Id IN :paIdsChanged
            AND Account__c IN :acctIds
            AND EntitlementException__c = false
            AND Support_Tier__c IN ('Advanced','Signature','Core')
            AND Status__c ='Cancelled'
        ];
        
        List<String> reportLines = new List<String>();
        reportLines.add(
            'Type,AccountId,RecordId,EntitlementException,StatusOld,StatusNew,StatusChangedAt,SupportTierOld,SupportTierNew,PreviousSupportTierFieldAfter,Notes'
        );
        
        for (Product_Account__c pa : pasToUpdate) {
            Product_Account__History h = paIdToStatusChange.get(pa.Id);
            
            String statusOld = (h != null && h.OldValue != null) ? String.valueOf(h.OldValue) : '';
            String statusNew = (h != null && h.NewValue != null) ? String.valueOf(h.NewValue) : '';
            String statusChangedAt = (h != null) ? String.valueOf(h.CreatedDate) : '';
            
            String tierOld = pa.Support_Tier__c;
            
            // Store previous tier (don’t overwrite if already captured)
            if (pa.Previous_SupportTierVal__c == null) {
                pa.Previous_SupportTierVal__c = pa.Support_Tier__c;
            }
            
            // Wipe/downgrade tier so it won't rank
            if (SET_TIER_TO_CORE_INSTEAD_OF_NULL) {
                pa.Support_Tier__c = 'Core';
            } else {
                pa.Support_Tier__c = null;
            }
            
            String tierNew = pa.Support_Tier__c;
            
            reportLines.add(csvLine(new List<String>{
                'Product_Account__c',
                    String.valueOf(pa.Account__c),
                    String.valueOf(pa.Id),
                    String.valueOf(pa.EntitlementException__c),
                    statusOld,
                    statusNew,
                    statusChangedAt,
                    tierOld,
                    tierNew,
                    pa.Previous_SupportTierVal__c,
                    'Tier updated; exception rows bypassed'
                    }));
        }
        
        if (!pasToUpdate.isEmpty()) update pasToUpdate;
        
        // -------------------------------------------------------
        // 3) Update Contacts (for impacted accounts) + append to report
        // -------------------------------------------------------
        List<Contact> cons = [
            SELECT Id, AccountId,
            Active_Services__c,
            Premium_Support_Contact__c,
            X24_7_Hand_off_Contact__c,
            Support_Level_Available__c
            FROM Contact
            WHERE AccountId IN :acctIds
            AND (Premium_Support_Contact__c = true
                 OR X24_7_Hand_off_Contact__c = true
                 OR Active_Services__c != null)
        ];
        
        for (Contact c : cons) {
            String beforeSupportLevel = c.Support_Level_Available__c;
            String before247 = String.valueOf(c.X24_7_Hand_off_Contact__c);
            String beforeServices = c.Active_Services__c;
            
            c.Support_Level_Available__c = '';
            c.X24_7_Hand_off_Contact__c = false;
            c.Active_Services__c = null;
            
            reportLines.add(csvLine(new List<String>{
                'Contact',
                    String.valueOf(c.AccountId),
                    String.valueOf(c.Id),
                    '', // exception N/A
                    '', '', '',
                    '', '', '',
                    '',
                    'Support_Level_Available: "' + safeInline(beforeSupportLevel) + '" -> "" ; ' +
                    'X24_7_Hand_off_Contact: ' + before247 + ' -> false ; ' +
                    'Active_Services: "' + safeInline(beforeServices) + '" -> null'
                    }));
        }
        
        if (!cons.isEmpty()) update cons;
        
        // -------------------------------------------------------
        // 4) Email report if any changes
        // -------------------------------------------------------
        if (reportLines.size() > 1) {
            sendReportEmail(reportLines);
        }
    }
    
    // ===== Email + CSV helpers =====
    
    private static void sendReportEmail(List<String> reportLines) {
        List<String> recipients = getReportRecipients();
        if (recipients.isEmpty()) return; // no recipients configured
        
        String csvBody = String.join(reportLines, '\n');
        
        Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
        att.setFileName('WeeklySupportEntitlementCleanup_Report_' + Date.today().format() + '.csv');
        att.setBody(Blob.valueOf(csvBody));
        att.setContentType('text/csv');
        
        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setToAddresses(recipients);
        msg.setSubject('Weekly Support Entitlement Cleanup Report - ' + Date.today().format());
        msg.setPlainTextBody(
            'Attached is the Excel-friendly CSV report of updates made by WeeklySupportEntitlementCleanup.\n' +
            'Product_Account__c rows with EntitlementException__c = true were bypassed.'
        );
        msg.setFileAttachments(new Messaging.EmailFileAttachment[] { att });
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { msg });
    }
    
    private static String csvLine(List<String> cols) {
        List<String> out = new List<String>();
        for (String c : cols) out.add(csvCell(c));
        return String.join(out, ',');
    }
    
    private static String csvCell(String v) {
        if (v == null) v = '';
        String escaped = v.replace('"', '""');
        if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n') || escaped.contains('\r')) {
            return '"' + escaped + '"';
        }
        return escaped;
    }
    
    private static String safeInline(String v) {
        if (v == null) return '';
        return v.replace('\n',' ').replace('\r',' ');
    }
}