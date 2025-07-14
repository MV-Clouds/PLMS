public with sharing class ProductPlanManagementController {
    public class ProductPlanResult {
        @AuraEnabled
        public List<Product_Plan__c> plans {get;set;}
        @AuraEnabled
        public Integer totalRecords {get;set;}
    }

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts() {
        return [SELECT Id, Name FROM Product__c ORDER BY Name];
    }
    
    @AuraEnabled()
    public static ProductPlanResult getProductPlans(String productId) {
        ProductPlanResult result = new ProductPlanResult();
        result.plans = [SELECT Id, Name, Price__c, Description__c FROM Product_Plan__c WHERE Product__c = :productId];
        result.totalRecords = result.plans.size();
        return result;
    }
}