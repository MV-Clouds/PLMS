public with sharing class ManagePLMSRecordsPageController {
    @AuraEnabled
    public static List<Account> searchAccounts(String searchTerm, Integer maxSize) {
        if ( String.isBlank(searchTerm) ) {
            return new List<Account>();
        }
    
        String likeTerm = '%' + searchTerm.trim().replace('%', '\\%').replace('_', '\\_') + '%';
        return [SELECT Id, Name FROM Account WHERE Name LIKE :likeTerm  ORDER BY LastModifiedDate DESC LIMIT 50000];
    }
    
    @AuraEnabled
    public static List<Organization__c> getOrganizationsByAccount(String accountId) {
        return [SELECT Id, Name, Account__c FROM Organization__c WHERE Account__c = :accountId ORDER BY Name ASC LIMIT 50];        
    }
    
    @AuraEnabled
    public static Organization__c getOrganizationById(String organizationId) {
        List<Organization__c> orgs = [SELECT Id, Name, Account__c FROM Organization__c WHERE Id = :organizationId LIMIT 1];
        return orgs.isEmpty() ? null : orgs[0];
    }
    
    @AuraEnabled
    public static List<Product_Subscriber__c> getProductSubscribersByOrganization(String organizationId) {
        List<Product_Subscriber__c> subscribers = [SELECT Id, Name, Product__c, Product__r.Name, Install_Date__c, Expiration_DateTime__c, Is_Trial__c, Active__c FROM Product_Subscriber__c WHERE Organization__c = :organizationId and Active__c = true ORDER BY Active__c DESC, Install_Date__c DESC];
        
        return subscribers;
    }
    
    @AuraEnabled
    public static List<Invoice__c> getInvoicesByOrganization(String organizationId) {
        List<Invoice__c> invoices = [SELECT Id, Name, Start_Date__c, Price__c, Status__c, Product_Subscriber__c, CreatedDate FROM Invoice__c WHERE Product_Subscriber__r.Organization__c = :organizationId ORDER BY CreatedDate DESC];
        
        return invoices;
    }
    
    @AuraEnabled
    public static List<Product_Version__c> getProductVersionsBySubscriber(String productSubscriberId) {
        List<Product_Version__c> versions = [SELECT Id, Name, Installed_Date__c, Version_Number__c FROM Product_Version__c WHERE Product_Subscriber__c = :productSubscriberId ORDER BY Installed_Date__c DESC];
        
        return versions;
    }
    
    @AuraEnabled
    public static Product_Subscriber__c getProductSubscriberById(String productSubscriberId) {
        List<Product_Subscriber__c> results = [SELECT Id, Name, Organization__c, Organization__r.Name, Org_Type__c, Org_Name__c, Org_Id__c, Product__c, Product__r.Name, Install_Date__c, Expiration_DateTime__c, Is_Trial__c, Active__c, Last_Upgrade_Date__c, Uninstall_Date__c, Version_Number_Text__c, Product_Plan__c, Product_Plan__r.Name, User_Id__c, Username__c, First_Name__c, Last_Name__c, Email__c, Mobile_Phone__c FROM Product_Subscriber__c WHERE Id = :productSubscriberId LIMIT 1];
        
        return results.isEmpty() ? null : results[0];
    }
    
    @AuraEnabled
    public static Boolean updateProductSubscriberExpiry(String productSubscriberId, String newExpirationDate) {
        try {
            // Expecting date in YYYY-MM-DD (ISO) or an acceptable Date.valueOf format
            Date parsedDate = Date.valueOf(newExpirationDate);
            Datetime newExp = Datetime.newInstance(parsedDate, Time.newInstance(0,0,0,0));
            
            Product_Subscriber__c ps = [SELECT Id, Expiration_DateTime__c FROM Product_Subscriber__c WHERE Id = :productSubscriberId LIMIT 1];
            ps.Expiration_DateTime__c = newExp;
            update ps;
            System.debug('date updated');
            return true;
        } catch (Exception e) {
            System.debug('Error updating expiry: ' + e.getMessage());
            return false;
        }
    }
    
    @AuraEnabled
    public static Boolean updateProductSubscriberPlan(String productSubscriberId, Id newProductPlanId) {
        try {
            Product_Subscriber__c ps = [SELECT Id, Product_Plan__c FROM Product_Subscriber__c WHERE Id = :productSubscriberId LIMIT 1];
            ps.Product_Plan__c = newProductPlanId;
            update ps;
            System.debug('plan updated'  );
            
            return true;
        } catch (Exception e) {
            System.debug('Error updating product plan: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled
    public static List<Product_Plan__c> getProductPlansByProduct(String productId) {
        
        if (String.isBlank(productId)) {
            return new List<Product_Plan__c>();
        }
        
        return [SELECT Id, Name FROM Product_Plan__c WHERE Product__c = :productId ORDER BY Price__c ASC];
    }



}