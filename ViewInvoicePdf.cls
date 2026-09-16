public class ViewInvoicePdf {
    public String pdf {
        get {
            HttpRequest req = new HttpRequest();
            Http http = new Http();
            String invoiceId;
            
	        //PageReference tmp = ApexPages.currentPage();

            // Login and get sessionid to include in header
            req.setEndpoint('https://sandbox.billingplatform.com/quickbase_dev/rest/2.0/login');
            req.setHeader('Content-Type', 'text/plain');
            req.setMethod('POST');
            req.setBody('{ "username":"quickbasebilling@quickbase.com", "password":"BYVDxfL0yanntuVq" }');
            HTTPResponse res = http.send(req);
            System.debug(res.getBody());
            loginResponse wrapper = (loginResponse) JSON.deserialize(res.getBody(), loginResponse.class);
            String sessionId = wrapper.loginResponse[0].SessionID;
            System.debug('Sessionid: ' + sessionId);
            
            req = new HttpRequest();
            req.setHeader('sessionid', sessionId);
            
            //Map<String, String> pg = ApexPages.currentPage().getParameters();
            //System.debug(pg);
            //if (pg.get('id') != '') {
            //    invoiceId = pg.get('id');
            //}
			
            PageReference currentPage = ApexPages.currentPage();
            if (currentPage != null) {
                invoiceId = ApexPages.currentPage().getParameters().get('id');
            }
            
            //invoiceId = ApexPages.currentPage().getParameters().get('id');
            System.debug('invoiceid:' + invoiceId);
            //System.debug('id:' + ApexPages.currentPage().getParameters().get('id'));
            
            //invoiceId = '668420';
            req.setEndpoint('https://sandbox.billingplatform.com/quickbase_dev/rest/2.0/files/invoice/' + invoiceId + '/PdfFile');
            req.setMethod('GET');
            req.setHeader('Content-Type', 'text/plain');
            res = http.send(req);
            String body = req.getBody();
            System.debug('body:' + body);
            fileDownloadResponse pdfWrapper = (fileDownloadResponse) JSON.deserialize(res.getBody(), fileDownloadResponse.class);
            String pdfData = '';
            if (pdfWrapper != null && pdfWrapper.fileDownloadResponse != null) {
                List<cls_fileDownloadResponse> t2 = pdfWrapper.fileDownloadResponse;
                pdfData = pdfWrapper.fileDownloadResponse[0].Data;
            }
            else {
                pdfData = '';
            }
            req = new HttpRequest();
            req.setEndpoint('https://sandbox.billingplatform.com/quickbase_dev/rest/2.0/logout');
            req.setMethod('GET');

            return pdfData;
        }
    }
    
    public class loginResponse {
        public cls_loginResponse[] loginResponse;
    }
    class cls_loginResponse {
        public String SessionID;	//qIYsMgFsRbbXRUlxaLnTFWPxbdfCiYabkmBGvzgj
        public String ErrorCode;	//0
        public String ErrorText;
    }
    
    public class fileDownloadResponse {
        public cls_fileDownloadResponse[] fileDownloadResponse;
    }
    
    class cls_fileDownloadResponse {
        public String ErrorCode;
        public String ErrorText;
        public String ErrorElementfield;
        public String Filename;
        public String Data;
    }
}