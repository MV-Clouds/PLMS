@RestResource(urlMapping='/webhook/zoho/*')
global without sharing class ZohoWebhookController {

    @HttpPost
    global static void handleZohoWebhook() {
        try {
            System.debug(' POST Method Invoke ' );
            
            RestRequest req = RestContext.request;
            System.debug(JSON.serialize(req));
            
            String jsonString = RestContext.request.requestBody.toString();
            System.debug('Request Body: ' + jsonString);
    
            String path = req.requestURI;
            System.debug('🌐 Incoming Zoho Webhook at: ' + path);
    
            Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
            System.debug('payload: ' + payload);
    
            if (path.contains('/webhook/zoho/quote')) {
                System.debug('✅ Handling Quote Webhook');
                processQuoteData(payload);
            } else if (path.contains('/webhook/zoho/invoice')) {
                System.debug('✅ Handling Invoice Webhook');
                processInvoiceData(payload);
            } else {
                System.debug('⚠️ Unrecognized webhook path: ' + path);
            }
        } catch (Exception e) {
            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - handleZohoWebhook.<br/>Exeception Message : ' + e.getMessage() + '<br/>Exeception Line Number : ' + e.getLineNumber() + '<br/>Strack Track : ' + e.getStackTraceString() + '<br/>Regards,<br/>PLMS Team');
        }
    }

    private static void processQuoteData(Map<String, Object> payload) {
        try {
            if (payload.containsKey('estimate')){
                Map<String, Object> estimate = (Map<String, Object>)payload.get('estimate');
                System.debug('Estimate Details: ' + estimate);
    
                // Example: Extracting specific fields from the estimate
                String estimateNumber = (String)estimate.get('reference_number');
                String status = (String)estimate.get('status_formatted');
                System.debug('Estimate Number: ' + estimateNumber);
                System.debug('Status: ' + status);
    
                // Add your custom logic here, e.g., updating records in Salesforce
                if (estimateNumber != null && status != null) {
                    if(status == 'Accepted'){
                        System.debug('Processing approved estimate: ' + estimateNumber);
                        // Implement your logic to handle the approved estimate
                        List<Quote> quoteRec = [SELECT Id, Name, QuoteNumber, Status, Contract_Start_Date__c, AccountId, OpportunityId FROM Quote WHERE QuoteNumber = :estimateNumber LIMIT 1];
                        if (!quoteRec.isEmpty()) {
                            Quote quoteToUpdate = quoteRec[0];
                            quoteToUpdate.Status = 'Accepted';
                            update quoteToUpdate;
                            System.debug('Quote updated successfully: ' + quoteToUpdate);
        
                            List<Opportunity> oppRecs = [SELECT Id, StageName, Is_Product_Trial__c, Is_Product_Trial_Extended__c FROM Opportunity WHERE Id = :quoteRec[0].OpportunityId];
                            if (!oppRecs.isEmpty()) {
                                Opportunity oppRec = oppRecs[0];
                                oppRec.StageName = 'Closed Won';
                                oppRec.Is_Product_Trial__c = false;
                                oppRec.Is_Product_Trial_Extended__c = false;
                                update oppRec;
                                System.debug('Opportunity updated successfully: ' + oppRec.Id);
                                
                                Contract cont = new Contract();
                                cont.StartDate = quoteToUpdate.Contract_Start_Date__c;
                                cont.AccountId = quoteToUpdate.AccountId;
                                cont.ContractTerm = 1;
                                cont.Quote__c = quoteToUpdate.Id;
                                cont.Opportunity__c = quoteToUpdate.OpportunityId;
                                cont.Status = 'Draft';
                                insert cont;
                            } else {
                                System.debug('No opportunity found for the quote.');
                                sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processQuoteData.<br/>Exeception Message : No opportunity found for the quote - ' + quoteToUpdate.Id + ' in the Org. Hence no contract record is not created. <br/>Regards,<br/>PLMS Team');
                            }
                        } else {
                            System.debug('No quote found with the given estimate number.');
                            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processQuoteData.<br/>Exeception Message : No quote found with the given estimate number in the Org. Hence no automation done in Zoho webhook.<br/>Zoho EstimateNumber : ' + estimateNumber + ' <br/>Regards,<br/>PLMS Team');
                        }
                    } else {
                        System.debug('Estimate is not approved');
                    }
                } else {
                    sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processQuoteData.<br/>Exeception Message : Quote Number or Status not found in payload.<br/>Payload Details: ' + JSON.serialize(payload) + ' <br/>Regards,<br/>PLMS Team');
                }
            } else {
                System.debug('No estimate key found in the payload.');
                sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processQuoteData.<br/>Exeception Message : No estimate key found in the payload for Quote. Hence no automation done in Zoho webhook.<br/>Payload Details: ' + JSON.serialize(payload) + ' <br/>Regards,<br/>PLMS Team');
            }
        } catch (Exception e) {
            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processQuoteData.<br/>Exeception Message : ' + e.getMessage() + '<br/>Exeception Line Number : ' + e.getLineNumber() + '<br/>Strack Track : ' + e.getStackTraceString() + '<br/>Regards,<br/>PLMS Team');
        }
    }

    private static void processInvoiceData(Map<String, Object> payload) {
        try {
            if (payload.containsKey('invoice')){
                Map<String, Object> invoice = (Map<String, Object>)payload.get('invoice');
                System.debug('Invoice Details: ' + invoice);
    
                // Example: Extracting specific fields from the invoice
                String invoiceNumber = (String)invoice.get('reference_number');
                String status = (String)invoice.get('status_formatted');
                System.debug('Invoice Number: ' + invoiceNumber);
                System.debug('Status: ' + status);
    
                // Add your custom logic here, e.g., updating records in Salesforce
                if (invoiceNumber != null && status != null) {
                    if(status == 'Paid'){
                        System.debug('Processing paid invoice: ' + invoiceNumber);
                        // Implement your logic to handle the paid invoice
                        List<Invoice__c> invoiceRec = [SELECT Id, Name, Status__c, Product_Subscriber__c, Start_Date__c FROM Invoice__c WHERE Name = :invoiceNumber LIMIT 1];
                        if (!invoiceRec.isEmpty()) {
                            Invoice__c invoiceToUpdate = invoiceRec[0];
                            invoiceToUpdate.Status__c = 'Paid';
                            update invoiceToUpdate;
                            System.debug('Invoice updated successfully: ' + invoiceToUpdate);
        
                            // fetch product subscriber records related to this invoice
                            List<Product_Subscriber__c> psRecords = [ SELECT Id, Expiration_DateTime__c, Active__c, Product_Plan__c, Is_Temp_Expiry__c FROM Product_Subscriber__c WHERE Id = :invoiceRec[0].Product_Subscriber__c AND Active__c = true ORDER BY CreatedDate DESC LIMIT 1];
                            if (!psRecords.isEmpty()) {
                                Product_Subscriber__c psRecord = psRecords[0];
                                System.debug('Found product subscriber: ' + psRecord);
        
                                List<Product_Plan__c> ppRecords = [ SELECT Id, Duration__c FROM Product_Plan__c WHERE Id = :psRecord.Product_Plan__c LIMIT 1];
                                // fetch product plan records related to this product subscriber
                                if (!ppRecords.isEmpty()) {
                                    Product_Plan__c ppRecord = ppRecords[0];
                                    System.debug('Found product plan: ' + ppRecord);
        
                                    Integer duration = ppRecord.Duration__c != null ? (Integer)ppRecord.Duration__c : 0;
    
                                    if (psRecord.Expiration_DateTime__c != null && psRecord.Expiration_DateTime__c.date() >= System.today()) {
                                        // Add months to today’s date
                                        Date futureDate = invoiceToUpdate.Start_Date__c.addMonths(duration);
                                        // Build a 10:00 AM time
                                        Time tenAM = Time.newInstance(10, 0, 0, 0);
                                        // Combine into DateTime
                                        psRecord.Expiration_DateTime__c = DateTime.newInstance(futureDate, tenAM);
                                    } else {
                                        System.debug('Invoice Paid after due date');
                                        // Add months to today’s date
                                        Date futureDate = Date.today().addMonths(duration);
                                        // Build a 10:00 AM time
                                        Time tenAM = Time.newInstance(10, 0, 0, 0);
                                        // Combine into DateTime
                                        psRecord.Expiration_DateTime__c = DateTime.newInstance(futureDate, tenAM);
                                    }
    
                                    psRecord.Is_Temp_Expiry__c = false;
        
                                    update psRecord;
                                    System.debug('Product subscriber updated successfully: ' + psRecord);
                                } else {
                                    System.debug('No product plan found for product subscriber: ' + psRecord);
                                    sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processInvoiceData.<br/>Exeception Message : No product plan found for product subscriber - ' + psRecord.Id + ' in the org. Hence product subscriber\'s expiry date is not updated.<br/>Regards,<br/>PLMS Team');
                                }
                            } else {
                                System.debug('No product subscriber found for invoice: ' + invoiceRec[0].Id);
                                sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processInvoiceData.<br/>Exeception Message : No product subscriber found for invoice - ' + invoiceToUpdate.Id + ' in the org. Hence product subscriber\'s expiry date is not updated.<br/>Regards,<br/>PLMS Team');
                            }
                        } else {
                            System.debug('No invoice found with the given invoice number.');
                            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processInvoiceData.<br/>Exeception Message : No invoice found with the given invoice number. Hence no automation done in Zoho webhook.<br/>Zoho Invoice Reference Number: ' + invoiceNumber + ' <br/>Regards,<br/>PLMS Team');
                        }
                    } else {
                        System.debug('Invoice is not paid');
                    }
                } else {
                    sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processInvoiceData.<br/>Exeception Message : Invoice Number or Status not found in payload.<br/>Payload Details: ' + JSON.serialize(payload) + ' <br/>Regards,<br/>PLMS Team');
                }
            } else {
                System.debug('No invoice key found in the payload.');
                sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processInvoiceData.<br/>Exeception Message : No invoice key found in the payload. Hence no automation done in Zoho webhook.<br/>Payload Details: ' + JSON.serialize(payload) + ' <br/>Regards,<br/>PLMS Team');
            }
        } catch (Exception e) {
            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - ZohoWebhookController.<br/>Method Name - processInvoiceData.<br/>Exeception Message : ' + e.getMessage() + '<br/>Exeception Line Number : ' + e.getLineNumber() + '<br/>Strack Track : ' + e.getStackTraceString() + '<br/>Regards,<br/>PLMS Team');
        }
    }

    public static void sendEmail(String body) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            String toAddressLabel = System.Label.ExceptionEmailRecipients;
            List<String> toAddresses = toAddressLabel.split(',');
            
            email.setToAddresses(toAddresses);
            email.setSubject('An Exception Occurred in Zoho Webhook');
            email.setHtmlBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}

// https://mvcloudsprivatelimited--plms.sandbox.my.salesforce-sites.com/services/apexrest/webhook/zoho/quote
// https://mvcloudsprivatelimited--plms.sandbox.my.salesforce-sites.com/services/apexrest/webhook/zoho/invoice