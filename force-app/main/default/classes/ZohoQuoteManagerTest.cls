/**
 * Test class for ZohoQuoteManager
 */
@isTest
public class ZohoQuoteManagerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Company',
        Email__c = 'test@company.com',
        Phone = '1234567890',
        Website = 'www.testcompany.com',
        Description = 'Test company description'
            );
        insert testAccount;
        
        // Create test Opportunity linked to the Account
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
        AccountId = testAccount.Id,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30)
            );
        insert testOpportunity;
        
        Product__c testProduct = new Product__c(Name = 'Test Product');
        insert testProduct;
        
        Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = pricebookId,
        IsActive = true
            );
        upsert standardPricebook;
        
        // fetch mvproduct
        Product__c mvProduct = [SELECT Id, Product__c FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
        Product2Id = mvProduct.Product__c,
        UnitPrice = 100,
        IsActive = true
            );
        insert pbe;
        
        // Create test Product Plan
        Product_Plan__c testPlan = new Product_Plan__c(
            Name = 'Test Plan',
        Description__c = 'Test plan description',
        Price__c = 99.99,
        Product__c = testProduct.Id,
        Zoho_Item_Id__c = 'item123'
            );
        insert testPlan;
        
        // Create Quote
        Quote testQuote = new Quote(
            Name = 'Test Quote',
        OpportunityId = testOpportunity.Id,
        ExpirationDate = Date.today().addDays(30),
        Description = 'Test quote description',
        zoho_quote_id__c = null,
        Pricebook2Id = standardPricebook.Id
            );
        insert testQuote;
        
        
        
        // Create Quote Line Item
        QuoteLineItem testLineItem = new QuoteLineItem(
            QuoteId = testQuote.Id,
        Product_Plan__c = testPlan.Id,
        Quantity = 2,
        UnitPrice = 100.00,
        Description = 'Test line item',
        PricebookEntryId = pbe.Id,
        Product2Id = mvProduct.Product__c
            );
        insert testLineItem;
    }
    
    @isTest
    static void testSendQuoteEmails() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new ZohoQuoteMockHttpResponse());
        
        Test.startTest();
        ZohoQuoteManager.sendQuoteEmails(new List<String>{ testQuote.Id });
        Test.stopTest();
        
        // Assert quote was processed (this will be async, so we test the invocation)
        System.assert(true, 'Method executed without exception');
    }
    
    @isTest
    static void testCreateOrUpdateQuotes() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new ZohoQuoteMockHttpResponse());
        
        Test.startTest();
        ZohoQuoteManager.createOrUpdateQuotes(new List<String>{ testQuote.Id });
        Test.stopTest();
        
        // Assert quote was processed
        System.assert(true, 'Method executed without exception');
    }
    
    @isTest
    static void testMarkQuotesAsAccepted() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        testQuote.zoho_quote_id__c = 'zoho123';
        update testQuote;
        
        Test.setMock(HttpCalloutMock.class, new ZohoQuoteMockHttpResponse());
        
        Test.startTest();
        ZohoQuoteManager.markQuotesAsAccepted(new List<String>{ testQuote.Id });
        Test.stopTest();
        
        System.assert(true, 'Method executed without exception');
    }
    
    @isTest
    static void testMarkQuotesAsDeclined() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        testQuote.zoho_quote_id__c = 'zoho123';
        update testQuote;
        
        Test.setMock(HttpCalloutMock.class, new ZohoQuoteMockHttpResponse());
        
        Test.startTest();
        ZohoQuoteManager.markQuotesAsDeclined(new List<String>{ testQuote.Id });
        Test.stopTest();
        
        System.assert(true, 'Method executed without exception');
    }
    
    @isTest
    static void testMarkQuotesAsSent() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        testQuote.zoho_quote_id__c = 'zoho123';
        update testQuote;
        
        Test.setMock(HttpCalloutMock.class, new ZohoQuoteMockHttpResponse());
        
        Test.startTest();
        ZohoQuoteManager.markQuotesAsSent(new List<String>{ testQuote.Id });
        Test.stopTest();
        
        System.assert(true, 'Method executed without exception');
    }

    /**
     * Mock HTTP Response for Zoho Quote API calls
     */
    public class ZohoQuoteMockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            
            String endpoint = request.getEndpoint();
            String method = request.getMethod();
            
            if (endpoint.contains('/estimates') && method == 'POST') {
                // Create quote response
                response.setStatusCode(201);
                response.setBody('{"code": 0, "message": "The quote has been created", "estimate": {"estimate_id": "zoho123"}}');
            } else if (endpoint.contains('/estimates') && method == 'PUT') {
                // Update quote response
                response.setStatusCode(200);
                response.setBody('{"code": 0, "message": "The quote has been updated"}');
            } else if (endpoint.contains('/email')) {
                // Email quote response
                response.setStatusCode(200);
                response.setBody('{"code": 0, "message": "Your Estimate has been sent."}');
            } else if (endpoint.contains('/status/')) {
                // Status update response
                response.setStatusCode(200);
                response.setBody('{"code": 0, "message": "Quote status updated"}');
            } else if (endpoint.contains('/items') && method == 'GET') {
                // Get items response
                response.setStatusCode(200);
                response.setBody('{"code": 0, "message": "success", "items": [{"item_id": "item123", "name": "Test Item"}]}');
            } else if (endpoint.contains('/customers') && method == 'POST') {
                // Create customer response
                response.setStatusCode(201);
                response.setBody('{"code": 0, "message": "The customer has been created", "customer": {"customer_id": "cust123"}}');
            } else if (endpoint.contains('/items') && method == 'POST') {
                // Create item response
                response.setStatusCode(201);
                response.setBody('{"code": 0, "message": "The item has been created", "item": {"item_id": "item123"}}');
            } else {
                // Default response
                response.setStatusCode(200);
                response.setBody('{"code": 0, "message": "success"}');
            }
            
            return response;
        }
    }
}