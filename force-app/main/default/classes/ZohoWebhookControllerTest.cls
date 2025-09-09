@IsTest
public class ZohoWebhookControllerTest {
    
    @IsTest
    static void testGetMethod() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.requestURI = '/services/apexrest/webhook/zoho/test-get';
        RestContext.request = req;
        RestContext.response = res;

        ZohoWebhookController.getProductSubscriber();
    }
    
    @IsTest
    static void testPostQuoteApproved() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/webhook/zoho/quote-approved';
        
        Account acc = new Account(Name='Test Account');
        insert acc;

        Opportunity opp = new Opportunity(Name='Test Opportunity', StageName='Prospecting', CloseDate=System.today(), AccountId=acc.Id);
        insert opp;

        Quote q = new Quote(Name='Test Quote', Status='Draft', Contract_Start_Date__c=System.today(), OpportunityId=opp.Id);
        insert q;

        // get the quote number
        q = [SELECT QuoteNumber FROM Quote WHERE Id = :q.Id];
        String quoteNumber = q.QuoteNumber;

        String body = '{"estimate":{"estimate_number":"'+quoteNumber+'","status_formatted":"Accepted"}}';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = res;
        
        ZohoWebhookController.handleZohoWebhook();
    }
    
    @IsTest
    static void testPostInvoicePaid() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/webhook/zoho/invoice-paid';
        
        // Setup related records
        Account acc = new Account(Name='Test Account');
        insert acc;

        Product__c prod = new Product__c(Name='Test Product');
        insert prod;

        PriceBook2 pb = new PriceBook2(Name='Standard Price Book', IsActive=true);
        insert pb;
        
        Product_Plan__c plan = new Product_Plan__c(Name='Test Plan', Product__c=prod.Id, Price__c=100);
        insert plan;
        
        Product_Subscriber__c ps = new Product_Subscriber__c(
            Account__c = acc.Id,
            Product_Plan__c = plan.Id,
            Expiration_DateTime__c = System.now().addDays(5),
            Active__c = true
        );
        insert ps;
        
        Invoice__c inv = new Invoice__c(Status__c='Paid', Product_Subscriber__c=ps.Id);
        insert inv;

        inv = [SELECT Id, Name FROM Invoice__c WHERE Id = :inv.Id];

        String body = '{"invoice":{"invoice_number":"'+inv.Name+'","status_formatted":"Paid"}}';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = res;
        
        ZohoWebhookController.handleZohoWebhook();
    }
    
    @IsTest
    static void testPostUnknownPath() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/webhook/zoho/something-else';
        
        String body = '{"random":"data"}';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = res;
        
        ZohoWebhookController.handleZohoWebhook();
    }
}
