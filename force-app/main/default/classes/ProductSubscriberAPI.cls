@RestResource(urlMapping='/product-subscriber')
global without sharing class ProductSubscriberAPI {

    @HttpGet
    global static void getProductSubscriber() {
        System.debug(' get Method Invoke ' );
        RestRequest req = RestContext.request;
        System.debug(req);
        RestResponse res = RestContext.response;
        System.debug(res);
        
        String orgId = RestContext.request.params.get('orgId');
        System.debug(orgId);
        String productName = RestContext.request.params.get('productName');

        if (String.isBlank(orgId)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Missing OrgId');
            return;
        }

        try {
            List<Product_Subscriber__c> records = [
                SELECT Id, Org_Id__c, Expiration_DateTime__c
                FROM Product_Subscriber__c
                WHERE Product__r.Name = :productName
                AND Org_Id__c = :orgId
                ORDER BY CreatedDate DESC
            ];

            if (records.isEmpty()) {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf('No records found for the given OrgId');
                return;
            }
            Product_Subscriber__c record = records[0];
            System.debug('Record found: ' + record);

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(record));
        } catch (Exception e) {
            System.debug('error >>' + e.getMessage());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
}