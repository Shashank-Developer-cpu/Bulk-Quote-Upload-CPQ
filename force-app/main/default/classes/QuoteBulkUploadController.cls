/*
* Project     : Bulk Quote Upload using Salesforce CPQ
* Class       : QuoteBulkUploadController
* Description : Entry point for LWC requests. Validation and processing are now two separate
*               calls: previewValidation() only validates and never writes anything, so the
*               LWC can show errors and let the user confirm before any Upload_Process__c /
*               Upload_Error__c records exist or any async processing is enqueued.
*               submitForProcessing() re-validates (data could theoretically have changed
*               between the preview and the confirm click) and, if there's anything valid,
*               creates the process record and kicks off QuoteUploadQueueable - this is what
*               the old single-step validateExcel() used to do.
* Author      : Shashank
*/
public with sharing class QuoteBulkUploadController {
    
    // Validate only - no DML, no async job. Used for the initial "Validate" click so the
    // user can review errors before anything is committed or processing starts.
    @AuraEnabled
    public static QuoteUploadResponse previewValidation(List<ExcelRowWrapper> excelRows){
        return QuoteValidationService.validate(excelRows);
    }
    
    // Re-validates and, if there are valid rows, creates the Upload Process record, logs
    // row errors, and enqueues Phase 1 processing. Called only after the user confirms.
    @AuraEnabled
    public static QuoteUploadResponse submitForProcessing(List<ExcelRowWrapper> excelRows){
        
        QuoteUploadResponse response = QuoteValidationService.validate(excelRows);
        List<ExcelRowWrapper> validRows = QuoteValidationService.getValidRows(excelRows, response);
        
        if (validRows.isEmpty()) {
            response.success = false;
            response.message = 'No valid rows to process.';
            return response;
        }
        
        Map<String, QuoteGroupWrapper> groupedQuotes = QuoteGroupingService.groupByQuoteNumber(validRows);
        Upload_Process__c process = UploadProcessService.createProcess(groupedQuotes.size(), validRows.size());
        
        if (!response.rowErrors.isEmpty()) {
            UploadErrorService.logRowErrors(process.Id, response.rowErrors);
        }
        
        System.enqueueJob(new QuoteUploadQueueable(groupedQuotes, process.Id));
        
        response.success = true;
        response.uploadProcessId = process.Id;
        return response;
    }
    
    // Polled by the LWC results screen while Phase 1/Phase 2 run in the background, and
    // also used to resume watching a run after a page refresh/reopen.
    // cacheable=false is intentional - each poll needs the current row, not a cached one.
    @AuraEnabled(cacheable=false)
    public static Upload_Process__c getProcessStatus(Id processId){
        return [
            SELECT Id, Status__c, Total_Quotes__c, Successful_Quotes__c,
            Failed_Quotes__c, Total_Quote_Lines__c
            FROM Upload_Process__c
            WHERE Id = :processId
            LIMIT 1
        ];
    }
    
    // Backs the "Download Error Report" button - returns every error row (both row-level
    // validation failures and quote/line processing failures) for one upload.
    @AuraEnabled(cacheable=false)
    public static List<Upload_Error__c> getErrorReport(Id processId){
        return [
            SELECT Row_Number__c, Quote_Number__c, Product_Name__c, Error_Message__c, Row_Data__c
            FROM Upload_Error__c
            WHERE Upload_Process__c = :processId
            ORDER BY Row_Number__c ASC NULLS LAST
        ];
    }
    
    // Stores the originally uploaded Excel file as a ContentVersion linked to the
    // Upload_Process__c record, so the source file is always retrievable from the process
    // later (task requirement #19). Called from the LWC right after submitForProcessing
    // returns a real uploadProcessId - kept as a separate call so a failure here never
    // blocks quote processing itself.
    @AuraEnabled
    public static void attachExcelFile(Id processId, String fileName, String base64Data){
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Data),
            FirstPublishLocationId = processId
        );
        insert cv;
    }
    
    // Backs the Processing History screen - lists every upload run, newest first.
    @AuraEnabled(cacheable=true)
    public static List<Upload_Process__c> getProcessingHistory(){
        return [
            SELECT Id, Name, Status__c, Total_Quotes__c, Successful_Quotes__c,
            Failed_Quotes__c, Total_Quote_Lines__c, CreatedDate
            FROM Upload_Process__c
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }
}