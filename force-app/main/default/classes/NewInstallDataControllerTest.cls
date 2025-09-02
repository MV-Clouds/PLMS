@isTest
private class NewInstallDataControllerTest {

    @testSetup
    static void setupData() {
        Product__c testProduct = new Product__c(Name = 'WBConnect');
        insert testProduct;
    }

    @isTest
    static void testHandleInboundEmail_Install() {
        // Arrange
        Product_Subscriber__c installData = new Product_Subscriber__c(
            Org_Id__c = '00DXXXXXXX',
            Org_Name__c = 'Test Org',
            Email__c = 'test@mvclouds.com',
            First_Name__c = 'Test',
            Last_Name__c = 'User',
            Phone__c = '9999999999',
            Mobile_Phone__c = '8888888888',
            Installed_Product__c = 'WBConnect',
            Version_Number_Text__c = '1.0',
            Expiration_DateTime__c = Date.today().addDays(30)
        );

        String backendJson = JSON.serialize(installData);

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'New Install Notification';
        email.htmlBody = '<div>Hello</div>' +
            '<|--- BackEnd Use Only Data Start ---|>' + backendJson + '<|--- BackEnd Use Only Data End ---|>' +
            '<|--- Package Action Start ---|>Install<|--- Package Action End ---|>';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'test@mvclouds.com';
        envelope.toAddress = 'newinstalldata@xyz.com';

        // Act
        Test.startTest();
        Messaging.InboundEmailResult result = new NewInstallDataController().handleInboundEmail(email, envelope);
        Test.stopTest();
    }

    @isTest
    static void testHandleInboundEmail_Uninstall() {
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'WBConnect' LIMIT 1];
        Product_Subscriber__c subscriber = new Product_Subscriber__c(
            Org_Id__c = '00DXXXXXXX',
            Org_Name__c = 'Test Org',
            Email__c = 'test@mvclouds.com',
            Installed_Product__c = 'WBConnect',
            Product__c = testProduct.Id,
            Active__c = true
        );
        insert subscriber;

        String backendJson = JSON.serialize(subscriber);

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Uninstall Notification';
        email.htmlBody = '<div>Uninstall</div>' +
            '<|--- BackEnd Use Only Data Start ---|>' + backendJson + '<|--- BackEnd Use Only Data End ---|>' +
            '<|--- Package Action Start ---|>Uninstall<|--- Package Action End ---|>';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'test@mvclouds.com';
        envelope.toAddress = 'newinstalldata@xyz.com';

        Test.startTest();
        Messaging.InboundEmailResult result = new NewInstallDataController().handleInboundEmail(email, envelope);
        Test.stopTest();
    }

    @isTest
    static void testHandleInboundEmail_Upgrade() {
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'WBConnect' LIMIT 1];
        Product_Subscriber__c subscriber = new Product_Subscriber__c(
            Org_Id__c = '00DXXXXXXX',
            Org_Name__c = 'Test Org',
            Email__c = 'test@mvclouds.com',
            Installed_Product__c = 'WBConnect',
            Product__c = testProduct.Id,
            Version_Number_Text__c = '2.0',
            Active__c = true
        );
        insert subscriber;

        String backendJson = JSON.serialize(subscriber);

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Upgrade Notification';
        email.htmlBody = '<div>Upgrade</div>' +
            '<|--- BackEnd Use Only Data Start ---|>' + backendJson + '<|--- BackEnd Use Only Data End ---|>' +
            '<|--- Package Action Start ---|>Upgrade<|--- Package Action End ---|>';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'test@mvclouds.com';
        envelope.toAddress = 'newinstalldata@xyz.com';

        Test.startTest();
        Messaging.InboundEmailResult result = new NewInstallDataController().handleInboundEmail(email, envelope);
        Test.stopTest();
    }
}