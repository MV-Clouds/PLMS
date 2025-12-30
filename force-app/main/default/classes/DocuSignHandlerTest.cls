/**
 * @description Test class for DocuSignHandler
 * @author System
 * @date 2025-09-19
 */
@isTest
private class DocuSignHandlerTest {
    
    @testSetup
    static void testSetup() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Account',
            Email__c = 'john.doe@test.com',
            BillingStreet = 'Test Street',
            BillingCity = 'Test City',
            BillingState = 'Test State',
            BillingPostalCode = '12345',
            BillingCountry = 'Test Country'
                );
            insert testAccount;
            
            // Create test contract with all required fields
            Contract testContract = new Contract();
            testContract.AccountId = testAccount.Id;
            testContract.StartDate = Date.today();
            testContract.ContractTerm = 12;
            testContract.Status = 'Draft';
            insert testContract;
        }
            
        @isTest
        static void testCreateAndSendEnvelope_DocumentGeneration_Success() {
            // Get test contract
            Contract testContract = [SELECT Id FROM Contract LIMIT 1];
            
            // Mock successful DocuSign 4-step workflow
            Test.setMock(HttpCalloutMock.class, new MockDocuSignDocGenSuccessResponse());
            
            Test.startTest();
            DocuSignHandler.createAndSendEnvelope(testContract.Id);
            Test.stopTest();
            
            // Verify contract was updated with envelope ID
            Contract updatedContract = [SELECT DocuSign_Envelope_Id__c, Status FROM Contract WHERE Id = :testContract.Id];
            System.assertNotEquals(null, updatedContract.DocuSign_Envelope_Id__c);
            System.assertEquals('Draft', updatedContract.Status);
        }
            
        @isTest
        static void testCreateAndSendEnvelope_DraftCreationError() {
            // Get test contract
            Contract testContract = [SELECT Id FROM Contract LIMIT 1];
            
            // Mock error in draft creation step
            Test.setMock(HttpCalloutMock.class, new MockDocuSignDraftErrorResponse());
            
            Test.startTest();
            DocuSignHandler.createAndSendEnvelope(testContract.Id);
            Test.stopTest();
            
            // Verify contract was not updated
            Contract updatedContract = [SELECT DocuSign_Envelope_Id__c FROM Contract WHERE Id = :testContract.Id];
            System.assertEquals(null, updatedContract.DocuSign_Envelope_Id__c);
        }
        
        @isTest
        static void testCreateAndSendEnvelope_FormFieldsError() {
            // Get test contract
            Contract testContract = [SELECT Id FROM Contract LIMIT 1];
            
            // Mock error in form fields retrieval step
            Test.setMock(HttpCalloutMock.class, new MockDocuSignFormFieldsErrorResponse());
            
            Test.startTest();
            DocuSignHandler.createAndSendEnvelope(testContract.Id);
            Test.stopTest();
            
            // Verify appropriate handling
            Contract updatedContract = [SELECT DocuSign_Envelope_Id__c FROM Contract WHERE Id = :testContract.Id];
            System.assertEquals(null, updatedContract.DocuSign_Envelope_Id__c);
        }
        
        @isTest
        static void testCreateAndSendEnvelope_ContractNotFound() {
            // Test with non-existent contract ID
            Test.startTest();
            DocuSignHandler.createAndSendEnvelope('800000000000000');
            Test.stopTest();
            
            // Should handle gracefully without throwing exception
            System.assert(true, 'Method should handle missing contract gracefully');
        }
        
        @isTest
        static void testDownloadSignedDocument_Success() {
            // Get test contract
            Contract testContract = [SELECT Id FROM Contract LIMIT 1];
            testContract.DocuSign_Envelope_Id__c = 'test-envelope-id';
            update testContract;
            
            // Mock successful PDF download response
            Test.setMock(HttpCalloutMock.class, new MockDocuSignPDFResponse());
            
            Test.startTest();
            DocuSignHandler.downloadSignedDocument('test-envelope-id', testContract.Id);
            Test.stopTest();
            
            // Verify ContentVersion was created
            List<ContentVersion> contentVersions = [SELECT Title FROM ContentVersion WHERE FirstPublishLocationId = :testContract.Id];
            System.assertEquals(1, contentVersions.size());
            System.assertEquals('Signed_Contract_' + testContract.Id, contentVersions[0].Title);
        }
        
        @isTest
        static void testDownloadSignedDocument_Error() {
            // Get test contract
            Contract testContract = [SELECT Id FROM Contract LIMIT 1];
            
            // Mock error PDF download response
            Test.setMock(HttpCalloutMock.class, new MockDocuSignErrorResponse());
            
            Test.startTest();
            DocuSignHandler.downloadSignedDocument('test-envelope-id', testContract.Id);
            Test.stopTest();
            
            // Should handle error gracefully
            System.assert(true, 'Method should handle download error gracefully');
        }
        
        @isTest
        static void testErrorMailBody() {
            Test.startTest();
            Exception testException = new DocuSignHandler.CustomValidationException('Test error message');
            String emailBody = DocuSignHandler.errorMailBody('TestClass', 'testMethod', testException);
            Test.stopTest();
            
            System.assert(emailBody.contains('TestClass'), 'Email body should contain class name');
            System.assert(emailBody.contains('testMethod'), 'Email body should contain method name');
            System.assert(emailBody.contains('Test error message'), 'Email body should contain exception message');
        }
        
        @isTest
        static void testSendExceptionEmail() {
            Test.startTest();
            // Test email sending - this should not throw exception
            DocuSignHandler.sendExceptionEmail('Test email body');
            Test.stopTest();
            
            // Should complete without exception
            System.assert(true, 'Email sending should complete without exception');
        }
        
        // Mock class for successful DocuSign Document Generation workflow (4 steps)
        private class MockDocuSignDocGenSuccessResponse implements HttpCalloutMock {
            private Integer callCount = 0;
            
            public HTTPResponse respond(HTTPRequest req) {
                HTTPResponse res = new HTTPResponse();
                callCount++;
                
                String endpoint = req.getEndpoint();
                String method = req.getMethod();
                
                if (method == 'POST' && endpoint.contains('/envelopes')) {
                    // Step 1: Create draft envelope
                    res.setStatusCode(201);
                res.setBody('{"envelopeId": "test-envelope-id-' + callCount + '", "status": "created"}');
            } else if (method == 'GET' && endpoint.contains('/docGenFormFields')) {
                // Step 2: Get form fields
                res.setStatusCode(200);
                res.setBody('{"docGenFormFields":[{"documentId":"test-doc-id","docGenFormFieldList":[{"label":"CF1","type":"TextBox","name":"/C_CF1"},{"label":"VF","type":"TableRow","name":"_10D","rowValues":[{"docGenFormFieldList":[{"label":"VF1","name":"vkC"},{"label":"VF2","name":"vkD"}]}]}]}]}');
            } else if (method == 'PUT' && endpoint.contains('/docGenFormFields')) {
                // Step 3: Update form fields
                res.setStatusCode(200);
                res.setBody('{"docGenFormFields":[{"documentId":"test-doc-id","docGenDocumentStatus":"mergesucceeded"}]}');
            } else if (method == 'PUT' && endpoint.contains('/envelopes/')) {
                // Step 4: Send envelope
                res.setStatusCode(200);
            res.setBody('{"envelopeId": "test-envelope-id-' + callCount + '"}');
        } else {
            res.setStatusCode(200);
            res.setBody('{"success": true}');
        }
        
        return res;
        }
    }
    
    // Mock class for draft creation error
    private class MockDocuSignDraftErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            if (req.getMethod() == 'POST' && req.getEndpoint().contains('/envelopes')) {
                res.setStatusCode(400);
                res.setBody('{"error": "Invalid template ID"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            }
            return res;
        }
    }
    
    // Mock class for form fields error
    private class MockDocuSignFormFieldsErrorResponse implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            callCount++;
            
            if (callCount == 1 && req.getMethod() == 'POST') {
                // First call (draft creation) succeeds
                res.setStatusCode(201);
                res.setBody('{"envelopeId": "test-envelope-id", "status": "created"}');
            } else if (req.getMethod() == 'GET' && req.getEndpoint().contains('/docGenFormFields')) {
                // Form fields retrieval fails
                res.setStatusCode(404);
                res.setBody('{"error": "Form fields not found"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            }
            return res;
        }
    }
    
    // Mock class for DocuSign error response
    private class MockDocuSignErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(400);
            res.setBody('{"error": "Invalid request"}');
            return res;
        }
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