@isTest
private class ProductVersionManagementControllerTest {

    @testSetup
    static void setup() {
        Product__c prod = new Product__c(Name = 'Test Product');
        insert prod;

        List<Product_Version__c> versions = new List<Product_Version__c>();
        for (Integer i = 0; i < 15; i++) {
            versions.add(new Product_Version__c(
                Name = 'Test Version ' + i,
                Product__c = prod.Id,
                Version_Number__c = '1.' + i,
                Type__c = 'Released',
                Release_Notes__c = 'Test Notes ' + i,
                Password__c = 'password' + i,
                Version_URL__c = 'http://test.com/' + i
            ));
        }
        insert versions;
    }

    @isTest
    static void testGetProducts() {
        Test.startTest();
        List<Product__c> products = ProductVersionManagementController.getProducts();
        Test.stopTest();

        System.assertEquals(1, products.size(), 'Should return one product.');
        System.assertEquals('Test Product', products[0].Name, 'Product name should be Test Product.');
    }

    @isTest
    static void testGetProductVersions() {
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        Test.startTest();
        ProductVersionManagementController.ProductVersionResult result = ProductVersionManagementController.getProductVersions(prod.Id);
        Test.stopTest();

        System.assertEquals(15, result.totalRecords, 'Total records should be 15.');
    }


    @isTest
    static void testGetProductVersions_NoResults() {
        Product__c newProd = new Product__c(Name = 'Empty Product');
        insert newProd;

        Test.startTest();
        ProductVersionManagementController.ProductVersionResult result = ProductVersionManagementController.getProductVersions(newProd.Id);
        Test.stopTest();

        System.assertEquals(0, result.versions.size(), 'Should return no versions.');
        System.assertEquals(0, result.totalRecords, 'Total records should be 0.');
    }
}