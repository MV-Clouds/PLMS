/**
 * Manager class for Zoho Quote operations
 * Provides synchronous methods that can be called from flows, process builder, or manually
 */
public class ZohoQuoteManager {
    
    /**
     * Sends a quote via email - can be called from Flow or Process Builder
     * @param quoteIds List of Quote IDs to send
     */
    @InvocableMethod(label='Send Zoho Quote Email' description='Sends quote to customer via Zoho Billing')
    public static void sendQuoteEmails(List<String> quoteIds) {
        for (String quoteId : quoteIds) {
            ZohoBillingService.sendEmailQuote(quoteId);
        }
    }
    
    /**
     * Creates or updates quotes in Zoho without sending email
     * @param quoteIds List of Quote IDs to process
     */
    public static void createOrUpdateQuotes(List<String> quoteIds) {
        for (String quoteId : quoteIds) {
            ZohoBillingService.createOrUpdateQuote(quoteId);
        }
    }
    
    /**
     * Marks quotes as accepted in Zoho
     * @param quoteIds List of Salesforce Quote IDs
     */
    public static void markQuotesAsAccepted(List<String> quoteIds) {
        List<Quote> quotes = [SELECT Id, zoho_quote_id__c FROM Quote WHERE Id IN :quoteIds AND zoho_quote_id__c != null];
        
        for (Quote quote : quotes) {
            ZohoBillingService.markQuoteAsAccepted(quote.zoho_quote_id__c);
        }
    }
    
    /**
     * Marks quotes as declined in Zoho
     * @param quoteIds List of Salesforce Quote IDs
     */
    public static void markQuotesAsDeclined(List<String> quoteIds) {
        List<Quote> quotes = [SELECT Id, zoho_quote_id__c FROM Quote WHERE Id IN :quoteIds AND zoho_quote_id__c != null];
        
        for (Quote quote : quotes) {
            ZohoBillingService.markQuoteAsDeclined(quote.zoho_quote_id__c);
        }
    }
    
    /**
     * Marks quotes as sent in Zoho
     * @param quoteIds List of Salesforce Quote IDs
     */
    public static void markQuotesAsSent(List<String> quoteIds) {
        List<Quote> quotes = [SELECT Id, zoho_quote_id__c FROM Quote WHERE Id IN :quoteIds AND zoho_quote_id__c != null];
        
        for (Quote quote : quotes) {
            ZohoBillingService.markQuoteAsSent(quote.zoho_quote_id__c);
        }
    }
    
}