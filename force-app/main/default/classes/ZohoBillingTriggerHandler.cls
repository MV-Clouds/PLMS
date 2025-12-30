/**
 * @description add your description here
 * @Date 10 September 2025
 */

public class ZohoBillingTriggerHandler {
    
    // Static flags to prevent recursive calls
    private static Boolean isAccountProcessingComplete = false;
    private static Boolean isProductPlanProcessingComplete = false;
    
    /**
     * Handles Account trigger events
     * @param newAccounts List of new Account records
     * @param oldAccountsMap Map of old Account records
     * @param triggerEvent Type of trigger event
     */
    public static void handleAccountTrigger(List<Account> newAccounts, Map<Id, Account> oldAccountsMap, String triggerEvent) {
        
        // Prevent recursive calls
        if (isAccountProcessingComplete) {
            return;
        }
        
        List<Account> accountsToProcess = new List<Account>();
        
        if (triggerEvent == 'INSERT') {
            // Process all new accounts for customer creation
            for (Account acc : newAccounts) {
                if (shouldProcessAccount(acc)) {
                    accountsToProcess.add(acc);
                }
            }
            
            if (!accountsToProcess.isEmpty()) {
                String jsonAccounts = JSON.serialize(accountsToProcess);
                processAccountsAsync(jsonAccounts, 'CREATE');
            }
            
        } else if (triggerEvent == 'UPDATE') {
            // Process accounts that have relevant field changes
            for (Account acc : newAccounts) {
                Account oldAcc = oldAccountsMap.get(acc.Id);
                if (shouldProcessAccount(acc) && hasRelevantChanges(acc, oldAcc)) {
                    accountsToProcess.add(acc);
                }
            }
            
            if (!accountsToProcess.isEmpty()) {
                String jsonAccounts = JSON.serialize(accountsToProcess);
                processAccountsAsync(jsonAccounts, 'UPDATE');
            }
        }
        
        isAccountProcessingComplete = true;
    }
    
    /**
     * Handles Product Plan trigger events
     * @param newProductPlans List of new Product_Plan__c records
     * @param oldProductPlansMap Map of old Product_Plan__c records
     * @param triggerEvent Type of trigger event
     */
    public static void handleProductPlanTrigger(List<Product_Plan__c> newProductPlans, Map<Id, Product_Plan__c> oldProductPlansMap, String triggerEvent) {
        
        // Prevent recursive calls
        if (isProductPlanProcessingComplete) {
            return;
        }
        
        List<Product_Plan__c> plansToProcess = new List<Product_Plan__c>();
        
        if (triggerEvent == 'INSERT') {
            // Process all new product plans for item creation
            for (Product_Plan__c plan : newProductPlans) {
                if (shouldProcessProductPlan(plan)) {
                    plansToProcess.add(plan);
                }
            }
            
            if (!plansToProcess.isEmpty()) {
                String jsonPlansToProcess = JSON.serialize(plansToProcess);
                processProductPlansAsync(jsonPlansToProcess, 'CREATE');
            }
            
        } else if (triggerEvent == 'UPDATE') {
            // Process product plans that have relevant field changes
            for (Product_Plan__c plan : newProductPlans) {
                Product_Plan__c oldPlan = oldProductPlansMap.get(plan.Id);
                if (shouldProcessProductPlan(plan) && hasRelevantChanges(plan, oldPlan)) {
                    plansToProcess.add(plan);
                }
            }
            
            if (!plansToProcess.isEmpty()) {
                String jsonPlansToProcess = JSON.serialize(plansToProcess);
                processProductPlansAsync(jsonPlansToProcess, 'UPDATE');
            }
        }
        
        isProductPlanProcessingComplete = true;
    }
    
    /**
     * Checks if account should be processed for Zoho integration
     * @param account Account record to check
     * @return Boolean true if account should be processed
     */
    private static Boolean shouldProcessAccount(Account account) {
        return ZohoBillingUtils.isZohoIntegrationEnabled() && 
               ZohoBillingUtils.isAccountEligibleForZoho(account);
    }
    
    /**
     * Checks if product plan should be processed for Zoho integration
     * @param plan Product_Plan__c record to check
     * @return Boolean true if plan should be processed
     */
    private static Boolean shouldProcessProductPlan(Product_Plan__c plan) {
        return ZohoBillingUtils.isZohoIntegrationEnabled() && 
               ZohoBillingUtils.isProductPlanEligibleForZoho(plan);
    }
    
