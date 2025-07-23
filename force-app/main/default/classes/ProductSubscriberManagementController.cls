public with sharing class ProductSubscriberManagementController {
    
    @AuraEnabled
    public static List<Product_Subscriber__c> getProductSubscribers(String productId) {
        return [SELECT Id, Name, Expiration_DateTime__c,Org_Name__c,Install_Date__c, Is_Trial__c, Product__r.Name, Product_Plan__r.Name ,Product_Version__r.Name , Discount__c, Duration__c, Version_Number_Text__c FROM Product_Subscriber__c WHERE Product__c = :productId ORDER BY LastModifiedDate DESC];
    }
    
    @AuraEnabled
    public static Product_Subscriber__c updateProductSubscriber(Id subscriberId, Boolean isTrial, Id productPlanId, Decimal discount, Integer duration, Datetime expirationDateTime) {
        try {
            Product_Subscriber__c subscriber = [SELECT Id, Is_Trial__c, Product_Plan__c, Discount__c, Duration__c, Price__c, Expiration_DateTime__c, Opportunity__c, Version_Number_Text__c FROM Product_Subscriber__c WHERE Id = :subscriberId];
            System.debug(' before update subscriber >>' + subscriber);
            
            subscriber.Is_Trial__c = isTrial;
            System.debug('isTrial >>' + isTrial);
            if (!isTrial) {
                subscriber.Product_Plan__c = productPlanId;
                subscriber.Discount__c = discount;
                subscriber.Duration__c = duration;
                subscriber.Expiration_DateTime__c = expirationDateTime;
                System.debug('productPlanId >>' + productPlanId);
                if (productPlanId != null) {
                    Product_Plan__c plan = [SELECT Price__c FROM Product_Plan__c WHERE Id = :productPlanId];
                    Decimal newPrice = plan.Price__c * duration;
                    subscriber.Price__c = newPrice;
                }
                if (expirationDateTime == null) {
                    List<Opportunity> oppRec = [SELECT Id, CloseDate FROM Opportunity WHERE Id = :subscriber.Opportunity__c];
                    if (!oppRec.isEmpty()) {
                        oppRec[0].CloseDate = Date.valueOf(expirationDateTime);
                        update oppRec[0];
                    }
                }
                System.debug('subscriber >>' + subscriber);
                
            }
            
            System.debug('after update subscriber >>' + subscriber);
            
            update subscriber;
            return subscriber;
        } catch (Exception e) {
            System.debug('Error retrieving product subscribers: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving product subscribers: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Product_Plan__c> getProductPlans() {
        return [SELECT Id, Name, Price__c FROM Product_Plan__c];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts() {
        return [SELECT Id, Name FROM Product__c ORDER BY Name];
    }
}