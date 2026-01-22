/**
 * Class Name: ProductSubscriberAPIController
 * Test Class: - ProductSubscriberAPIControllerTest
 * @description: Used to handle product subscriber actions (Install, Uninstall, Upgrade) via REST API
 * ****************************************************************
 * Created Date: 21 January, 2026
 * Created By: Rachit Shah
 * ****************************************************************
 * Modification Log:
 * ****************************************************************
*/
public without sharing class ProductSubscriberAPIController {
    
    // Wrapper class for API request
    public class ProductSubscriberRequest {
        public String action { get; set; } // Install, Uninstall, Upgrade
        public Product_Subscriber__c subscriberData { get; set; }
        public List<String> notificationEmails { get; set; } // Email addresses passed from package org 
    }

    // Wrapper class for API response
    public class ProductSubscriberResponse {
        public Boolean success { get; set; }
        public String message { get; set; }
        public String recordId { get; set; }

        public ProductSubscriberResponse(Boolean success, String message, String recordId) {
            this.success = success;
            this.message = message;
            this.recordId = recordId;
        }
    }

    /*
    *********************************************************
    @description     : Main method to process product subscriber actions based on action type
    @param           : request - {ProductSubscriberRequest} - Contains action and subscriber data
    @return          : ProductSubscriberResponse - Response with success status and message
    ********************************************************
    */
    public static ProductSubscriberResponse processAction(ProductSubscriberRequest request) {
        if (request == null || String.isBlank(request.action) || request.subscriberData == null) {
            return new ProductSubscriberResponse(false, 'Invalid request: action and subscriberData are required', null);
        }

        String action = request.action;
        Product_Subscriber__c subscriberData = request.subscriberData;

        // Validate Org_Id__c is present
        if (String.isBlank(subscriberData.Org_Id__c)) {
            return new ProductSubscriberResponse(false, 'Org_Id__c is required', null);
        }

        // Fetch product record with Support_Developer_Email__c for email notifications
        List<Product__c> productRecs = [SELECT Id, Support_Developer_Email__c FROM Product__c WHERE Name = :subscriberData.Installed_Product__c LIMIT 1];
        
        if (productRecs.isEmpty()) {
            return new ProductSubscriberResponse(false, 'Product not found: ' + subscriberData.Installed_Product__c, null);
        }

        // Get notification emails from request (passed from package org)
        List<String> notificationEmails = request.notificationEmails != null ? request.notificationEmails : new List<String>();

        if (action == 'Install') {
            return handleInstall(subscriberData, productRecs[0], notificationEmails);
        } else if (action == 'Uninstall') {
            return handleUninstall(subscriberData, productRecs[0], notificationEmails);
        } else if (action == 'Upgrade') {
            return handleUpgrade(subscriberData, productRecs[0], notificationEmails);
        } else {
            return new ProductSubscriberResponse(false, 'Invalid action: ' + action + '. Valid actions are Install, Uninstall, Upgrade', null);
        }
    }

    /*
    *********************************************************
    @description     : Handles the Install action - Creates Product Subscriber, Opportunity, Lead, and Task
    @param           : subscriberData - {Product_Subscriber__c} - Subscriber data from request
    @param           : product - {Product__c} - Related product record
    @param           : notificationEmails - {List<String>} - Email addresses passed from package org
    @return          : ProductSubscriberResponse
    ********************************************************
    */
    public static ProductSubscriberResponse handleInstall(Product_Subscriber__c subscriberData, Product__c product, List<String> notificationEmails) {
        try {
            // Populate necessary fields for product subscriber record
            subscriberData.Product__c = product.Id;
            subscriberData.Is_Trial__c = true;
            subscriberData.Install_Date__c = System.today();
            subscriberData.Active__c = true;

            // Find Product Version by Version_Number_Text__c
            List<Product_Version__c> productVersionRecs = [
                SELECT Id, Version_Number__c 
                FROM Product_Version__c 
                WHERE Version_Number__c = :subscriberData.Version_Number_Text__c 
                AND Product__c = :product.Id 
                LIMIT 1
            ];
            
            if (!productVersionRecs.isEmpty()) {
                subscriberData.Product_Version__c = productVersionRecs[0].Id;
            }

            // Insert Product Subscriber record
            insert subscriberData;

            // Create Opportunity record
            Opportunity opp = new Opportunity();
            opp.Name = subscriberData.Installed_Product__c + ' New Install' + ' - ' + Date.valueOf(System.today()) + ' - ' + subscriberData.Org_Name__c;
            opp.CloseDate = Date.valueOf(subscriberData.Expiration_DateTime__c);
            opp.StageName = 'New';
            opp.Product_Subscriber__c = subscriberData.Id;
            insert opp;

            // Query the inserted Product_Subscriber__c to get more fields
            Product_Subscriber__c productSubscriber = [
                SELECT Id, Environment__c, Org_Id__c, Org_Name__c, Email__c, First_Name__c, Last_Name__c, Phone__c, Mobile_Phone__c 
                FROM Product_Subscriber__c 
                WHERE Id = :subscriberData.Id 
                LIMIT 1
            ];
            productSubscriber.Opportunity__c = opp.Id;

            // Find or create Lead
            List<Lead> leadRecs = [SELECT Id, Email, FirstName, LastName, Company FROM Lead WHERE Email = :subscriberData.Email__c LIMIT 1];

            if (!leadRecs.isEmpty()) {
                productSubscriber.Lead__c = leadRecs[0].Id;
            } else {
                Lead leadRec = new Lead();
                leadRec.FirstName = productSubscriber.First_Name__c;
                leadRec.LastName = productSubscriber.Last_Name__c;
                leadRec.Company = productSubscriber.Org_Id__c;
                leadRec.Company_Name__c = productSubscriber.Org_Name__c;
                leadRec.Email = productSubscriber.Email__c;
                leadRec.Phone = productSubscriber.Phone__c;
                leadRec.MobilePhone = productSubscriber.Mobile_Phone__c;
                leadRec.LeadSource = productSubscriber.Environment__c == 'Sandbox' ? 'Product Installation - Sandbox' : 'Product Installation';
                insert leadRec;

                productSubscriber.Lead__c = leadRec.Id;
            }
            update productSubscriber;

            // Create Task record
            Task newTask = new Task();
            newTask.ActivityDate = Date.today();
            newTask.Subject = 'New Install - ' + subscriberData.Installed_Product__c;
            newTask.Description = 'Product: ' + subscriberData.Installed_Product__c + '\nOrg: ' + subscriberData.Org_Name__c + '\nVersion: ' + subscriberData.Version_Number_Text__c;
            newTask.WhatId = subscriberData.Id;
            newTask.Status = 'Completed';
            insert newTask;

            // Send success notification email
            sendSuccessEmail(product, subscriberData, notificationEmails, 'Install');

            return new ProductSubscriberResponse(true, 'Install processed successfully. Product Subscriber, Opportunity, Lead, and Task created.', subscriberData.Id);
        } catch (Exception e) {
            return new ProductSubscriberResponse(false, 'Error during Install: ' + e.getMessage(), null);
        }
    }

    /*
    *********************************************************
    @description     : Handles the Uninstall action - Closes Opportunity and deactivates Product Subscriber
    @param           : subscriberData - {Product_Subscriber__c} - Subscriber data from request
    @param           : product - {Product__c} - Related product record
    @param           : notificationEmails - {List<String>} - Email addresses passed from package org
    @return          : ProductSubscriberResponse
    ********************************************************
    */
    public static ProductSubscriberResponse handleUninstall(Product_Subscriber__c subscriberData, Product__c product, List<String> notificationEmails) {
        try {
            String productId = product.Id;
            String orgId = subscriberData.Org_Id__c;

            // Fetch active product subscriber record
            List<Product_Subscriber__c> productSubscriberRec = [
                SELECT Id, Org_Id__c, Active__c, Opportunity__c 
                FROM Product_Subscriber__c 
                WHERE Product__c = :productId 
                AND Org_Id__c = :orgId 
                AND Active__c = true 
                LIMIT 1
            ];

            String recordId = null;
            if (!productSubscriberRec.isEmpty()) {
                // If Opportunity exists, mark it as Closed Lost
                if (productSubscriberRec[0].Opportunity__c != null) {
                    Opportunity oppRec = [SELECT Id FROM Opportunity WHERE Id = :productSubscriberRec[0].Opportunity__c];
                    oppRec.StageName = 'Closed Lost';
                    update oppRec;
                }

                // Mark Product Subscriber as inactive
                productSubscriberRec[0].Active__c = false;
                update productSubscriberRec[0];
                recordId = productSubscriberRec[0].Id;
            }

            // Send success notification email
            sendSuccessEmail(product, subscriberData, notificationEmails, 'Uninstall');

            return new ProductSubscriberResponse(true, 'Uninstall processed successfully.', recordId);
        } catch (Exception e) {
            return new ProductSubscriberResponse(false, 'Error during Uninstall: ' + e.getMessage(), null);
        }
    }

    /*
    *********************************************************
    @description     : Handles the Upgrade action - Updates Product Subscriber with new version
    @param           : subscriberData - {Product_Subscriber__c} - Subscriber data from request
    @param           : product - {Product__c} - Related product record
    @param           : notificationEmails - {List<String>} - Email addresses passed from package org
    @return          : ProductSubscriberResponse
    ********************************************************
    */
    public static ProductSubscriberResponse handleUpgrade(Product_Subscriber__c subscriberData, Product__c product, List<String> notificationEmails) {
        try {
            String productId = product.Id;
            String orgId = subscriberData.Org_Id__c;

            // Fetch active product subscriber record
            List<Product_Subscriber__c> productSubscriberRec = [
                SELECT Id, Org_Id__c, Active__c, Product_Version__c 
                FROM Product_Subscriber__c 
                WHERE Product__c = :productId 
                AND Org_Id__c = :orgId 
                AND Active__c = true 
                LIMIT 1
            ];

            if (productSubscriberRec.isEmpty()) {
                // Send email if no active subscriber found
                sendEmail(product, subscriberData, notificationEmails);
                return new ProductSubscriberResponse(false, 'No active Product Subscriber found for the given Org Id', null);
            }
            else{
                productSubscriberRec[0].Version_Number_Text__c = subscriberData.Version_Number_Text__c;
                productSubscriberRec[0].Last_Upgrade_Date__c = System.today();
            }

            // Find Product Version by Version_Number_Text__c
            List<Product_Version__c> productVersionRecs = [
                SELECT Id, Version_Number__c 
                FROM Product_Version__c 
                WHERE Version_Number__c = :subscriberData.Version_Number_Text__c 
                AND Product__c = :productId 
                LIMIT 1
            ];

            if (!productVersionRecs.isEmpty()) {
                productSubscriberRec[0].Product_Version__c = productVersionRecs[0].Id;
            } 
           
            update productSubscriberRec[0];

            // Send success notification email
            sendSuccessEmail(product, subscriberData, notificationEmails, 'Upgrade');
            return new ProductSubscriberResponse(true, 'Upgrade processed successfully.', productSubscriberRec[0].Id);

        } catch (Exception e) {
            return new ProductSubscriberResponse(false, 'Error during Upgrade: ' + e.getMessage(), null);
        }
    }


    /*
    *********************************************************
    @description     : Sends email to notification emails if no active Product Subscriber found
    @param           : product - {Product__c} - Product record with Support_Developer_Email__c
    @param           : subscriberData - {Product_Subscriber__c} - Subscriber data for email content
    @param           : notificationEmails - {List<String>} - Email addresses passed from package org
    @return          : void
    ********************************************************
    */
    public static void sendEmail(Product__c product, Product_Subscriber__c subscriberData, List<String> notificationEmails) {
        try {
            OrgWideEmailAddress owea = [
                SELECT Id , Address, DisplayName
                FROM OrgWideEmailAddress
                WHERE DisplayName = 'PLMS'
                LIMIT 1
            ];
            // Use emails passed from package org, fall back to empty list if null
            List<String> emails = notificationEmails != null && !notificationEmails.isEmpty() 
                ? new List<String>(notificationEmails)
                : new List<String>();

            // Return if no emails to send to
            if (emails.isEmpty()) {
                return;
            }

            String subject = 'Upgrade Attempt - No Active Subscriber Found - ' + subscriberData.Org_Id__c;
            String bodyIntro = 'Hello Team,<br/><br/>An upgrade attempt was made for the ' + subscriberData.Installed_Product__c + ' app in an Organization, but no active Product Subscriber record was found. Below are some details about the client org.<br/><br/>';
            // Build Organization Details Table
            String orgDataTable = '<table border="1" style="border-collapse: collapse;text-align:left; color: black;" cellpadding="4px">' +
                '<tr style="text-align:center;">' +
                    '<th colspan="2" style="font-size: 18px; color: white; background-color:#165668;">Organization Details</th>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Organization Id</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Org_Id__c) ? subscriberData.Org_Id__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Organization Name</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Org_Name__c) ? subscriberData.Org_Name__c : '-') + '</td>' +
                '</tr>' +
                '</table>'; 
            String body = '<div style="font-family:Verdana;">' + bodyIntro + orgDataTable + '<br/><br/>Thanks,<br/>PLMS Team</div>'; 
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setOrgWideEmailAddressId(owea.Id);
            mail.setToAddresses(emails);
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug('Error in sendEmail :: ' + e.getMessage());
        }
    }

    /*
    *********************************************************
    @description     : Sends success notification email for Install, Upgrade, or Uninstall actions
    @param           : productRec - {Product__c} - Product record with Support_Developer_Email__c
    @param           : subscriberData - {Product_Subscriber__c} - Subscriber data for email content
    @param           : notificationEmails - {List<String>} - Email addresses passed from package org
    @param           : action - {String} - The action type (Install, Upgrade, Uninstall)
    @return          : void
    ********************************************************
    */
    public static void sendSuccessEmail(Product__c productRec, Product_Subscriber__c subscriberData, List<String> notificationEmails, String action) {
        try {
            OrgWideEmailAddress owea = [
                SELECT Id , Address, DisplayName
                FROM OrgWideEmailAddress
                WHERE DisplayName = 'PLMS'
                LIMIT 1
            ];

            // Use emails passed from package org, fall back to empty list if null
            List<String> emails = notificationEmails != null && !notificationEmails.isEmpty() 
                ? new List<String>(notificationEmails) 
                : new List<String>();
            
            // Add Support Developer Email if available and not already in list
            if (productRec.Support_Developer_Email__c != null) {
                String supportEmail = productRec.Support_Developer_Email__c;
                if (!emails.contains(supportEmail)) {
                    emails.add(supportEmail);
                }
            }

            // Return if no emails to send to
            if (emails.isEmpty()) {
                return;
            }

            // Build Organization Details Table
            String orgDataTable = '<table border="1" style="border-collapse: collapse;text-align:left; color: black;" cellpadding="4px">' +
                '<tr style="text-align:center;">' +
                    '<th colspan="2" style="font-size: 18px; color: white; background-color:#165668;">Organization Details</th>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Organization Id</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Org_Id__c) ? subscriberData.Org_Id__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Organization Name</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Org_Name__c) ? subscriberData.Org_Name__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Environment</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Environment__c) ? subscriberData.Environment__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Product</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Installed_Product__c) ? subscriberData.Installed_Product__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Version</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Version_Number_Text__c) ? subscriberData.Version_Number_Text__c : '-') + '</td>' +
                '</tr>' +
                '</table>';

            // Build User Details Table
            String userDataTable = '<table border="1" style="border-collapse: collapse;text-align:left; color: black;" cellpadding="4px">' +
                '<tr style="text-align:center;">' +
                    '<th colspan="2" style="font-size: 18px; color: white; background-color:#165668;">User Details</th>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">First Name</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.First_Name__c) ? subscriberData.First_Name__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Last Name</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Last_Name__c) ? subscriberData.Last_Name__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Email</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Email__c) ? subscriberData.Email__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Phone</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Phone__c) ? subscriberData.Phone__c : '-') + '</td>' +
                '</tr>' +
                '<tr>' +
                    '<th style="color: #165668">Mobile Phone</th>' +
                    '<td>' + (String.isNotBlank(subscriberData.Mobile_Phone__c) ? subscriberData.Mobile_Phone__c : '-') + '</td>' +
                '</tr>' +
                '</table>';

            // Build backend data map for processing
            Map<String, Object> mapOfData = new Map<String, Object>();
            mapOfData.put('Org_Id__c', subscriberData.Org_Id__c);
            mapOfData.put('Org_Name__c', subscriberData.Org_Name__c);
            mapOfData.put('Environment__c', subscriberData.Environment__c);
            mapOfData.put('Installed_Product__c', subscriberData.Installed_Product__c);
            mapOfData.put('Version_Number_Text__c', subscriberData.Version_Number_Text__c);
            mapOfData.put('First_Name__c', subscriberData.First_Name__c);
            mapOfData.put('Last_Name__c', subscriberData.Last_Name__c);
            mapOfData.put('Email__c', subscriberData.Email__c);
            mapOfData.put('Phone__c', subscriberData.Phone__c);
            mapOfData.put('Mobile_Phone__c', subscriberData.Mobile_Phone__c);
            String stringToSend = JSON.serialize(mapOfData);

            // Build email subject and body based on action
            String subject = '';
            String bodyIntro = '';
            
            if (action == 'Install') {
                subject = subscriberData.Installed_Product__c + ' New Install - ' + subscriberData.Org_Id__c;
                bodyIntro = 'Congrats Team 🎉,<br/><br/>The ' + subscriberData.Installed_Product__c + ' app has been installed in an Organization. Below are some details about the client org.<br/><br/>';
            } else if (action == 'Upgrade') {
                subject = subscriberData.Installed_Product__c + ' Upgraded - ' + subscriberData.Org_Id__c;
                bodyIntro = 'Dear Team,<br/><br/>The ' + subscriberData.Installed_Product__c + ' app has been upgraded to version ' + subscriberData.Version_Number_Text__c + ' in an Organization. Below are some details about the client org.<br/><br/>';
            } else if (action == 'Uninstall') {
                subject = subscriberData.Installed_Product__c + ' Uninstalled - ' + subscriberData.Org_Id__c;
                bodyIntro = 'Dear Team,<br/><br/>The ' + subscriberData.Installed_Product__c + ' app has been uninstalled from an Organization. Below are some details about the client org.<br/><br/>';
            }

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(emails);
            email.setSubject(subject);
            email.setOrgWideEmailAddressId(owea.Id);
            
            // Include userDataTable only for Install and Upgrade actions, not for Uninstall
            String emailBody = '<div style="font-family:Verdana;">' + bodyIntro + orgDataTable;
            if (action != 'Uninstall') {
                emailBody += '<br/>' + userDataTable;
            }
            emailBody += '</div>';
            email.setHtmlBody(emailBody);
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            System.debug('Error in sendSuccessEmail :: ' + e.getMessage());
        }
    }
}