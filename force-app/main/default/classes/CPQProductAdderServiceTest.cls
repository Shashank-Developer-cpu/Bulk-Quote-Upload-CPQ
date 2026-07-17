@isTest
private class CPQProductAdderServiceTest {
    
    @testSetup
    static void setup(){
        TestDataFactory.createStandardProducts();
    }
    
    private static SBQQ__Quote__c buildQuote(String quoteNumber){
        Account acc = new Account(Name = 'Acme Inc');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Acme Deal', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            Excel_Quote_Number__c = quoteNumber,
            External_Quote_Name__c = 'Acme Quote',
            SBQQ__Opportunity2__c = opp.Id,
            SBQQ__Account__c = acc.Id,
            SBQQ__PriceBook__c = Test.getStandardPricebookId(),
            SBQQ__StartDate__c = Date.today(),
            SBQQ__EndDate__c = Date.today().addDays(30),
            SBQQ__Type__c = 'Quote'
        );
        insert quote;
        return quote;
    }
    
    @isTest
    static void testAddLinesToQuote_Success(){
        SBQQ__Quote__c quote = buildQuote('Q001');
        Id pricebookId = Test.getStandardPricebookId();
        
        List<ExcelRowWrapper> lines = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Laptop', 3, 950),
                TestDataFactory.buildRow(3, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Mouse', 5, 25)
                };
                    
                    Test.startTest();
        CPQProductAdderService.addLinesToQuote(quote.Id, pricebookId, lines);
        Test.stopTest();
        
        List<SBQQ__QuoteLine__c> quoteLines = [
            SELECT SBQQ__Product__r.Name, SBQQ__Quantity__c, SBQQ__NetPrice__c
            FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quote.Id
        ];
        System.assertEquals(2, quoteLines.size());
        
        Map<String, SBQQ__QuoteLine__c> byProduct = new Map<String, SBQQ__QuoteLine__c>();
        for (SBQQ__QuoteLine__c ql : quoteLines) byProduct.put(ql.SBQQ__Product__r.Name, ql);
        
        System.assertEquals(3, byProduct.get('Laptop').SBQQ__Quantity__c);
        System.assertEquals(950, byProduct.get('Laptop').SBQQ__NetPrice__c);
        System.assertEquals(5, byProduct.get('Mouse').SBQQ__Quantity__c);
        System.assertEquals(25, byProduct.get('Mouse').SBQQ__NetPrice__c);
    }
    
    @isTest
    static void testAddLinesToQuote_EmptyLines_NoOp(){
        SBQQ__Quote__c quote = buildQuote('Q002');
        
        Test.startTest();
        CPQProductAdderService.addLinesToQuote(quote.Id, Test.getStandardPricebookId(), new List<ExcelRowWrapper>());
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quote.Id]);
    }
    
    @isTest
    static void testAddLinesToQuote_UnknownProductSkipped(){
        SBQQ__Quote__c quote = buildQuote('Q003');
        
        List<ExcelRowWrapper> lines = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q003', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Does Not Exist', 1, 10)
                };
                    
                    Test.startTest();
        CPQProductAdderService.addLinesToQuote(quote.Id, Test.getStandardPricebookId(), lines);
        Test.stopTest();
        
        // Unknown product rows are silently skipped by addLinesToQuote (validation should
        // have already caught this earlier in the flow) - no line, no exception.
        System.assertEquals(0, [SELECT COUNT() FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quote.Id]);
    }
}