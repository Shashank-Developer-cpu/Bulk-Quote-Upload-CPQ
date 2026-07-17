/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : UploadErrorService
 * Description : Logs row-level validation errors and quote processing failures into Upload_Error__c records.
 * Author      : Shashank
 */
public with sharing class UploadErrorService {

    public static void logRowErrors(Id uploadProcessId, List<RowError> rowErrors){
        List<Upload_Error__c> toInsert = new List<Upload_Error__c>();
        for (RowError re : rowErrors) {
            toInsert.add(new Upload_Error__c(
                Upload_Process__c = uploadProcessId,
                Row_Number__c = re.rowNumber,
                Quote_Number__c = re.quoteNumber,
                Product_Name__c = re.productName,
                Error_Message__c = re.message,
                Row_Data__c = re.rawRowJson
            ));
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }

    public static void logQuoteFailure(Id uploadProcessId, String quoteNumber, String message){
        insert new Upload_Error__c(
            Upload_Process__c = uploadProcessId,
            Quote_Number__c = quoteNumber,
            Error_Message__c = message
        );
    }
}