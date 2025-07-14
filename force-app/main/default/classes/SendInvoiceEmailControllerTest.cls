@isTest
private class SendInvoiceEmailControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create a product
        Product__c product = new Product__c(Name = 'Test Product');
        insert product;

        // Create a subscriber linked to that product
        Product_Subscriber__c subscriber = new Product_Subscriber__c(
            Email__c     = 'test@subscriber.com',
            Org_Name__c  = 'Test Org',
            Product__c   = product.Id
        );
        insert subscriber;

        // Create an invoice linked to that subscriber
        Invoice__c invoice = new Invoice__c(
            Product_Subscriber__c = subscriber.Id,
            Additional_Recipient__c = 'cc@test.com'
        );
        insert invoice;
    }

    @isTest
    static void testGetInvoiceData_Success() {
        // Retrieve the test invoice
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];

        Test.startTest();
            Map<String, Object> result = SendInvoiceEmailController.getInvoiceData(inv.Id);
            SendInvoiceEmailController.test();
        Test.stopTest();
    }

    @isTest
    static void testGetInvoiceData_Exception() {
        Test.startTest();
        try {
            // Pass an invalid ID to cause the SOQL to fail
            SendInvoiceEmailController.getInvoiceData('001invalidID');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(),
                'Exception message should detail the SOQL error');
        }
        Test.stopTest();
    }
}