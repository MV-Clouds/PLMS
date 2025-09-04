public with sharing class ManagePLMSRecordsPageController {
    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchTerm, Integer maxSize) {
        // if (!Schema.sObjectType.Account.isAccessible() || String.isBlank(searchTerm) ) {
        //     return new List<Account>();
        // }
        
        // Field access
        Map<String, Schema.SObjectField> f = Account.SObjectType.getDescribe().fields.getMap();
        Boolean nameReadable = isReadable(f, 'Name');
        if (!nameReadable ) {
            return new List<Account>();
        }
        
        Integer size = (maxSize == null || maxSize <= 0 || maxSize > 100) ? 50 : maxSize;
        
        // Query with or without filter
        if (String.isBlank(searchTerm)) {
            return runBaseQuery(nameReadable, size);
        }
        
        String likeTerm = buildLike(searchTerm);
        QueryAccess qa = new QueryAccess(nameReadable,  size);
        return runSearchQuery(qa, likeTerm);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Organization__c> getOrganizationsByAccount(String accountId) {
        // if (!Schema.sObjectType.Organization__c.isAccessible()) {
        //     return new List<Organization__c>();
        // }
        
        // // Field access check
        // Map<String, Schema.SObjectField> orgFields = Organization__c.SObjectType.getDescribe().fields.getMap();
        // Boolean nameReadable = isReadable(orgFields, 'Name');
        // Boolean accountReadable = isReadable(orgFields, 'Account__c');
        
        // if (!nameReadable || !accountReadable) {
        //     return new List<Organization__c>();
        // }
        
        try {
            return [SELECT Id, Name, Account__c FROM Organization__c WHERE Account__c = :accountId ORDER BY Name ASC LIMIT 50];
        } catch (Exception e) {
            System.debug('Error fetching organizations: ' + e.getMessage());
            return new List<Organization__c>();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Organization__c getOrganizationById(String organizationId) {
        // if (!Schema.sObjectType.Organization__c.isAccessible()) {
        //     return null;
        // }
        
        // // Field access check
        // Map<String, Schema.SObjectField> orgFields = Organization__c.SObjectType.getDescribe().fields.getMap();
        // Boolean nameReadable = isReadable(orgFields, 'Name');
        // Boolean accountReadable = isReadable(orgFields, 'Account__c');
        
        // if (!nameReadable || !accountReadable) {
        //     return null;
        // }
        
        try {
            List<Organization__c> orgs = [SELECT Id, Name, Account__c FROM Organization__c WHERE Id = :organizationId LIMIT 1];
            return orgs.isEmpty() ? null : orgs[0];
        } catch (Exception e) {
            System.debug('Error fetching organization: ' + e.getMessage());
            return null;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Product_Subscriber__c> getProductSubscribersByOrganization(String organizationId) {
        // if (!Schema.sObjectType.Product_Subscriber__c.isAccessible()) {
        //     return new List<Product_Subscriber__c>();
        // }
        
        // // Field access check
        // Map<String, Schema.SObjectField> psFields = Product_Subscriber__c.SObjectType.getDescribe().fields.getMap();
        // Boolean orgReadable = isReadable(psFields, 'Organization__c');
        // Boolean nameReadable = isReadable(psFields, 'Name');
        // Boolean productReadable = isReadable(psFields, 'Product__c');
        // Boolean installDateReadable = isReadable(psFields, 'Install_Date__c');
        // Boolean expirationReadable = isReadable(psFields, 'Expiration_DateTime__c');
        // Boolean isTrialReadable = isReadable(psFields, 'Is_Trial__c');
        // Boolean activeReadable = isReadable(psFields, 'Active__c');
        
        // if (!orgReadable) {
        //     return new List<Product_Subscriber__c>();
        // }
        
        try {
            // String query = 'SELECT Id, Name';
            // if (productReadable) { query += ', Product__c, Product__r.Name'; }
            // if (installDateReadable) { query += ', Install_Date__c'; }
            // if (expirationReadable) { query += ', Expiration_DateTime__c'; }
            // if (isTrialReadable) { query += ', Is_Trial__c'; }
            // if (activeReadable) { query += ', Active__c'; }
            
            // query += ' FROM Product_Subscriber__c WHERE Organization__c = :organizationId and Active__c = true'; 
            // if (activeReadable) {
            //     query += ' ORDER BY Active__c DESC, Install_Date__c DESC';
            // } else {
            //     query += ' ORDER BY Install_Date__c DESC';
            // }
            // query += ' LIMIT 100';

            List<Product_Subscriber__c> subscribers = [SELECT Id, Name, Product__c, Product__r.Name, Install_Date__c, Expiration_DateTime__c, Is_Trial__c, Active__c FROM Product_Subscriber__c WHERE Organization__c = :organizationId and Active__c = true ORDER BY Active__c DESC, Install_Date__c DESC];
            
            return subscribers;
        } catch (Exception e) {
            System.debug('Error fetching product subscribers: ' + e.getMessage());
            return new List<Product_Subscriber__c>();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoicesByOrganization(String organizationId) {
        // if (!Schema.sObjectType.Invoice__c.isAccessible() ||
        // !Schema.sObjectType.Product_Subscriber__c.isAccessible()) {
        //     return new List<Invoice__c>();
        // }
        
        // // Field access check
        // Map<String, Schema.SObjectField> invFields = Invoice__c.SObjectType.getDescribe().fields.getMap();
        // Boolean nameReadable = isReadable(invFields, 'Name');
        // Boolean startDateReadable = isReadable(invFields, 'Start_Date__c');
        // Boolean priceReadable = isReadable(invFields, 'Price__c');
        // Boolean statusReadable = isReadable(invFields, 'Status__c');
        // Boolean productSubscriberReadable = isReadable(invFields, 'Product_Subscriber__c');
        
        // if (!productSubscriberReadable) {
        //     return new List<Invoice__c>();
        // }
        
        try {
            // String query = 'SELECT Id';
            // if (nameReadable) {query += ', Name';}
            // if (startDateReadable) {query += ', Start_Date__c';}
            // if (priceReadable) {query += ', Price__c';}
            // if (statusReadable) {query += ', Status__c';}
            
            // query += ' FROM Invoice__c WHERE Product_Subscriber__r.Organization__c = :organizationId';
            // if (startDateReadable) {
            //     query += ' ORDER BY Start_Date__c DESC';
            // }
            // query += ' LIMIT 100';

            List<Invoice__c> invoices = [SELECT Id, Name, Start_Date__c, Price__c, Status__c, Product_Subscriber__c, CreatedDate FROM Invoice__c WHERE Product_Subscriber__r.Organization__c = :organizationId ORDER BY CreatedDate DESC];
            
            return invoices;
        } catch (Exception e) {
            System.debug('Error fetching invoices: ' + e.getMessage());
            return new List<Invoice__c>();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Product_Version__c> getProductVersionsBySubscriber(String productSubscriberId) {
        // if (!Schema.sObjectType.Product_Version__c.isAccessible()) {
        //     return new List<Product_Version__c>();
        // }
        
        // // Field access check
        // Map<String, Schema.SObjectField> pvFields = Product_Version__c.SObjectType.getDescribe().fields.getMap();
        // Boolean nameReadable = isReadable(pvFields, 'Name');
        // Boolean installedDateReadable = isReadable(pvFields, 'Installed_Date__c');
        // Boolean productSubscriberReadable = isReadable(pvFields, 'Product_Subscriber__c');
        
        // if (!productSubscriberReadable) {
        //     return new List<Product_Version__c>();
        // }
        
        try {
            // String query = 'SELECT Id';
            // if (nameReadable) {query += ', Name';}
            // if (installedDateReadable) {query += ', Installed_Date__c';}
            
            // query += ' FROM Product_Version__c WHERE Product_Subscriber__c = :productSubscriberId';
            // if (installedDateReadable) {
            //     query += ' ORDER BY Installed_Date__c DESC';
            // }
            // query += ' LIMIT 50';

            List<Product_Version__c> versions = [SELECT Id, Name, Installed_Date__c, Version_Number__c FROM Product_Version__c WHERE Product_Subscriber__c = :productSubscriberId ORDER BY Installed_Date__c DESC];
            
            return versions;
        } catch (Exception e) {
            System.debug('Error fetching product versions: ' + e.getMessage());
            return new List<Product_Version__c>();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Product_Subscriber__c getProductSubscriberById(String productSubscriberId) {
        
        
        // System.debug('productSubscriberId >>' + productSubscriberId);
        // if (!Schema.sObjectType.Product_Subscriber__c.isAccessible()) {
        //     System.debug(' not accessible ' );
        //     return null;
        // }
        
        // // Field access check
        // Map<String, Schema.SObjectField> psFields = Product_Subscriber__c.SObjectType.getDescribe().fields.getMap();
        // Boolean nameReadable = isReadable(psFields, 'Name');
        // Boolean orgReadable = isReadable(psFields, 'Organization__c');
        // Boolean productReadable = isReadable(psFields, 'Product__c');
        // Boolean installDateReadable = isReadable(psFields, 'Install_Date__c');
        // Boolean expirationReadable = isReadable(psFields, 'Expiration_DateTime__c');
        // Boolean isTrialReadable = isReadable(psFields, 'Is_Trial__c');
        // Boolean activeReadable = isReadable(psFields, 'Active__c');
        // Boolean lastUpgradeReadable = isReadable(psFields, 'Last_Upgrade_Date__c');
        // Boolean uninstallDateReadable = isReadable(psFields, 'Uninstall_Date__c');
        // Boolean versionNumberReadable = isReadable(psFields, 'Version_Number__c');
        // Boolean productPlanReadable = isReadable(psFields, 'Product_Plan__c');
        // Boolean installedUserReadable = isReadable(psFields, 'Installed_User__c');
        
        try {
        //     String query = 'SELECT Id';
        //     if (nameReadable) {query += ', Name';}
        //     if (orgReadable) {query += ', Organization__c, Organization__r.Name, Org_Type__c';}
        //     if (productReadable) {query += ', Product__c, Product__r.Name';}
        //     if (installDateReadable) {query += ', Install_Date__c';}
        //     if (expirationReadable) {query += ', Expiration_DateTime__c';}
        //     if (isTrialReadable) {query += ', Is_Trial__c';}
        //     if (activeReadable) {query += ', Active__c';}
        //     if (lastUpgradeReadable) {query += ', Last_Upgrade_Date__c';}
        //     if (uninstallDateReadable) {query += ', Uninstall_Date__c';}
        //     if (versionNumberReadable) {query += ', Version_Number__c';}
        //     if (productPlanReadable) {query += ', Product_Plan__c, Product_Plan__r.Name';}
        //     if (installedUserReadable) {
        //         query += ', Installed_User__c, Installed_User__r.FirstName, Installed_User__r.LastName';
        //         query += ', Installed_User__r.Email, Installed_User__r.Username, Installed_User__r.Phone';
        //     }
            
        //     query += ' FROM Product_Subscriber__c WHERE Id = :productSubscriberId LIMIT 1';
            
            List<Product_Subscriber__c> results = [SELECT Id, Name, Organization__c, Organization__r.Name, Org_Type__c, Org_Name__c, Org_Id__c, Product__c, Product__r.Name, Install_Date__c, Expiration_DateTime__c, Is_Trial__c, Active__c, Last_Upgrade_Date__c, Uninstall_Date__c, Version_Number_Text__c, Product_Plan__c, Product_Plan__r.Name, User_Id__c, Username__c, First_Name__c, Last_Name__c, Email__c, Mobile_Phone__c FROM Product_Subscriber__c WHERE Id = :productSubscriberId LIMIT 1];
            
            return results.isEmpty() ? null : results[0];
        } catch (Exception e) {
            System.debug('Error fetching product subscriber: ' + e.getMessage());
            return null;
        }
    }
    
    @AuraEnabled
    public static Boolean updateProductSubscriberExpiry(String productSubscriberId, String newExpirationDate) {
        if (String.isBlank(productSubscriberId) || String.isBlank(newExpirationDate)) {
            return false;
        }
        if (!Schema.sObjectType.Product_Subscriber__c.isAccessible()) {
            return false;
        }
        Map<String, Schema.SObjectField> psFields = Product_Subscriber__c.SObjectType.getDescribe().fields.getMap();
        if (!psFields.containsKey('Expiration_DateTime__c') || !psFields.get('Expiration_DateTime__c').getDescribe().isUpdateable()) {
            System.debug('Field Expiration_DateTime__c is not updateable or does not exist');
            return false;
        }
        
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
        if (String.isBlank(productSubscriberId) || newProductPlanId == null) {
            return false;
        }
        if (!Schema.sObjectType.Product_Subscriber__c.isAccessible()) {
            return false;
        }
        Map<String, Schema.SObjectField> psFields = Product_Subscriber__c.SObjectType.getDescribe().fields.getMap();
        if (!psFields.containsKey('Product_Plan__c') || !psFields.get('Product_Plan__c').getDescribe().isUpdateable()) {
            System.debug('Field Product_Plan__c is not updateable or does not exist');
            return false;
        }
        
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
    
    private static Boolean isReadable(Map<String, Schema.SObjectField> f, String api) {
        return f.containsKey(api) && f.get(api).getDescribe().isAccessible();
    }
    
    private static String buildLike(String input) {
        String term = input.trim();
        term = term.replace('%', '\\%').replace('_', '\\_');
        return '%' + term + '%';
    }
    
    private static List<Account> runBaseQuery(Boolean nameReadable, Integer size) {
        if (nameReadable ) {
            return [SELECT Id, Name FROM Account ORDER BY LastModifiedDate DESC LIMIT :size];
        }
        return new List<Account>();
    }
    
    private static List<Account> runSearchQuery(QueryAccess qa, String likeTerm) {
        if (qa.nameReadable ) {
            return [SELECT Id, Name FROM Account WHERE Name LIKE :likeTerm  ORDER BY LastModifiedDate DESC LIMIT :qa.size];
        }
        return new List<Account>();
    }
    
    private class QueryAccess {
        Boolean nameReadable;
        Integer size;
        QueryAccess(Boolean n,  Integer s) {
            this.nameReadable = n;
            this.size = s;
        }
    }
}