    /**
     * Checks if Account has relevant field changes for Zoho update
     * @param newAccount New Account record
     * @param oldAccount Old Account record
     * @return Boolean true if has relevant changes
     */
    private static Boolean hasRelevantChanges(Account newAccount, Account oldAccount) {
        return newAccount.Name != oldAccount.Name ||
               newAccount.Email__c != oldAccount.Email__c ||
               newAccount.Phone != oldAccount.Phone ||
               newAccount.Website != oldAccount.Website ||
               newAccount.Description != oldAccount.Description;
    }
    
    /**
     * Checks if Product Plan has relevant field changes for Zoho update
     * @param newPlan New Product_Plan__c record
     * @param oldPlan Old Product_Plan__c record
     * @return Boolean true if has relevant changes
     */
    private static Boolean hasRelevantChanges(Product_Plan__c newPlan, Product_Plan__c oldPlan) {
        return newPlan.Name != oldPlan.Name ||
               newPlan.Description__c != oldPlan.Description__c ||
               newPlan.Price__c != oldPlan.Price__c;
    }
    
    /**
     * Processes accounts asynchronously to avoid mixed DML errors
     * @param accounts List of accounts to process
     * @param operation Operation type (CREATE or UPDATE)
     */
    @future(callout=true)
    public static void processAccountsAsync(String jsonAccounts, String operation) {
        List<Account> accounts = (List<Account>) JSON.deserialize(jsonAccounts, List<Account>.class);
        List<Account> accountsToUpdate = new List<Account>();
        
        for (Account acc : accounts) {
            try {
                if (operation == 'CREATE') {
                    String customerId = ZohoBillingService.createCustomer(acc);
                    if (String.isNotBlank(customerId)) {
                        acc.zoho_customer_id__c = customerId;
                        accountsToUpdate.add(acc);
                    }
                } else if (operation == 'UPDATE' && String.isNotBlank(acc.zoho_customer_id__c)) {
                    ZohoBillingService.updateCustomer(acc, acc.zoho_customer_id__c);
                }
            } catch (Exception ex) {
                System.debug('Error processing account ' + acc.Id + ': ' + ex.getMessage());
                // Consider adding error logging or notification here
                // ExceptionHandler.publishError('ZohoBillingTriggerHandler', 'processAccountsAsync', ex.getMessage());
            }
        }
        
        // Update accounts with new Zoho customer IDs
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate;
            } catch (Exception ex) {
                System.debug('Error updating accounts with Zoho customer IDs: ' + ex.getMessage());
                // ExceptionHandler.publishError('ZohoBillingTriggerHandler', 'processAccountsAsync', 'Error updating accounts: ' + ex.getMessage());
            }
        }
    }
    
    /**
     * Processes product plans asynchronously to avoid mixed DML errors
     * @param plans List of product plans to process
     * @param operation Operation type (CREATE or UPDATE)
     */
    @future(callout=true)
    public static void processProductPlansAsync(String jsonPlans, String operation) {
        List<Product_Plan__c> plans = (List<Product_Plan__c>) JSON.deserialize(jsonPlans, List<Product_Plan__c>.class);
        
        List<Product_Plan__c> plansToUpdate = new List<Product_Plan__c>();
        
        for (Product_Plan__c plan : plans) {
            try {
                if (operation == 'CREATE') {
                    String itemId = ZohoBillingService.createItem(plan);
                    if (String.isNotBlank(itemId)) {
                        plan.zoho_item_id__c = itemId;
                        plansToUpdate.add(plan);
                    }
                } else if (operation == 'UPDATE' && String.isNotBlank(plan.zoho_item_id__c)) {
                    ZohoBillingService.updateItem(plan, plan.zoho_item_id__c);
                }
            } catch (Exception ex) {
                System.debug('Error processing product plan ' + plan.Id + ': ' + ex.getMessage());
                // Consider adding error logging or notification here
                //ExceptionHandler.publishError('ZohoBillingTriggerHandler', 'processProductPlansAsync', ex.getMessage());
            }
        }
        
        // Update product plans with new Zoho item IDs
        if (!plansToUpdate.isEmpty()) {
            try {
                update plansToUpdate;
            } catch (Exception ex) {
                System.debug('Error updating product plans with Zoho item IDs: ' + ex.getMessage());
                // ExceptionHandler.publishError('ZohoBillingTriggerHandler', 'processProductPlansAsync', 'Error updating product plans: ' + ex.getMessage());
            }
        }
    }

    
}