@isTest
private class ProductSubscriberAPITest {

    @TestSetup
    static void setupTestData() {
        // Create Product with Support Developer Email for email coverage
        Product__c testProduct = new Product__c(
            Name = 'Test Product',
            Support_Developer_Email__c = 'support@test.com'
        );
        insert testProduct;

        // Create Product Version
        Product_Version__c productVersion = new Product_Version__c(
            Product__c = testProduct.Id,
            Version_Number__c = '1.0.0'
        );
        insert productVersion;
    }

    private static Map<String, Object> createFullSubscriberData(String orgId) {
        return new Map<String, Object>{
            'Org_Id__c' => orgId,
            'Installed_Product__c' => 'Test Product',
            'Org_Name__c' => 'Test Organization',
            'Email__c' => 'testuser@example.com',
            'Version_Number_Text__c' => '1.0.0',
            'First_Name__c' => 'John',
            'Last_Name__c' => 'Doe',
            'Company_Name__c' => 'Test Company',
            'Environment__c' => 'Production',
            'Phone__c' => '1234567890',
            'Mobile_Phone__c' => '0987654321'
        };
    }

    @isTest static void testGetProductSubscriber_Success() {
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        Product_Subscriber__c testSubscriber = new Product_Subscriber__c(
            Product__c = testProduct.Id,
            Org_Id__c = 'testOrgId',
            Expiration_DateTime__c = System.now().addDays(30)
        );
        insert testSubscriber;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'GET';
        req.params.put('orgId', 'testOrgId');
        req.params.put('productName', 'Test Product');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.getProductSubscriber();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assert(res.responseBody.toString().contains('testOrgId'));
    }

