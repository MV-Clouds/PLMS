@IsTest
public class ManagePLMSRecordsPageControllerTest {
    
    @TestSetup
    static void setupData() {
        // Create Account
        Account testAcc = new Account(Name = 'Test Account');
        insert testAcc;
        
        // Create Product
        Product__c testProduct = new Product__c(Name = 'Test Product');
        insert testProduct;
        
        // Create Product Plan
        Product_Plan__c testPlan = new Product_Plan__c(Name = 'Basic Plan', Product__c = testProduct.Id);
        insert testPlan;
        
        // Create Organization
        Organization__c testOrg = new Organization__c(
            Name = 'Test Org',
            Account__c = testAcc.Id
        );
        insert testOrg;
        
        // Create Product Subscriber
        Product_Subscriber__c testSub = new Product_Subscriber__c(
            Product__c = testProduct.Id,
            Organization__c = testOrg.Id,
            Active__c = true,
            Install_Date__c = Date.today(),
            Expiration_DateTime__c = System.now().addDays(30),
            Product_Plan__c = testPlan.Id
        );
        insert testSub;
        
        // Create Product Version
        Product_Version__c testVersion = new Product_Version__c(
            Name = 'v1.0',
            Product_Subscriber__c = testSub.Id,
            Installed_Date__c = Date.today(),
            Version_Number__c = '1.0',
            Product__c = testProduct.Id
        );
        insert testVersion;
        
        // Create Invoice
        Invoice__c testInv = new Invoice__c(
            Product_Subscriber__c = testSub.Id,
            Start_Date__c = Date.today(),
            Price__c = 100,
            Status__c = 'Sent'
        );
        insert testInv;
    }
    
    @IsTest
    static void testSearchAccounts() {
        Test.startTest();
        List<Account> results1 = ManagePLMSRecordsPageController.searchAccounts(null, 10);
        
        List<Account> results2 = ManagePLMSRecordsPageController.searchAccounts('Test', 10);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetOrganizationsByAccount() {
        Test.startTest();
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        List<Organization__c> orgs = ManagePLMSRecordsPageController.getOrganizationsByAccount(acc.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetOrganizationById() {
        Test.startTest();
        Organization__c testOrg = [SELECT Id FROM Organization__c WHERE Name = 'Test Org' LIMIT 1];
        Organization__c org = ManagePLMSRecordsPageController.getOrganizationById(testOrg.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetProductSubscribersByOrganization() {
        Test.startTest();
        Organization__c testOrg = [SELECT Id FROM Organization__c WHERE Name = 'Test Org' LIMIT 1];
        List<Product_Subscriber__c> subs = ManagePLMSRecordsPageController.getProductSubscribersByOrganization(testOrg.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetInvoicesByOrganization() {
        Test.startTest();
        Organization__c testOrg = [SELECT Id FROM Organization__c WHERE Name = 'Test Org' LIMIT 1];
        List<Invoice__c> invoices = ManagePLMSRecordsPageController.getInvoicesByOrganization(testOrg.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetProductVersionsBySubscriber() {
        Test.startTest();
        Product_Subscriber__c testSub = [SELECT Id FROM Product_Subscriber__c WHERE Active__c = true LIMIT 1];
        List<Product_Version__c> versions = ManagePLMSRecordsPageController.getProductVersionsBySubscriber(testSub.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetProductSubscriberById() {
        Test.startTest();
        Product_Subscriber__c testSub = [SELECT Id FROM Product_Subscriber__c WHERE Active__c = true LIMIT 1];
        Product_Subscriber__c sub = ManagePLMSRecordsPageController.getProductSubscriberById(testSub.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testUpdateProductSubscriberExpiry() {
        Test.startTest();
        Product_Subscriber__c testSub = [SELECT Id FROM Product_Subscriber__c WHERE Active__c = true LIMIT 1];
        Boolean success = ManagePLMSRecordsPageController.updateProductSubscriberExpiry(testSub.Id, Date.today().addDays(90).format());
        Test.stopTest();
    }
    
    @IsTest
    static void testUpdateProductSubscriberPlan() {
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        Product_Plan__c newPlan = new Product_Plan__c(Name = 'Premium Plan', Product__c = testProduct.Id);
        insert newPlan;
        Product_Subscriber__c testSub = [SELECT Id FROM Product_Subscriber__c WHERE Active__c = true LIMIT 1];
        
        Test.startTest();
        Boolean success = ManagePLMSRecordsPageController.updateProductSubscriberPlan(testSub.Id, newPlan.Id);
        Test.stopTest();
    }

    @IsTest
    static void testgetProductPlansByProduct() {
        Test.startTest();
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
        List<Product_Plan__c> res = ManagePLMSRecordsPageController.getProductPlansByProduct(testProduct.Id);
        Test.stopTest();
    }
}