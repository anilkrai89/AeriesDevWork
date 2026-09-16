@isTest
global class SurveySparrowMockHttpResponseGenerator implements HttpCalloutMock {
    // Implement this interface method
    global HTTPResponse respond(HTTPRequest req) {
        System.assertNotEquals(req.getEndpoint(), null);
        System.debug('line 6 inside mock call out');
        
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"example":"test"}');
        res.setStatusCode(200);
         System.debug('line 13 inside mock call out');
        return res;
    }
}