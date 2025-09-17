/**
 * @description add your description here
 * @Date 10 September 2025
 */

@isTest
private class ZohoInvoiceManagerTest {
    
    /**
     * Setup test data
     */
    @testSetup
    static void setupTestData() {
        // Create Account
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
        
        // Create Product
        Product__c testProduct = new Product__c(
            Name = 'Test Product'
            );
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
        
        // Create Product Subscriber
        Product_Subscriber__c testSubscriber = new Product_Subscriber__c(
            Account__c = testAccount.Id,
        Email__c = 'test@example.com',
        Product_Plan__c = testPlan.Id
            );
        insert testSubscriber;
        
        // Create Invoice
        // Create test Invoice for invoice functionality tests
        Invoice__c testInvoice = new Invoice__c(
            Product_Subscriber__c = testSubscriber.Id,
        Product_Plan__c = testPlan.Id,
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addMonths(1),
        Duration__c = 30,
        Price__c = 100.00,
        Discount__c = 10.00
            );
        insert testInvoice;
    }
    
    /**
     * Test successful invoice creation and sending
     */
    @isTest
    static void testCreateAndSendInvoiceSuccess() {
        // Get test data
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        // Set up mock response for customer creation
        Test.setMock(HttpCalloutMock.class, new ZohoInvoiceManagerMockSuccess());
        
        // Test
        Test.startTest();
        ZohoInvoiceManager.createAndSendInvoices(new List<String>{testInvoice.Id} );
        Test.stopTest();
        
        // Verify invoice status updated
        Invoice__c updatedInvoice = [SELECT Status__c FROM Invoice__c WHERE Id = :testInvoice.Id];
        System.assertEquals('Sent', updatedInvoice.Status__c, 'Invoice status should be updated to Sent');
    }
    
    /**
     * Test invoice creation with existing Zoho IDs
     */
    @isTest
    static void testCreateInvoiceWithExistingZohoIds() {
        // Get test data and set Zoho IDs
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        testAccount.Zoho_Customer_Id__c = 'existing_customer_123';
        update testAccount;
        
        Product_Plan__c testPlan = [SELECT Id FROM Product_Plan__c LIMIT 1];
        testPlan.Zoho_Item_Id__c = 'existing_item_123';
        update testPlan;
        
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        // Set up mock response for invoice creation only
        Test.setMock(HttpCalloutMock.class, new ZohoInvoiceManagerMockExistingIds());
        
        // Test
        Test.startTest();
        ZohoInvoiceManager.createAndSendInvoices(new List<String>{testInvoice.Id});
        Test.stopTest();
        
        // Verify invoice status updated
        Invoice__c updatedInvoice = [SELECT Status__c FROM Invoice__c WHERE Id = :testInvoice.Id];
        System.assertEquals('Sent', updatedInvoice.Status__c, 'Invoice status should be updated to Sent');
    } 
    
    /**
     * Mock class for successful operations
     */
    private class ZohoInvoiceManagerMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            
            if (request.getEndpoint().contains('/customers')) {
                // Customer creation response
                response.setStatusCode(201);
                response.setBody('{"code": 0, "message": "Customer created", "customer": {"customer_id": "new_customer_123"}}');
            } else if (request.getEndpoint().contains('/items')) {
                // Item creation response
                response.setStatusCode(201);
                response.setBody('{"code": 0, "message": "Item created", "item": {"item_id": "new_item_123"}}');
            } else if (request.getEndpoint().contains('/invoices') && request.getMethod() == 'POST' && !request.getEndpoint().contains('/email')) {
                // Invoice creation response
                response.setStatusCode(201);
                response.setBody('{"code": 0, "message": "Invoice created", "invoice": {"invoice_id": "new_invoice_123"}}');
            } else if (request.getEndpoint().contains('/email')) {
                // Email invoice response
                response.setStatusCode(200);
                response.setBody('{"code": 0, "message": "Invoice emailed successfully"}');
            }
            
            return response;
        }
    }
    
    /**
     * Mock class for existing Zoho IDs scenario
     */
    private class ZohoInvoiceManagerMockExistingIds implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            
            if (request.getEndpoint().contains('/invoices') && request.getMethod() == 'POST' && !request.getEndpoint().contains('/email')) {
                // Invoice creation response
                response.setStatusCode(201);
                response.setBody('{"code": 0, "message": "Invoice created", "invoice": {"invoice_id": "new_invoice_456"}}');
            } else if (request.getEndpoint().contains('/email')) {
                // Email invoice response
                response.setStatusCode(200);
                response.setBody('{"code": 0, "message": "Invoice emailed successfully"}');
            }
            
            return response;
        }
    }
    
    /**
     * Mock class for convert to open
     */
    private class ZohoInvoiceManagerMockConvertToOpen implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('{"code": 0, "message": "Status of the invoice has been changed to open."}');
            return response;
        }
    }
    
    /**
     * Mock class for update invoice
     */
    private class ZohoInvoiceManagerMockUpdate implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('{"code": 0, "message": "Invoice updated successfully"}');
            return response;
        }
    }
}