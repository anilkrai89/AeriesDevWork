public with sharing class UpdateHierarchyAccountsBatchLauncher {

    public class Request {
        @InvocableVariable(required=true)
        public String ultimateParentId;

        @InvocableVariable(required=true)
        public String segment;

        @InvocableVariable(required=true)
        public String territoryName;

        @InvocableVariable(required=true)
        public Id newOwnerId;
        
        @InvocableVariable(required=true)
        public String sdrOwnerId;

        // Optional: allow Flow to control batch chunk size
        @InvocableVariable
        public Integer batchSize;
    }

    public class Response {
        @InvocableVariable
        public String message;

        @InvocableVariable
        public Integer batchSizeUsed;
    }

    @InvocableMethod(
        label='Run UpdateHierarchyAccountsBatch'
        description='Launches UpdateHierarchyAccountsBatch using inputs from Flow.'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Request req = requests[0];

        // Basic validation (Flow can still pass blanks)
        if (String.isBlank(req.ultimateParentId)) {
            Response r = new Response();
            r.message = 'ultimateParentId is required.';
            responses.add(r);
            return responses;
        }
        if (String.isBlank(req.segment)) {
            Response r = new Response();
            r.message = 'segment is required.';
            responses.add(r);
            return responses;
        }
        if (String.isBlank(req.territoryName)) {
            Response r = new Response();
            r.message = 'territoryName is required.';
            responses.add(r);
            return responses;
        }
        if (req.newOwnerId == null) {
            Response r = new Response();
            r.message = 'newOwnerId is required.';
            responses.add(r);
            return responses;
        }
            if (req.sdrOwnerId == null) {
            Response r = new Response();
            r.message = 'newOwnerId is required.';
            responses.add(r);
            return responses;
        }

        Integer sizeToUse = (req.batchSize == null || req.batchSize <= 0) ? 200 : req.batchSize;

        // Launch the batch
        Database.executeBatch(
            new UpdateHierarchyAccountsBatch(
                req.ultimateParentId,
                req.segment,
                req.territoryName,
                req.newOwnerId,
                req.sdrOwnerId
            ),
            sizeToUse
        );

        Response ok = new Response();
        ok.message = 'UpdateHierarchyAccountsBatch submitted successfully.';
        ok.batchSizeUsed = sizeToUse;
        responses.add(ok);

        return responses;
    }
}