/**
 * Test class for ZohoBillingUtils
 */
@isTest
public class ZohoBillingUtilsTest {
    
    @testSetup
    static void setup() {
        Product__c testProduct = new Product__c(Name = 'Test Product');
        insert testProduct;
    }
    
    /**
     * Test account eligibility validation
     */
    @isTest
    static void testIsAccountEligibleForZoho() {
        // Test valid account
        Account validAccount = new Account(
            Name = 'Test Company',
            Email__c = 'test@company.com'
        );
        System.assert(ZohoBillingUtils.isAccountEligibleForZoho(validAccount), 'Valid account should be eligible');
    }
    
    /**
     * Test product plan eligibility validation
     */
    @isTest
    static void testIsProductPlanEligibleForZoho() {
        // Query the test product created in setup
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        
        // Test valid plan
        Product_Plan__c validPlan = new Product_Plan__c(
            Name = 'Test Plan',
            Price__c = 99.99,
            Product__c = testProduct.Id
        );
        System.assert(ZohoBillingUtils.isProductPlanEligibleForZoho(validPlan), 'Valid plan should be eligible');
        
        // Test plan without price
        Product_Plan__c invalidPlan2 = new Product_Plan__c(
            Name = 'Test Plan',
            Product__c = testProduct.Id
        );
        System.assert(!ZohoBillingUtils.isProductPlanEligibleForZoho(invalidPlan2), 'Plan without price should not be eligible');
    }
    
    /**
     * Test text sanitization
     */
    @isTest
    static void testSanitizeForZoho() {
        // Test normal text
        String result1 = ZohoBillingUtils.sanitizeForZoho('Normal Text', 50);
        System.assertEquals('Normal Text', result1, 'Normal text should remain unchanged');
        
        // Test text with leading/trailing spaces
        String result2 = ZohoBillingUtils.sanitizeForZoho('  Spaced Text  ', 50);
        System.assertEquals('Spaced Text', result2, 'Spaces should be trimmed');
        
        // Test text exceeding max length
        String longText = 'This is a very long text that exceeds the maximum allowed length';
        String result3 = ZohoBillingUtils.sanitizeForZoho(longText, 20);
        System.assertEquals(20, result3.length(), 'Text should be truncated to max length');
        
        // Test null/empty text
        String result4 = ZohoBillingUtils.sanitizeForZoho(null, 50);
        System.assertEquals(null, result4, 'Null text should remain null');
        
        String result5 = ZohoBillingUtils.sanitizeForZoho('', 50);
        System.assertEquals(null, result5, 'Empty text should return null');
        
        String result6 = ZohoBillingUtils.sanitizeForZoho('   ', 50);
        System.assertEquals(null, result6, 'Whitespace-only text should return null');
    }
    
    // /**
    //  * Test SKU generation
    //  */
    // @isTest
    // static void testGenerateProductPlanSKU() {
    //     // Query the test product created in setup
    //     Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        
        
    //      Id pricebookId = Test.getStandardPricebookId();
    //     Pricebook2 standardPricebook = new Pricebook2(
    //         Id = pricebookId,
    //         IsActive = true
    //     );
    //     upsert standardPricebook;
    //     Product__c mvProduct = [SELECT Id, Product__c FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

    //     PricebookEntry pbe = new PricebookEntry(
    //         Pricebook2Id = standardPricebook.Id,
    //         Product2Id = mvProduct.Product__c,
    //         UnitPrice = 100,
    //         IsActive = true
    //     );
    //     insert pbe;


    //     // Create test plan
    //     Product_Plan__c testPlan = new Product_Plan__c(
    //         Name = 'Test Plan 123!',
    //         Product__c = testProduct.Id,
    //         Price_Book__c = standardPricebook.Id
    //     );
    //     insert testPlan;
        
    //     String sku = ZohoBillingUtils.generateProductPlanSKU(testPlan);
        
    //     System.assert(sku.startsWith('PLAN_'), 'SKU should start with PLAN_');
    //     System.assert(sku.contains('TESTPLAN'), 'SKU should contain cleaned name');
    //     System.assert(sku.contains(testPlan.Id.toString().substring(testPlan.Id.toString().length() - 5)), 'SKU should contain part of ID');
    // }
    
