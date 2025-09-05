/**
 * @description Controller for the Invoice Visualforce Page PDF.
 * This controller fetches invoice, customer, and product details from Salesforce objects
 * based on the provided data model.
 */
public with sharing class InvoiceController {

    /**
     * @description The Invoice record being processed. It's public so the VF page can access its fields.
     * The SOQL query includes related parent records to avoid extra queries.
     */
    public Invoice__c invoice { get; private set; }

    /**
     * @description Public property to hold the current date for display on the invoice.
     */
    public Date todaysDate { get; private set; }

    /**
     * @description Constructor that retrieves the Invoice record based on the 'id' parameter from the page URL.
     */
    public InvoiceController() {
        // Get the Invoice ID from the page's URL parameters.
        Id invoiceId = ApexPages.currentPage().getParameters().get('id');
        todaysDate = Date.today();

        // Query for the invoice and all related data using the new field names.
        if (invoiceId != null) {
            try {
                invoice = [
                    SELECT
                        Id, Name, Start_Date__c, End_Date__c, Price__c, Discount__c, Price_after_Discount__c, Duration__c, Status__c, Product_Plan__r.Name,
                        Product_Subscriber__r.First_Name__c, Product_Subscriber__r.Last_Name__c, Product_Subscriber__r.Address__c, Product_Subscriber__r.Email__c, Product_Subscriber__r.Product__r.Name
                    FROM Invoice__c
                    WHERE Id = :invoiceId
                    LIMIT 1
                ];
                System.debug('invoice.Price_after_Discount__c >>' + invoice.Price_after_Discount__c);
            } catch (Exception e) {
                // Handle potential errors, e.g., if the record is not found or the user doesn't have access.
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'An error occurred while retrieving the invoice data: ' + e.getMessage()));
                invoice = new Invoice__c(); // Initialize to prevent null pointer exceptions on the page
            }
        } else {
            // Handle the case where no ID is provided in the URL.
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invoice ID not found in page parameters.'));
            invoice = new Invoice__c(); // Initialize to prevent null pointer exceptions on the page
        }
    }
}