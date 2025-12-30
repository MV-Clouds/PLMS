@RestResource(urlMapping='/webhook/docusign/*')
global without sharing class DocuSignWebhookController {
    
    @HttpPost
    global static void handleDocuSignWebhook() {
        System.debug('DocuSign Webhook: POST Method Invoked');
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            String jsonString = RestContext.request.requestBody.toString();
            // System.debug('DocuSign Webhook Request Body: ' + jsonString);
            
            String path = req.requestURI;
            // System.debug('🌐 Incoming DocuSign Webhook at: ' + path);
            
            Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
            // System.debug('DocuSign Webhook Payload: ' + payload);
            
            // Process the webhook based on envelope status
            processEnvelopeEvent(payload);
            
            // Send success response
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"message": "Webhook processed successfully"}');
            
        } catch (Exception e) {
            // Send error email notification
            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - DocuSignWebhookController.<br/>Method Name - handleDocuSignWebhook.<br/>Exception Message : ' + e.getMessage() + '<br/>Exception Line Number : ' + e.getLineNumber() + '<br/>Stack Track : ' + e.getStackTraceString() + '<br/>Regards,<br/>PLMS Team');
            
            // Send error response
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error": "Failed to process webhook"}');
        }
    }
    
    /**
     * @description Process envelope event from DocuSign webhook
     * @param payload The webhook payload
     */
    private static void processEnvelopeEvent(Map<String, Object> payload) {
        try {
            String status = (String) payload.get('status');
            String envelopeId = (String) payload.get('envelopeId');
            
            // System.debug('Processing envelope event - Status: ' + status + ', EnvelopeId: ' + envelopeId);
            
            if (String.isBlank(envelopeId)) {
                System.debug('No envelope ID found in webhook payload');
                sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - DocuSignWebhookController.<br/>Method Name - processEnvelopeEvent.<br/>Exception Message : No envelope ID found in webhook payload.<br/>Payload Details: ' + JSON.serialize(payload) + '<br/>Regards,<br/>PLMS Team');
                return;
            }
            
            // Get custom fields to find the Salesforce contract ID
            String contractId = extractContractIdFromPayload(payload);
            
            if (String.isBlank(contractId)) {
                System.debug('No Salesforce contract ID found in webhook payload');
                sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - DocuSignWebhookController.<br/>Method Name - processEnvelopeEvent.<br/>Exception Message : No Salesforce contract ID found in webhook payload for envelope - ' + envelopeId + '. Hence no contract automation done in DocuSign webhook.<br/>Payload Details: ' + JSON.serialize(payload) + '<br/>Regards,<br/>PLMS Team');
                return;
            }
            
            // Update contract status based on DocuSign status
            updateContractStatus(contractId, envelopeId, status);
            
            // If completed, download the signed document
            if ('completed'.equalsIgnoreCase(status)) {
                System.debug('Envelope completed, downloading signed document');
                DocuSignHandler.downloadSignedDocument(envelopeId, contractId);
            }
            
        } catch (Exception e) {
            System.debug('Error in processEnvelopeEvent: ' + e.getMessage());
            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - DocuSignWebhookController.<br/>Method Name - processEnvelopeEvent.<br/>Exception Message : ' + e.getMessage() + '<br/>Exception Line Number : ' + e.getLineNumber() + '<br/>Stack Track : ' + e.getStackTraceString() + '<br/>Regards,<br/>PLMS Team');
        }
    }
    
    /**
     * @description Extract Salesforce contract ID from webhook payload
     * @param payload The webhook payload
     * @return Contract ID if found
     */
    private static String extractContractIdFromPayload(Map<String, Object> payload) {
        try {
            // Check custom fields for Salesforce contract ID
            Map<String, Object> customFields = (Map<String, Object>) payload.get('customFields');
            if (customFields != null) {
                List<Object> textCustomFields = (List<Object>) customFields.get('textCustomFields');
                if (textCustomFields != null) {
                    for (Object fieldObj : textCustomFields) {
                        Map<String, Object> field = (Map<String, Object>) fieldObj;
                        String fieldName = (String) field.get('name');
                        if ('Salesforce_Contract_Id'.equals(fieldName)) {
                            return (String) field.get('value');
                        }
                    }
                }
            }
            
            // Alternative: check documents URI for contract ID if not in custom fields
            String documentsUri = (String) payload.get('documentsUri');
            if (String.isNotBlank(documentsUri)) {
                // Extract envelope ID from documentsUri and find contract by envelope ID
                String envelopeId = (String) payload.get('envelopeId');
                if (String.isNotBlank(envelopeId)) {
                    List<Contract> contracts = [SELECT Id FROM Contract WHERE DocuSign_Envelope_Id__c = :envelopeId LIMIT 1];
                    if (!contracts.isEmpty()) {
                        return contracts[0].Id;
                    }
                }
            }
            
            return null;
            
        } catch (Exception e) {
            System.debug('Error extracting contract ID from payload: ' + e.getMessage());
            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - DocuSignWebhookController.<br/>Method Name - extractContractIdFromPayload.<br/>Exception Message : ' + e.getMessage() + '<br/>Exception Line Number : ' + e.getLineNumber() + '<br/>Stack Track : ' + e.getStackTraceString() + '<br/>Regards,<br/>PLMS Team');
            return null;
        }
    }
    
    /**
     * @description Update contract status based on DocuSign webhook
     * @param contractId The contract ID
     * @param envelopeId The envelope ID
     * @param status The DocuSign status
     */
    private static void updateContractStatus(String contractId, String envelopeId, String status) {
        try {
            Contract contractToUpdate = new Contract(Id = contractId);
            System.debug('Updating contract status for ContractId: ' + contractToUpdate);
            // Map DocuSign status to contract fields
            if ('sent'.equalsIgnoreCase(status)) {
                // Contract remains in Draft status when sent
                contractToUpdate.Status = 'Draft';
            } else if ('delivered'.equalsIgnoreCase(status)) {
                // Contract remains in Draft status when delivered
                contractToUpdate.Status = 'In Approval Process';
            } else if ('completed'.equalsIgnoreCase(status)) {
                contractToUpdate.Is_Signed__c = true;
                contractToUpdate.Status = 'Activated';
            } else if ('declined'.equalsIgnoreCase(status)) {
                contractToUpdate.Status = 'Draft'; // Keep as draft if declined
            } else if ('voided'.equalsIgnoreCase(status)) {
                contractToUpdate.Status = 'Draft'; // Keep as draft if voided
            }else {
                System.debug('Unhandled DocuSign status: ' + status + ' for ContractId: ' + contractId);
                sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - DocuSignWebhookController.<br/>Method Name - updateContractStatus.<br/>Exception Message : Unhandled DocuSign status: ' + status + ' for ContractId: ' + contractId + '.<br/>Regards,<br/>PLMS Team');
                return; // Exit if status is unhandled
            }
            
            // Ensure envelope ID is set
            if (String.isBlank(contractToUpdate.DocuSign_Envelope_Id__c)) {
                contractToUpdate.DocuSign_Envelope_Id__c = envelopeId;
            }
            
            update contractToUpdate;
            System.debug('Contract status updated: ' + contractId + ' - Status: ' + status);
            
        } catch (Exception e) {
            System.debug('Error updating contract status: ' + e.getMessage());
            sendEmail('Hello,<br/><br/>An Error occurred executing in <br/><br/>Apex Class - DocuSignWebhookController.<br/>Method Name - updateContractStatus.<br/>Exception Message : Error updating contract status for contract - ' + contractId + ' and envelope - ' + envelopeId + '. Exception: ' + e.getMessage() + '<br/>Exception Line Number : ' + e.getLineNumber() + '<br/>Stack Track : ' + e.getStackTraceString() + '<br/>Regards,<br/>PLMS Team');
        }
    }
    
    /**
     * @description Send email notification for errors and important events
     * @param body The email body content in HTML format
     */
    global static void sendEmail(String body) {
        try {
            ZohoWebhookController.sendEmail(body);
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}

// https://mvcloudsprivatelimited--plms.sandbox.my.salesforce-sites.com//services/apexrest/webhook/docusign/