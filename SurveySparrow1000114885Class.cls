public class SurveySparrow1000114885Class {
        @future(callout=true)
        public static void makeCallout(String endpoint, String method, String jsonS) {
            HttpRequest request = new HttpRequest();
            request.setEndPoint(endpoint);
            request.setBody(jsonS);
            request.setHeader('content-type', 'application/json');
            String authorizationHeader = 'BEARER pdEm0yRjb_dHwlOpkAHisCt-LxT1IJIVtae4_CBjQm8D_nADu7S8vX6ft2rrZ0BxFEUst44OY25HNu8q_I6HRrqQ';
            request.setMethod(method);
            request.setHeader('Authorization', authorizationHeader);
            HttpResponse response = new HTTP().send(request);
            System.debug('response Succesful'+response);
        }
      }