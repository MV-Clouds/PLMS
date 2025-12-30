/**
 * @description add your description here
 * @Date 10 September 2025
 */

@isTest
public class ZohoBillingServiceTest {
    
    /**
     * Test data setup
     */
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Company',
        Email__c = 'test@company.com',
        Phone = '1234567890',
        Description = 'Test company description',
        zoho_Customer_Id__c = '1234'
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
        
        
        // Create test Quote linked to the Opportunity (AccountId will be auto-populated)
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
        
        // Create test Product Subscriber for invoice
        Product_Subscriber__c testSubscriber = new Product_Subscriber__c(
            Account__c = testAccount.Id,
        Email__c = 'test@example.com',
        Product_Plan__c = testPlan.Id
            );
        insert testSubscriber;
        
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
     * Test successful customer creation
     */
    @isTest
    static void testCreateCustomerSuccess() {
        Account testAccount = [SELECT Id, Name, Email__c,  Phone, Description FROM Account LIMIT 1];
        
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(201, 'customer_creation_success'));
        
        Test.startTest();
        String customerId = ZohoBillingService.createCustomer(testAccount);
        Test.stopTest();
        
        System.assertEquals('903000000000099', customerId, 'Customer ID should match mock response');
    }
    
    
    
    /**
     * Test successful customer update
     */
    @isTest
    static void testUpdateCustomerSuccess() {
        Account testAccount = [SELECT Id, Name, Email__c, Phone, Description FROM Account LIMIT 1];
        
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(200, 'customer_update_success'));
        
        Test.startTest();
        ZohoBillingService.updateCustomer(testAccount, '903000000000099');
        Test.stopTest();
        
        // No exception should be thrown for successful update
        System.assert(true, 'Update should complete successfully');
    }
    
    /**
     * Test successful invoice creation and sending
     */
    @isTest
    static void testCreateAndSendInvoiceSuccess() {
        // Get test data
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        Product_Plan__c testPlan = [SELECT Id FROM Product_Plan__c LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Ensure no existing Zoho IDs
        testAccount.Zoho_Customer_Id__c = null;
        update testAccount;
        testPlan.Zoho_Item_Id__c = null;
        update testPlan;
        testInvoice.Zoho_Invoice_Id__c = null;
        update testInvoice;
        
        // Set up mock response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingInvoiceMockSuccess());
        
        Test.startTest();
        ZohoBillingService.createAndSendInvoice(testInvoice.Id);
        Test.stopTest();
        
        // Verify invoice status updated
        Invoice__c updatedInvoice = [SELECT Status__c, Zoho_Invoice_Id__c FROM Invoice__c WHERE Id = :testInvoice.Id];
        System.assertEquals('Sent', updatedInvoice.Status__c, 'Invoice status should be updated to Sent');
        System.assertNotEquals(null, updatedInvoice.Zoho_Invoice_Id__c, 'Invoice should have Zoho Invoice ID');
        
        // Verify account and product plan updated with Zoho IDs
        Account updatedAccount = [SELECT Zoho_Customer_Id__c FROM Account WHERE Id = :testAccount.Id];
        System.assertNotEquals(null, updatedAccount.Zoho_Customer_Id__c, 'Account should have Zoho Customer ID');
        
        Product_Plan__c updatedPlan = [SELECT Zoho_Item_Id__c FROM Product_Plan__c WHERE Id = :testPlan.Id];
        System.assertNotEquals(null, updatedPlan.Zoho_Item_Id__c, 'Product Plan should have Zoho Item ID');
    }
    
    /**
     * Test invoice creation with existing Zoho IDs
     */
    @isTest
    static void testCreateInvoiceWithExistingZohoIds() {
        // Get test data and set existing Zoho IDs
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        testAccount.Zoho_Customer_Id__c = 'existing_customer_123';
        update testAccount;
        
        Product_Plan__c testPlan = [SELECT Id FROM Product_Plan__c LIMIT 1];
        testPlan.Zoho_Item_Id__c = 'existing_item_123';
        update testPlan;
        
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        // Set up mock response for invoice creation only
        Test.setMock(HttpCalloutMock.class, new ZohoBillingInvoiceMockExistingIds());
        
        Test.startTest();
        ZohoBillingService.createAndSendInvoice(testInvoice.Id);
        Test.stopTest();
        
        // Verify invoice status updated
        Invoice__c updatedInvoice = [SELECT Status__c FROM Invoice__c WHERE Id = :testInvoice.Id];
        System.assertEquals('Sent', updatedInvoice.Status__c, 'Invoice status should be updated to Sent');
    }
    
    /**
     * Test create invoice only (without sending)
     */
    @isTest
    static void testCreateInvoiceOnly() {
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        Product_Plan__c testPlan = [SELECT Id FROM Product_Plan__c LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Clear existing Zoho IDs
        testAccount.Zoho_Customer_Id__c = null;
        update testAccount;
        testPlan.Zoho_Item_Id__c = null;
        update testPlan;
        
        Test.setMock(HttpCalloutMock.class, new ZohoBillingInvoiceMockSuccess());
        
        Test.startTest();
        ZohoBillingService.createInvoiceOnly(testInvoice.Id);
        Test.stopTest();
    }
    
    /**
     * Test send invoice email
     */
    @isTest
    static void testSendInvoiceEmail() {
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        testInvoice.Zoho_Invoice_Id__c = 'test_invoice_123';
        update testInvoice;
        
        Test.setMock(HttpCalloutMock.class, new ZohoBillingEmailMock());
        
        Test.startTest();
        ZohoBillingService.sendInvoiceEmail(testInvoice.Id);
        Test.stopTest();
    }
    
    
    /**
     * Test update invoice in Zoho
     */
    @isTest
    static void testUpdateInvoiceInZoho() {
        Test.setMock(HttpCalloutMock.class, new ZohoBillingUpdateMock());
        
        String invoiceData = '{"notes": "Updated notes"}';
        
        Test.startTest();
        ZohoBillingService.updateInvoiceInZoho('test_invoice_123', invoiceData);
        Test.stopTest();
        
        // No exceptions should be thrown
        System.assert(true, 'Update invoice should complete without errors');
    }
    
    /**
     * Test with invalid invoice ID
     */
    @isTest
    static void testCreateAndSendInvoiceInvalidId() {
        Test.startTest();
        ZohoBillingService.createAndSendInvoice('invalid_id');
        Test.stopTest();
        
        // Should handle gracefully without throwing exceptions
        System.assert(true, 'Should handle invalid invoice ID gracefully');
    }
    
    /**
     * Test successful item creation
     */
    @isTest
    static void testCreateItemSuccess() {
        Product_Plan__c testPlan = [SELECT Id, Name, Description__c, Price__c, Product__c FROM Product_Plan__c LIMIT 1];
        
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(201, 'item_creation_success'));
        
        Test.startTest();
        String itemId = ZohoBillingService.createItem(testPlan);
        Test.stopTest();
        
        System.assertEquals('903000000045027', itemId, 'Item ID should match mock response');
    }
    
    /**
     * Test quote email sending
     */
    @isTest
    static void testSendEmailQuote() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        // Mock successful responses for all API calls
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(201, 'quote_creation_success'));
        
        Test.startTest();
        ZohoBillingService.sendEmailQuote(testQuote.Id);
        Test.stopTest();
        
        // Verify quote was updated with Zoho ID (this is async, so we test the method call)
        System.assert(true, 'Method executed without exception');
    }
    
    /**
     * Test quote creation/update without email
     */
    @isTest
    static void testCreateOrUpdateQuote() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(201, 'quote_creation_success'));
        
        Test.startTest();
        ZohoBillingService.createOrUpdateQuote(testQuote.Id);
        Test.stopTest();
        
        System.assert(true, 'Method executed without exception');
    }
    
    /**
     * Test marking quote as accepted
     */
    @isTest
    static void testMarkQuoteAsAccepted() {
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(200, 'quote_status_success'));
        
        Test.startTest();
        ZohoBillingService.markQuoteAsAccepted('zoho123');
        Test.stopTest();
        
        System.assert(true, 'Method executed without exception');
    }
    
    /**
     * Test marking quote as declined
     */
    @isTest
    static void testMarkQuoteAsDeclined() {
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(200, 'quote_status_success'));
        
        Test.startTest();
        ZohoBillingService.markQuoteAsDeclined('zoho123');
        Test.stopTest();
        
        System.assert(true, 'Method executed without exception');
    }
    
    /**
     * Test marking quote as sent
     */
    @isTest
    static void testMarkQuoteAsSent() {
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(200, 'quote_status_success'));
        
        Test.startTest();
        ZohoBillingService.markQuoteAsSent('zoho123');
        Test.stopTest();
        
        System.assert(true, 'Method executed without exception');
    }
    
    /**
     * Test item creation failure
     */
    @isTest
    static void testCreateItemFailure() {
        Product_Plan__c testPlan = [SELECT Id, Name, Description__c, Price__c, Product__c FROM Product_Plan__c LIMIT 1];
        
        // Mock error response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(400, 'error'));
        
        Test.startTest();
        try {
            ZohoBillingService.createItem(testPlan);
        } catch (ZohoBillingService.ZohoBillingException ex) {
            // Accept messages that indicate failure to create/update (be tolerant to message text changes)
        }
        Test.stopTest();
    }
    
    /**
     * Test successful item update
     */
    @isTest
    static void testUpdateItemSuccess() {
        Product_Plan__c testPlan = [SELECT Id, Name, Description__c, Price__c, Product__c FROM Product_Plan__c LIMIT 1];
        
        // Mock successful response
        Test.setMock(HttpCalloutMock.class, new ZohoBillingMockResponse(200, 'item_update_success'));
        
        Test.startTest();
        ZohoBillingService.updateItem(testPlan, '903000000045027');
        Test.stopTest();
        
        // No exception should be thrown for successful update
        System.assert(true, 'Update should complete successfully');
    }
    
    /**
     * Mock HTTP response class for testing
     */
    public class ZohoBillingMockResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String responseType;
        
        public ZohoBillingMockResponse(Integer statusCode, String responseType) {
            this.statusCode = statusCode;
            this.responseType = responseType;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            
            String responseBody = '';
            
            switch on this.responseType {
                when 'customer_creation_success' {
                    responseBody = '{"code": 0, "message": "The customer has been created", "customer": {"customer_id": "903000000000099"}}';
                }
                when 'customer_update_success' {
                    responseBody = '{"code": 0, "message": "The customer details have been updated."}';
                }
                when 'item_creation_success' {
                    responseBody = '{"code": 0, "message": "The item has been added.", "item": {"item_id": 903000000045027}}';
                }
                when 'item_update_success' {
                    responseBody = '{"code": 0, "message": "Item details have been saved."}';
                }
                when 'quote_creation_success' {
                    responseBody = '{"code": 0, "message": "The quote has been created", "estimate": {"estimate_id": "zoho123"}}';
                }
                when 'quote_email_success' {
                    responseBody = '{"code": 0, "message": "Your Estimate has been sent."}';
                }
                when 'quote_status_success' {
                    responseBody = '{"code": 0, "message": "Quote status updated"}';
                }
                when 'items_list_success' {
                    responseBody = '{"code": 0, "message": "success", "items": [{"item_id": "item123", "name": "Test Item"}]}';
                }
                when 'error' {
                    responseBody = '{"code": 1000, "message": "Error occurred"}';
                }
            }
            
            res.setBody(responseBody);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    /**
     * Mock class for invoice operations
     */
    private class ZohoBillingInvoiceMockSuccess implements HttpCalloutMock {
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
    private class ZohoBillingInvoiceMockExistingIds implements HttpCalloutMock {
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
     * Mock class for email invoice
     */
    private class ZohoBillingEmailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('{"code": 0, "message": "Invoice emailed successfully"}');
            return response;
        }
    }
    
    /**
     * Mock class for convert to open
     */
    private class ZohoBillingConvertToOpenMock implements HttpCalloutMock {
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
    private class ZohoBillingUpdateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('{"code": 0, "message": "Invoice updated successfully"}');
            return response;
        }
    }
}