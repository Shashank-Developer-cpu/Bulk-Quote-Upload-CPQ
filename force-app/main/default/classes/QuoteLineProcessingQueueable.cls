/*
* Project     : Bulk Quote Upload using Salesforce CPQ
* Class       : QuoteLineProcessingQueueable
* Description : Phase 2 - adds CPQ Quote Lines to already-committed Quote records, one quote
*               per execute() invocation (see CPQProductAdderService for why: calculateQuote
*               makes a real HTTP callout, and once a transaction has DML pending, no further
*               callouts are allowed in it - so each quote's callout+DML cycle needs its own
*               transaction).
*
*               Progress reporting: UploadProcessService.updateProgress() is called after
*               EVERY quote (not just at the end) so Successful_Quotes__c/Failed_Quotes__c
*               climb in real time as the LWC polls - previously these only got written once,
*               at the very end of the whole chain, so the UI looked stuck on a spinner for
*               the entire run with no visible progress.
*
*               Chain-depth handling: Developer Edition/Trial orgs cap chained Queueable jobs
*               at depth 5 (production/sandbox have no such cap - see Salesforce Trailhead,
*               "Optimize Queueable Apex for Asynchronous Processing"). This class chains
*               directly (fast path, never throws in production/sandbox) and only falls back
*               to QuoteLineChainResetScheduler (a fresh Scheduled Apex context, depth resets)
*               if System.enqueueJob actually throws "Maximum stack depth has been reached".
*
* Author      : Shashank
*/
public with sharing class QuoteLineProcessingQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<String> remainingQuoteNumbers;
    private Map<String, Id> quoteIdByNumber;
    private Map<String, QuoteGroupWrapper> groupedQuotes;
    private Id pricebookId;
    private Id uploadProcessId;
    private Integer successCountSoFar;
    private Integer failCountSoFar;
    
    // Public constructor - called once from QuoteUploadQueueable to kick off Phase 2.
    public QuoteLineProcessingQueueable(
        Map<String, Id> quoteIdByNumber,
        Map<String, QuoteGroupWrapper> groupedQuotes,
        Id pricebookId,
        Id uploadProcessId,
        Integer failCountSoFar
    ){
        this(new List<String>(quoteIdByNumber.keySet()), quoteIdByNumber,
             groupedQuotes, pricebookId, uploadProcessId, 0, failCountSoFar);
    }
    
    // Used for chaining from execute() and from the reset scheduler.
    public QuoteLineProcessingQueueable(
        List<String> remainingQuoteNumbers,
        Map<String, Id> quoteIdByNumber,
        Map<String, QuoteGroupWrapper> groupedQuotes,
        Id pricebookId,
        Id uploadProcessId,
        Integer successCountSoFar,
        Integer failCountSoFar
    ){
        this.remainingQuoteNumbers = remainingQuoteNumbers;
        this.quoteIdByNumber = quoteIdByNumber;
        this.groupedQuotes = groupedQuotes;
        this.pricebookId = pricebookId;
        this.uploadProcessId = uploadProcessId;
        this.successCountSoFar = successCountSoFar;
        this.failCountSoFar = failCountSoFar;
    }
    
    public void execute(QueueableContext context){
        if (remainingQuoteNumbers.isEmpty()) {
            UploadProcessService.completeProcess(uploadProcessId, successCountSoFar, failCountSoFar);
            return;
        }
        
        String quoteNumber = remainingQuoteNumbers.remove(0);
        Id quoteId = quoteIdByNumber.get(quoteNumber);
        QuoteGroupWrapper quoteGroup = groupedQuotes.get(quoteNumber);
        
        Integer successCount = successCountSoFar;
        Integer failCount = failCountSoFar;
        
        try {
            CPQProductAdderService.addLinesToQuote(quoteId, pricebookId, quoteGroup.quoteLines);
            successCount++;
        } catch (Exception lineEx) {
            failCount++;
            UploadErrorService.logQuoteFailure(
                uploadProcessId, quoteNumber,
                lineEx.getMessage() + '\n\n' + lineEx.getStackTraceString()
            );
        }
        
        // Report progress after every quote, whether it succeeded or failed, so the LWC's
        // polling has real numbers to show instead of a static 0/0 for the whole run.
        UploadProcessService.updateProgress(uploadProcessId, successCount, failCount);
        
        if (remainingQuoteNumbers.isEmpty()) {
            UploadProcessService.completeProcess(uploadProcessId, successCount, failCount);
            return;
        }
        
        // Chain directly as fast as the platform allows (always succeeds in production/
        // sandbox). Only falls back to the scheduler if we actually hit the Developer/
        // Trial org depth-5 ceiling.
        try {
            System.enqueueJob(new QuoteLineProcessingQueueable(
                remainingQuoteNumbers, quoteIdByNumber, groupedQuotes,
                pricebookId, uploadProcessId, successCount, failCount
            ));
        } catch (System.AsyncException chainLimitEx) {
            if (!chainLimitEx.getMessage().contains('stack depth')) {
                throw chainLimitEx; // a different problem - don't mask it
            }
            String jobName = 'QLineReset-' + uploadProcessId + '-' + Datetime.now().getTime();
            System.schedule(
                jobName.left(80),
                QuoteLineChainResetScheduler.buildOneMinuteOutCron(),
                new QuoteLineChainResetScheduler(
                    remainingQuoteNumbers, quoteIdByNumber, groupedQuotes,
                    pricebookId, uploadProcessId, successCount, failCount
                )
            );
        }
    }
}