/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : QuoteUploadResponse
 * Description : Stores validation and processing results, including success status, summary, and error messages returned to LWC.
 * Author      : Shashank
 */
public class QuoteUploadResponse {
    @AuraEnabled public Boolean success;
    @AuraEnabled public String message;
    @AuraEnabled public Integer totalRows;
    @AuraEnabled public Integer validRows;
    @AuraEnabled public Integer invalidRows;
    @AuraEnabled public Id uploadProcessId;
    @AuraEnabled public List<String> errors = new List<String>();
    public List<RowError> rowErrors = new List<RowError>(); // not exposed to LWC, used server-side for Upload_Error__c
}