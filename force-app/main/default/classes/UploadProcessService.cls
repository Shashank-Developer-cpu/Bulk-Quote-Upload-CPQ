/*
* Project     : Bulk Quote Upload using Salesforce CPQ
* Class       : UploadProcessService
* Description : Creates and updates Upload Process records used to track each Excel upload.
* Author      : Shashank
*/

public with sharing class UploadProcessService {
    
    public static Upload_Process__c createProcess(Integer totalQuotes, Integer totalQuoteLines){
        Upload_Process__c process = new Upload_Process__c(
            Status__c = 'Pending',
            Total_Quotes__c = totalQuotes,
            Total_Quote_Lines__c = totalQuoteLines,
            Successful_Quotes__c = 0,
            Failed_Quotes__c = 0
        );
        insert process;
        return process;
    }
    
    public static void markProcessing(Id processId){
        update new Upload_Process__c(Id = processId, Status__c = 'Processing');
    }
    
    // Called once per quote as Phase 2 works through the chain, so the LWC's polling has
    // real incremental numbers to show instead of a static 0/0 until the very end. This is
    // a single small DML call inside a transaction that's already isolated to one quote, so
    // it doesn't add any bulkification/governor-limit risk.
    public static void updateProgress(Id processId, Integer successCount, Integer failCount){
        update new Upload_Process__c(
            Id = processId,
            Successful_Quotes__c = successCount,
            Failed_Quotes__c = failCount
        );
    }
    
    public static void completeProcess(Id processId, Integer successCount, Integer failCount){
        update new Upload_Process__c(
            Id = processId,
            Status__c = successCount > 0 ? 'Completed' : 'Failed',
            Successful_Quotes__c = successCount,
            Failed_Quotes__c = failCount
        );
    }
    
    public static void failProcess(Id processId, String reason){
        update new Upload_Process__c(Id = processId, Status__c = 'Failed');
        UploadErrorService.logQuoteFailure(processId, null, reason);
    }
}