    @isTest static void testGetProductSubscriber_MissingOrgId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'GET';
        req.params.put('productName', 'Test Product');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.getProductSubscriber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assertEquals('Missing OrgId', res.responseBody.toString());
    }

    @isTest static void testGetProductSubscriber_NoRecordsFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'GET';
        req.params.put('orgId', 'nonExistentOrgId');
        req.params.put('productName', 'Test Product');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.getProductSubscriber();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
        System.assertEquals('No records found for the given OrgId', res.responseBody.toString());
    }

    // ==================== POST Method Tests ====================

    @isTest static void testCreateProductSubscriber_EmptyRequestBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('Request body is required'));
    }

    @isTest static void testCreateProductSubscriber_MissingAction() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'subscriberData' => new Map<String, Object>{
                'Org_Id__c' => 'testOrgId'
            }
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('Action is required'));
    }

    @isTest static void testCreateProductSubscriber_MissingSubscriberData() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Install'
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('subscriberData is required'));
    }

    @isTest static void testCreateProductSubscriber_InstallSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = createFullSubscriberData('testOrgId123');
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Install',
            'subscriberData' => subscriberData,
            'notificationEmails' => new List<String>{'admin@test.com'}
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        // Debug the response for troubleshooting
        System.debug('Response Status Code: ' + res.statusCode);
        System.debug('Response Body: ' + res.responseBody.toString());
        
        // Parse response to check success
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'), 'Expected success but got: ' + responseMap.get('message'));
        System.assertEquals(200, res.statusCode);

        // Verify records were created
        List<Product_Subscriber__c> subscribers = [SELECT Id, Org_Id__c, Active__c FROM Product_Subscriber__c WHERE Org_Id__c = 'testOrgId123'];
        System.assertEquals(1, subscribers.size());
        System.assertEquals(true, subscribers[0].Active__c);

        // Verify Opportunity was created
        List<Opportunity> opps = [SELECT Id, StageName FROM Opportunity WHERE Product_Subscriber__c = :subscribers[0].Id];
        System.assertEquals(1, opps.size());

        // Verify Lead was created
        List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email = 'testuser@example.com'];
        System.assertEquals(1, leads.size());
    }

    @isTest static void testCreateProductSubscriber_InstallWithExistingLead() {
        // Create existing Lead
        Lead existingLead = new Lead(
            FirstName = 'Existing',
            LastName = 'Lead',
            Company = 'Existing Company',
            Email = 'existinglead@example.com'
        );
        insert existingLead;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = createFullSubscriberData('testOrgIdExistingLead');
        subscriberData.put('Email__c', 'existinglead@example.com');
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Install',
            'subscriberData' => subscriberData,
            'notificationEmails' => new List<String>{'admin@test.com'}
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'), 'Expected success but got: ' + responseMap.get('message'));
        System.assertEquals(200, res.statusCode);

        // Verify existing Lead was linked, not a new one created
        List<Lead> leads = [SELECT Id FROM Lead WHERE Email = 'existinglead@example.com'];
        System.assertEquals(1, leads.size());
    }

    @isTest static void testCreateProductSubscriber_UninstallSuccess() {
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        // Create Product Subscriber with Opportunity
        Product_Subscriber__c testSubscriber = new Product_Subscriber__c(
            Product__c = testProduct.Id,
            Org_Id__c = 'testOrgId456',
            Active__c = true,
            Expiration_DateTime__c = System.now().addDays(30)
        );
        insert testSubscriber;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            Product_Subscriber__c = testSubscriber.Id
        );
        insert opp;

        testSubscriber.Opportunity__c = opp.Id;
        update testSubscriber;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = createFullSubscriberData('testOrgId456');
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Uninstall',
            'subscriberData' => subscriberData,
            'notificationEmails' => new List<String>{'admin@test.com'}
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'), 'Expected success but got: ' + responseMap.get('message'));

    }

    @isTest static void testCreateProductSubscriber_UpgradeSuccess() {
        Product__c testProduct = [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];

        Product_Subscriber__c testSubscriber = new Product_Subscriber__c(
            Product__c = testProduct.Id,
            Org_Id__c = 'testOrgId789',
            Active__c = true,
            Version_Number_Text__c = '1.0.0',
            Expiration_DateTime__c = System.now().addDays(30)
        );
        insert testSubscriber;

        // Create new Product Version for upgrade
        Product_Version__c newVersion = new Product_Version__c(
            Product__c = testProduct.Id,
            Version_Number__c = '2.0.0'
        );
        insert newVersion;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = createFullSubscriberData('testOrgId789');
        subscriberData.put('Version_Number_Text__c', '2.0.0');
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Upgrade',
            'subscriberData' => subscriberData,
            'notificationEmails' => new List<String>{'admin@test.com'}
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'), 'Expected success but got: ' + responseMap.get('message'));

        // Verify version was updated
        Product_Subscriber__c updatedSubscriber = [SELECT Id, Version_Number_Text__c, Product_Version__c FROM Product_Subscriber__c WHERE Id = :testSubscriber.Id];
        System.assertEquals('2.0.0', updatedSubscriber.Version_Number_Text__c);
    }

    @isTest static void testCreateProductSubscriber_UpgradeNoActiveSubscriber() {
        // This test covers the sendEmail method when no active subscriber is found during upgrade
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = createFullSubscriberData('nonExistentOrgId');
        subscriberData.put('Version_Number_Text__c', '2.0.0');
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Upgrade',
            'subscriberData' => subscriberData,
            'notificationEmails' => new List<String>{'admin@test.com'}
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assert(((String)responseMap.get('message')).contains('No active Product Subscriber'));
    }

    @isTest static void testCreateProductSubscriber_InvalidAction() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = createFullSubscriberData('testOrgIdInvalid');
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'InvalidAction',
            'subscriberData' => subscriberData
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('Invalid action'));
    }

    @isTest static void testCreateProductSubscriber_ProductNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = new Map<String, Object>{
            'Org_Id__c' => 'testOrgId',
            'Installed_Product__c' => 'NonExistent Product',
            'Org_Name__c' => 'Test Org',
            'First_Name__c' => 'John',
            'Last_Name__c' => 'Doe',
            'Email__c' => 'test@test.com'
        };
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Install',
            'subscriberData' => subscriberData
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('Product not found'));
    }

    @isTest static void testCreateProductSubscriber_MissingOrgId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = new Map<String, Object>{
            'Installed_Product__c' => 'Test Product'
        };
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Install',
            'subscriberData' => subscriberData
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        System.assert(res.responseBody.toString().contains('Org_Id__c is required'));
    }

    @isTest static void testCreateProductSubscriber_InstallSandboxEnvironment() {
        // Test Install with Sandbox environment to cover different LeadSource
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = createFullSubscriberData('testOrgIdSandbox');
        subscriberData.put('Environment__c', 'Sandbox');
        subscriberData.put('Email__c', 'sandbox@test.com');
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Install',
            'subscriberData' => subscriberData,
            'notificationEmails' => new List<String>{'admin@test.com'}
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'), 'Expected success but got: ' + responseMap.get('message'));
        System.assertEquals(200, res.statusCode);

        // Verify Lead was created with Sandbox LeadSource
        List<Lead> leads = [SELECT Id, LeadSource FROM Lead WHERE Email = 'sandbox@test.com'];
        System.assertEquals(1, leads.size());
        System.assertEquals('Product Installation - Sandbox', leads[0].LeadSource);
    }

    @isTest static void testCreateProductSubscriber_UninstallNoActiveSubscriber() {
        // Test Uninstall when no active subscriber exists
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/product-subscriber';
        req.httpMethod = 'POST';
        
        Map<String, Object> subscriberData = createFullSubscriberData('nonExistentUninstallOrgId');
        
        Map<String, Object> requestMap = new Map<String, Object>{
            'action' => 'Uninstall',
            'subscriberData' => subscriberData,
            'notificationEmails' => new List<String>{'admin@test.com'}
        };
        req.requestBody = Blob.valueOf(JSON.serialize(requestMap));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        ProductSubscriberAPI.createProductSubscriber();
        Test.stopTest();

        // Uninstall should still succeed even if no active subscriber found
        System.assertEquals(200, res.statusCode);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
    }
}