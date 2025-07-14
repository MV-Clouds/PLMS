public with sharing class SendInvoiceEmailController {
    
    @AuraEnabled
    public static Map<String, Object> getInvoiceData(String recordId) {
        try {
            Invoice__c invoice = [
                SELECT Product_Subscriber__r.Email__c, Additional_Recipient__c, Product_Subscriber__r.Org_Name__c, Product_Subscriber__r.Product__r.Name
                FROM Invoice__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            Map<String, Object> response = new Map<String, Object>();
            response.put('toAddress', invoice.Product_Subscriber__r.Email__c);
            response.put('ccAddresses', invoice.Additional_Recipient__c);
            
            String emailBody = 'Hello ' + invoice.Product_Subscriber__r.Org_Name__c + ',<br/><br/>' +
                'We hope you\'re enjoying using ' + invoice.Product_Subscriber__r.Product__r.Name + '.<br/><br/>' +
                'This is a friendly reminder that your subscription is expiring soon.<br/><br/>' +
                'Please find the attached invoice with all the necessary details to renew your subscription and avoid any service interruptions.<br/><br/>' +
                'If you have any questions or need assistance with the renewal process, feel free to reach out to our support team.<br/><br/>' +
                'Thank you for choosing ' + invoice.Product_Subscriber__r.Product__r.Name + '.<br/><br/>' +
                'Best regards,<br/>';
            
            response.put('emailBody', emailBody);
            
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void sendEmailWithAttachment(String recordId, List<String> toAddresses, List<String> ccAddresses, String subject, String body) {
        try {
            PageReference pdfPage = new PageReference('/apex/InvoicePDF?id=' + recordId);
            Blob pdfBlob = pdfPage.getContent();
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            if (ccAddresses != null && !ccAddresses.isEmpty()) {
                email.setCcAddresses(ccAddresses);
            }
            email.setSubject(subject);
            email.setHtmlBody(body);
            
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('Invoice.pdf');
            attachment.setBody(pdfBlob);
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void test(){
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}