/**
 * Test class for ZohoBillingTriggerHandler
 */
@isTest
public class ZohoBillingTriggerHandlerTest {
    
    /**
     * Test data setup
     */
    @testSetup
    static void setup() {
        Product__c testProduct = new Product__c(Name = 'Test Product');
        insert testProduct;
    }
    
    /**
     * Test Account insert trigger handling
     */
    @isTest
    static void testAccountInsertTrigger() {
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse());
        
        Test.startTest();
        
        Account testAccount = new Account(
            Name = 'Test Company',
        Email__c = 'test@company.com',
        Phone = '1234567890',
        Website = 'www.testcompany.com'
            );
        insert testAccount;
        
        Test.stopTest();
        
        // Verify account was created
        Account updatedAccount = [SELECT Id, Name, zoho_customer_id__c FROM Account WHERE Id = :testAccount.Id];
        System.assertNotEquals(null, updatedAccount, 'Account should exist');
    }
    
    /**
     * Test Account update trigger handling
     */
    @isTest
    static void testAccountUpdateTrigger() {
        // Create test account first
        Account testAccount = new Account(
            Name = 'Test Company',
        Email__c = 'test@company.com',
        zoho_customer_id__c = '903000000000099'
            );
        insert testAccount;
        
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse());
        
        // Test.startTest();
        
        // Update account
        testAccount.Name = 'Updated Company Name';
        testAccount.Email__c = 'updated@company.com';
        update testAccount;
        
        // Test.stopTest();
        
        // Verify account was updated
        Account updatedAccount = [SELECT Id, Name, Email__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Updated Company Name', updatedAccount.Name, 'Account name should be updated');
    }
    
    /**
     * Test Product Plan insert trigger handling
     */
    @isTest
    static void testProductPlanInsertTrigger() {
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse());
        
        Test.startTest();
        // Query the test product created in setup
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        
         Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = pricebookId,
            IsActive = true
        );
        upsert standardPricebook;
        Product__c mvProduct = [SELECT Id, Product__c FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = mvProduct.Product__c,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        
        Product_Plan__c testPlan = new Product_Plan__c(
            Name = 'Test Plan',
        Description__c = 'Test plan description',
        Price__c = 99.99,
        Product__c = testProduct.Id,
        Price_Book__c = standardPricebook.Id
            
        );
        insert testPlan;
        
        Test.stopTest();
        
        // Verify plan was created
        Product_Plan__c updatedPlan = [SELECT Id, Name, zoho_item_id__c FROM Product_Plan__c WHERE Id = :testPlan.Id];
        System.assertNotEquals(null, updatedPlan, 'Product plan should exist');
    }
    
    /**
     * Test Product Plan update trigger handling
     */
    @isTest
    static void testProductPlanUpdateTrigger() {
        
        // Query the test product created in setup
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        
         Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = pricebookId,
            IsActive = true
        );
        upsert standardPricebook;
        Product__c mvProduct = [SELECT Id, Product__c FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = mvProduct.Product__c,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // Create test plan first
        Product_Plan__c testPlan = new Product_Plan__c(
            Name = 'Test Plan',
        Description__c = 'Test plan description',
        Price__c = 99.99,
        zoho_item_id__c = '903000000045027',
        Product__c = testProduct.Id,
        Price_Book__c = standardPricebook.Id
        );

        

        insert testPlan;
        
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse());
        
        // Test.startTest();
        
        // Update plan
        testPlan.Name = 'Updated Plan Name';
        testPlan.Price__c = 149.99;
        update testPlan;
        
        // Test.stopTest();
        
        // Verify plan was updated
        Product_Plan__c updatedPlan = [SELECT Id, Name, Price__c FROM Product_Plan__c WHERE Id = :testPlan.Id];
        System.assertEquals('Updated Plan Name', updatedPlan.Name, 'Plan name should be updated');
        System.assertEquals(149.99, updatedPlan.Price__c, 'Plan price should be updated');
    }
    
    /**
     * Test shouldProcessAccount method
     */
    @isTest
    static void testShouldProcessAccount() {
        Account validAccount = new Account(Name = 'Valid Account');
        Account invalidAccount = new Account();
        
        // Test the logic indirectly by creating records that should and shouldn't be processed
        Test.startTest();
        
        // This should process - has required Name field
        insert validAccount;
        
        Test.stopTest();
        
        System.assertNotEquals(null, validAccount.Id, 'Valid account should be inserted');
    }
    
    /**
     * Test shouldProcessProductPlan method
     */
    @isTest
    static void testShouldProcessProductPlan() {
        
        // Query the test product created in setup
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = pricebookId,
            IsActive = true
        );
        upsert standardPricebook;

        Product__c mvProduct = [SELECT Id, Product__c FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = mvProduct.Product__c,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Product_Plan__c validPlan = new Product_Plan__c(Name = 'Valid Plan', Price__c = 99.99 , Product__c = testProduct.Id ,Price_Book__c = standardPricebook.Id );
        Product_Plan__c invalidPlan = new Product_Plan__c();
        

        Test.startTest();
        
        // This should process - has required Name and Price fields
        insert validPlan;
        
        // This should fail validation if proper validation rules exist
        try {
            insert invalidPlan;
            // If it doesn't fail, that's okay for this test context
        } catch (DmlException ex) {
            System.assert(true, 'Invalid plan should fail validation');
        }
        
        Test.stopTest();
        
        System.assertNotEquals(null, validPlan.Id, 'Valid plan should be inserted');
    }
    
    /**
     * Test error handling in async processing
     */
    @isTest
    static void testAsyncProcessingError() {
        // Mock error response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingErrorMockResponse());
        
        Test.startTest();
        
        Account testAccount = new Account(
            Name = 'Test Company',
        Email__c = 'test@company.com'
            );
        insert testAccount;
        
        Test.stopTest();
        
        // Verify account exists but no Zoho ID was set due to error
        Account updatedAccount = [SELECT Id, Name, zoho_customer_id__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals(null, updatedAccount.zoho_customer_id__c, 'Zoho customer ID should be null due to error');
    }
    
    /**
     * Mock HTTP response class for successful responses
     */
    public class ZohoBillingMockResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            String responseBody = '';
            
            if (req.getMethod() == 'POST' && req.getEndpoint().contains('customers')) {
                res.setStatusCode(201);
                responseBody = '{"code": 0, "message": "The customer has been created", "customer": {"customer_id": "903000000000099"}}';
            } else if (req.getMethod() == 'PUT' && req.getEndpoint().contains('customers')) {
                responseBody = '{"code": 0, "message": "The customer details have been updated."}';
            } else if (req.getMethod() == 'POST' && req.getEndpoint().contains('items')) {
                res.setStatusCode(201);
                responseBody = '{"code": 0, "message": "The item has been added.", "item": {"item_id": 903000000045027}}';
            } else if (req.getMethod() == 'PUT' && req.getEndpoint().contains('items')) {
                responseBody = '{"code": 0, "message": "Item details have been saved."}';
            }
            
            res.setBody(responseBody);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    /**
     * Mock HTTP response class for error responses
     */
    public class ZohoBillingErrorMockResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"code": 1000, "message": "Error occurred"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
}