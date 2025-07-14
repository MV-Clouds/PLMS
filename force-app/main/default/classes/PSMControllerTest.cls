@isTest
private class PSMControllerTest {

    @testSetup
    static void setup() {
        Product__c prod = new Product__c(Name = 'Test Product');
        insert prod;

        Product_Plan__c plan = new Product_Plan__c( Product__c = prod.Id ,Name = 'Test Plan', Price__c = 100);
        insert plan;

        List<Product_Subscriber__c> subscribers = new List<Product_Subscriber__c>();
        for (Integer i = 0; i < 5; i++) {
            subscribers.add(new Product_Subscriber__c(
                Product__c = prod.Id,
                Is_Trial__c = true
            ));
        }
        insert subscribers;
    }

    @isTest
    static void testGetProductSubscribers() {
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        Test.startTest();
        List<Product_Subscriber__c> subscribers = ProductSubscriberManagementController.getProductSubscribers(prod.Id);
        Test.stopTest();

        System.assertEquals(5, subscribers.size(), 'Should return five subscribers.');
    }

    @isTest
    static void testUpdateProductSubscriber_ToPaid() {
        Product_Subscriber__c subscriber = [SELECT Id FROM Product_Subscriber__c LIMIT 1];
        Product_Plan__c plan = [SELECT Id, Price__c FROM Product_Plan__c LIMIT 1];

        Test.startTest();
        Product_Subscriber__c updatedSubscriber = ProductSubscriberManagementController.updateProductSubscriber(subscriber.Id, false, plan.Id, 10, 12, Datetime.now().addMonths(1));
        Test.stopTest();
    }

    @isTest
    static void testUpdateProductSubscriber_ToTrial() {
        Product_Subscriber__c subscriber = [SELECT Id FROM Product_Subscriber__c LIMIT 1];
        Product_Plan__c plan = [SELECT Id FROM Product_Plan__c LIMIT 1];

        Test.startTest();
        Product_Subscriber__c updatedSubscriber = ProductSubscriberManagementController.updateProductSubscriber(subscriber.Id, true, null, 0, null, Datetime.now().addMonths(1));
        Test.stopTest();
    }

    @isTest
    static void testGetProductPlans() {
        Test.startTest();
        List<Product_Plan__c> plans = ProductSubscriberManagementController.getProductPlans();
        Test.stopTest();
    }

    @isTest
    static void testGetProducts() {
        Test.startTest();
        List<Product__c> prods = ProductSubscriberManagementController.getProducts();
        Test.stopTest();
    }
}