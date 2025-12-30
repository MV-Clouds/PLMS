/**
 * @description DocuSign integration handler for contract envelope creation and management.
 *              Implements a 4-step Document Generation workflow:
 *              1. Create draft envelope from template
 *              2. Get document form fields from the draft envelope
 *              3. Update document form fields with PLMS contract data
 *              4. Send the populated envelope for signature
 * @author PLMS Development Team
 * @date 2024-09-23
 * @version 2.0 - Document Generation workflow implementation
 */
public without sharing class DocuSignHandler {
    
    /**
     * @description Create and send DocuSign envelope for contract signing using Document Generation workflow.
     *              This method implements a 4-step process:
     *              1. Create draft envelope from template
     *              2. Get document form fields from the draft envelope
     *              3. Update document form fields with PLMS contract data
     *              4. Send the populated envelope for signature
     * @param contractId The ID of the contract to send for signing
     */
    @future(callout=true)
    public static void createAndSendEnvelope(Id contractId) {
        try {
            System.debug('DocuSignHandler: Creating envelope for contract: ' + contractId);
            
            // Get contract details
            Contract contract = getContractDetails(contractId);
            if (contract == null) {
                System.debug('Contract not found: ' + contractId);
                String body = errorMailBody('DocuSignHandler', 'createAndSendEnvelope', new CustomValidationException('Contract not found: ' + contractId));
                sendExceptionEmail(body);
                return;
            }
            
            // Check if contract is already activated - if so, don't update status
            if ('Activated'.equals(contract.Status)) {
                System.debug('Contract is already activated: ' + contractId);
                
                // If envelope ID exists, just resend the envelope
                if (String.isNotBlank(contract.DocuSign_Envelope_Id__c)) {
                    System.debug('Resending existing envelope: ' + contract.DocuSign_Envelope_Id__c);
                    // Could implement resend logic here if needed
                    return;
                } else {
                    System.debug('Contract is activated but no envelope ID found. Creating new envelope.');
                }
            }
            
            // Step 1: Create draft envelope from template
            String envelopeId = createDraftEnvelope(contract);
            if (String.isBlank(envelopeId)) {
                String body = errorMailBody('DocuSignHandler', 'createAndSendEnvelope', new CustomValidationException('Failed to create draft envelope for contract: ' + contractId));
                sendExceptionEmail(body);
                return;
            }
            
            // Step 2: Get document form fields from the draft envelope
            Map<String, Object> formFieldsData = getEnvelopeDocGenFormFields(envelopeId);
            if (formFieldsData == null) {
                String body = errorMailBody('DocuSignHandler', 'createAndSendEnvelope', new CustomValidationException('Failed to get form fields for envelope: ' + envelopeId));
                sendExceptionEmail(body);
                return;
            }
            
            // Step 3: Update document form fields with contract data
            Boolean updateSuccess = updateEnvelopeDocGenFormFields(envelopeId, contract, formFieldsData);
            if (!updateSuccess) {
                String body = errorMailBody('DocuSignHandler', 'createAndSendEnvelope', new CustomValidationException('Failed to update form fields for envelope: ' + envelopeId));
                sendExceptionEmail(body);
                return;
            }
            
            // Step 4: Send the envelope
            Boolean sendSuccess = sendDraftEnvelope(envelopeId);
            if (!sendSuccess) {
                String body = errorMailBody('DocuSignHandler', 'createAndSendEnvelope', new CustomValidationException('Failed to send envelope: ' + envelopeId));
                sendExceptionEmail(body);
                return;
            }
            
            // Step 5: Update contract with envelope ID
            updateContractWithEnvelopeId(contractId, envelopeId);
            System.debug('Successfully created and sent envelope: ' + envelopeId + ' for contract: ' + contractId);
            
        } catch (Exception e) {
            System.debug('Error in DocuSignHandler.createAndSendEnvelope: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            String body = errorMailBody('DocuSignHandler', 'createAndSendEnvelope', e);
            sendExceptionEmail(body);
        }
    }
    
    /**
     * @description Get contract details with related account and billing information.
     *              Retrieves contract data needed for DocuSign envelope creation including
     *              account details, status, and existing envelope ID.
     * @param contractId The contract ID to retrieve details for
     * @return Contract record with related account data, or null if not found
     */
    private static Contract getContractDetails(Id contractId) {
        try {
            List<Contract> contracts = [
                SELECT Id, AccountId, Account.Name, StartDate, ContractTerm, Status, DocuSign_Envelope_Id__c,
                       Account.Email__c,Account.BillingStreet, Account.BillingCity, Account.BillingState,
                       Account.BillingPostalCode, Account.BillingCountry
                FROM Contract 
                WHERE Id = :contractId 
                LIMIT 1
            ];
            
            return contracts.isEmpty() ? null : contracts[0];
        } catch (Exception e) {
            System.debug('Error fetching contract details: ' + e.getMessage());
            String body = errorMailBody('DocuSignHandler', 'getContractDetails', e);
            sendExceptionEmail(body);
            return null;
        }
    }
    
    /**
     * @description Build webhook configuration for DocuSign events.
     *              Configures the webhook URL and event types for envelope status updates.
     *              Includes events for Sent, Delivered, Completed, Declined, and Voided statuses.
     * @return Map containing complete webhook configuration for DocuSign API
     */
    private static Map<String, Object> buildWebhookConfiguration() {
        Map<String, Object> eventNotification = new Map<String, Object>();
        eventNotification.put('url', 'https://mvcloudsprivatelimited--plms.sandbox.my.salesforce-sites.com/services/apexrest/webhook/docusign');
        eventNotification.put('loggingEnabled', true);
        eventNotification.put('requireAcknowledgment', true);
        eventNotification.put('includeDocuments', false);
        eventNotification.put('includeEnvelopeVoidReason', true);
        eventNotification.put('includeTimeZone', true);
        
        // Envelope Events
        List<Object> envelopeEvents = new List<Object>{
            new Map<String, Object>{ 'envelopeEventStatusCode' => 'Sent' },
            new Map<String, Object>{ 'envelopeEventStatusCode' => 'Delivered' },
            new Map<String, Object>{ 'envelopeEventStatusCode' => 'Completed' },
            new Map<String, Object>{ 'envelopeEventStatusCode' => 'Declined' },
            new Map<String, Object>{ 'envelopeEventStatusCode' => 'Voided' }
        };
        eventNotification.put('envelopeEvents', envelopeEvents);
        
        // Event Data
        Map<String, Object> eventData = new Map<String, Object>();
        eventData.put('format', 'json');
        eventData.put('version', 'restv2.1');
        eventData.put('includeData', new List<String>{ 'recipients', 'custom_fields', 'documents', 'tabs' });
        eventNotification.put('eventData', eventData);
        
        return eventNotification;
    }
    
    /**
     * @description Step 1: Create draft envelope from DocuSign template.
     *              Creates a draft envelope with signer information, custom fields for Salesforce
     *              integration, and webhook configuration. The envelope is created in 'created' status
     *              (draft) to allow for field population before sending.
     * @param contract The contract record containing account and signer information
     * @return String envelope ID if successful, null if failed
     */
    private static String createDraftEnvelope(Contract contract) {
        try {
            Map<String, Object> payload = new Map<String, Object>();
            
            // Template ID from custom label
            payload.put('templateId', System.Label.DocuSignTemplateId);
            
            // Template Roles (Signer)
            List<Object> templateRoles = new List<Object>();
            Map<String, Object> signer = new Map<String, Object>();
            signer.put('roleName', 'Signer1');
            signer.put('name', contract.Account.Name);
            signer.put('email', contract.Account.Email__c);
            templateRoles.add(signer);
            payload.put('templateRoles', templateRoles);
            
            // Custom Fields for Salesforce integration metadata
            // Required for webhook processing to identify the related Salesforce contract
            Map<String, Object> customFields = new Map<String, Object>();
            List<Object> textCustomFields = new List<Object>();
            textCustomFields.add(new Map<String, Object>{
                'name' => 'Salesforce_Contract_Id',
                'value' => contract.Id,
                'show' => false
            });
            customFields.put('textCustomFields', textCustomFields);
            payload.put('customFields', customFields);
            
            // Event Notification (Webhook)
            Map<String, Object> eventNotification = buildWebhookConfiguration();
            payload.put('eventNotification', eventNotification);
            
            // Email settings
            payload.put('emailSubject', 'Contract Ready for Digital Signature - ' + contract.Account.Name);
            payload.put('emailBlurb', 'Dear ' + contract.Account.Name + ', please review and sign your contract digitally.');
            payload.put('status', 'created'); // Create as draft
            
            String body = JSON.serialize(payload);
            System.debug('DocuSign Draft Request Body: ' + body);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:DocuSign/restapi/v2.1/accounts/' + System.Label.DocuSignAccId + '/envelopes');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('DocuSign Draft Response Status: ' + res.getStatusCode());
            System.debug('DocuSign Draft Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) resMap.get('envelopeId');
            } else {
                System.debug('DocuSign Draft API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
                String errorBody = errorMailBody('DocuSignHandler', 'createDraftEnvelope',
                new CalloutException('DocuSign Draft API Error: ' + res.getStatusCode() + ' - ' + res.getBody()));
                sendExceptionEmail(errorBody);
                return null;
            }
            
        } catch (Exception e) {
            System.debug('Error creating draft envelope: ' + e.getMessage());
            String body = errorMailBody('DocuSignHandler', 'createDraftEnvelope', e);
            sendExceptionEmail(body);
            return null;
        }
    }
    
    /**
     * @description Step 2: Get document form fields from the draft envelope.
     *              Retrieves the template field structure including field names, types, and labels.
     *              Also extracts the document ID needed for field updates in step 3.
     * @param envelopeId The envelope ID from step 1
     * @return Map containing form fields data structure and document ID, null if failed
     */
    private static Map<String, Object> getEnvelopeDocGenFormFields(String envelopeId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:DocuSign/restapi/v2.1/accounts/' + System.Label.DocuSignAccId + '/envelopes/' + envelopeId + '/docGenFormFields');
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('DocuSign Get Form Fields Response Status: ' + res.getStatusCode());
            System.debug('DocuSign Get Form Fields Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // Debug the response structure
                System.debug('Form Fields Response Data: ' + responseData);
                
                // Get document ID from the response
                List<Object> docGenFormFields = (List<Object>) responseData.get('docGenFormFields');
                if (docGenFormFields != null && !docGenFormFields.isEmpty()) {
                    Map<String, Object> firstDoc = (Map<String, Object>) docGenFormFields[0];
                    String documentId = (String) firstDoc.get('documentId');
                    System.debug('Found Document ID: ' + documentId);
                    
                    // Store document ID for use in update
                    responseData.put('foundDocumentId', documentId);
                }
                
                return responseData;
            } else {
                System.debug('DocuSign Get Form Fields API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
                String errorBody = errorMailBody('DocuSignHandler', 'getEnvelopeDocGenFormFields',
                new CalloutException('DocuSign Get Form Fields API Error: ' + res.getStatusCode() + ' - ' + res.getBody()));
                sendExceptionEmail(errorBody);
                return null;
            }
            
        } catch (Exception e) {
            System.debug('Error getting envelope form fields: ' + e.getMessage());
            String body = errorMailBody('DocuSignHandler', 'getEnvelopeDocGenFormFields', e);
            sendExceptionEmail(body);
            return null;
        }
    }
    
    /**
     * @description Step 3: Update document form fields with PLMS contract data.
     *              Maps template fields to actual contract data using exact label matching.
     *              Supports both text fields (contract details) and table fields (quote line items).
     *              Processes ProductTable and ServiceTable with appropriate column mapping.
     * @param envelopeId The envelope ID from step 1
     * @param contract The contract record containing data to populate
     * @param formFieldsData The form fields structure from step 2
     * @return Boolean true if update successful, false if failed
     */
    private static Boolean updateEnvelopeDocGenFormFields(String envelopeId, Contract contract, Map<String, Object> formFieldsData) {
        try {
            // Get document ID from the form fields response
            String documentId = (String) formFieldsData.get('foundDocumentId');
            System.debug(documentId);
            if (String.isBlank(documentId)) {
                System.debug('No document ID found in form fields data');
                return false;
            }
            
            // Get quote and quote line items data for contract
            Map<String, Object> contractData = getContractAndQuoteData(contract.Id);
            
            // Build the update payload
            Map<String, Object> payload = new Map<String, Object>();
            List<Object> docGenFormFields = new List<Object>();
            
            Map<String, Object> documentUpdate = new Map<String, Object>();
            documentUpdate.put('documentId', documentId);
            
            List<Object> docGenFormFieldList = new List<Object>();
            
            // Get the actual form fields from the template response
            List<Object> templateFields = (List<Object>)((Map<String, Object>)((List<Object>)formFieldsData.get('docGenFormFields'))[0]).get('docGenFormFieldList');
            
            System.debug('Processing template fields: ' + templateFields.size());
            
            // Process each field found in the template
            for (Object fieldObj : templateFields) {
                Map<String, Object> field = (Map<String, Object>)fieldObj;
                String fieldType = (String)field.get('type');
                String fieldName = (String)field.get('name');
                String fieldLabel = (String)field.get('label');
                
                System.debug('Processing field - Label: ' + fieldLabel + ', Name: ' + fieldName + ', Type: ' + fieldType);
                
                if (fieldType == 'TextBox') {
                    // Map fields based on labels to actual PLMS data
                    String fieldValue = getFieldValueByLabel(fieldLabel, contractData);
                    if (fieldValue != null) {
                        Map<String, Object> textField = new Map<String, Object>();
                        textField.put('name', fieldName);
                        textField.put('type', 'TextBox');
                        textField.put('value', fieldValue);
                        docGenFormFieldList.add(textField);
                        System.debug('Added TextBox field: ' + fieldName + ' with value: ' + fieldValue);
                    }
                    
                } else if (fieldType == 'TableRow') {
                    // Handle table fields based on field labels
                    List<Object> tableRows = getTableRowsByLabel(fieldLabel, contractData);
                    if (tableRows != null && !tableRows.isEmpty()) {
                        // Get the column names from the template
                        List<Object> templateRowValues = (List<Object>)field.get('rowValues');
                        if (templateRowValues != null && !templateRowValues.isEmpty()) {
                            Map<String, Object> firstRow = (Map<String, Object>)templateRowValues[0];
                            List<Object> templateColumns = (List<Object>)firstRow.get('docGenFormFieldList');
                            
                            List<String> columnNames = new List<String>();
                            for (Object colObj : templateColumns) {
                                Map<String, Object> col = (Map<String, Object>)colObj;
                                String colName = (String)col.get('name');
                                columnNames.add(colName);
                                System.debug('Found table column: ' + colName);
                            }
                            
                            // Create table field with actual data
                            Map<String, Object> tableField = new Map<String, Object>();
                            tableField.put('name', fieldName);
                            tableField.put('type', 'TableRow');
                            
                            List<Object> rowValues = new List<Object>();
                            for (Object rowDataObj : tableRows) {
                                Map<String, Object> rowData = (Map<String, Object>)rowDataObj;
                                Map<String, Object> row = new Map<String, Object>();
                                List<Object> rowFields = new List<Object>();
                                
                                // Map row data to actual column names from template
                                for (Integer i = 0; i < columnNames.size() && i < rowData.size(); i++) {
                                    String columnName = columnNames[i];
                                    String columnKey = 'col' + (i + 1);
                                    String cellValue = (String)rowData.get(columnKey);
                                    if (cellValue != null) {
                                        rowFields.add(new Map<String, Object>{'name' => columnName, 'value' => cellValue});
                                    }
                                }
                                
                                row.put('docGenFormFieldList', rowFields);
                                rowValues.add(row);
                            }
                            
                            tableField.put('rowValues', rowValues);
                            docGenFormFieldList.add(tableField);
                            System.debug('Added TableRow field: ' + fieldName + ' with ' + rowValues.size() + ' rows');
                        }
                    }
                }
            }
            
            documentUpdate.put('docGenFormFieldList', docGenFormFieldList);
            docGenFormFields.add(documentUpdate);
            payload.put('docGenFormFields', docGenFormFields);
            
            String body = JSON.serialize(payload);
            System.debug('DocuSign Update Form Fields Request Body: ' + body);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:DocuSign/restapi/v2.1/accounts/' + System.Label.DocuSignAccId + '/envelopes/' + envelopeId + '/docGenFormFields');
            req.setMethod('PUT');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('DocuSign Update Form Fields Response Status: ' + res.getStatusCode());
            System.debug('DocuSign Update Form Fields Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                System.debug('Successfully updated form fields for envelope: ' + envelopeId);
                return true;
            } else {
                System.debug('DocuSign Update Form Fields API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
                String errorBody = errorMailBody('DocuSignHandler', 'updateEnvelopeDocGenFormFields',
                new CalloutException('DocuSign Update Form Fields API Error: ' + res.getStatusCode() + ' - ' + res.getBody()));
                sendExceptionEmail(errorBody);
                return false;
            }
            
        } catch (Exception e) {
            System.debug('Error updating envelope form fields: ' + e.getMessage());
            String body = errorMailBody('DocuSignHandler', 'updateEnvelopeDocGenFormFields', e);
            sendExceptionEmail(body);
            return false;
        }
    }
    
    /**
     * @description Step 4: Send the populated draft envelope for signature.
     *              Changes envelope status from 'created' to 'sent', triggering email
     *              delivery to the signer with the populated contract document.
     * @param envelopeId The envelope ID from step 1
     * @return Boolean true if envelope sent successfully, false if failed
     */
    private static Boolean sendDraftEnvelope(String envelopeId) {
        try {
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('status', 'sent');
            
            String body = JSON.serialize(payload);
            System.debug('DocuSign Send Envelope Request Body: ' + body);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:DocuSign/restapi/v2.1/accounts/' + System.Label.DocuSignAccId + '/envelopes/' + envelopeId);
            req.setMethod('PUT');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('DocuSign Send Envelope Response Status: ' + res.getStatusCode());
            System.debug('DocuSign Send Envelope Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                System.debug('Successfully sent envelope: ' + envelopeId);
                return true;
            } else {
                System.debug('DocuSign Send Envelope API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
                String errorBody = errorMailBody('DocuSignHandler', 'sendDraftEnvelope',
                new CalloutException('DocuSign Send Envelope API Error: ' + res.getStatusCode() + ' - ' + res.getBody()));
                sendExceptionEmail(errorBody);
                return false;
            }
            
        } catch (Exception e) {
            System.debug('Error sending draft envelope: ' + e.getMessage());
            String body = errorMailBody('DocuSignHandler', 'sendDraftEnvelope', e);
            sendExceptionEmail(body);
            return false;
        }
    }
    
    /**
     * @description Update contract record with DocuSign envelope ID for tracking.
     *              Stores the envelope ID for future reference and webhook processing.
     *              Contract status updates are handled separately by the webhook controller.
     * @param contractId The contract ID to update
     * @param envelopeId The DocuSign envelope ID to store
     */
    private static void updateContractWithEnvelopeId(Id contractId, String envelopeId) {
        try {
            Contract contractToUpdate = new Contract(Id = contractId);
            contractToUpdate.DocuSign_Envelope_Id__c = envelopeId;
            
            // Contract status is updated by the webhook controller when signing is complete
            
            update contractToUpdate;
        } catch (Exception e) {
            System.debug('Error updating contract with envelope ID: ' + e.getMessage());
            String body = errorMailBody('DocuSignHandler', 'updateContractWithEnvelopeId', e);
            sendExceptionEmail(body);
        }
    }
    
    /**
     * @description Download signed document from DocuSign and save to Salesforce.
     *              Retrieves the combined PDF document after signing completion and
     *              creates a ContentVersion record linked to the contract for storage.
     *              Called by webhook controller when envelope status becomes 'Completed'.
     * @param envelopeId The DocuSign envelope ID containing the signed document
     * @param contractId The related contract ID for document attachment
     */
    @future(callout=true)
    public static void downloadSignedDocument(String envelopeId, Id contractId) {
        try {
            System.debug('Downloading signed document for envelope: ' + envelopeId);
            
            HttpRequest pdfReq = new HttpRequest();
            pdfReq.setEndpoint('callout:DocuSign/restapi/v2.1/accounts/' + System.Label.DocuSignAccId + '/envelopes/' + envelopeId + '/documents/combined');
            pdfReq.setMethod('GET');
            pdfReq.setHeader('Accept', 'application/pdf');
            pdfReq.setTimeout(120000);
            
            Http pdfHttp = new Http();
            HttpResponse pdfRes = pdfHttp.send(pdfReq);
            
            if (pdfRes.getStatusCode() == 200) {
                Blob pdfBlob = pdfRes.getBodyAsBlob();
                System.debug('PDF Size: ' + pdfBlob.size());
                
                // Save to Salesforce ContentVersion
                ContentVersion cv = new ContentVersion();
                cv.Title = 'Signed_Contract_' + contractId;
                cv.PathOnClient = 'Signed_Contract_' + contractId + '.pdf';
                cv.VersionData = pdfBlob;
                cv.FirstPublishLocationId = contractId; // Link to contract
                insert cv;
                
                System.debug('Successfully saved signed document for contract: ' + contractId);
                
                
            } else {
                System.debug('Failed to download PDF: ' + pdfRes.getStatusCode() + ' - ' + pdfRes.getBody());
                String errorBody = errorMailBody('DocuSignHandler', 'downloadSignedDocument', new CalloutException('Failed to download PDF: ' + pdfRes.getStatusCode() + ' - ' + pdfRes.getBody()));
                sendExceptionEmail(errorBody);
            }
            
        } catch (Exception e) {
            System.debug('Error downloading signed document: ' + e.getMessage());
            String body = errorMailBody('DocuSignHandler', 'downloadSignedDocument', e);
            sendExceptionEmail(body);
        }
    }
    
    /**
     * @description Creates error email body for exceptions
     * @param apexClass The class name where error occurred
     * @param methodName The method name where error occurred
     * @param e The exception
     * @return HTML formatted error email body
     */
    public static String errorMailBody(String apexClass, String methodName, Exception e){
        return ZohoBillingService.errorMailBody(apexClass, methodName, e);
    }
    
    
    /**
     * @description Sends exception notification email to configured recipients.
     *              Uses the ZohoBillingService for consistent error reporting across
     *              the PLMS system. Recipients are defined in ExceptionEmailRecipients custom label.
     * @param emailBody The HTML-formatted email body containing error details
     */
    public static void sendExceptionEmail(String emailBody) {
        try {
            ZohoBillingService.sendExceptionEmail(emailBody);
        } catch (Exception e) {
            System.debug('Error sending exception email: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get contract and related quote data for DocuSign template population.
     *              Retrieves contract details, associated quote information, and quote line items
     *              organized by type (Product vs Service). Calculates contract end dates and
     *              determines table visibility flags for template rendering.
     * @param contractId The contract ID to retrieve data for
     * @return Map containing contract data, quote data, quote line items, and display flags
     */
    private static Map<String, Object> getContractAndQuoteData(Id contractId) {
        Map<String, Object> contractData = new Map<String, Object>();
        
        try {
            // Get contract with related account and quote data
            List<Contract> contracts = [
                SELECT Id, Name, StartDate, EndDate, Account.Name, Account.Email__c,
                       Quote__r.Id, Quote__r.Name, Quote__r.Contract_Start_Date__c,
                       Quote__r.RecordType.Name
                FROM Contract 
                WHERE Id = :contractId 
                LIMIT 1
            ];
            
            if (contracts.isEmpty()) {
                return contractData;
            }
            
            Contract contract = contracts[0];
            contractData.put('contract', contract);
            
            // Calculate contract end date based on start date + duration from quote lines
            Date contractEndDate = contract.EndDate;
            
            // Get quote line items
            List<QuoteLineItem> productLines = new List<QuoteLineItem>();
            List<QuoteLineItem> serviceLines = new List<QuoteLineItem>();
            
            if (contract.Quote__c != null) {
                List<QuoteLineItem> allLines = [
                    SELECT Id, Product2.Name, Product_Plan__r.Name, Product_Plan__r.Duration__c,
                           Quantity, UnitPrice, Discount, TotalPrice, Description,
                           Record_Type__c, Title__c
                    FROM QuoteLineItem 
                    WHERE QuoteId = :contract.Quote__c
                    ORDER BY Record_Type__c, Product2.Name, Title__c
                ];
                
                for (QuoteLineItem qli : allLines) {
                    if (qli.Record_Type__c == 'Product Quote Line') {
                        productLines.add(qli);
                    } else if (qli.Record_Type__c == 'Service Quote Line') {
                        serviceLines.add(qli);
                    }
                }
            }
            
            contractData.put('productLines', productLines);
            contractData.put('serviceLines', serviceLines);
            contractData.put('contractEndDate', contractEndDate);
            contractData.put('hasProductLines', !productLines.isEmpty());
            contractData.put('hasServiceLines', !serviceLines.isEmpty());
            
            System.debug('Contract data prepared: Product lines: ' + productLines.size() + ', Service lines: ' + serviceLines.size());
            
        } catch (Exception e) {
            String body = errorMailBody('DocuSignHandler', 'getContractAndQuoteData', e);
            sendExceptionEmail(body);
            System.debug('Error getting contract and quote data: ' + e.getMessage());
        }
        
        return contractData;
    }
    
    /**
     * @description Map DocuSign template field labels to actual PLMS data values.
     *              Uses exact label matching to map template fields to contract data.
     *              Supported labels: PLMS_ContractStartDate, PLMS_ContractEndDate,
     *              PLMS_AccountName, PLMS_AccountEmail, PLMS_QuoteNumber,
     *              PLMS_ShowProductTable, PLMS_ShowServiceTable.
     * @param fieldLabel The exact DocuSign template field label
     * @param contractData The contract and quote data map from getContractAndQuoteData
     * @return String value for the field, or null if label not recognized
     */
    private static String getFieldValueByLabel(String fieldLabel, Map<String, Object> contractData) {
        if (String.isBlank(fieldLabel) || contractData.isEmpty()) {
            return null;
        }
        
        Contract contract = (Contract)contractData.get('contract');
        Date contractEndDate = (Date)contractData.get('contractEndDate');
        Boolean hasProductLines = (Boolean)contractData.get('hasProductLines');
        Boolean hasServiceLines = (Boolean)contractData.get('hasServiceLines');
        
        // Map field labels to values based on exact PLMS template labels
        if (fieldLabel == 'PLMS_ContractStartDate') {
            return contract.Quote__r.Contract_Start_Date__c != null ?
                contract.Quote__r.Contract_Start_Date__c.format() : Date.today().format();
        }
        else if (fieldLabel == 'PLMS_ContractEndDate') {
            return contractEndDate != null ? contractEndDate.format() : '';
        }
        else if (fieldLabel == 'PLMS_AccountName') {
            return contract.Account.Name != null ? contract.Account.Name : '';
        }
        else if (fieldLabel == 'PLMS_AccountEmail') {
            return contract.Account.Email__c != null ? contract.Account.Email__c : '';
        }
        else if (fieldLabel == 'PLMS_QuoteNumber') {
            return contract.Quote__r.Name != null ? contract.Quote__r.Name : '';
        }
        else if (fieldLabel == 'PLMS_ShowProductTable') {
            return hasProductLines ? 'true' : 'false';
        }
        else if (fieldLabel == 'PLMS_ShowServiceTable') {
            return hasServiceLines ? 'true' : 'false';
        }
        
        return null;
    }
    
    /**
     * @description Get table rows data for DocuSign template table population.
     *              Supports two table types:
     *              - ProductTable (product quote lines with plan details, dates, original price,
     *                discounts, and final pricing) - 6 columns: Product Name, Order Date,
     *                Expiration Date, Original Price (PT_Price), Discount, Total Price
     *              - ServiceTable (service quote lines with hourly rates, quantities, and totals)
     *                - 5 columns: Service Name, Price Per Hour, Total Hours, Discount, Total Price
     *              Maps quote line item data to column structure expected by DocuSign template.
     * @param fieldLabel The exact DocuSign template table field label ('ProductTable' or 'ServiceTable')
     * @param contractData The contract and quote data map from getContractAndQuoteData
     * @return List of table row data maps with column keys (col1-col6 for ProductTable, col1-col5 for ServiceTable), empty list if label not recognized
     */
    private static List<Object> getTableRowsByLabel(String fieldLabel, Map<String, Object> contractData) {
        List<Object> tableRows = new List<Object>();
        
        if (String.isBlank(fieldLabel) || contractData.isEmpty()) {
            return tableRows;
        }
        
        List<QuoteLineItem> productLines = (List<QuoteLineItem>)contractData.get('productLines');
        List<QuoteLineItem> serviceLines = (List<QuoteLineItem>)contractData.get('serviceLines');
        Contract contract = (Contract)contractData.get('contract');
        Date startDate = contract.Quote__r.Contract_Start_Date__c != null ?
            contract.Quote__r.Contract_Start_Date__c : Date.today();
        
        // Product Table Data - exact table name match
        if (fieldLabel == 'ProductsTable') {
            for (QuoteLineItem qli : productLines) {
                Map<String, Object> rowData = new Map<String, Object>();
                
                // Column 1: Product Name (Plan Name)
                String productName = qli.Product2.Name != null ? qli.Product2.Name : 'Product';
                String planName = qli.Product_Plan__r.Name != null ? qli.Product_Plan__r.Name : '';
                String fullProductName = !String.isBlank(planName) ? productName + ' (' + planName + ')' : productName;
                rowData.put('col1', fullProductName);
                
                // Column 2: Order Date (Today)
                rowData.put('col2', startDate.format());
                
                // Column 3: Expiration Date (Start + Duration)
                Integer duration = qli.Product_Plan__r.Duration__c != null ?
                    Integer.valueOf(qli.Product_Plan__r.Duration__c) : 365;
                Date expirationDate = startDate.addDays(duration);
                rowData.put('col3', expirationDate.format());
                
                // Column 4: Original Price (PT_Price) - Price before discount
                Decimal originalPrice = qli.UnitPrice != null ? qli.UnitPrice : 0;
                rowData.put('col4', originalPrice.setScale(2).toPlainString());
                
                // Column 5: Discount
                Decimal discount = qli.Discount != null ? qli.Discount : 0;
                rowData.put('col5', discount.setScale(2).toPlainString());
                
                // Column 6: Total Price
                Decimal totalPrice = qli.TotalPrice != null ? qli.TotalPrice : 0;
                rowData.put('col6', totalPrice.setScale(2).toPlainString());
                
                tableRows.add(rowData);
            }
        }
        // Service Table Data - exact table name match
        else if (fieldLabel == 'ServiceTable') {
            for (QuoteLineItem qli : serviceLines) {
                Map<String, Object> rowData = new Map<String, Object>();
                
                // Column 1: Service Name (Title)
                rowData.put('col1', qli.Title__c != null ? qli.Title__c : 'Service');
                
                // Column 2: Price Per Hour
                Decimal pricePerHour = qli.UnitPrice != null ? qli.UnitPrice : 0;
                rowData.put('col2', pricePerHour.setScale(2).toPlainString());
                
                // Column 3: Total Hours
                Decimal totalHours = qli.Quantity != null ? qli.Quantity : 0;
                rowData.put('col3', totalHours.setScale(1).toPlainString());
                
                // Column 4: Discount
                Decimal discount = qli.Discount != null ? qli.Discount : 0;
                rowData.put('col4', discount.setScale(2).toPlainString());
                
                // Column 5: Total Price
                Decimal totalPrice = qli.TotalPrice != null ? qli.TotalPrice : 0;
                rowData.put('col5', totalPrice.setScale(2).toPlainString());
                
                tableRows.add(rowData);
            }
        }
        
        System.debug('Generated ' + tableRows.size() + ' table rows for field: ' + fieldLabel);
        return tableRows;
    }
    
    
    public class CustomValidationException extends Exception {}
    
}