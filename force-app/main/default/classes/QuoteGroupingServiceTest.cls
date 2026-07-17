@IsTest
public class QuoteGroupingServiceTest {
    
    @testSetup
    static void setupData() {
        TestDataFactory.createStandardProducts();
    }
    
    @IsTest
    static void testGroupByQuoteNumber() {
        
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>();
        
        rows.add(TestDataFactory.buildRow(
            1,'Q001','ABC',
            'Opp1','Quote1',
            'Laptop',1,100
        ));
        
        rows.add(TestDataFactory.buildRow(
            2,'Q001','ABC',
            'Opp1','Quote1',
            'Mouse',2,50
        ));
        
        rows.add(TestDataFactory.buildRow(
            3,'Q002','XYZ',
            'Opp2','Quote2',
            'Laptop',1,100
        ));
        
        Test.startTest();
        QuoteGroupingService.groupByQuoteNumber(rows);
        Test.stopTest();
    }
    
    @IsTest
    static void testGroupByQuoteNumber_EmptyList() {
        
        Test.startTest();
        QuoteGroupingService.groupByQuoteNumber(
            new List<ExcelRowWrapper>()
        );
        Test.stopTest();
    }
    
}