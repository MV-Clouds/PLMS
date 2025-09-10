@RestResource(urlMapping='/webhook/zoho/*')
global without sharing class ZohoWebhookController {
    
    @HttpGet
    global static void getProductSubscriber() {
        System.debug(' get Method Invoke ' );
        RestRequest req = RestContext.request;
        System.debug(req);
        RestResponse res = RestContext.response;
        System.debug(res);
    }

    @HttpPost
    global static void handleZohoWebhook() {
        System.debug(' POST Method Invoke ' );
        
        RestRequest req = RestContext.request;
        System.debug(JSON.serialize(req));
        
        String jsonString = RestContext.request.requestBody.toString();
        System.debug('Request Body: ' + jsonString);

        String path = req.requestURI;
        System.debug('🌐 Incoming Zoho Webhook at: ' + path);

        Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
        System.debug('payload: ' + payload);

        if (path.contains('/webhook/zoho/quote-approved')) {
            System.debug('✅ Handling Quote Approved Webhook');
            processQuoteApproved(payload);
        } else if (path.contains('/webhook/zoho/invoice-paid')) {
            System.debug('✅ Handling Invoice Paid Webhook');
            processInvoicePaid(payload);
        } else {
            System.debug('⚠️ Unrecognized webhook path: ' + path);
        }
    }

    private static void processQuoteApproved(Map<String, Object> payload) {
        if (payload.containsKey('estimate')){
            Map<String, Object> estimate = (Map<String, Object>)payload.get('estimate');
            System.debug('Estimate Details: ' + estimate);

            // Example: Extracting specific fields from the estimate
            String estimateNumber = (String)estimate.get('reference_number');
            String status = (String)estimate.get('status_formatted');
            System.debug('Estimate Number: ' + estimateNumber);
            System.debug('Status: ' + status);

            // Add your custom logic here, e.g., updating records in Salesforce
            if (estimateNumber != null && status != null && status == 'Accepted') {
                System.debug('Processing approved estimate: ' + estimateNumber);
                // Implement your logic to handle the approved estimate
                List<Quote> quoteRec = [SELECT Id, Name, QuoteNumber, Status, Contract_Start_Date__c, AccountId FROM Quote WHERE QuoteNumber = :estimateNumber LIMIT 1];
                if (!quoteRec.isEmpty()) {
                    Quote quoteToUpdate = quoteRec[0];
                    quoteToUpdate.Status = 'Accepted';
                    update quoteToUpdate;
                    System.debug('Quote updated successfully: ' + quoteToUpdate);

                    Contract cont = new Contract();
                    cont.StartDate = quoteToUpdate.Contract_Start_Date__c;
                    cont.AccountId = quoteToUpdate.AccountId;
                    cont.ContractTerm = 1;
                    cont.Status = 'Draft';
                    insert cont;
                } else {
                    System.debug('No quote found with the given estimate number.');
                }
            } else {
                System.debug('Estimate is not approved or missing necessary information.');
            }
        } else {
            System.debug('No estimate key found in the payload.');
        }
    }

    private static void processInvoicePaid(Map<String, Object> payload) {
        if (payload.containsKey('invoice')){
            Map<String, Object> invoice = (Map<String, Object>)payload.get('invoice');
            System.debug('Invoice Details: ' + invoice);

            // Example: Extracting specific fields from the invoice
            String invoiceNumber = (String)invoice.get('reference_number');
            String status = (String)invoice.get('status_formatted');
            System.debug('Invoice Number: ' + invoiceNumber);
            System.debug('Status: ' + status);

            // Add your custom logic here, e.g., updating records in Salesforce
            if (invoiceNumber != null && status != null && status == 'Paid') {
                System.debug('Processing paid invoice: ' + invoiceNumber);
                // Implement your logic to handle the paid invoice
                List<Invoice__c> invoiceRec = [SELECT Id, Name, Status__c, Product_Subscriber__c FROM Invoice__c WHERE Name = :invoiceNumber LIMIT 1];
                if (!invoiceRec.isEmpty()) {
                    Invoice__c invoiceToUpdate = invoiceRec[0];
                    invoiceToUpdate.Status__c = 'Paid';
                    update invoiceToUpdate;
                    System.debug('Invoice updated successfully: ' + invoiceToUpdate);

                    // fetch product subscriber records related to this invoice
                    List<Product_Subscriber__c> psRecords = [ SELECT Id, Expiration_DateTime__c, Active__c, Product_Plan__c FROM Product_Subscriber__c WHERE Id = :invoiceRec[0].Product_Subscriber__c AND Active__c = true ORDER BY CreatedDate DESC LIMIT 1];
                    if (!psRecords.isEmpty()) {
                        Product_Subscriber__c psRecord = psRecords[0];
                        System.debug('Found product subscriber: ' + psRecord);

                        if (psRecord.Expiration_DateTime__c != null && psRecord.Expiration_DateTime__c.date() >= System.today()) {
                            // fetch product plan records related to this invoice
                            List<Product_Plan__c> ppRecords = [ SELECT Id, Duration__c FROM Product_Plan__c WHERE Id = :psRecord.Product_Plan__c LIMIT 1];
                            if (!ppRecords.isEmpty()) {
                                Product_Plan__c ppRecord = ppRecords[0];
                                System.debug('Found product plan: ' + ppRecord);
    
                                Integer duration = ppRecord.Duration__c != null ? (Integer)ppRecord.Duration__c : 0;
    
                                // Add months to today’s date
                                Date futureDate = System.today().addMonths(duration);
                                // Build a 10:00 AM time
                                Time tenAM = Time.newInstance(10, 0, 0, 0);
                                // Combine into DateTime
                                psRecord.Expiration_DateTime__c = DateTime.newInstance(futureDate, tenAM);
    
                                update psRecord;
                                System.debug('Product subscriber updated successfully: ' + psRecord);
                            } else {
                                System.debug('No product plan found for product subscriber: ' + psRecord);
                            }
                        } else {
                            System.debug('Invoice Paid after due date, skipping processing');
                        }
                    } else {
                        System.debug('No product subscriber found for invoice: ' + invoiceRec[0]);
                    }
                } else {
                    System.debug('No invoice found with the given invoice number.');
                }
            } else {
                System.debug('Invoice is not paid or missing necessary information.');
            }
        } else {
            System.debug('No invoice key found in the payload.');
        }
    }
}

// https://mvcloudsprivatelimited--plms.sandbox.my.salesforce-sites.com/services/apexrest/webhook/zoho/quote-approved
// https://mvcloudsprivatelimited--plms.sandbox.my.salesforce-sites.com/services/apexrest/webhook/zoho/invoice-paid