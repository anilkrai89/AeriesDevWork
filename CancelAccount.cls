public class CancelAccount {
@InvocableMethod(callout=true label='Cancel a product account' category='Quickbase')
    public static void cancel(List<String> accountIds) {
        SmsController.cancelAccount((String)accountIds.get(0));
    }
}