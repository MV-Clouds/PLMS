@IsTest
public class ZohoWebhookControllerTest {
    
    @IsTest
    static void testPostQuote() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/webhook/zoho/quote';
        
        Account acc = new Account(Name='Test Account');
        insert acc;

        Opportunity opp = new Opportunity(Name='Test Opportunity', StageName='Prospecting', CloseDate=System.today(), AccountId=acc.Id);
        insert opp;

        Quote q = new Quote(Name='Test Quote', Status='Draft', Contract_Start_Date__c=System.today(), OpportunityId=opp.Id);
        insert q;

        // get the quote number
        q = [SELECT QuoteNumber FROM Quote WHERE Id = :q.Id];
        String quoteNumber = q.QuoteNumber;

        String body = '{"estimate":{"reference_number":"'+quoteNumber+'","status_formatted":"Accepted"}}';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = res;
        
        ZohoWebhookController.handleZohoWebhook();
    }
    
    @IsTest
    static void testPostInvoice() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/webhook/zoho/invoice';
        
        // Setup related records
        Account acc = new Account(Name='Test Account');
        insert acc;

        // Create Custom Product__c (your lookup in Quote)
        Product__c prod = new Product__c(
            Name = 'Custom Product'
        );
        insert prod;

        Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = pricebookId,
            IsActive = true
        );
        upsert standardPricebook;

        // fetch mvproduct 
        Product__c mvProduct = [SELECT Id, Product__c FROM Product__c WHERE Name = 'Custom Product' LIMIT 1];

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = mvProduct.Product__c,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // Create Product Plan
        Product_Plan__c plan = new Product_Plan__c(
            Name = 'Basic Plan',
            Price__c = 99,
            Product__c = mvProduct.Id,
            Price_Book__c = standardPricebook.Id
        );
        insert plan;
        
        Product_Subscriber__c ps = new Product_Subscriber__c(
            Account__c = acc.Id,
            Product_Plan__c = plan.Id,
            Expiration_DateTime__c = System.now().addDays(5),
            Active__c = true
        );
        insert ps;
        
        Invoice__c inv = new Invoice__c(Status__c='Paid', Product_Subscriber__c=ps.Id, Start_Date__c = System.today());
        insert inv;

        inv = [SELECT Id, Name FROM Invoice__c WHERE Id = :inv.Id];

        String body = '{"invoice":{"reference_number":"'+inv.Name+'","status_formatted":"Paid"}}';
        req.requestBody = Blob.valueOf(body);
        
        RestContext.request = req;
        RestContext.response = res;
        
        ZohoWebhookController.handleZohoWebhook();
        ZohoWebhookController.sendEmail('Test');
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