public class AccountOwnerChangeBridge {
    @InvocableMethod(label='Update Account Owner' description='Updates account owner using batch Apex')
    public static void updateAccountOwner(List<UpdateAccountOwnerParams> paramsList) {
        if (paramsList != null && !paramsList.isEmpty()) {
            UpdateAccountOwnerParams params = paramsList[0];
            String oldOwnerId = params.oldOwnerId;
            String newOwnerId = params.newOwnerId;
            Boolean coverae = params.coverAE;
            Integer batchSize = 20; 
            UpdateAccountOwnerBatch batch = new UpdateAccountOwnerBatch(oldOwnerId, newOwnerId, coverae);
            Database.executeBatch(batch, batchSize);
        }
    }
    
    public class UpdateAccountOwnerParams {
        @InvocableVariable(label='Old Owner ID' description='The ID of the current account owner')
        public String oldOwnerId;
        
        @InvocableVariable(label='New Owner ID' description='The ID of the new account owner')
        public String newOwnerId;
        
        @InvocableVariable(label='Cover AE' description='Cover AE')
        public Boolean coverAE;
    }
}