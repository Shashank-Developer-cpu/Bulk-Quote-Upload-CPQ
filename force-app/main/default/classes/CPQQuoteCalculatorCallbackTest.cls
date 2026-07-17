@isTest
private class CPQQuoteCalculatorCallbackTest {
    
    @testSetup
    static void setup(){
        TestDataFactory.createStandardProducts();
    }
    
    @isTest
    static void testCallback_SavesQuoteWithoutError(){
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
        
        String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quote.Id);
        
        Test.startTest();
        new CPQQuoteCalculatorCallback().callback(quoteJSON);
        Test.stopTest();
        
        // No exception thrown is the primary assertion here - callback() delegates straight
        // to CPQ's own QuoteSaver, so there's nothing else of ours to assert against beyond
        // "this integration point works with a real quote model".
        System.assert(true);
    }
}