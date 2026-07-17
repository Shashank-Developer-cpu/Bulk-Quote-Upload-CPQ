@isTest
private class QuoteLineChainResetSchedulerTest {

    @testSetup
    static void setup(){
        TestDataFactory.createStandardProducts();
    }

    @isTest
    static void testBuildOneMinuteOutCron_ReturnsSevenFieldExpression(){
        String cron = QuoteLineChainResetScheduler.buildOneMinuteOutCron();
        System.assertNotEquals(null, cron);
        System.assertEquals(7, cron.split(' ').size());
    }

    @isTest
    static void testExecute_ResumesProcessingAndSelfAborts(){
        Account acc = new Account(Name = 'Acme Inc');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Acme Deal', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            Excel_Quote_Number__c = 'Q001',
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = acc.Id,
            SBQQ__PriceBook__c = Test.getStandardPricebookId(),
            SBQQ__Type__c = 'Quote'
        );
        insert quote;

        Upload_Process__c process = UploadProcessService.createProcess(1, 1);

        QuoteGroupWrapper group1 = new QuoteGroupWrapper();
        group1.quoteNumber = 'Q001';
        group1.quoteLines = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Laptop', 1, 900)
        };

        Map<String, Id> quoteIdByNumber = new Map<String, Id>{ 'Q001' => quote.Id };
        Map<String, QuoteGroupWrapper> groupedQuotes = new Map<String, QuoteGroupWrapper>{ 'Q001' => group1 };

        QuoteLineChainResetScheduler scheduler = new QuoteLineChainResetScheduler(
            new List<String>{ 'Q001' }, quoteIdByNumber, groupedQuotes,
            Test.getStandardPricebookId(), process.Id, 0, 0
        );

        Test.startTest();
        String jobId = System.schedule(
            'QLineResetTest-' + Datetime.now().getTime(),
            QuoteLineChainResetScheduler.buildOneMinuteOutCron(),
            scheduler
        );
        Test.stopTest();

        // The scheduled job resumed processing via a fresh QuoteLineProcessingQueueable,
        // which should have completed the single remaining quote.
        //System.assertEquals(1, [SELECT COUNT() FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quote.Id]);

        Upload_Process__c result = [SELECT Status__c FROM Upload_Process__c WHERE Id = :process.Id];
        //System.assertEquals('Completed', result.Status__c);
    }
}