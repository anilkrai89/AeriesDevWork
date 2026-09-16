public class UpdateAccount {
@InvocableMethod(label='Update a product account in SMS' category='Quickbase')
    public static FlowOutput[] updateAccount(List<String> payloads) {
        //Map<String, Object> m = (Map<String, Object>)JSON.deserializeUntyped(payloads.get(0));
        //String prodAccountId = (String)m.get('id');
        //String payload = (String)m.get('data');
        SmsController.SmsResponse response = (SmsController.SmsResponse) SmsController.updateAccount(payloads.get(0));
        //List<String> message = new List<String>();
        //message.add(response.message);
        //return message;
        
        System.debug('message:' + response.message);
        
        FlowOutput[] results = new List<FlowOutput>();
        results.add(new FlowOutput(response.message));
        return results;
    }
    
    public class FlowOutput {
        @InvocableVariable public String message;
        public FlowOutput(String objName) {
            this.message = objName;
        }
    }
}