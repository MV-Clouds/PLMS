/**
 * @description add your description here
 * @Date 10 September 2025
 */

public class ZohoInvoiceManager {
    
    /**
     * Creates and sends invoice via email - can be called from Flow or Process Builder
     * @param invoiceIds List of Invoice IDs to process
     */
    @InvocableMethod(label='Create and Send Zoho Invoice' description='Creates invoice in Zoho and sends via email')
    public static void createAndSendInvoices(List<String> invoiceIds) {
        for (String invoiceId : invoiceIds) {
            ZohoBillingService.createAndSendInvoice(invoiceId);
        }
    }
    
    /**
     * Creates invoices in Zoho without sending email
     * @param invoiceIds List of Invoice IDs to process
     */
    public static void createInvoicesOnly(List<String> invoiceIds) {
        for (String invoiceId : invoiceIds) {
            ZohoBillingService.createInvoiceOnly(invoiceId);
        }
    }
    
    /**
     * Sends existing invoices via email
     * @param invoiceIds List of Invoice IDs to send
     */
    public static void sendInvoiceEmails(List<String> invoiceIds) {
        for (String invoiceId : invoiceIds) {
            ZohoBillingService.sendInvoiceEmail(invoiceId);
        }
    } 

    
    
}