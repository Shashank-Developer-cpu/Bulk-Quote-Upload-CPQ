/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : QuoteUploadQueueable
 * Description : Phase 1 - creates Accounts, Opportunities, and Quote header records, then
 *               kicks off QuoteLineProcessingQueueable to add CPQ Quote Lines once the Quotes
 *               are committed to the database.
 *
 *               BULKIFICATION NOTE: Quote header records are collected into a list and
 *               inserted with a SINGLE Database.insert call, not one insert statement per
 *               record. At 110 quotes, one-insert-per-record caused "SBQQ: Too many SOQL
 *               queries: 201" - CPQ's own SBQQ__Quote__c trigger logic (which syncs Quote/
 *               Opportunity fields and similar bookkeeping) was firing once per insert
 *               statement instead of once for the whole batch, and its per-invocation query
 *               cost multiplied by 110 blew past the 200-query async Apex limit. A single bulk
 *               insert lets that trigger process all records in one invocation instead.
 *               Database.insert(..., false) is used (not plain insert) so that one bad record
 *               doesn't roll back the whole batch - each row's success/failure is inspected
 *               individually via Database.SaveResult, preserving the same per-quote error
 *               logging behavior as before.
 *
 *               IMPORTANT: this must stay Queueable, not Batch Apex. SBQQ.QuoteAPI.QuoteCalculator
 *               (used by CPQProductAdderService) relies on System.AsyncInfo.hasMaxStackDepth(),
 *               which is only callable inside a Queueable or Finalizer context - calling it from
 *               Batch Apex's execute() throws "hasMaxStackDepth is not allowed outside a
 *               Queueable of Finalizer execution". See QuoteLineProcessingQueueable for how
 *               chain-depth limits are handled instead.
 * Author      : Shashank
 */
public with sharing class QuoteUploadQueueable implements Queueable {

    private Map<String, QuoteGroupWrapper> groupedQuotes;
    private Id uploadProcessId;

    public QuoteUploadQueueable(Map<String, QuoteGroupWrapper> groupedQuotes, Id uploadProcessId){
        this.groupedQuotes = groupedQuotes;
        this.uploadProcessId = uploadProcessId;
    }

    public void execute(QueueableContext context){
        UploadProcessService.markProcessing(uploadProcessId);

        try {
            Map<String, Account> accountMap = AccountService.getOrCreateAccounts(groupedQuotes);
            Map<String, Opportunity> opportunityMap = OpportunityService.createOpportunities(groupedQuotes, accountMap);

            Id standardPricebookId = Test.isRunningTest()
                ? Test.getStandardPricebookId()
                : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

            // Build every Quote header record first - NO DML inside this loop.
            List<SBQQ__Quote__c> quotesToInsert = new List<SBQQ__Quote__c>();
            List<String> quoteNumberForRow = new List<String>(); // parallel to quotesToInsert

            Integer failCount = 0;

            for (QuoteGroupWrapper quoteGroup : groupedQuotes.values()) {
                Account acc = accountMap.get(quoteGroup.customerName);
                Opportunity opp = opportunityMap.get(quoteGroup.quoteNumber);

                if (acc == null || opp == null) {
                    failCount++;
                    UploadErrorService.logQuoteFailure(
                        uploadProcessId, quoteGroup.quoteNumber, 'Missing Account or Opportunity for this quote.'
                    );
                    continue;
                }

                quotesToInsert.add(new SBQQ__Quote__c(
                    Excel_Quote_Number__c = quoteGroup.quoteNumber,
                    External_Quote_Name__c = quoteGroup.quoteName,
                    SBQQ__Opportunity2__c = opp.Id,
                    SBQQ__Account__c = acc.Id,
                    SBQQ__PriceBook__c = standardPricebookId,
                    SBQQ__StartDate__c = quoteGroup.quoteStartDate,
                    SBQQ__EndDate__c = quoteGroup.quoteEndDate,
                    SBQQ__Notes__c = quoteGroup.notes,
                    SBQQ__Type__c = 'Quote'
                ));
                quoteNumberForRow.add(quoteGroup.quoteNumber);
            }

            // ONE bulk DML statement for every Quote header - see class header comment.
            Map<String, Id> quoteIdByNumber = new Map<String, Id>();

            if (!quotesToInsert.isEmpty()) {
                List<Database.SaveResult> results = Database.insert(quotesToInsert, false);
                for (Integer i = 0; i < results.size(); i++) {
                    Database.SaveResult sr = results[i];
                    String quoteNumber = quoteNumberForRow[i];
                    if (sr.isSuccess()) {
                        quoteIdByNumber.put(quoteNumber, sr.getId());
                    } else {
                        failCount++;
                        String errMsg = sr.getErrors().isEmpty()
                            ? 'Unknown error creating Quote.'
                            : sr.getErrors()[0].getMessage();
                        UploadErrorService.logQuoteFailure(uploadProcessId, quoteNumber, errMsg);
                    }
                }
            }

            if (!quoteIdByNumber.isEmpty()) {
                System.enqueueJob(new QuoteLineProcessingQueueable( 
                    quoteIdByNumber, groupedQuotes, standardPricebookId, uploadProcessId, failCount
                ));
            } else {
                UploadProcessService.completeProcess(uploadProcessId, 0, failCount);
            }

        } catch (Exception fatalEx) {
            UploadProcessService.failProcess(uploadProcessId, fatalEx.getMessage());
        }
    }
}