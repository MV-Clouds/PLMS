/**
 * Class Name: NewInstallDataController
 * Test Class: - NewInstallDataControllerTest
 * @description: Used to handle the emails and store the org data
 * ****************************************************************
 * @Note: This class is not to be added to the package, it's for the handler org only
 * ****************************************************************
 * Created Date: 1 July, 2025
 * Created By: Harsh Gandhi
 * Last Modified Date: 2 September, 2025
 * Last Modified By: Harsh Gandhi
 * ****************************************************************
 * Modification Log:
 * 2 September, 2025 - Harsh Gandhi - Updated class to create account, contact, account organization, product susbscriber and version records on install and on upgrade creating new product version records
 * ****************************************************************
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
            Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
            String emailBody = email.htmlBody;
            System.debug('emailBody ' + emailBody);

            // Extract data which needs to be used and package action from the email body
            String backendUseData = emailBody.substringAfter('<|--- BackEnd Use Only Data Start ---|>').substringBefore('<|--- BackEnd Use Only Data End ---|>');
            String packageAction = emailBody.substringAfter('<|--- Package Action Start ---|>').substringBefore('<|--- Package Action End ---|>');

            System.debug('packageAction ' + packageAction);
            System.debug('backendUseData ' + backendUseData);

            // Extract product subscriber data wrapper
            Product_Subscriber__c newInstallData = (Product_Subscriber__c) JSON.deserialize(backendUseData, Product_Subscriber__c.class);
            System.debug('newInstallData ' + newInstallData);

            List<Product__c> productRecs = [SELECT Id FROM Product__c WHERE Name = :newInstallData.Installed_Product__c LIMIT 1];
            System.debug('productRecs size ' + productRecs.size());

            // Package Action = Install
            if(packageAction == 'Install' && backendUseData != null && backendUseData != '' && !productRecs.isEmpty()) {
                // Populate necessary fields for product subscriber record
                newInstallData.Product__c = productRecs[0].Id;
                newInstallData.Is_Trial__c = true;
                newInstallData.Install_Date__c = System.today();
                newInstallData.Last_Upgrade_Date__c = System.today();

                // Fetch related account, create new if not found
                List<Account> accountRecs = [SELECT Id, Name FROM Account WHERE Name = :newInstallData.Org_Name__c LIMIT 1];
                Account orgAccount = new Account();
                if(accountRecs.isEmpty()){
                    orgAccount.Name = newInstallData.Org_Name__c;
                    orgAccount.Email__c = newInstallData.Email__c;
                    orgAccount.Phone = newInstallData.Phone__c;

                    Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
                    orgAccount.RecordTypeId = rtId;
                    insert orgAccount;
                } else {
                    orgAccount = accountRecs[0];
                }

                // Create Opportunity record
                Opportunity opp = new Opportunity();
                opp.Name = orgAccount.Name + ' - ' + newInstallData.Installed_Product__c + ' - ' + newInstallData.Version_Number_Text__c;
                opp.AccountId = orgAccount.Id;
                opp.CloseDate = Date.valueOf(newInstallData.Expiration_DateTime__c);
                opp.StageName = 'New';
                opp.MV_Product__c = productRecs[0].Id;
                opp.Product_Subscriber_Detail_JSON__c = JSON.serialize(newInstallData);

                Id rtId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
                opp.RecordTypeId = rtId;
                insert opp;
            } 
            
            // Package Action = Uninstall
            else if(packageAction == 'Uninstall' && backendUseData != null && backendUseData != '' && !productRecs.isEmpty()){
                String productId = productRecs[0].Id;
                String orgId = newInstallData.Org_Id__c;

                // Fetch opportunity record and mark it as closed lost
                List<Opportunity> oppRecs = [SELECT Id, StageName FROM Opportunity WHERE AccountId IN (SELECT Id FROM Account WHERE Name = :newInstallData.Org_Name__c) AND StageName != 'Closed Lost' LIMIT 1];
                System.debug('oppRecs size ' + oppRecs.size());
                if(!oppRecs.isEmpty()){
                    oppRecs[0].StageName = 'Closed Lost';
                    update oppRecs[0];
                }
                
                // Fetch product subscriber record and mark it as inactive
                List<Product_Subscriber__c> productSubscriberRec = [SELECT Id, Org_Id__c, Active__c FROM Product_Subscriber__c WHERE Product__c = :productId AND Org_Id__c = :orgId AND Active__c = true LIMIT 1];
                System.debug('productSubscriberRec size ' + productSubscriberRec.size());

                if(!productSubscriberRec.isEmpty()){
                    productSubscriberRec[0].Uninstall_Date__c = System.today();
                    productSubscriberRec[0].Active__c = false;
                    update productSubscriberRec[0];
                }
            } 
            
            // Package Action = Upgrade
            else if(packageAction == 'Upgrade' && backendUseData != null && backendUseData != '' && !productRecs.isEmpty()){
                String productId = productRecs[0].Id;
                String orgId = newInstallData.Org_Id__c;

                // Fetch product subscriber record
                List<Product_Subscriber__c> productSubscriberRec = [SELECT Id, Org_Id__c, Active__c, Product_Version__c FROM Product_Subscriber__c WHERE Product__c = :productId AND Org_Id__c = :orgId AND Active__c = true LIMIT 1];
                System.debug('productSubscriberRec size ' + productSubscriberRec.size());

                if(!productSubscriberRec.isEmpty()){
                    // Update product subscriber record
                    productSubscriberRec[0].Version_Number_Text__c = newInstallData.Version_Number_Text__c;
                    productSubscriberRec[0].Last_Upgrade_Date__c = System.today();
                    update productSubscriberRec[0];

                    // Create product version record
                    Product_Version__c productVersion = new Product_Version__c();
                    productVersion.Product__c = productRecs[0].Id;
                    productVersion.Name = newInstallData.Installed_Product__c + ' ' + newInstallData.Version_Number_Text__c;
                    productVersion.Version_Number__c = newInstallData.Version_Number_Text__c;
                    productVersion.Product_Subscriber__c = newInstallData.Id;
                    productVersion.Installed_Date__c = System.now();
                    insert productVersion;
                } 
            }

            return result;
        } catch (Exception e) {
            System.debug('Error in handleInboundEmail :: ' + e.getMessage());
            return null;
        }
    }
//The Email Service Email for now is : newinstalldata@xu3km95o0v0e1sqwtcmzhpgmxtfy170b801sod3wb4o19psz0.dm-fn77nuab.ind136.apex.salesforce.com
}