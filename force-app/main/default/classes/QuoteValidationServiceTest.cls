@IsTest
public class QuoteValidationServiceTest {
    
    @testSetup
    static void setupData() {
        TestDataFactory.createStandardProducts();
    }
    
    @IsTest
    static void testValidate_AllValidRows() {
        
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>();
        
        rows.add(
            TestDataFactory.buildRow(
                1,'Q001','ABC Technologies',
                'Opp1','Quote1',
                'Laptop',2,100
            )
        );
        
        Test.startTest();
        QuoteValidationService.validate(rows);
        Test.stopTest();
    }
    
    @IsTest
    static void testValidate_InvalidRows() {
        
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>();
        
        rows.add(
            TestDataFactory.buildRow(
                1,'Q001','ABC',
                'Opp1','Quote1',
                'Inactive Widget',2,100
            )
        );
        
        rows.add(
            TestDataFactory.buildRow(
                2,'Q002','ABC',
                'Opp2','Quote2',
                'No Pricebook Widget',1,100
            )
        );
        
        rows.add(
            TestDataFactory.buildRow(
                3,'Q003','ABC',
                'Opp3','Quote3',
                'Unknown Product',1,100
            )
        );
        
        ExcelRowWrapper qtyRow =
            TestDataFactory.buildRow(
                4,'Q004','ABC',
                'Opp4','Quote4',
                'Laptop',0,100
            );
        
        rows.add(qtyRow);
        
        Test.startTest();
        QuoteValidationService.validate(rows);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetValidRows() {
        
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>();
        
        rows.add(TestDataFactory.buildRow(
            1,'Q001','ABC','Opp1',
            'Quote1','Laptop',1,100
        ));
        
        rows.add(TestDataFactory.buildRow(
            2,'Q002','ABC','Opp2',
            'Quote2','Inactive Widget',1,100
        ));
        
        QuoteUploadResponse response =
            QuoteValidationService.validate(rows);
        
        Test.startTest();
        QuoteValidationService.getValidRows(rows,response);
        Test.stopTest();
    }
    
}