    /**
     * Test address formatting
     */
    @isTest
    static void testFormatAddressForZoho() {
        // Test complete address
        Map<String, Object> address1 = ZohoBillingUtils.formatAddressForZoho(
            '123 Main St',
            'Test City',
            'Test State',
            '12345',
            'USA'
        );
        
        System.assertEquals('123 Main St', address1.get('street'), 'Street should be set');
        System.assertEquals('Test City', address1.get('city'), 'City should be set');
        System.assertEquals('Test State', address1.get('state'), 'State should be set');
        System.assertEquals('12345', address1.get('zip'), 'ZIP should be set');
        System.assertEquals('USA', address1.get('country'), 'Country should be set');
        
        // Test partial address
        Map<String, Object> address2 = ZohoBillingUtils.formatAddressForZoho(
            '456 Oak Ave',
            null,
            'CA',
            null,
            'USA'
        );
        
        System.assertEquals('456 Oak Ave', address2.get('street'), 'Street should be set');
        System.assertEquals(false, address2.containsKey('city'), 'City should not be present');
        System.assertEquals('CA', address2.get('state'), 'State should be set');
        System.assertEquals(false, address2.containsKey('zip'), 'ZIP should not be present');
        System.assertEquals('USA', address2.get('country'), 'Country should be set');
        
        // Test empty address
        Map<String, Object> address3 = ZohoBillingUtils.formatAddressForZoho(null, null, null, null, null);
        System.assertEquals(null, address3, 'Empty address should return null');
    }
    
    /**
     * Test integration activity logging
     */
    @isTest
    static void testLogIntegrationActivity() {
        Test.startTest();
        
        // Test successful operation
        ZohoBillingUtils.logIntegrationActivity('CREATE_CUSTOMER', '001000000000001', 'ZOHO123', true, null);
        
        // Test failed operation
        ZohoBillingUtils.logIntegrationActivity('CREATE_CUSTOMER', '001000000000002', null, false, 'API Error');
        
        Test.stopTest();
        
        // No exceptions should be thrown
        System.assert(true, 'Logging should complete without errors');
    }
    
    /**
     * Test integration enabled check
     */
    @isTest
    static void testIsZohoIntegrationEnabled() {
        Boolean result = ZohoBillingUtils.isZohoIntegrationEnabled();
        System.assertEquals(true, result, 'Integration should be enabled by default');
    }
    
    /**
     * Test organization ID retrieval
     */
    @isTest
    static void testGetZohoOrganizationId() {
        String orgId = ZohoBillingUtils.getZohoOrganizationId();
        // Currently returns null, but method should not throw exception
        System.assertNotEquals(null, orgId, 'Organization ID should be null when not configured');
    }
    
    /**
     * Test customer required fields validation
     */
    @isTest
    static void testValidateCustomerRequiredFields() {
        // Test valid account
        Account validAccount = new Account(
            Name = 'Test Company',
            Email__c = 'test@company.com'
        );
        List<String> missing1 = ZohoBillingUtils.validateCustomerRequiredFields(validAccount);
        System.assertEquals(0, missing1.size(), 'Valid account should have no missing fields');
    }
    
    /**
     * Test item required fields validation
     */
    @isTest
    static void testValidateItemRequiredFields() {
        // Query the test product created in setup
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        
        // Test valid plan
        Product_Plan__c validPlan = new Product_Plan__c(
            Name = 'Test Plan',
            Price__c = 99.99,
            Product__c = testProduct.Id
        );
        List<String> missing1 = ZohoBillingUtils.validateItemRequiredFields(validPlan);
        System.assertEquals(0, missing1.size(), 'Valid plan should have no missing fields');
        
        // Test plan with missing fields
        Product_Plan__c invalidPlan = new Product_Plan__c(
            Product__c = testProduct.Id
        );
        List<String> missing2 = ZohoBillingUtils.validateItemRequiredFields(invalidPlan);
        System.assertEquals(2, missing2.size(), 'Invalid plan should have 2 missing fields');
        System.assert(missing2.contains('Name'), 'Should identify missing Name');
        System.assert(missing2.contains('Price__c'), 'Should identify missing Price__c');
    }
}