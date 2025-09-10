public with sharing class AddProductsCustomLwcController {
    
    @AuraEnabled
    public static QuoteWrapper getQuoteDetails(Id quoteId) {
        
        Quote q = [ SELECT Id, Name, MV_Product_Id__c FROM Quote WHERE Id = :quoteId LIMIT 1];

        Product__c prod = [ SELECT Id, Name FROM Product__c WHERE Id = :q.MV_Product_Id__c LIMIT 1];

        return new QuoteWrapper(q, prod);
    }

    @AuraEnabled
    public static List<PlanOption> getProductPlans(Id productId) {
        List<Product_Plan__c> plans = [
            SELECT Id, Name, Price__c
            FROM Product_Plan__c
            WHERE Product__c = :productId
        ];
        List<PlanOption> options = new List<PlanOption>();
        for (Product_Plan__c p : plans) {
            options.add(new PlanOption(p.Id, p.Name, p.Price__c));
        }
        return options;
    }

    @AuraEnabled
    public static Id createQuoteLineItem(Id quoteId, Id productPlanId, Decimal discountValue, String description) {
        // Fetch Quote with Product2
        Quote q = [ SELECT Id, Product2_Id__c, Pricebook2Id FROM Quote WHERE Id = :quoteId LIMIT 1];

        // Fetch Product Plan with Pricebook
        Product_Plan__c plan = [ SELECT Id, Price__c, Price_Book__c FROM Product_Plan__c WHERE Id = :productPlanId LIMIT 1];

        // Find PricebookEntry for this product + pricebook
        PricebookEntry pbe = [ SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :plan.Price_Book__c AND Product2Id = :q.Product2_Id__c AND IsActive = true LIMIT 1];

        if(q.Pricebook2Id == null){
            q.Pricebook2Id = plan.Price_Book__c;
            update q;
        }

        // Create Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = q.Product2_Id__c,
            PricebookEntryId = pbe.Id,
            Product_Plan__c = plan.Id,
            UnitPrice = plan.Price__c,
            Quantity = 1,
            Discount = discountValue,
            Description = description
        );

        insert qli;
        return qli.Id;
    }

    public class QuoteWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public Id MV_Product_Id;
        @AuraEnabled public String ProductName;

        public QuoteWrapper(Quote q, Product__c prod) {
            Id = q.Id;
            Name = q.Name;
            MV_Product_Id = q.MV_Product_Id__c;
            ProductName = prod != null ? prod.Name : null;
        }
    }

    public class PlanOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Decimal price;

        public PlanOption(Id id, String name, Decimal price) {
            this.label = name;
            this.value = id;
            this.price = price;
        }
    }
}