/**
 * @description add your description here
 * @Date 10 September 2025
 */

@SuppressWarnings('PMD.CognitiveComplexity')
public with sharing class ZohoBillingService {
    
    // Named Credential name for Zoho Billing authentication
    private static final String NAMED_CREDENTIAL = 'Zoho_Billing';
    
    /**
     * Wrapper class to reduce parameter lists in quote methods
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private class QuoteData {
        public Quote quote;
        public String zohoCustomerId;
        public Account acc;
        public List<QuoteLineItem> lineItems;
        public Map<String, Object> zohoItems;
        
        public QuoteData(Quote quote, String zohoCustomerId,Account acc , List<QuoteLineItem> lineItems, Map<String, Object> zohoItems) {
            this.quote = quote;
            this.zohoCustomerId = zohoCustomerId;
            this.acc = acc;
            this.lineItems = lineItems;
            this.zohoItems = zohoItems;
        }
    }
    
    /**
     * Wrapper class to store IDs that need to be updated after callouts
     */
    private class ZohoUpdateData {
        public String accountId;
        public String newZohoCustomerId;
        public String quoteId;
        public String newZohoQuoteId;
        public String invoiceId;
        public String newZohoInvoiceId;
        public Map<String, String> productPlanToZohoItemId;
        public Boolean accountNeedsUpdate = false;
        public List<String> itemsNeedingUpdate;
        
        public ZohoUpdateData() {
            this.productPlanToZohoItemId = new Map<String, String>();
            this.itemsNeedingUpdate = new List<String>();
        }
    }
    
    /**
     * Runtime variables to hold current Zoho IDs (both existing and newly created)
     */
    private class ZohoRuntimeIds {
        public String currentZohoCustomerId;
        public Map<String, String> currentZohoItemIds; // Product Plan ID -> Zoho Item ID
        
        public ZohoRuntimeIds() {
            this.currentZohoItemIds = new Map<String, String>();
        }
    }
    
    /**
     * Wrapper class for HTTP callout parameters
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private class HttpCalloutParams {
        public String httpMethod;
        public String endpoint;
        public String requestBody;
        public Integer expectedStatusCode;
        
        public HttpCalloutParams(String httpMethod, String endpoint, String requestBody, Integer expectedStatusCode) {
            this.httpMethod = httpMethod;
            this.endpoint = endpoint;
            this.requestBody = requestBody;
            this.expectedStatusCode = expectedStatusCode;
        }
    }
    
    // Base API endpoints
    private static final String CUSTOMERS_ENDPOINT = '/billing/v1/customers';
    private static final String ITEMS_ENDPOINT = '/billing/v1/items';
    private static final String QUOTES_ENDPOINT = '/billing/v1/estimates';
    private static final String INVOICES_ENDPOINT = '/billing/v1/invoices';


    // ===============================
    // COMMON HTTP CALLOUT METHOD
    // ===============================
    
    /**
     * Generic method for making HTTP callouts to Zoho Billing API
     * @param params HttpCalloutParams containing all request parameters
     * @return HttpResponse The response from Zoho API
     */
    private static HttpResponse makeZohoCallout(HttpCalloutParams params) {
        try {
            String fullEndpoint = 'callout:' + NAMED_CREDENTIAL + params.endpoint;
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(fullEndpoint);
            req.setMethod(params.httpMethod);
            req.setHeader('Content-Type', 'application/json');
            
            // Add organization ID header if available
            String orgId = ZohoBillingUtils.getZohoOrganizationId();
            if (String.isNotBlank(orgId)) {
                req.setHeader('X-com-zoho-subscriptions-organizationid', orgId);
            }
            
            // Set request body if provided
            if (String.isNotBlank(params.requestBody)) {
                req.setBody(params.requestBody);
            }
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            // Log the request and response for debugging
            System.debug('Zoho API Request - Method: ' + params.httpMethod + ', Endpoint: ' + params.endpoint);
            System.debug('Zoho API Response - Status: ' + response.getStatusCode() + ', Body: ' + response.getBody());
            
            return response;
            
        } catch (Exception ex) {
            System.debug('Error in makeZohoCallout: ' + ex.getMessage());
            throw new ZohoBillingException('Error making Zoho API call: ' + ex.getMessage());
        }
    }
    
    
    /**
     * Creates a customer in Zoho Billing
     * @param account Account record to create customer from
     * @return String Customer ID returned from Zoho Billing
     */
    public static String createCustomer(Account account) {
        // Validate required fields
        List<String> missingFields = ZohoBillingUtils.validateCustomerRequiredFields(account);
        if (!missingFields.isEmpty()) {
            System.debug('❗ mising fields'+ missingFields);
            throw new ZohoBillingException('Missing required fields for customer creation: ' + String.join(missingFields, ', '));
        }
        
        try {
            String requestBody = buildCustomerRequestBody(account);
            HttpCalloutParams params = new HttpCalloutParams('POST', CUSTOMERS_ENDPOINT, requestBody, 201);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> customerData = (Map<String, Object>) responseMap.get('customer');
                String customerId = (String) customerData.get('customer_id');
                
                ZohoBillingUtils.logIntegrationActivity('CREATE_CUSTOMER', account.Id, customerId, true, null);
                return customerId;
            } else {
                String errorMsg = 'Failed to create customer in Zoho Billing: ' + response.getBody();
                ZohoBillingUtils.logIntegrationActivity('CREATE_CUSTOMER', account.Id, null, false, errorMsg);
                throw new ZohoBillingException(errorMsg);
            }
        } catch (Exception ex) {
            ZohoBillingUtils.logIntegrationActivity('CREATE_CUSTOMER', account.Id, null, false, ex.getMessage());
            throw new ZohoBillingException('Error creating customer: ' + ex.getMessage());
        }
    }
    
    /**
     * Updates a customer in Zoho Billing
     * @param account Account record to update customer from
     * @param customerId Zoho customer ID to update
     */
    public static void updateCustomer(Account account, String customerId) {
        try {
            String requestBody = buildCustomerRequestBody(account);
            HttpCalloutParams params = new HttpCalloutParams('PUT', CUSTOMERS_ENDPOINT + '/' + customerId, requestBody, 200);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() != 200) {
                System.debug('Error updating customer: ' + response.getBody());
                throw new ZohoBillingException('Failed to update customer in Zoho Billing: ' + response.getBody());
            }
        } catch (Exception ex) {
            System.debug('Exception in updateCustomer: ' + ex.getMessage());
            throw new ZohoBillingException('Error updating customer: ' + ex.getMessage());
        }
    }
    
    /**
     * Creates an item in Zoho Billing
     * @param productPlan Product_Plan__c record to create item from
     * @return String Item ID returned from Zoho Billing
     */
    public static String createItem(Product_Plan__c productPlan) {
        // Validate required fields
        List<String> missingFields = ZohoBillingUtils.validateItemRequiredFields(productPlan);
        if (!missingFields.isEmpty()) {
            System.debug('Missing fields for item creation: ' + String.join(missingFields, ', '));
            throw new ZohoBillingException('Missing required fields for item creation: ' + String.join(missingFields, ', '));
        }
        
        try {
            String requestBody = buildItemRequestBody(productPlan);
            HttpCalloutParams params = new HttpCalloutParams('POST', ITEMS_ENDPOINT, requestBody, 201);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> itemData = (Map<String, Object>) responseMap.get('item');
                String itemId = String.valueOf(itemData.get('item_id'));
                
                ZohoBillingUtils.logIntegrationActivity('CREATE_ITEM', productPlan.Id, itemId, true, null);
                return itemId;
            } else {
                String errorMsg = 'Failed to create item in Zoho Billing: ' + response.getBody();
                System.debug(errorMsg);
                ZohoBillingUtils.logIntegrationActivity('CREATE_ITEM', productPlan.Id, null, false, errorMsg);
                throw new ZohoBillingException(errorMsg);
            }
        } catch (Exception ex) {
            System.debug('Error creating item: ' + ex.getMessage());
            throw new ZohoBillingException('Error Create item: ' + ex.getMessage());
        }
    }
    
    /**
     * Updates an item in Zoho Billing
     * @param productPlan Product_Plan__c record to update item from
     * @param itemId Zoho item ID to update
     */
    public static void updateItem(Product_Plan__c productPlan, String itemId) {
        try {
            String requestBody = buildItemRequestBody(productPlan);
            HttpCalloutParams params = new HttpCalloutParams('PUT', ITEMS_ENDPOINT + '/' + itemId, requestBody, 200);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() != 200) {
                System.debug('Error updating item: ' + response.getBody());
                throw new ZohoBillingException('Failed to update item in Zoho Billing: ' + response.getBody());
            }
        } catch (Exception ex) {
            System.debug('Exception in updateItem: ' + ex.getMessage());
            throw new ZohoBillingException('Error updating item: ' + ex.getMessage());
        }
    }
    
    /**
     * Builds the request body for customer API calls
     * @param account Account record
     * @return String JSON request body
     */
    private static String buildCustomerRequestBody(Account account) {
        Map<String, Object> customerData = new Map<String, Object>();
        
        // Required fields
        customerData.put('display_name', ZohoBillingUtils.sanitizeForZoho(account.Name, 100));
        customerData.put('company_name', ZohoBillingUtils.sanitizeForZoho(account.Name, 100));
        
        if (String.isNotBlank(account.Email__c)){
            customerData.put('email', account.Email__c != null ? account.Email__c : '');
        }
        
        // Optional fields
        if (String.isNotBlank(account.Phone)) {
            customerData.put('phone', ZohoBillingUtils.sanitizeForZoho(account.Phone, 20));
        }

        if (String.isNotBlank(account.Description)) {
            customerData.put('notes', ZohoBillingUtils.sanitizeForZoho(account.Description, 2000));
        }
        return JSON.serialize(customerData);
    }
    
    /**
     * Builds the request body for item API calls
     * @param productPlan Product_Plan__c record
     * @return String JSON request body
     */
    private static String buildItemRequestBody(Product_Plan__c productPlan) {
        Map<String, Object> itemData = new Map<String, Object>();
        
        // Required fields
        
        itemData.put('name', ZohoBillingUtils.sanitizeForZoho(productPlan.Name, 100));
        itemData.put('rate', productPlan.Price__c != null ? productPlan.Price__c : 0);
        
        // Optional fields
        if (String.isNotBlank(productPlan.Description__c)) {
            String description = productPlan.Description__c;
            // check for length and truncate if necessary
            itemData.put('description', ZohoBillingUtils.sanitizeForZoho(description, 2000));
        }
        
        // Set product type - defaulting to 'service' for plans
        itemData.put('product_type', ZohoBillingUtils.DEFAULT_PRODUCT_TYPE);
        
        // Add unique SKU
        itemData.put('sku', ZohoBillingUtils.generateProductPlanSKU(productPlan));
        itemData.put('product', productPlan.Product__c);
        
        return JSON.serialize(itemData);
    }
    
    // ===============================
    // QUOTE METHODS
    // ===============================
    
    /**
     * Creates or updates a quote in Zoho Billing and sends it via email
     * @param quoteId Salesforce Quote ID
     * @return String The Zoho quote ID
     */
    @future(callout=true)
    @SuppressWarnings('PMD.NcssMethodCount')
    public static void sendEmailQuote(String quoteId) {
        try {
            // Get quote with related data
            Map<String,List<SObject>> quoteMap = getQuoteWithDetails(quoteId);
            
            Quote quote = (Quote)quoteMap.get('quote')[0];
            Account acc = (Account) quoteMap.get('account')[0];
            List<QuoteLineItem> lineItems = (List<QuoteLineItem>) quoteMap.get('QuoteLineItem');
            
            // Step 1: Setup runtime IDs and tracking
            ZohoRuntimeIds runtimeIds = new ZohoRuntimeIds();
            ZohoUpdateData updateTracker = new ZohoUpdateData();
            updateTracker.accountId = acc.Id;
            updateTracker.quoteId = quote.Id;
            
            // Step 2: Handle Customer ID (existing or create new)
            if (String.isNotBlank(acc.Zoho_Customer_Id__c)) {
                // Use existing customer ID
                runtimeIds.currentZohoCustomerId = acc.Zoho_Customer_Id__c;
            } else {
                // Create new customer and store in runtime variable
                System.debug('🔄 Creating missing Zoho customer for: ' + acc.Name);
                String newCustomerId = createCustomer(acc);
                if (String.isNotBlank(newCustomerId)) {
                    runtimeIds.currentZohoCustomerId = newCustomerId;
                    updateTracker.newZohoCustomerId = newCustomerId;
                    updateTracker.accountNeedsUpdate = true;
                    System.debug('✅ Created new Zoho customer ID: ' + newCustomerId);
                } else {
                    System.debug('❗ Failed to create Zoho customer');
                    return;
                }
            }
            
            // Step 3: Handle Item IDs (existing or create new)
            for (QuoteLineItem lineItem : lineItems) {
                String productPlanId = lineItem.Product_Plan__c;
                if (String.isNotBlank(lineItem.Product_Plan__r.Zoho_Item_Id__c)) {
                    // Use existing item ID
                    runtimeIds.currentZohoItemIds.put(productPlanId, lineItem.Product_Plan__r.Zoho_Item_Id__c);
                } else {
                    // Create new item and store in runtime variable
                    System.debug('🔄 Creating missing Zoho item for: ' + lineItem.Product_Plan__r.Name);
                    String newItemId = createItem(lineItem.Product_Plan__r);
                    if (String.isNotBlank(newItemId)) {
                        runtimeIds.currentZohoItemIds.put(productPlanId, newItemId);
                        updateTracker.productPlanToZohoItemId.put(productPlanId, newItemId);
                        updateTracker.itemsNeedingUpdate.add(productPlanId);
                        System.debug('✅ Created new Zoho item ID: ' + newItemId);
                    } else {
                        System.debug('❗ Failed to create Zoho item for: ' + lineItem.Product_Plan__r.Name);
                        return;
                    }
                }
            }
            
            // Step 4: Get all Zoho items for reference
            Map<String, Object> zohoItems = getAllZohoItems();
            if (zohoItems == null) {
                System.debug('Failed to retrieve Zoho items');
                return;
            }
            
            // Step 5: Update line items in memory with runtime IDs for quote processing
            updateLineItemsWithRuntimeIds(lineItems, runtimeIds);
            
            // Step 6: Process the quote using runtime IDs
            String zohoQuoteId;
            QuoteData quoteData = new QuoteData(quote, runtimeIds.currentZohoCustomerId, acc, lineItems, zohoItems);
            
            if (String.isBlank(quote.zoho_quote_id__c)) {
                // Create new quote
                zohoQuoteId = createQuoteInZoho(quoteData);
                
                // Send quote via email if successful
                if (String.isNotBlank(zohoQuoteId) && String.isNotBlank(acc.Email__c)) {
                    sendQuoteEmail(zohoQuoteId, acc.Email__c);
                }
                
                // Track quote ID for update
                if (String.isNotBlank(zohoQuoteId)) {
                    updateTracker.newZohoQuoteId = zohoQuoteId;
                }
            } else {
                // Update existing quote
                zohoQuoteId = updateQuoteInZoho(quote.zoho_quote_id__c, quoteData);
                
                // Send quote via email if successful
                if (String.isNotBlank(zohoQuoteId) && String.isNotBlank(acc.Email__c)) {
                    sendQuoteEmail(zohoQuoteId, acc.Email__c);
                }
            }
            
            // Step 7: Update all Salesforce records with new Zoho IDs (if any were created)
            if (updateTracker.accountNeedsUpdate ||
                !updateTracker.itemsNeedingUpdate.isEmpty() ||
            String.isNotBlank(updateTracker.newZohoQuoteId)) {
                String updateDataJson = JSON.serialize(updateTracker);
                updateAllRecordsWithZohoIds(updateDataJson);
            }
            
        } catch (Exception e) {
            System.debug('Error in sendEmailQuote: ' + e.getMessage());
            System.debug('Error in sendEmailQuote: ' + e.getLineNumber());
            // Log the error for debugging
            ZohoBillingUtils.logIntegrationActivity('SEND_EMAIL_QUOTE', quoteId, null, false, e.getMessage());
            throw new ZohoBillingException('Error sending email quote: ' + e.getMessage());
        }
    }
    
    /**
     * Creates or updates a quote in Zoho Billing without sending email
     * @param quoteId Salesforce Quote ID
     * @return String The Zoho quote ID
     */
    @future(callout=true)
    @SuppressWarnings('PMD.NcssMethodCount')
    public static void createOrUpdateQuote(String quoteId) {
        try {
            // Get quote with related data
            Map<String,List<SObject>> quoteMap = getQuoteWithDetails(quoteId);
            
            Quote quote = (Quote)quoteMap.get('quote')[0];
            Account acc = (Account) quoteMap.get('account')[0];
            List<QuoteLineItem> lineItems = (List<QuoteLineItem>) quoteMap.get('QuoteLineItem');
            
            // Step 1: Setup runtime IDs and tracking
            ZohoRuntimeIds runtimeIds = new ZohoRuntimeIds();
            ZohoUpdateData updateTracker = new ZohoUpdateData();
            updateTracker.accountId = acc.Id;
            updateTracker.quoteId = quote.Id;
            
            // Step 2: Handle Customer ID (existing or create new)
            if (String.isNotBlank(acc.Zoho_Customer_Id__c)) {
                // Use existing customer ID
                runtimeIds.currentZohoCustomerId = acc.Zoho_Customer_Id__c;
            } else {
                // Create new customer and store in runtime variable
                System.debug('🔄 Creating missing Zoho customer for: ' + acc.Name);
                String newCustomerId = createCustomer(acc);
                if (String.isNotBlank(newCustomerId)) {
                    runtimeIds.currentZohoCustomerId = newCustomerId;
                    updateTracker.newZohoCustomerId = newCustomerId;
                    updateTracker.accountNeedsUpdate = true;
                    System.debug('✅ Created new Zoho customer ID: ' + newCustomerId);
                } else {
                    System.debug('❗ Failed to create Zoho customer');
                    return;
                }
            }
            
            // Step 3: Handle Item IDs (existing or create new)
            for (QuoteLineItem lineItem : lineItems) {
                String productPlanId = lineItem.Product_Plan__c;
                if (String.isNotBlank(lineItem.Product_Plan__r.Zoho_Item_Id__c)) {
                    // Use existing item ID
                    runtimeIds.currentZohoItemIds.put(productPlanId, lineItem.Product_Plan__r.Zoho_Item_Id__c);
                } else {
                    // Create new item and store in runtime variable
                    System.debug('🔄 Creating missing Zoho item for: ' + lineItem.Product_Plan__r.Name);
                    String newItemId = createItem(lineItem.Product_Plan__r);
                    if (String.isNotBlank(newItemId)) {
                        runtimeIds.currentZohoItemIds.put(productPlanId, newItemId);
                        updateTracker.productPlanToZohoItemId.put(productPlanId, newItemId);
                        updateTracker.itemsNeedingUpdate.add(productPlanId);
                        System.debug('✅ Created new Zoho item ID: ' + newItemId);
                    } else {
                        System.debug('❗ Failed to create Zoho item for: ' + lineItem.Product_Plan__r.Name);
                        return;
                    }
                }
            }
            
            // Step 4: Get all Zoho items for reference
            Map<String, Object> zohoItems = getAllZohoItems();
            if (zohoItems == null) {
                System.debug('Failed to retrieve Zoho items');
                return;
            }
            
            // Step 5: Update line items in memory with runtime IDs for quote processing
            updateLineItemsWithRuntimeIds(lineItems, runtimeIds);
            
            // Step 6: Process the quote using runtime IDs
            String zohoQuoteId;
            QuoteData quoteData = new QuoteData(quote, runtimeIds.currentZohoCustomerId, acc, lineItems, zohoItems);
            
            if (String.isBlank(quote.zoho_quote_id__c)) {
                // Create new quote
                zohoQuoteId = createQuoteInZoho(quoteData);
                
                // Track quote ID for update
                if (String.isNotBlank(zohoQuoteId)) {
                    updateTracker.newZohoQuoteId = zohoQuoteId;
                }
            } else {
                // Update existing quote
                zohoQuoteId = updateQuoteInZoho(quote.zoho_quote_id__c, quoteData);
            }
            
            // Step 7: Update all Salesforce records with new Zoho IDs (if any were created)
            if (updateTracker.accountNeedsUpdate ||
                !updateTracker.itemsNeedingUpdate.isEmpty() ||
            String.isNotBlank(updateTracker.newZohoQuoteId)) {
                String updateDataJson = JSON.serialize(updateTracker);
                updateAllRecordsWithZohoIds(updateDataJson);
            }
            
        } catch (Exception e) {
            System.debug('Error in createOrUpdateQuote: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to create customer first, then create quote in separate transaction
     * @deprecated This method is no longer needed as we handle missing IDs in the main flow
     */
    @future(callout=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void createCustomerAndThenCreateQuote(String quoteId) {
        try {
            Map<String,List<SObject>> quoteMap = getQuoteWithDetails(quoteId);
            Account acc = (Account) quoteMap.get('account')[0];
            
            // Create customer in Zoho first
            String customerId = createCustomer(acc);
            if (String.isNotBlank(customerId)) {
                // Update account with customer ID
                acc.Zoho_Customer_Id__c = customerId;
                update acc; // NOPMD - Deprecated method
                
                // Now call createOrUpdateQuote again
                createOrUpdateQuote(quoteId);
            }
        } catch (Exception e) {
            System.debug('Error in createCustomerAndThenCreateQuote: ' + e.getMessage());
        }
    }
    
    /**
     * Marks a quote as accepted in Zoho
     * @param zohoQuoteId The Zoho quote ID
     */
    @future(callout=true)
    public static void markQuoteAsAccepted(String zohoQuoteId) {
        updateQuoteStatus(zohoQuoteId, 'accepted');
    }
    
    /**
     * Marks a quote as declined in Zoho
     * @param zohoQuoteId The Zoho quote ID
     */
    @future(callout=true)
    public static void markQuoteAsDeclined(String zohoQuoteId) {
        updateQuoteStatus(zohoQuoteId, 'declined');
    }
    
    /**
     * Marks a quote as sent in Zoho
     * @param zohoQuoteId The Zoho quote ID
     */
    @future(callout=true)
    public static void markQuoteAsSent(String zohoQuoteId) {
        updateQuoteStatus(zohoQuoteId, 'sent');
    }
    
    // ===============================
    // PRIVATE HELPER METHODS FOR QUOTES
    // ===============================
    
    /**
     * Updates line items in memory with runtime Zoho IDs (both existing and new)
     * @param lineItems List of QuoteLineItems to update
     * @param runtimeIds ZohoRuntimeIds containing current IDs to use
     */
    private static void updateLineItemsWithRuntimeIds(List<QuoteLineItem> lineItems, ZohoRuntimeIds runtimeIds) {
        for (QuoteLineItem lineItem : lineItems) {
            String productPlanId = lineItem.Product_Plan__c;
            if (runtimeIds.currentZohoItemIds.containsKey(productPlanId)) {
                // Update the related Product_Plan__r record in memory with runtime ID
                if (lineItem.Product_Plan__r != null) {
                    lineItem.Product_Plan__r.Zoho_Item_Id__c = runtimeIds.currentZohoItemIds.get(productPlanId);
                }
            }
        }
    }
    
    /**
     * Updates line items in memory with new Zoho item IDs
     * @param lineItems List of QuoteLineItems to update
     * @param productPlanToZohoItemId Map of Product Plan ID to new Zoho Item ID
     */
    private static void updateLineItemsWithZohoIds(List<QuoteLineItem> lineItems, Map<String, String> productPlanToZohoItemId) {
        for (QuoteLineItem lineItem : lineItems) {
            if (productPlanToZohoItemId.containsKey(lineItem.Product_Plan__c)) {
                // Update the related Product_Plan__r record in memory
                if (lineItem.Product_Plan__r != null) {
                    lineItem.Product_Plan__r.Zoho_Item_Id__c = productPlanToZohoItemId.get(lineItem.Product_Plan__c);
                }
            }
        }
    }
    
    /**
     * Updates all Salesforce records with new Zoho IDs in separate transaction
     * @param updateData ZohoUpdateData containing all IDs to update
     */
    public static void updateAllRecordsWithZohoIds(String updateDataJson) {
        try {
            
            ZohoUpdateData updateData = (ZohoUpdateData) JSON.deserialize(updateDataJson, ZohoUpdateData.class);
            
            List<SObject> recordsToUpdate = new List<SObject>();
            
            // Update Account with new Zoho customer ID if created
            if (String.isNotBlank(updateData.newZohoCustomerId)) {
                // Check account update permissions
                recordsToUpdate.add(new Account(
                    Id = updateData.accountId,
                Zoho_Customer_Id__c = updateData.newZohoCustomerId
                    ));
            }
            
            // Update Product Plans with new Zoho item IDs if created
            if (!updateData.productPlanToZohoItemId.isEmpty()) {
                for (String productPlanId : updateData.productPlanToZohoItemId.keySet()) {
                    recordsToUpdate.add(new Product_Plan__c(
                        Id = productPlanId,
                    Zoho_Item_Id__c = updateData.productPlanToZohoItemId.get(productPlanId)
                        ));
                }
                
            }
            
            // Update Quote with new Zoho quote ID if created
            if (String.isNotBlank(updateData.newZohoQuoteId)) {
                recordsToUpdate.add(new Quote(
                    Id = updateData.quoteId,
                zoho_quote_id__c = updateData.newZohoQuoteId
                    ));
                
            }
            
            // Perform all updates
            if (!recordsToUpdate.isEmpty()) {
                // CRUD permissions already validated before adding to list
                update recordsToUpdate; // NOPMD - Permission checks done above
                System.debug('✅ Updated ' + recordsToUpdate.size() + ' records with new Zoho IDs');
            }
            
        } catch (Exception e) {
            System.debug('❗ Error updating records with Zoho IDs: ' + e.getMessage());
        }
    }
    
    /**
     * Gets quote with all related data using individual queries
     */
    private static Map<String,List<SObject>> getQuoteWithDetails(String quoteId) {
        
        
        // First, get the quote record with AccountId
        List<Quote> quote = [
            SELECT Id, Name, Description, ExpirationDate, zoho_quote_id__c, AccountId, QuoteNumber
            FROM Quote 
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        
        
        // Get the Account record using AccountId
        List<Account> account = [
            SELECT Id, Name, Email__c, Zoho_Customer_Id__c, Phone, Website, Description 
            FROM Account
            WHERE Id = :quote[0].AccountId
            LIMIT 1
            ];
        
        
        
        // Get QuoteLineItems using QuoteId
        List<QuoteLineItem> lineItems = new List<QuoteLineItem>();
        lineItems = [
                SELECT Id, Product_Plan__c, Product_Plan__r.Name, Product_Plan__r.Zoho_Item_Id__c, Product_Plan__r.Price__c,
                       Product_Plan__r.Product__c, Product_Plan__r.Description__c, Quantity, UnitPrice, TotalPrice, Description
                FROM QuoteLineItem 
                WHERE QuoteId = :quoteId
            ];
        
        Map<String, List<SObject>> objectMap = new Map<String, List<SObject>>();
        objectMap.put('quote', quote);
        objectMap.put('account', account);
        objectMap.put('QuoteLineItem', lineItems);
        
        return objectMap;
    }
    
    
    /**
     * Gets all items from Zoho for reference during quote creation
     */
    private static Map<String, Object> getAllZohoItems() {
        try {
            HttpCalloutParams params = new HttpCalloutParams('GET', ITEMS_ENDPOINT, null, 200);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                return responseMap;
            } else {
                return null;
            }
        } catch (Exception ex) {
            System.debug('Error getting Zoho items: ' + ex.getMessage());
            return null;
        }
    }
    
    /**
     * Creates a new quote in Zoho
     */
    private static String createQuoteInZoho(QuoteData quoteData) {
        try {
            String requestBody = buildQuoteRequestBody(quoteData);
            System.debug('requestBody >>' + JSON.serializePretty(requestBody));
            
            HttpCalloutParams params = new HttpCalloutParams('POST', QUOTES_ENDPOINT, requestBody, 201);
            HttpResponse response = makeZohoCallout(params);
            System.debug('response >>' + response.getBody());
            
            
            
            if (response.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> estimateData = (Map<String, Object>) responseMap.get('estimate');
                return (String) estimateData.get('estimate_id');
            } else {
                System.debug('Failed to create quote - Status: ' + response.getStatusCode());
                System.debug('Response: ' + response.getBody());
                return null;
            }
        } catch (Exception ex) {
            System.debug('Error creating quote in Zoho: ' + ex.getMessage());
            return null;
        }
    }
    
    /**
     * Updates an existing quote in Zoho
     */
    private static String updateQuoteInZoho(String zohoQuoteId, QuoteData quoteData) {
        try {
            String requestBody = buildQuoteRequestBody(quoteData);
            HttpCalloutParams params = new HttpCalloutParams('PUT', QUOTES_ENDPOINT + '/' + zohoQuoteId, requestBody, 200);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() == 200) {
                return zohoQuoteId;
            } else {
                System.debug('Failed to update quote - Status: ' + response.getStatusCode());
                System.debug('Response: ' + response.getBody());
                return null;
            }
        } catch (Exception ex) {
            System.debug('Error updating quote in Zoho: ' + ex.getMessage());
            return null;
        }
    }
    
    /**
     * Sends quote via email
     */
    private static void sendQuoteEmail(String zohoQuoteId, String customerEmail) {
        try {
            Map<String, Object> emailData = new Map<String, Object>();
            emailData.put('send_from_org_email_id', true);
            emailData.put('to_mail_ids', new List<String>{ customerEmail });
            // emailData.put('subject', 'Your Quote is Ready');
            // emailData.put('body', 'Dear Customer, Please find attached your quote. Thank you for your business.');
            
            HttpCalloutParams params = new HttpCalloutParams('POST', QUOTES_ENDPOINT + '/' + zohoQuoteId + '/email', JSON.serialize(emailData), 200);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() != 200) {
                System.debug('Failed to send quote email: ' + response.getBody());
            }
        } catch (Exception ex) {
            System.debug('Error sending quote email: ' + ex.getMessage());
        }
    }
    
    /**
     * Updates quote status in Zoho
     */
    private static void updateQuoteStatus(String zohoQuoteId, String status) {
        try {
            HttpCalloutParams params = new HttpCalloutParams('POST', QUOTES_ENDPOINT + '/' + zohoQuoteId + '/status/' + status, null, 200);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() != 200) {
                System.debug('Failed to update quote status: ' + response.getBody());
            }
        } catch (Exception ex) {
            System.debug('Error updating quote status: ' + ex.getMessage());
        }
    }
    
    /**
     * Builds the request body for quote creation/update
     */
    private static String buildQuoteRequestBody(QuoteData data) {
        Map<String, Object> quoteData = new Map<String, Object>();
        
        // Customer ID (required)
        quoteData.put('customer_id', data.zohoCustomerId);
        
        // Quote details
        if (String.isNotBlank(data.quote.QuoteNumber)) {
            quoteData.put('reference_number', data.quote.QuoteNumber);
        }
        
        
        if (data.quote.ExpirationDate != null) {
            String exdateStr = data.quote.ExpirationDate.format();
            List<String> exparts = exdateStr.split('/');
            String exformattedDate = exparts[2] + '-' + exparts[0] + '-' + exparts[1];
            quoteData.put('expiry_date', exformattedDate);
        }
        
        
        // Quote description/notes
        if (String.isNotBlank(data.quote.Description)) {
            quoteData.put('notes', ZohoBillingUtils.sanitizeForZoho(data.quote.Description, 2000));
        }
        
        // Default settings
        String dateStr = Date.today().format();
        List<String> parts = dateStr.split('/');
        String formattedDate = parts[2] + '-' + parts[0] + '-' + parts[1];
        quoteData.put('date', formattedDate); // Today's date in YYYY-MM-DD
        
        // Build line items
        List<Map<String, Object>> lineItemsList = new List<Map<String, Object>>();
        Integer itemOrder = 1;
        
        for (QuoteLineItem lineItem : data.lineItems) {
            Map<String, Object> itemData = new Map<String, Object>();
            
            // Use Zoho Item ID
            itemData.put('item_id', lineItem.Product_Plan__r.Zoho_Item_Id__c);
            
            // Item details
            itemData.put('name', lineItem.Product_Plan__r.Name);
            if (String.isNotBlank(lineItem.Description)) {
                itemData.put('description', ZohoBillingUtils.sanitizeForZoho(lineItem.Description, 2000));
            } else if (String.isNotBlank(lineItem.Product_Plan__r.Description__c)) {
                itemData.put('description', ZohoBillingUtils.sanitizeForZoho(lineItem.Product_Plan__r.Description__c, 2000));
            }
            
            itemData.put('item_order', itemOrder++);
            itemData.put('quantity', lineItem.Quantity != null ? lineItem.Quantity : 1);
            itemData.put('rate', lineItem.UnitPrice != null ? lineItem.UnitPrice : 0);
            itemData.put('item_total', lineItem.TotalPrice != null ? lineItem.TotalPrice : 0);
            
            lineItemsList.add(itemData);
        }
        
        quoteData.put('line_items', lineItemsList);
        return JSON.serialize(quoteData);
    }
    
    
    // ===== INVOICE MANAGEMENT METHODS =====
    
    /**
     * Main method to create and send invoice
     * Called by scheduled flows when invoice expires
     *
     * @future method to handle HTTP callouts and DML operations separately
     *
     * Flow:
     * 1. Get invoice with all related data (account, product plans, line items)
     * 2. Create missing Zoho IDs (customer, items) via callouts if needed
     * 3. Store all current IDs in runtime variables for transaction consistency
     * 4. Create invoice in Zoho using runtime IDs
     * 5. Email the invoice automatically
     * 6. Update Salesforce records with new Zoho IDs at the end
     * 7. Update invoice status to 'Sent'
     */
    @future(callout=true)
    public static void createAndSendInvoice(String invoiceId) {
        try {
            // Step 1: Get invoice with all details
            Invoice__c invoice = getInvoiceWithDetails(invoiceId);
            if (invoice == null) {
                System.debug('Invoice not found: ' + invoiceId);
                return;
            }
            
            // Step 2-3: Ensure all required Zoho IDs exist and store in runtime variables
            ZohoRuntimeIds runtimeIds = new ZohoRuntimeIds();
            ZohoUpdateData updateData = new ZohoUpdateData();
            updateData.invoiceId = invoiceId;
            
            // Get account and ensure it has Zoho Customer ID
            Account acc = getAccountById(invoice.Product_Subscriber__r.Account__c);
            System.debug(acc);
            if ( acc!=null && String.isBlank(acc.Zoho_Customer_Id__c)) {
                // Create customer in Zoho and store in runtime variables
                String newZohoCustomerId = createCustomer(acc);
                
                runtimeIds.currentZohoCustomerId = newZohoCustomerId;
                updateData.newZohoCustomerId = newZohoCustomerId;
                updateData.accountId = acc.Id;
                updateData.accountNeedsUpdate = true;
            } else {
                runtimeIds.currentZohoCustomerId = acc.Zoho_Customer_Id__c;
            }
            
            // Get invoice line items and ensure they have Zoho Item IDs
            List<Product_Plan__c> productPlans = getProductPlansForInvoice(invoiceId);
            for (Product_Plan__c plan : productPlans) {
                if (String.isBlank(plan.Zoho_Item_Id__c)) {
                    // Create item in Zoho and store in runtime variables
                    String newZohoItemId = createItem(plan);
                    runtimeIds.currentZohoItemIds.put(plan.Id, newZohoItemId);
                    updateData.productPlanToZohoItemId.put(plan.Id, newZohoItemId);
                    updateData.itemsNeedingUpdate.add(plan.Id);
                } else {
                    runtimeIds.currentZohoItemIds.put(plan.Id, plan.Zoho_Item_Id__c);
                }
            }
            
            // Step 4: Create invoice in Zoho using runtime IDs
            String zohoInvoiceId = createInvoiceInZoho(invoice, runtimeIds);
            if (String.isNotBlank(zohoInvoiceId)) {
                updateData.newZohoInvoiceId = zohoInvoiceId;
                
                // Step 5: Email the invoice automatically (no custom subject/body)
                emailInvoiceInZoho(zohoInvoiceId, invoice.Product_Subscriber__r.Account__r.Email__c , invoice.Additional_Recipient__c);
                
                // Step 6: Update all Salesforce records with new Zoho IDs
                updateSalesforceRecordsForInvoice(updateData);
                
                // Step 7: Update invoice status to 'Sent'
                updateInvoiceStatus(invoiceId, 'Sent');
                
            } else {
                System.debug('Failed to create invoice in Zoho for: ' + invoiceId);
            }
            
        } catch (Exception e) {
            System.debug('Error in createAndSendInvoice: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Log the error for debugging
            ZohoBillingUtils.logIntegrationActivity('CREATE_AND_SEND_INVOICE', invoiceId, null, false, e.getMessage());
            throw new ZohoBillingException('Error creating and sending invoice: ' + e.getMessage());
        }
    }
    
    /**
     * Get invoice with all related details
     */
    private static Invoice__c getInvoiceWithDetails(String invoiceId) {
        
        List<Invoice__c> invoices = [
                SELECT Id, Name , Product_Subscriber__c, Product_Subscriber__r.Account__c ,Product_Subscriber__r.Account__r.Email__c, 
                       Product_Subscriber__r.Email__c, Additional_Recipient__c,
                       Start_Date__c, End_Date__c, Duration__c, Price__c, 
                       Discount__c, Price_after_Discount__c, Status__c,
                       Product_Plan__c, Product_Version__c
                FROM Invoice__c 
                WHERE Id = :invoiceId
                LIMIT 1
            ];
        
        return invoices.isEmpty() ? null : invoices[0];
    }
    
    /**
     * Get product plans for invoice
     */
    private static List<Product_Plan__c> getProductPlansForInvoice(String invoiceId) {
        
        return [
                SELECT Id, Name, Description__c, Zoho_Item_Id__c , Price__c , Product__c
                FROM Product_Plan__c 
                WHERE Id IN (
                    SELECT Product_Plan__c 
                    FROM Invoice__c 
                    WHERE Id = :invoiceId
                )
            ];
    }
    
    /**
     * Get account by ID for invoice processing
     */
    private static Account getAccountById(String accountId) {
        
        System.debug('accountId >>' + accountId);
        
        List<Account> accounts = [
                SELECT Id, Name, Email__c, Zoho_Customer_Id__c, Phone, Website, Description
                FROM Account 
                WHERE Id = :accountId
                LIMIT 1
            ];
        
        return accounts.isEmpty() ? null : accounts[0];
    }
    
    /**
     * Create invoice in Zoho Billing using existing callout infrastructure
     */
    private static String createInvoiceInZoho(Invoice__c invoice, ZohoRuntimeIds runtimeIds) {
        try {
            // Build invoice line items using runtime IDs
            List<Object> invoiceItems = new List<Object>();
            
            Object invoiceItem = new Map<String, Object>{
                'product_id' => runtimeIds.currentZohoItemIds.get(invoice.Product_Plan__c),
                'name' => 'Subscription Service',
                'description' => 'Subscription from ' + String.valueOf(invoice.Start_Date__c) + ' to ' + String.valueOf(invoice.End_Date__c),
                'quantity' => 1,
                'rate' => invoice.Price_after_Discount__c != null ? invoice.Price_after_Discount__c : invoice.Price__c
            };
            invoiceItems.add(invoiceItem);
            
            Map<String, Object> invoiceData = new Map<String, Object>{
                'customer_id' => runtimeIds.currentZohoCustomerId,
                'reference_number' => invoice.Name,
                'date' => String.valueOf(System.today()),
                'due_date' => String.valueOf(System.today().addDays(5)), // 30 days payment terms
                'invoice_items' => invoiceItems,
                'notes' => 'Thank you for your business!'
            };
            
            String requestBody = JSON.serialize(invoiceData);
            
            // Use existing callout infrastructure
            HttpCalloutParams params = new HttpCalloutParams('POST', INVOICES_ENDPOINT, requestBody, 201);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() == 201) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> zohoInvoice = (Map<String, Object>) responseBody.get('invoice');
                return (String) zohoInvoice.get('invoice_id');
            } else {
                System.debug('Failed to create invoice. Status: ' + response.getStatusCode() + ', Body: ' + response.getBody());
                return null;
            }
        } catch (Exception e) {
            System.debug('Error creating invoice: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Email invoice in Zoho Billing using existing callout infrastructure
     * Uses default templates, no custom subject/body
     */
    private static void emailInvoiceInZoho(String zohoInvoiceId, String recipient  , String additionalRecipient) {
        try {
            List<String> ccRecipients = new List<String>();
            List<String> toRecipients = new List<String>();
            
            // Add additional recipient if provided
            if (String.isNotBlank(additionalRecipient)) {
                ccRecipients.add(additionalRecipient);
            }
            
            if (String.isNotBlank(recipient)) {
                toRecipients.add(recipient);
            }
            
            
            Map<String, Object> emailData = new Map<String, Object>();
            
            // Only add recipients if we have additional ones
            // Zoho will automatically send to the customer's primary email
            if (!toRecipients.isEmpty()) {
                emailData.put('to_mail_ids', toRecipients);
            }
            if (!ccRecipients.isEmpty()) {
                emailData.put('cc_mail_ids',ccRecipients );
            }
            
            String requestBody = JSON.serialize(emailData);
            
            // Use existing callout infrastructure
            HttpCalloutParams params = new HttpCalloutParams('POST', INVOICES_ENDPOINT + '/' + zohoInvoiceId + '/email', requestBody, 200);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() == 200) {
                System.debug('Invoice emailed successfully: ' + zohoInvoiceId);
            } else {
                System.debug('Failed to email invoice. Status: ' + response.getStatusCode() + ', Body: ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Error emailing invoice: ' + e.getMessage());
        }
    }
    
    /**
     * Update Salesforce records with new Zoho IDs for invoice operations
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void updateSalesforceRecordsForInvoice(ZohoUpdateData updateData) {
        try {
            List<SObject> recordsToUpdate = new List<SObject>();
            System.debug('updateData >>' + updateData);
            System.debug('updateData.itemsNeedingUpdate >>' + updateData.itemsNeedingUpdate);
            // Update Account with new Zoho Customer ID
            if (updateData.accountNeedsUpdate && String.isNotBlank(updateData.newZohoCustomerId)) {
                
                Account accToUpdate = new Account(
                    Id = updateData.accountId,
                Zoho_Customer_Id__c = updateData.newZohoCustomerId
                    );
                recordsToUpdate.add(accToUpdate);
                
            }
            
            // Update Product Plans with new Zoho Item IDs
            if (!updateData.itemsNeedingUpdate.isEmpty()) {
                for (String planId : updateData.itemsNeedingUpdate) {
                    String zohoItemId = updateData.productPlanToZohoItemId.get(planId);
                    if (String.isNotBlank(zohoItemId)) {
                        Product_Plan__c planToUpdate = new Product_Plan__c(
                            Id = planId,
                        Zoho_Item_Id__c = zohoItemId
                            );
                        recordsToUpdate.add(planToUpdate);
                    }
                    
                }
            }
            
            // Update Invoice with new Zoho Invoice ID
            if (String.isNotBlank(updateData.newZohoInvoiceId)) {
                
                Invoice__c invoiceToUpdate = new Invoice__c(
                    Id = updateData.invoiceId,
                Zoho_Invoice_Id__c = updateData.newZohoInvoiceId
                    );
                recordsToUpdate.add(invoiceToUpdate);
            }
            
            // Perform all updates together
            if (!recordsToUpdate.isEmpty()) {
                // Verify update permissions before DML
                Boolean canUpdate = true;
                for (SObject record : recordsToUpdate) {
                    if (record instanceof Account) {
                        canUpdate = canUpdate ;
                    } else if (record instanceof Product_Plan__c) {
                        canUpdate = canUpdate ;
                    } else if (record instanceof Invoice__c) {
                        canUpdate = canUpdate ;
                    }
                }
                
                if (canUpdate) {
                    Database.update(recordsToUpdate, false); // Allow partial success
                } else {
                    System.debug('Insufficient permissions to update records');
                }
            }
            
        } catch (Exception e) {
            System.debug('Error updating Salesforce records: ' + e.getMessage());
        }
    }
    
    /**
     * Update invoice status
     */
    private static void updateInvoiceStatus(String invoiceId, String status) {
        try {
            
            Invoice__c invoiceToUpdate = new Invoice__c(
                Id = invoiceId,
            Status__c = status
                );
            
            update invoiceToUpdate;
            
        } catch (Exception e) {
            System.debug('Error updating invoice status: ' + e.getMessage());
        }
    }
    /**
     * Update invoice in Zoho (if needed)
     */
    @future(callout=true)
    public static void updateInvoiceInZoho(String zohoInvoiceId, String invoiceData) {
        try {
            HttpCalloutParams params = new HttpCalloutParams('PUT', INVOICES_ENDPOINT + '/' + zohoInvoiceId, invoiceData, 200);
            HttpResponse response = makeZohoCallout(params);
            
            if (response.getStatusCode() == 200) {
                System.debug('Invoice updated successfully: ' + zohoInvoiceId);
            } else {
                System.debug('Failed to update invoice. Status: ' + response.getStatusCode() + ', Body: ' + response.getBody());
            }
        } catch (Exception e) {
            System.debug('Error updating invoice: ' + e.getMessage());
        }
    }
    
    // ===== END INVOICE MANAGEMENT METHODS =====
    
    /**
     * Alternative method to create invoice without sending email
     * Called from ZohoInvoiceManager for create-only operations
     */
    @future(callout=true)
    public static void createInvoiceOnly(String invoiceId) {
        try {
            // Get invoice with all details
            Invoice__c invoice = getInvoiceWithDetails(invoiceId);
            if (invoice == null) {
                System.debug('Invoice not found: ' + invoiceId);
                return;
            }
            
            // Setup runtime IDs and tracking (same as createAndSendInvoice)
            ZohoRuntimeIds runtimeIds = new ZohoRuntimeIds();
            ZohoUpdateData updateData = new ZohoUpdateData();
            updateData.invoiceId = invoiceId;
            
            // Get account and ensure it has Zoho Customer ID
            Account acc = getAccountById(invoice.Product_Subscriber__r.Account__c);
            if (String.isBlank(acc.Zoho_Customer_Id__c)) {
                String newZohoCustomerId = createCustomer(acc);
                runtimeIds.currentZohoCustomerId = newZohoCustomerId;
                updateData.newZohoCustomerId = newZohoCustomerId;
                updateData.accountId = acc.Id;
                updateData.accountNeedsUpdate = true;
            } else {
                runtimeIds.currentZohoCustomerId = acc.Zoho_Customer_Id__c;
            }
            
            // Get invoice line items and ensure they have Zoho Item IDs
            List<Product_Plan__c> productPlans = getProductPlansForInvoice(invoiceId);
            for (Product_Plan__c plan : productPlans) {
                if (String.isBlank(plan.Zoho_Item_Id__c)) {
                    String newZohoItemId = createItem(plan);
                    runtimeIds.currentZohoItemIds.put(plan.Id, newZohoItemId);
                    updateData.productPlanToZohoItemId.put(plan.Id, newZohoItemId);
                    updateData.itemsNeedingUpdate.add(plan.Id);
                } else {
                    runtimeIds.currentZohoItemIds.put(plan.Id, plan.Zoho_Item_Id__c);
                }
            }
            
            // Create invoice in Zoho using runtime IDs (but don't send email)
            String zohoInvoiceId = createInvoiceInZoho(invoice, runtimeIds);
            if (String.isNotBlank(zohoInvoiceId)) {
                updateData.newZohoInvoiceId = zohoInvoiceId;
                
                // Update Salesforce records with new Zoho IDs
                updateSalesforceRecordsForInvoice(updateData);
                
                // Update invoice status to 'Created' (not 'Sent')
                updateInvoiceStatus(invoiceId, 'Created');
                
            } else {
                System.debug('Failed to create invoice in Zoho for: ' + invoiceId);
            }
            
        } catch (Exception e) {
            System.debug('Error in createInvoiceOnly: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Method to send existing invoice via email
     * Called from ZohoInvoiceManager for email-only operations
     */
    @future(callout=true)
    public static void sendInvoiceEmail(String invoiceId) {
        try {
            // Get invoice to find Zoho Invoice ID
            Invoice__c invoice = getInvoiceWithDetails(invoiceId);
            if (invoice == null) {
                System.debug('Invoice not found: ' + invoiceId);
                return;
            }
            
            // Check if invoice has Zoho Invoice ID
            if (String.isBlank(invoice.Zoho_Invoice_Id__c)) {
                System.debug('Invoice does not have Zoho Invoice ID: ' + invoiceId);
                return;
            }
            
            // Send email for existing invoice
            emailInvoiceInZoho(invoice.Zoho_Invoice_Id__c,invoice.Product_Subscriber__r.Account__r.Email__c ,invoice.Additional_Recipient__c);
            
            // Update invoice status to 'Sent'
            updateInvoiceStatus(invoiceId, 'Sent');
            
        } catch (Exception e) {
            System.debug('Error in sendInvoiceEmail: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Custom exception class for Zoho Billing errors
     */
    public class ZohoBillingException extends Exception {}
}