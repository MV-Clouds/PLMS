/**
 * Trigger for Product_Plan__c object - Zoho Billing integration
 * Handles creation and updates of items in Zoho Billing
 */
trigger ProductPlanZohoBillingTrigger on Product_Plan__c (after insert, after update) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ZohoBillingTriggerHandler.handleProductPlanTrigger(
                Trigger.new,
            null,
            'INSERT'
                );
        } else if (Trigger.isUpdate) {
            ZohoBillingTriggerHandler.handleProductPlanTrigger(
                Trigger.new,
            Trigger.oldMap,
            'UPDATE'
                );
        }
    }
}