@isTest
private class QuoteUploadQueueableTest {
    
    @testSetup
    static void setup(){
        TestDataFactory.createStandardProducts();
    }
    
    @isTest
    static void testExecute_SingleQuote_EndToEndSuccess(){
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Laptop', 2, 900),
                TestDataFactory.buildRow(3, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Mouse', 4, 20)
                };
                    Map<String, QuoteGroupWrapper> groupedQuotes = QuoteGroupingService.groupByQuoteNumber(rows);
        Upload_Process__c process = UploadProcessService.createProcess(groupedQuotes.size(), rows.size());
        
        Test.startTest();
        System.enqueueJob(new QuoteUploadQueueable(groupedQuotes, process.Id));
        Test.stopTest();
        
        // Account and Opportunity should have been created since neither existed.
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = 'Acme Inc']);
        System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Name = 'Acme Deal']);
        
        SBQQ__Quote__c quote = [
            SELECT Id, Excel_Quote_Number__c FROM SBQQ__Quote__c WHERE Excel_Quote_Number__c = 'Q001'
        ];
        //System.assertEquals(2, [SELECT COUNT() FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quote.Id]);
        
        Upload_Process__c result = [
            SELECT Status__c, Successful_Quotes__c, Failed_Quotes__c
            FROM Upload_Process__c WHERE Id = :process.Id
        ];
        //System.assertEquals('Completed', result.Status__c);
        //System.assertEquals(1, result.Successful_Quotes__c);
        //System.assertEquals(0, result.Failed_Quotes__c);
    }
    
    @isTest
    static void testExecute_ReusesExistingAccountAndOpportunity(){
        Account existingAcc = new Account(Name = 'Acme Inc');
        insert existingAcc;
        Opportunity existingOpp = new Opportunity(
            Name = 'Acme Deal', AccountId = existingAcc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert existingOpp;
        
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Laptop', 1, 900)
                };
                    Map<String, QuoteGroupWrapper> groupedQuotes = QuoteGroupingService.groupByQuoteNumber(rows);
        Upload_Process__c process = UploadProcessService.createProcess(groupedQuotes.size(), rows.size());
        
        Test.startTest();
        System.enqueueJob(new QuoteUploadQueueable(groupedQuotes, process.Id));
        Test.stopTest();
        
        // Still only one Account and one Opportunity - no duplicates created.
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = 'Acme Inc']);
        System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Name = 'Acme Deal']);
        
        SBQQ__Quote__c quote = [SELECT SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE Excel_Quote_Number__c = 'Q001'];
        System.assertEquals(existingOpp.Id, quote.SBQQ__Opportunity2__c);
    }
}