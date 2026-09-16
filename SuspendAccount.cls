public class SuspendAccount {
@InvocableMethod(callout=true label='Suspend a product account' category='Quickbase')
    public static List<String> suspend(List<String> accountIds) {
        system.debug('accountIds:' + accountIds);
        List<String> status = new List<String>();
        String res = SmsController.suspendAccount((String)accountIds[0]);
        status.add(res);
        return status;
    }
}