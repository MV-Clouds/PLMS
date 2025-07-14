/**
 * Class Name: NewInstallDataController
 * Test Class: -
 * @description: Used to handle the emails and store the org data
 * ****************************************************************
 * @Note: This class is not to be added to the package, it's for the handler org only
 * ****************************************************************
 * Created Date: 1 July, 2025
 * Created By: Harsh Gandhi
*/
public with sharing class NewInstallDataController implements Messaging.InboundEmailHandler{
    /*
    *********************************************************
    @description     : Method is used to handle the emails and store the org data
    @param           : email - {Messaging.InboundEmail} - Data about the email to be handled
    @param           : envelope - {Messaging.InboundEnvelope} - emails of the sender and recipient
    @return          : none
    ********************************************************
    */
    public Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        try {
            System.debug('email :: ' + email);
            Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
            String emailBody = email.htmlBody;
            System.debug('emailBody ' + emailBody);
            String backendUseData = emailBody.substringAfter('<|--- BackEnd Use Only Data Start ---|>').substringBefore('<|--- BackEnd Use Only Data End ---|>');
            String packageAction = emailBody.substringAfter('<|--- Package Action Start ---|>').substringBefore('<|--- Package Action End ---|>');

            System.debug('packageAction ' + packageAction);
            System.debug('backendUseData ' + backendUseData);

            if(packageAction == 'Install' && backendUseData != null && backendUseData != '') {
                Product_Subscriber__c newInstallData = (Product_Subscriber__c) JSON.deserialize(backendUseData, Product_Subscriber__c.class);
                System.debug('newInstallData ' + newInstallData);
                
                if(newInstallData.Org_Id__c != null){
                    List<Product__c> productRecs = [SELECT Id FROM Product__c WHERE Name = :newInstallData.Installed_Product__c LIMIT 1];
                    System.debug('productRecs size ' + productRecs.size());

                    if(!productRecs.isEmpty()){
                        System.debug('productId ' + productRecs[0].Id);
    
                        newInstallData.Product__c = productRecs[0].Id;
                        newInstallData.Is_Trial__c = true;
                        newInstallData.Install_Date__c = System.today();
                        newInstallData.Active__c = true;

                        List<Product_Version__c> productVersionRecs = [SELECT Id, Version_Number__c FROM Product_Version__c WHERE Version_Number__c = :newInstallData.Version_Number_Text__c AND Product__c = :productRecs[0].Id LIMIT 1];
                        if(!productVersionRecs.isEmpty()){
                            newInstallData.Product_Version__c = productVersionRecs[0].Id;
                        } else {
                            sendEmail(productRecs[0], newInstallData);
                        }
                        insert newInstallData;
        
                        Opportunity opp = new Opportunity();
                        opp.Name = newInstallData.Installed_Product__c + ' New Install' + ' - ' + Date.valueOf(System.today()) + ' - ' + newInstallData.Org_Name__c;
                        opp.CloseDate = Date.valueOf(newInstallData.Expiration_DateTime__c);
                        opp.StageName = 'New';
                        opp.Product_Subscriber__c = newInstallData.Id;
                        insert opp;
                        System.debug('Opportunity created with Id: ' + opp.Id);
        
                        Product_Subscriber__c productSubscriber = [SELECT Id, Environment__c, Org_Id__c, Org_Name__c, Email__c, First_Name__c, Last_Name__c, Phone__c, Mobile_Phone__c FROM Product_Subscriber__c WHERE Id = :newInstallData.Id LIMIT 1];
                        productSubscriber.Opportunity__c = opp.Id;
                        List<Lead> leadRecs = [SELECT Id, Email, FirstName, LastName, Company FROM Lead WHERE Email = :newInstallData.Email__c LIMIT 1];
                        System.debug('leadRecs ' + leadRecs);
    
                        if(leadRecs.size() > 0){
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
                            leadRec.LeadSource = productSubscriber.Environment__c == 'Sandbox' ? 'Product Installation - Sandbox"' : 'Product Installation';
                            insert leadRec;
        
                            productSubscriber.Lead__c = leadRec.Id;
                        }
                        update productSubscriber;
        
                        Task newTask = new Task();
                        newTask.ActivityDate = Date.today();
                        newTask.Subject = email.subject;
                        newTask.description = emailBody;
                        newTask.WhatId = newInstallData.Id;
                        newTask.Status = 'Completed';
                        insert as User newTask;
                    }
                }
            } else if(packageAction == 'Uninstall'){
                Product_Subscriber__c newInstallData = (Product_Subscriber__c) JSON.deserialize(backendUseData, Product_Subscriber__c.class);
                List<Product__c> productRecs = [SELECT Id FROM Product__c WHERE Name = :newInstallData.Installed_Product__c LIMIT 1];
                System.debug('productRecs size ' + productRecs.size());
                
                if(!productRecs.isEmpty()){
                    String productId = productRecs[0].Id;
                    String orgId = newInstallData.Org_Id__c;
                    List<Product_Subscriber__c> productSubscriberRec = [SELECT Id, Org_Id__c, Active__c, Opportunity__c FROM Product_Subscriber__c WHERE Product__c = :productId AND Org_Id__c = :orgId AND Active__c = true LIMIT 1];
                    System.debug('productSubscriberRec size ' + productSubscriberRec.size());
    
                    if(!productSubscriberRec.isEmpty()){
                        if(productSubscriberRec[0].Opportunity__c != null){
                            Opportunity oppRec = [SELECT Id FROM Opportunity WHERE Id = :productSubscriberRec[0].Opportunity__c];
                            oppRec.StageName = 'Closed Lost';
                            update oppRec;
                        }
                        productSubscriberRec[0].Active__c = false;
                        update productSubscriberRec[0];
                    }
                }
            } else if(packageAction == 'Upgrade'){
                Product_Subscriber__c newInstallData = (Product_Subscriber__c) JSON.deserialize(backendUseData, Product_Subscriber__c.class);
                List<Product__c> productRecs = [SELECT Id, Support_Developer_Email__c FROM Product__c WHERE Name = :newInstallData.Installed_Product__c LIMIT 1];
                System.debug('productRecs size ' + productRecs.size());
                
                if(!productRecs.isEmpty()){
                    String productId = productRecs[0].Id;
                    String orgId = newInstallData.Org_Id__c;
                    List<Product_Subscriber__c> productSubscriberRec = [SELECT Id, Org_Id__c, Active__c, Product_Version__c FROM Product_Subscriber__c WHERE Product__c = :productId AND Org_Id__c = :orgId AND Active__c = true LIMIT 1];
                    System.debug('productSubscriberRec size ' + productSubscriberRec.size());
    
                    if(!productSubscriberRec.isEmpty()){
                        List<Product_Version__c> productVersionRecs = [SELECT Id, Version_Number__c FROM Product_Version__c WHERE Version_Number__c = :newInstallData.Version_Number_Text__c AND Product__c = :productId LIMIT 1];
                        if(!productVersionRecs.isEmpty()){
                            productSubscriberRec[0].Version_Number_Text__c = newInstallData.Version_Number_Text__c;
                            productSubscriberRec[0].Product_Version__c = productVersionRecs[0].Id;
                            productSubscriberRec[0].Last_Upgrade_Date__c = System.today();
                            update productSubscriberRec[0];
                        }
                    } else {
                        sendEmail(productRecs[0], newInstallData);
                    }
                }
            }

            return result;
        } catch (Exception e) {
            System.debug('Error in handleInboundEmail :: ' + e.getMessage());
            return null;
        }
    }

    public static void sendEmail(Product__c productRecs, Product_Subscriber__c newInstallData) {
        try {
            List<String> emails = new List<String>{'dharmik@mvclouds.com'};
            if(productRecs.Support_Developer_Email__c != null){
                String supportEmail = productRecs.Support_Developer_Email__c;
                if(!emails.contains(supportEmail)){
                    emails.add(supportEmail);
                }
            }
            string[] to = emails;
            
            Messaging.SingleEmailMessage sendemail = new Messaging.SingleEmailMessage();
            sendemail.setToAddresses(to);
            sendemail.setSubject('Someone has installed the ' + newInstallData.Installed_Product__c + ' package for which Package Version is not available in the PLMS org');
            sendemail.setHtmlBody('<div style="font-family:Verdana;">Hello Team,<br/>' + 'Someone has installed the ' + newInstallData.Installed_Product__c + ' package for which Package Version is not available in the PLMS org. <br/> Package Version Number : ' + newInstallData.Version_Number_Text__c + '<br/><br/></div>');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { sendemail });
        } catch (Exception e) {
            System.debug('Error in sendEmail :: ' + e.getMessage());
        }
    }
//The Email Service Email for now is : newinstalldata@xu3km95o0v0e1sqwtcmzhpgmxtfy170b801sod3wb4o19psz0.dm-fn77nuab.ind136.apex.salesforce.com
}