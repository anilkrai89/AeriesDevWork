public with sharing class CaseMilestoneController {

    @AuraEnabled(cacheable=true)
    public static List<CaseMilestoneWrapper> getMilestones(Id caseId) {
        if (caseId == null) {
            return new List<CaseMilestoneWrapper>();
        }

        List<CaseMilestoneWrapper> results = new List<CaseMilestoneWrapper>();

        for (CaseMilestone cm : [
            SELECT Id,
                   MilestoneType.Name,
                   TargetDate,
                   CompletionDate,
                   IsCompleted,
                   IsViolated,
                   TimeRemainingInMins
            FROM CaseMilestone
            WHERE CaseId = :caseId
            ORDER BY TargetDate ASC
        ]) {
            CaseMilestoneWrapper wrapper = new CaseMilestoneWrapper();
            wrapper.id = cm.Id;
            wrapper.milestoneName = cm.MilestoneType != null
                ? cm.MilestoneType.Name
                : 'Milestone';
            wrapper.targetDate = cm.TargetDate;
            wrapper.completionDate = cm.CompletionDate;
            wrapper.isCompleted = cm.IsCompleted;
            wrapper.isViolated = cm.IsViolated;
           wrapper.timeRemainingInMins = cm.TimeRemainingInMins;

            results.add(wrapper);
        }

        return results;
    }

    public class CaseMilestoneWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String milestoneName;
        @AuraEnabled public Datetime targetDate;
        @AuraEnabled public Datetime completionDate;
        @AuraEnabled public Boolean isCompleted;
        @AuraEnabled public Boolean isViolated;
        @AuraEnabled public String timeRemainingInMins;
    }
}