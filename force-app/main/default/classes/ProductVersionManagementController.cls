public with sharing class ProductVersionManagementController {
    public class ProductVersionResult {
        @AuraEnabled
        public List<Product_Version__c> versions {get;set;}
        @AuraEnabled
        public Integer totalRecords {get;set;}
    }

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts() {
        return [SELECT Id, Name FROM Product__c ORDER BY Name];
    }
    
    @AuraEnabled()
    public static ProductVersionResult getProductVersions(String productId) {
        ProductVersionResult result = new ProductVersionResult();
        result.versions = [SELECT Id, Name, Version_Number__c,  Type__c, Release_Notes__c, Password__c, Version_URL__c FROM Product_Version__c WHERE Product__c = :productId];
        result.totalRecords = result.versions.size();
        return result;
    }
}