@isTest
private class InvoiceControllerTest {

    @isTest
    static void testInvoiceControllerWithValidId() {
        // Prepare related data
        Product__c product = new Product__c(Name = 'WBConnect');
        insert product;

        Product_Subscriber__c subscriber = new Product_Subscriber__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Email__c = 'john.doe@example.com',
            Address__c = '123 Test Street',
            Product__c = product.Id
        );
        insert subscriber;

        Invoice__c invoice = new Invoice__c(
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            Price__c = 1000,
            Discount__c = 10,
            Duration__c = 30,
            Status__c = 'Paid',
            Product_Subscriber__c = subscriber.Id
        );
        insert invoice;

        // Set the page parameter for the controller to pick up
        Test.startTest();
        ApexPages.currentPage().getParameters().put('id', invoice.Id);
        InvoiceController controller = new InvoiceController();
        Test.stopTest();
    }

    @isTest
    static void testInvoiceControllerWithMissingId() {
        Test.startTest();
        InvoiceController controller = new InvoiceController(); // No ID in params
        Test.stopTest();
    }

    @isTest
    static void testInvoiceControllerWithInvalidId() {
        Test.startTest();
        ApexPages.currentPage().getParameters().put('id', 'a0B000000000000'); // Assume invalid
        InvoiceController controller = new InvoiceController(); // Invalid Id
        Test.stopTest();
    }
}