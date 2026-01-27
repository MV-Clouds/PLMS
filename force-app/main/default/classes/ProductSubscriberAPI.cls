/**
 * Class Name: ProductSubscriberAPI
 * Test Class: - ProductSubscriberAPITest
 * @description: REST API to handle product subscriber actions (Install, Uninstall, Upgrade)
 * ****************************************************************
 * Created Date: December, 2024
 * Created By: Kevin Suvagiya
 * ****************************************************************
 * Modification History:
 * * Date Modified - Developer Name - Description
 * 21 January, 2026 - Rachit Shah - Added Post Method named createProductSubscriber and implemented logic to handle Install, Uninstall, Upgrade actions
 */
@RestResource(urlMapping='/product-subscriber')
global without sharing class ProductSubscriberAPI {

    /*
    *********************************************************
    * Method Name: createProductSubscriber
    * Description: Handles POST requests to create or update product subscriber records based on action
    * Parameters: None (reads from RestRequest)
    * Return Type: void (writes to RestResponse)
    *********************************************************
    */

    @HttpPost
    global static void createProductSubscriber() {
        System.debug('POST Method Invoked');
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Parse the request body
            String requestBody = req.requestBody.toString();
            System.debug('Request Body: ' + requestBody);

            if (String.isBlank(requestBody)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new ProductSubscriberAPIController.ProductSubscriberResponse(false, 'Request body is required', null)));
                return;
            }

            // Deserialize the request
            ProductSubscriberAPIController.ProductSubscriberRequest request = 
                (ProductSubscriberAPIController.ProductSubscriberRequest) JSON.deserialize(requestBody, ProductSubscriberAPIController.ProductSubscriberRequest.class);

            // Validate required fields
            if (String.isBlank(request.action)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new ProductSubscriberAPIController.ProductSubscriberResponse(false, 'Action is required (Install, Uninstall, Upgrade)', null)));
                return;
            }

            if (request.subscriberData == null) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new ProductSubscriberAPIController.ProductSubscriberResponse(false, 'subscriberData is required', null)));
                return;
            }

            // Process the action using the controller
            ProductSubscriberAPIController.ProductSubscriberResponse response = ProductSubscriberAPIController.processAction(request);

            if (response.success) {
                res.statusCode = 200;
            } else {
                res.statusCode = 400;
            }
            res.responseBody = Blob.valueOf(JSON.serialize(response));

        } catch (Exception e) {
            System.debug('Error in createProductSubscriber: ' + e.getMessage());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ProductSubscriberAPIController.ProductSubscriberResponse(false, 'Error: ' + e.getMessage(), null)));
        }
    }

    /*
    *********************************************************
    * Method Name: getProductSubscriber
    * Description: Handles GET requests to retrieve product subscriber records based on orgId and productName
    * Parameters: orgId (String), productName (String)
    * Return Type: void (writes to RestResponse)
    *********************************************************
    */
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