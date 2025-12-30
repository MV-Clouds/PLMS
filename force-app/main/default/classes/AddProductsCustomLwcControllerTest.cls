@isTest
private class AddProductsCustomLwcControllerTest {

    @testSetup
    static void setupData() {
        // Create Custom Product__c (your lookup in Quote)
        Product__c prod = new Product__c(
            Name = 'Custom Product'
        );
        insert prod;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            MV_Product__c = prod.Id
        );
        insert opp;

        // Create Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id
        );
        insert q;

        Id pricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = pricebookId,
            IsActive = true
        );
        upsert standardPricebook;

        // fetch mvproduct 
        Product__c mvProduct = [SELECT Id, Product__c FROM Product__c WHERE Name = 'Custom Product' LIMIT 1];

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = mvProduct.Product__c,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // Create Product Plan
        Product_Plan__c plan = new Product_Plan__c(
            Name = 'Basic Plan',
            Price__c = 99,
            Product__c = prod.Id,
            Price_Book__c = standardPricebook.Id
        );
        insert plan;
    }

    @isTest
    static void testGetQuoteDetails() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        Test.startTest();
        AddProductsCustomLwcController.QuoteWrapper result = 
            AddProductsCustomLwcController.getQuoteDetails(q.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetProductPlans() {
        Product__c prod = [SELECT Id FROM Product__c LIMIT 1];

        Test.startTest();
        List<AddProductsCustomLwcController.PlanOption> plans =
            AddProductsCustomLwcController.getProductPlans(prod.Id);
        Test.stopTest();
    }

    @isTest
    static void testCreateQuoteLineItem() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Product_Plan__c plan = [SELECT Id, Price__c FROM Product_Plan__c LIMIT 1];

        Test.startTest();
        Id qliId = AddProductsCustomLwcController.createQuoteLineItem(
            q.Id, plan.Id, 10, 'Test Description'
        );
        Test.stopTest();
    }
}