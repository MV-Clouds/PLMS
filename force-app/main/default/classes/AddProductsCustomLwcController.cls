public with sharing class AddProductsCustomLwcController {
    
    @AuraEnabled
    public static QuoteWrapper getQuoteDetails(Id quoteId) {
        try {
            List<Quote> quotes = [SELECT Id, Name, MV_Product_Id__c, RecordTypeId, RecordType.Name FROM Quote WHERE Id = :quoteId LIMIT 1];
            if (quotes.isEmpty()) {
                throw new AuraHandledException('Quote not found');
            }
            Quote q = quotes[0];
            
            // Determine quote type based on RecordType
            Boolean isServiceQuote = (q.RecordType.Name == 'Service' || q.RecordType.Name == 'Service Quote');
            Boolean isProductQuote = (q.RecordType.Name == 'Product' || q.RecordType.Name == 'Product Quote');
            
            if (isServiceQuote) {
                // For service quotes, only allow service quote lines
                List<QuoteLineItem> existingServiceLines = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId AND Record_Type__c = 'Service Quote Line' LIMIT 1];
                
                // Return wrapper indicating it's a service quote with no product
                return new QuoteWrapper(q, null, !existingServiceLines.isEmpty(), true);
            } else if (isProductQuote) {
                // For product quotes, check if quote already has a product type quote line
                List<QuoteLineItem> existingProductLines = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId AND Record_Type__c = 'Product Quote Line' LIMIT 1];
                
                // For product quotes: first quote line must be product type, then can add service types
                Boolean hasProductLine = !existingProductLines.isEmpty();
                
                Product__c prod = null;
                if (q.MV_Product_Id__c != null) {
                    List<Product__c> products = [SELECT Id, Name FROM Product__c WHERE Id = :q.MV_Product_Id__c LIMIT 1];
                    if (!products.isEmpty()) {
                        prod = products[0];
                    }
                }
                
                return new QuoteWrapper(q, prod, hasProductLine, false);
            } else {
                throw new AuraHandledException('Quote record type not recognized. Please ensure the quote has a valid Service or Product record type.');
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error loading quote details: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<PlanOption> getProductPlans(Id productId) {
        try {
            List<Product_Plan__c> plans = [ SELECT Id, Name, Price__c FROM Product_Plan__c WHERE Product__c = :productId];
            List<PlanOption> options = new List<PlanOption>();
            for (Product_Plan__c p : plans) {
                options.add(new PlanOption(p.Id, p.Name, p.Price__c));
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading product plans: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id createQuoteLineItem(Id quoteId, Id productPlanId, Decimal discountValue, String description) {
        try {
            // Fetch Quote with Product2 and RecordType
            List<Quote> quotes = [SELECT Id, Product2_Id__c, Pricebook2Id, RecordType.Name FROM Quote WHERE Id = :quoteId LIMIT 1];
            if (quotes.isEmpty()) {
                throw new AuraHandledException('Quote not found');
            }
            Quote q = quotes[0];
            
            // Validate that this is a product quote
            Boolean isProductQuote = (q.RecordType.Name == 'Product' || q.RecordType.Name == 'Product Quote');
            if (!isProductQuote) {
                throw new AuraHandledException('Cannot create product quote lines on a non-product quote. This quote has record type: ' + q.RecordType.Name);
            }
            
            // Fetch Product Plan with Pricebook
            List<Product_Plan__c> plans = [SELECT Id, Price__c, Price_Book__c FROM Product_Plan__c WHERE Id = :productPlanId LIMIT 1];
            if (plans.isEmpty()) {
                throw new AuraHandledException('Product plan not found');
            }
            Product_Plan__c plan = plans[0];
            
            // Find PricebookEntry for this product + pricebook
            List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :plan.Price_Book__c AND Product2Id = :q.Product2_Id__c AND IsActive = true LIMIT 1];
            if (pbes.isEmpty()) {
                throw new AuraHandledException('No active pricebook entry found for this product and pricebook');
            }
            PricebookEntry pbe = pbes[0];
            
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
                Description = description,
                Record_Type__c = 'Product Quote Line'
            );
            
            insert qli;
            return qli.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating quote line item: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Id> createServiceQuoteLineItems(Id quoteId, List<ServiceLineItem> serviceItems) {
        try {
            System.debug('Creating service quote line items for quoteId: ' + quoteId);
            System.debug('Service items: ' + serviceItems);
            
            // First, validate that this is either a service quote OR a product quote with existing product lines
            List<Quote> quotes = [SELECT Id, RecordType.Name, Pricebook2Id FROM Quote WHERE Id = :quoteId LIMIT 1];
            if (quotes.isEmpty()) {
                throw new AuraHandledException('Quote not found');
            }
            
            Quote quote = quotes[0];
            Boolean isServiceQuote = (quote.RecordType.Name == 'Service' || quote.RecordType.Name == 'Service Quote');
            Boolean isProductQuote = (quote.RecordType.Name == 'Product' || quote.RecordType.Name == 'Product Quote');
            
            if (isProductQuote) {
                // Product quotes can have service quote line items ONLY after they have at least one product line item
                List<QuoteLineItem> existingProductLines = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId AND Record_Type__c = 'Product Quote Line' LIMIT 1];
                
                if (existingProductLines.isEmpty()) {
                    throw new AuraHandledException('Product quotes must have at least one product quote line item before adding service items. Please add a product line item first.');
                }
            } else if(!isServiceQuote) {
                throw new AuraHandledException('Cannot create service quote lines on this quote type: ' + quote.RecordType.Name);
            }
            
            // For service quote lines, we need to handle the required Product2Id and PricebookEntryId
            // We'll create a generic service product if needed, or use an existing one
            Product2 serviceProduct = getOrCreateServiceProduct();
            
            // Handle missing pricebook on quote - use standard pricebook as fallback
            Id pricebookId = quote.Pricebook2Id;
            if (pricebookId == null) {
                // Get standard pricebook as fallback
                List<Pricebook2> standardPricebooks = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
                if (!standardPricebooks.isEmpty()) {
                    pricebookId = standardPricebooks[0].Id;
                    
                    // Update the quote with standard pricebook
                    quote.Pricebook2Id = pricebookId;
                    update quote;
                } else {
                    throw new AuraHandledException('No pricebook found on quote and no standard pricebook available. Please assign a pricebook to the quote.');
                }
            }
            
            PricebookEntry servicePbe = getOrCreateServicePricebookEntry(serviceProduct.Id, pricebookId);
            
            List<QuoteLineItem> qliList = new List<QuoteLineItem>();
            
            for (ServiceLineItem serviceItem : serviceItems) {
                QuoteLineItem qli = new QuoteLineItem(
                    QuoteId = quoteId,
                    Product2Id = serviceProduct.Id,
                    PricebookEntryId = servicePbe.Id,
                    Title__c = serviceItem.title,
                    Description = serviceItem.description,
                    Quantity = serviceItem.quantityHours,
                    UnitPrice = serviceItem.pricePerHour,
                    Record_Type__c = 'Service Quote Line'
                );
                qliList.add(qli);
            }
            
            if (!qliList.isEmpty()) {
                insert qliList;
            }
            
            List<Id> insertedIds = new List<Id>();
            for (QuoteLineItem qli : qliList) {
                insertedIds.add(qli.Id);
            }
            
            return insertedIds;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating service quote line items: ' + e.getMessage());
        }
    }
    
    // Helper method to get or create a generic service product
    private static Product2 getOrCreateServiceProduct() {
        List<Product2> existingProducts = [SELECT Id FROM Product2 WHERE Name = 'Service Item' AND IsActive = true LIMIT 1];
        
        if (!existingProducts.isEmpty()) {
            return existingProducts[0];
        }
        
        // Create a generic service product
        Product2 serviceProduct = new Product2(
            Name = 'Service Item',
            Description = 'Generic service item for service quote lines',
            IsActive = true
        );
        insert serviceProduct;
        
        return serviceProduct;
    }
    
    // Helper method to get or create pricebook entry for service product
    private static PricebookEntry getOrCreateServicePricebookEntry(Id productId, Id pricebookId) {
        List<PricebookEntry> existingEntries = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId AND Pricebook2Id = :pricebookId AND IsActive = true LIMIT 1];
        
        if (!existingEntries.isEmpty()) {
            return existingEntries[0];
        }
        
        // For custom pricebooks, we need to ensure there's a standard pricebook entry first
        List<Pricebook2> standardPricebooks = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Id standardPricebookId = !standardPricebooks.isEmpty() ? standardPricebooks[0].Id : null;
        
        if (standardPricebookId != null && pricebookId != standardPricebookId) {
            // Check if standard pricebook entry exists
            List<PricebookEntry> standardEntries = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productId AND Pricebook2Id = :standardPricebookId AND IsActive = true LIMIT 1];
            
            if (standardEntries.isEmpty()) {
                // Create standard pricebook entry first
                PricebookEntry standardPbe = new PricebookEntry(
                    Product2Id = productId,
                    Pricebook2Id = standardPricebookId,
                    UnitPrice = 0,
                    IsActive = true
                );
                insert standardPbe;
            }
        }
        
        // Create pricebook entry for the requested pricebook
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = productId,
            Pricebook2Id = pricebookId,
            UnitPrice = 0, // Will be overridden by QuoteLineItem UnitPrice
            IsActive = true
        );
        insert pbe;
        
        return pbe;
    }
    
    public class QuoteWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public Id MV_Product_Id;
        @AuraEnabled public String ProductName;
        @AuraEnabled public Boolean hasProductLine;
        @AuraEnabled public Boolean isServiceQuote;
        
        public QuoteWrapper(Quote q, Product__c prod, Boolean hasProductLine, Boolean isServiceQuote) {
            Id = q.Id;
            Name = q.Name;
            MV_Product_Id = q.MV_Product_Id__c;
            ProductName = prod != null ? prod.Name : null;
            this.hasProductLine = hasProductLine;
            this.isServiceQuote = isServiceQuote;
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
    
    public class ServiceLineItem {
        @AuraEnabled public String title {get; set;}
        @AuraEnabled public String description {get; set;}
        @AuraEnabled public Decimal quantityHours {get; set;}
        @AuraEnabled public Decimal pricePerHour {get; set;}
        @AuraEnabled public Decimal totalPrice {get; set;}
        
        // No-arg constructor
        public ServiceLineItem() {
            this.title = '';
            this.description = '';
            this.quantityHours = 0;
            this.pricePerHour = 0;
            this.totalPrice = 0;
        }
        
        public ServiceLineItem(String title, String description, Decimal quantityHours, Decimal pricePerHour) {
            this.title = title;
            this.description = description;
            this.quantityHours = quantityHours;
            this.pricePerHour = pricePerHour;
            this.totalPrice = quantityHours * pricePerHour;
        }
    }

    @AuraEnabled
    public static void sendEmail(String body) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            String toAddressLabel = System.Label.ExceptionEmailRecipients;
            List<String> toAddresses = toAddressLabel.split(',');
            
            email.setToAddresses(toAddresses);
            email.setSubject('An Exception Occurred in Custom Quote Line Creation');
            email.setHtmlBody(body);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}