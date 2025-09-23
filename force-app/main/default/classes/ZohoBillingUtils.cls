/**
 * Utility class for Zoho Billing integration configuration and helpers
 */
public class ZohoBillingUtils {
    
    // Custom settings or custom metadata type for configuration
    public static final String DEFAULT_CURRENCY_CODE = 'USD';
    public static final String DEFAULT_PRODUCT_TYPE = 'goods';
    
    /**
     * Validates if an account is eligible for Zoho integration
     * @param account Account record to validate
     * @return Boolean true if account is eligible
     */
    public static Boolean isAccountEligibleForZoho(Account account) {
        return String.isNotBlank(account.Name) &&
            (String.isNotBlank(account.Email__c) || account.Email__c != null);
    }
    
    /**
     * Validates if a product plan is eligible for Zoho integration
     * @param plan Product_Plan__c record to validate
     * @return Boolean true if plan is eligible
     */
    public static Boolean isProductPlanEligibleForZoho(Product_Plan__c plan) {
        return String.isNotBlank(plan.Name) &&
            plan.Price__c != null &&
            plan.Price__c > 0;
    }
    
    /**
     * Sanitizes text fields for Zoho API
     * @param value String value to sanitize
     * @param maxLength Maximum allowed length
     * @return String sanitized value
     */
    public static String sanitizeForZoho(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return null;
        }
        
        String sanitized = value.trim();
        
        if (maxLength != null && sanitized.length() > maxLength) {
            sanitized = sanitized.substring(0, maxLength);
        }
        
        return sanitized;
    }
    
    /**
     * Generates a unique SKU for product plans
     * @param plan Product_Plan__c record
     * @return String unique SKU
     */
    public static String generateProductPlanSKU(Product_Plan__c plan) {
        String baseSKU = 'PLAN_' + plan.Id;
        
        // Add additional uniqueness if needed
        if (String.isNotBlank(plan.Name)) {
            String cleanName = plan.Name.replaceAll('[^a-zA-Z0-9]', '').toUpperCase();
            if (cleanName.length() > 10) {
                cleanName = cleanName.substring(0, 10);
            }
            String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
            String randomPart = '';
            for (Integer i = 0; i < 4; i++) {
                Integer rand = Math.floor(Math.random() * chars.length()).intValue();
                randomPart += chars.substring(rand, rand + 1);
            }
            baseSKU = 'PLAN_' + cleanName + '_' + String.valueOf(plan.Id).substring(String.valueOf(plan.Id).length() - 5) + randomPart;
        }
        
        return baseSKU;
    }
    
    /**
     * Formats address for Zoho API
     * @param street Street address
     * @param city City
     * @param state State/Province
     * @param postalCode Postal/ZIP code
     * @param country Country
     * @return Map<String, Object> formatted address
     */
    public static Map<String, Object> formatAddressForZoho(String street, String city, String state, String postalCode, String country) {
        Map<String, Object> address = new Map<String, Object>();
        
        if (String.isNotBlank(street)) {
            address.put('street', sanitizeForZoho(street, 250));
        }
        if (String.isNotBlank(city)) {
            address.put('city', sanitizeForZoho(city, 50));
        }
        if (String.isNotBlank(state)) {
            address.put('state', sanitizeForZoho(state, 50));
        }
        if (String.isNotBlank(postalCode)) {
            address.put('zip', sanitizeForZoho(postalCode, 20));
        }
        if (String.isNotBlank(country)) {
            address.put('country', sanitizeForZoho(country, 50));
        }
        
        return address.isEmpty() ? null : address;
    }
    
    /**
     * Logs integration activity for monitoring
     * @param operation Type of operation (CREATE_CUSTOMER, UPDATE_CUSTOMER, etc.)
     * @param recordId Salesforce record ID
     * @param zohoId Zoho record ID
     * @param success Whether operation was successful
     * @param errorMessage Error message if failed
     */
    public static void logIntegrationActivity(String operation, String recordId, String zohoId, Boolean success, String errorMessage) {
        String logMessage = String.format(
            'Zoho Integration - Operation: {0}, SF Record: {1}, Zoho ID: {2}, Success: {3}',
        new List<String>{operation, recordId, zohoId, String.valueOf(success)}
        );
        
        if (!success && String.isNotBlank(errorMessage)) {
            logMessage += ', Error: ' + errorMessage;
        }
        
        System.debug(LoggingLevel.INFO, logMessage);
        
        // Could also insert into a custom logging object here for better tracking
        // IntegrationLog__c log = new IntegrationLog__c(...);
        // insert log;
    }
    
    /**
     * Checks if Zoho integration is enabled (could use custom setting)
     * @return Boolean true if integration is enabled
     */
    public static Boolean isZohoIntegrationEnabled() {
        // This could check a custom setting or permission
        // For now, defaulting to true
        // Example: return ZohoSettings__c.getInstance().IsEnabled__c;
        return true;
    }
    
    /**
     * Gets the organization ID for Zoho API calls
     * @return String organization ID
     */
    public static String getZohoOrganizationId() {
        // This should come from custom settings or custom metadata
        // For now, returning null (will be passed as header if available)
        // Example: return ZohoSettings__c.getInstance().OrganizationId__c;

        return System.Label.Zoho_Organization_Id;
    }
    
    /**
     * Validates required fields for customer creation
     * @param account Account record
     * @return List<String> list of missing required fields
     */
    public static List<String> validateCustomerRequiredFields(Account account) {
        List<String> missingFields = new List<String>();
        
        if (String.isBlank(account.Name)) {
            missingFields.add('Name');
        }
        
        // if we want to require email as well 
        // if (String.isBlank(account.Email__c)) {
        //     missingFields.add('Email__c');
        // }
        
        return missingFields;
    }
    
    /**
     * Validates required fields for item creation
     * @param plan Product_Plan__c record
     * @return List<String> list of missing required fields
     */
    public static List<String> validateItemRequiredFields(Product_Plan__c plan) {
        System.debug('plan >>' + plan);
        List<String> missingFields = new List<String>();
        
        if (String.isBlank(plan.Name)) {
            missingFields.add('Name');
        }
        
        if (plan.Price__c == null) {
            missingFields.add('Price__c');
        }
        
        return missingFields;
    }
}