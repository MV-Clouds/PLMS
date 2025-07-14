@isTest
private class ProductPlanManagementControllerTest {

    @testSetup
    static void setup() {
        Product__c prod = new Product__c(Name = 'Test Product');
        insert prod;

        List<Product_Plan__c> plans = new List<Product_Plan__c>();
        for (Integer i = 0; i < 15; i++) {
            plans.add(new Product_Plan__c(
                Name = 'Test Plan ' + i,
                Product__c = prod.Id,
                Price__c = 10.0 * i,
                Description__c = 'Test Description ' + i
            ));
        }
        insert plans;
    }

    @isTest
    static void testGetProducts() {
        Test.startTest();
        List<Product__c> products = ProductPlanManagementController.getProducts();
        Test.stopTest();

        System.assertEquals(1, products.size(), 'Should return one product.');
        System.assertEquals('Test Product', products[0].Name, 'Product name should be Test Product.');
    }

    @isTest
    static void testGetProductPlans() {
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        Test.startTest();
        ProductPlanManagementController.ProductPlanResult result = ProductPlanManagementController.getProductPlans(prod.Id);
        Test.stopTest();

        System.assertEquals(15, result.totalRecords, 'Total records should be 15.');
    }

   
    @isTest
    static void testGetProductPlans_NoResults() {
        Product__c newProd = new Product__c(Name = 'Empty Product');
        insert newProd;

        Test.startTest();
        ProductPlanManagementController.ProductPlanResult result = ProductPlanManagementController.getProductPlans(newProd.Id);
        Test.stopTest();

        System.assertEquals(0, result.totalRecords, 'Total records should be 0.');
    }
    
   
}