@IsTest
public class ContractTriggerHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Product__c prod = new Product__c(
            Name = 'Custom Product'
        );
        insert prod;

        // Create Product_Subscriber__c record with TEST values
        Product_Subscriber__c subscriber = new Product_Subscriber__c(
            Mobile_Phone__c        = '+15551234567',
            Org_Name__c            = 'Test Org Inc',
            Domain__c              = 'https://testorg-dev-ed.my.salesforce.com',
            Expiration_DateTime__c = DateTime.newInstance(2025, 12, 31, 10, 0, 0),
            TimeZoneSidKey__c      = 'Asia/Kolkata',
            Address__c             = '123 Test Street, Test City',
            Org_Type__c            = 'Enterprise Edition',
            Version_Number_Text__c = '9.9',
            Last_Upgrade_Date__c   = Date.newInstance(2025, 9, 1),
            Phone__c               = '+15557654321',
            Username__c            = 'testuser@testorg.com',
            User_Id__c             = '005XXXXXXXXXXXX',
            First_Name__c          = 'TestFirst',
            Environment__c         = 'Sandbox',
            Product__c             = prod.Id,
            Org_Id__c              = '00DXXXXXXXXXXXX',
            Is_Trial__c            = false,
            Install_Date__c        = Date.newInstance(2025, 8, 15),
            Installed_Product__c   = 'TestProduct',
            Email__c               = 'testuser@example.com',
            Last_Name__c           = 'TestLast'
        );

        // Serialize subscriber into JSON
        String subscriberJson = JSON.serialize(subscriber);

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

        // Create Opportunity with JSON details of Product Subscriber
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            MV_Product__c = prod.Id,
            Product_Subscriber_Detail_JSON__c = subscriberJson
        );
        insert opp;

        // Create Quote
        Quote quote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebook.Id
        );
        insert quote;

        // Create Quote Line Item with reference to Product Plan
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quote.Id,
            Quantity = 1,
            UnitPrice = 1000,
            Product2Id = mvProduct.Product__c, // Required field
            PricebookEntryId = pbe.Id,
            Product_Plan__c = plan.Id
        );
        insert qli;

        // Create Contract (unsigned initially)
        Contract con = new Contract(
            AccountId = acc.Id,
            StartDate = Date.today(),
            Opportunity__c = opp.Id,
            Quote__c = quote.Id,
            Is_Signed__c = false
        );
        insert con;
    }
    
    @IsTest
    static void testProcessSignedContract() {
        // Fetch contract
        Contract con = [SELECT Id, Is_Signed__c, Opportunity__c, Quote__c, StartDate, AccountId FROM Contract LIMIT 1];
        con.Is_Signed__c = true;

        Test.startTest();
        // Simulate afterUpdate trigger handler
        ContractTriggerHandler.afterUpdate(
            new List<Contract>{ con },
            new Map<Id, Contract>{ con.Id => new Contract(Id = con.Id, Is_Signed__c = false) }
        );
        Test.stopTest();
    }
}
