trigger ContractTrigger on Contract (after update) {

    if(Trigger.isAfter && Trigger.isUpdate){
        ContractTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}