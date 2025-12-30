/**
 * @description Test class for DocuSignWebhookController
 * @author System
 * @date 2025-09-19
 */
@isTest
private class DocuSignWebhookControllerTest {
    
    @testSetup
    static void testSetup() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account',
            Email__c = 'john.doe@test.com'
            );
        insert testAccount;
        
        // Create test contract with DocuSign envelope ID
        Contract testContract = new Contract();
        testContract.AccountId = testAccount.Id;
        testContract.StartDate = Date.today();
        testContract.ContractTerm = 12;
        testContract.Status = 'Draft';
        testContract.DocuSign_Envelope_Id__c = 'test-envelope-id';
        insert testContract;
    }
    
    @isTest
    static void testHandleDocuSignWebhook_Completed() {
        // Get test contract
        Contract testContract = [SELECT Id, DocuSign_Envelope_Id__c FROM Contract LIMIT 1];
        
        // Create webhook payload for completed envelope
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'completed',
            'envelopeId' => testContract.DocuSign_Envelope_Id__c,
            'customFields' => new Map<String, Object>{
                'textCustomFields' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'Salesforce_Contract_Id',
                        'value' => testContract.Id
                    }
                }
            }
        };
        
        // Mock PDF download response
        Test.setMock(HttpCalloutMock.class, new MockDocuSignPDFResponse());
        
        // Setup REST request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webhook/docusign/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        DocuSignWebhookController.handleDocuSignWebhook();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        // Verify contract was updated
        Contract updatedContract = [SELECT Status, Is_Signed__c FROM Contract WHERE Id = :testContract.Id];
        System.assertEquals('Activated', updatedContract.Status);
        System.assertEquals(true, updatedContract.Is_Signed__c);
    }
    
    @isTest
    static void testHandleDocuSignWebhook_Sent() {
        // Get test contract
        Contract testContract = [SELECT Id, DocuSign_Envelope_Id__c FROM Contract LIMIT 1];
        
        // Create webhook payload for sent envelope
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'sent',
            'envelopeId' => testContract.DocuSign_Envelope_Id__c,
            'customFields' => new Map<String, Object>{
                'textCustomFields' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'Salesforce_Contract_Id',
                        'value' => testContract.Id
                    }
                }
            }
        };
        
        executeWebhookTest(payload, 200);
        
        // Verify contract was updated
        Contract updatedContract = [SELECT Status, Is_Signed__c FROM Contract WHERE Id = :testContract.Id];
        System.assertEquals('Draft', updatedContract.Status);
        System.assertEquals(false, updatedContract.Is_Signed__c);
    }
    
    @isTest
    static void testHandleDocuSignWebhook_Delivered() {
        // Get test contract
        Contract testContract = [SELECT Id, DocuSign_Envelope_Id__c FROM Contract LIMIT 1];
        
        // Create webhook payload for delivered envelope
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'delivered',
            'envelopeId' => testContract.DocuSign_Envelope_Id__c,
            'customFields' => new Map<String, Object>{
                'textCustomFields' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'Salesforce_Contract_Id',
                        'value' => testContract.Id
                    }
                }
            }
        };
        
        executeWebhookTest(payload, 200);
        
        // Verify contract was updated
        Contract updatedContract = [SELECT Status, Is_Signed__c FROM Contract WHERE Id = :testContract.Id];
        System.assertEquals('In Approval Process', updatedContract.Status);
        System.assertEquals(false, updatedContract.Is_Signed__c);
    }
    
    @isTest
    static void testHandleDocuSignWebhook_Declined() {
        // Get test contract
        Contract testContract = [SELECT Id, DocuSign_Envelope_Id__c FROM Contract LIMIT 1];
        
        // Create webhook payload for declined envelope
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'declined',
            'envelopeId' => testContract.DocuSign_Envelope_Id__c,
            'customFields' => new Map<String, Object>{
                'textCustomFields' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'Salesforce_Contract_Id',
                        'value' => testContract.Id
                    }
                }
            }
        };
        
        executeWebhookTest(payload, 200);
        
        // Verify contract was updated
        Contract updatedContract = [SELECT Status, Is_Signed__c FROM Contract WHERE Id = :testContract.Id];
        System.assertEquals('Draft', updatedContract.Status);
        System.assertEquals(false, updatedContract.Is_Signed__c);
    }
    
    @isTest
    static void testHandleDocuSignWebhook_Voided() {
        // Get test contract
        Contract testContract = [SELECT Id, DocuSign_Envelope_Id__c FROM Contract LIMIT 1];
        
        // Create webhook payload for voided envelope
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'voided',
            'envelopeId' => testContract.DocuSign_Envelope_Id__c,
            'customFields' => new Map<String, Object>{
                'textCustomFields' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'Salesforce_Contract_Id',
                        'value' => testContract.Id
                    }
                }
            }
        };
        
        executeWebhookTest(payload, 200);
        
        // Verify contract was updated
        Contract updatedContract = [SELECT Status, Is_Signed__c FROM Contract WHERE Id = :testContract.Id];
        System.assertEquals('Draft', updatedContract.Status);
        System.assertEquals(false, updatedContract.Is_Signed__c);
    }
    
    @isTest
    static void testHandleDocuSignWebhook_UnhandledStatus() {
        // Get test contract
        Contract testContract = [SELECT Id, DocuSign_Envelope_Id__c FROM Contract LIMIT 1];
        
        // Create webhook payload with unhandled status
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'unknown_status',
            'envelopeId' => testContract.DocuSign_Envelope_Id__c,
            'customFields' => new Map<String, Object>{
                'textCustomFields' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'Salesforce_Contract_Id',
                        'value' => testContract.Id
                    }
                }
            }
        };
        
        executeWebhookTest(payload, 200);
        
        // Verify contract was not updated (remains in original state)
        Contract updatedContract = [SELECT Status, Is_Signed__c FROM Contract WHERE Id = :testContract.Id];
        System.assertEquals('Draft', updatedContract.Status);
        System.assertEquals(false, updatedContract.Is_Signed__c);
    }
    
    @isTest
    static void testHandleDocuSignWebhook_NoEnvelopeId() {
        // Create webhook payload without envelope ID
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'completed'
        };
        
        executeWebhookTest(payload, 200);
        // Should handle gracefully without throwing exception
    }
    
    @isTest
    static void testHandleDocuSignWebhook_NoContractId() {
        // Create webhook payload without contract ID
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'completed',
            'envelopeId' => 'some-envelope-id'
        };
        
        executeWebhookTest(payload, 200);
        // Should handle gracefully without throwing exception
    }
    
    @isTest
    static void testHandleDocuSignWebhook_ContractIdFromEnvelopeSearch() {
        // Get test contract
        Contract testContract = [SELECT Id, DocuSign_Envelope_Id__c FROM Contract LIMIT 1];
        
        // Create webhook payload without custom fields but with documentsUri
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'completed',
            'envelopeId' => testContract.DocuSign_Envelope_Id__c,
            'documentsUri' => 'https://demo.docusign.net/restapi/v2.1/accounts/123/envelopes/' + testContract.DocuSign_Envelope_Id__c + '/documents'
        };
        
        executeWebhookTest(payload, 200);
        
        // Should find contract by envelope ID
        Contract updatedContract = [SELECT Status, Is_Signed__c FROM Contract WHERE Id = :testContract.Id];
        System.assertEquals('Activated', updatedContract.Status);
        System.assertEquals(true, updatedContract.Is_Signed__c);
    }
    
    @isTest
    static void testHandleDocuSignWebhook_ContractNotFound() {
        // Create webhook payload with non-existent contract ID
        Map<String, Object> payload = new Map<String, Object>{
            'status' => 'completed',
            'envelopeId' => 'some-envelope-id',
            'customFields' => new Map<String, Object>{
                'textCustomFields' => new List<Object>{
                    new Map<String, Object>{
                        'name' => 'Salesforce_Contract_Id',
                        'value' => '800000000000000' // Non-existent contract ID
                    }
                }
            }
        };
        
        executeWebhookTest(payload, 200);
        // Should handle gracefully without throwing exception
    }
    
    @isTest
    static void testHandleDocuSignWebhook_InvalidPayload() {
        // Setup REST request with invalid JSON
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webhook/docusign/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('invalid json');
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        DocuSignWebhookController.handleDocuSignWebhook();
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(500, res.statusCode);
    }
    
    @isTest
    static void testHandleDocuSignWebhook_EmptyPayload() {
        // Setup REST request with empty payload
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webhook/docusign/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        DocuSignWebhookController.handleDocuSignWebhook();
        Test.stopTest();
        
        // Verify response (should handle empty payload gracefully)
        System.assertEquals(200, res.statusCode);
    }
    
    @isTest
    static void testSendEmail() {
        Test.startTest();
        // Test email sending - this should not throw exception
        DocuSignWebhookController.sendEmail('Test email body');
        Test.stopTest();
        
        // Should complete without exception
        System.assert(true, 'Email sending should complete without exception');
    }
    
    // Helper method to execute webhook test
    private static void executeWebhookTest(Map<String, Object> payload, Integer expectedStatusCode) {
        // Mock PDF download for completed status
        if (payload.get('status') == 'completed') {
            Test.setMock(HttpCalloutMock.class, new MockDocuSignPDFResponse());
        }
        
        // Setup REST request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webhook/docusign/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        DocuSignWebhookController.handleDocuSignWebhook();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(expectedStatusCode, res.statusCode);
    }
    
    // Mock class for successful PDF download
    private class MockDocuSignPDFResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf('Mock PDF content'));
            res.setHeader('Content-Type', 'application/pdf');
            return res;
        }
    }
}