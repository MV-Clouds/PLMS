@isTest
private class ProductSubscriberAPITest {

    @isTest static void testGetProductSubscriber_Success() {
        Product__c testProduct = new Product__c(Name = 'Test Product');
        insert testProduct;

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
}