/**
 * Trigger for Account object - Zoho Billing integration
 * Handles creation and updates of customers in Zoho Billing
 */
trigger AccountZohoBillingTrigger on Account (after insert, after update) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ZohoBillingTriggerHandler.handleAccountTrigger(
                Trigger.new,
            null,
            'INSERT'
                );
        } else if (Trigger.isUpdate) {
            ZohoBillingTriggerHandler.handleAccountTrigger(
                Trigger.new,
            Trigger.oldMap,
            'UPDATE'
                );
        }
    }
}