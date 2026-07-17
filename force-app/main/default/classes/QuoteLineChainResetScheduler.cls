/*
* Project     : Bulk Quote Upload using Salesforce CPQ
* Class       : QuoteLineChainResetScheduler
* Description : Fallback hand-off for QuoteLineProcessingQueueable's Phase 2 processing.
*               Developer Edition and Trial orgs cap chained Queueable jobs at a stack depth
*               of 5 - production and sandbox orgs have no such cap. QuoteLineProcessingQueueable
*               chains directly (fast path) and only reaches this class if System.enqueueJob
*               actually throws "Maximum stack depth has been reached".
*
*               A Scheduled Apex job starts a brand new async execution context, so its chain
*               depth starts fresh. This lets processing resume (and go back to fast direct
*               chaining) instead of failing the remaining quotes. In production this class
*               should essentially never run; it exists for Developer/Trial org testing and as
*               a safety net.
*
*               The scheduled job self-aborts as soon as it fires, so it doesn't linger in
*               Setup > Scheduled Jobs.
*
* Author      : Shashank
*/
public with sharing class QuoteLineChainResetScheduler implements Schedulable {
    
    private List<String> remainingQuoteNumbers;
    private Map<String, Id> quoteIdByNumber;
    private Map<String, QuoteGroupWrapper> groupedQuotes;
    private Id pricebookId;
    private Id uploadProcessId;
    private Integer successCountSoFar;
    private Integer failCountSoFar;
    
    public QuoteLineChainResetScheduler(
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
    
    public void execute(SchedulableContext sc){
        // Fresh async context here => Queueable stack depth starts back at 0.
        System.enqueueJob(new QuoteLineProcessingQueueable(
            remainingQuoteNumbers, quoteIdByNumber, groupedQuotes,
            pricebookId, uploadProcessId, successCountSoFar, failCountSoFar
        ));
        
        // Clean up - this was a one-shot reset, no reason to leave it in Scheduled Jobs.
        if (sc?.getTriggerId() != null) {
            System.abortJob(sc.getTriggerId());
        }
    }
    
    // Builds a one-off CRON expression ~1 minute in the future.
    // System.schedule requires a future time and only supports minute-level granularity.
    public static String buildOneMinuteOutCron(){
        Datetime target = System.now().addMinutes(1);
        return '' + target.second() + ' ' + target.minute() + ' ' + target.hour() + ' '
            + target.day() + ' ' + target.month() + ' ? ' + target.year();
    }
}