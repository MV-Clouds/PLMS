public with sharing class ContractTriggerHandler {
    
    public static void afterUpdate(List<Contract> newContracts, Map<Id, Contract> oldMap) {
        List<Contract> contractsToProcess = new List<Contract>();

        for (Contract con : newContracts) {
            Contract oldCon = oldMap.get(con.Id);
            if (oldCon.Is_Signed__c != true && con.Is_Signed__c == true) {
                contractsToProcess.add(con);
            }
        }

        if (!contractsToProcess.isEmpty()) {
            processSignedContracts(contractsToProcess);
        }
    }

    public static void processSignedContracts(List<Contract> contracts) {
        List<Contract> contractsToUpdate = new List<Contract>();
        for (Contract con : contracts) {
            System.debug('Processing signed contract: ' + con);

            // fetch contract related opportunity
            List<Opportunity> opp = [SELECT Id, Product_Subscriber_Detail_JSON__c, AccountId FROM Opportunity WHERE Id =:con.Opportunity__c];
            if (!opp.isEmpty()){
                if(opp[0].Product_Subscriber_Detail_JSON__c != null){
                    System.debug('Found opportunity: ' + opp);

                    // fetch contract related Quote
                    List<Quote> quote = [SELECT Id, (SELECT Id, Product_Plan__c, Discount FROM QuoteLineItems WHERE Product_Plan__c != null LIMIT 1) FROM Quote WHERE Id =:con.Quote__c];
                    if (!quote.isEmpty()){
                        System.debug('Found quote: ' + quote);
                        if(quote[0].QuoteLineItems.size() > 0){
                            System.debug('Found quote line item: ' + quote[0].QuoteLineItems);

                            // fetch product plan
                            List<Product_Plan__c> productPlan = [SELECT Id, Duration__c, Price__c FROM Product_Plan__c WHERE Id =: quote[0].QuoteLineItems[0].Product_Plan__c LIMIT 1];

                            if(!productPlan.isEmpty()){
                                System.debug('Found product plan: ' + productPlan);
                                
                                Product_Subscriber__c newProductSubscriber = (Product_Subscriber__c) JSON.deserialize(opp[0].Product_Subscriber_Detail_JSON__c, Product_Subscriber__c.class);
                                newProductSubscriber.Opportunity__c = con.Opportunity__c;
                                newProductSubscriber.Quote__c = quote[0].Id;
                                newProductSubscriber.Contract__c = con.Id;
                                newProductSubscriber.Product_Plan__c = productPlan[0].Id;
                                newProductSubscriber.Account__c = opp[0].AccountId;
                                newProductSubscriber.Active__c = true;
                                newProductSubscriber.Is_Trial__c = false;

                                Date baseDate = con.StartDate.addMonths(Integer.valueOf(productPlan[0].Duration__c));
                                newProductSubscriber.Expiration_DateTime__c = DateTime.newInstance(baseDate, Time.newInstance(10, 0, 0, 0));
                                insert newProductSubscriber;
            
                                // create Invoice record
                                Invoice__c newInvoice = new Invoice__c();
                                newInvoice.Product_Subscriber__c = newProductSubscriber.Id;
                                newInvoice.Product_Plan__c = newProductSubscriber.Product_Plan__c;
                                newInvoice.Status__c = 'Draft';
                                newInvoice.Start_Date__c = Date.today();
                                newInvoice.End_Date__c = Date.today().addDays(5);
                                newInvoice.Discount__c = quote[0].QuoteLineItems[0].Discount;
                                newInvoice.Price__c = productPlan[0].Price__c;
                                insert newInvoice;
    
                                Invoice_Line_Item__c newInvoiceLineItem = new Invoice_Line_Item__c();
                                newInvoiceLineItem.Invoice__c = newInvoice.Id;
                                newInvoiceLineItem.Product_Plan__c = newProductSubscriber.Product_Plan__c;
                                insert newInvoiceLineItem;
    
                                ZohoBillingService.createInvoiceOnly(newInvoice.Id);
                            } else {
                                System.debug('No product plan found for quote line item: ' + quote[0].QuoteLineItems[0].Id);
                            }
                        } else {
                            System.debug('No quote line item found for quote: ' + quote[0].Id);
                        }
                    } else {
                        System.debug('No quote found for contract: ' + con.Id);
                    }
                } else {
                    System.debug('No product subscriber detail found for opportunity: ' + opp[0].Id);
                }
            } else {
                System.debug('No opportunity found for contract: ' + con.Id);
            }
        }
    }
}