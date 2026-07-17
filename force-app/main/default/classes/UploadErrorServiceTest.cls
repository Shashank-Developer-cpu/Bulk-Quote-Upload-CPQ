@IsTest
public class UploadErrorServiceTest {
    
    @testSetup
    static void setupData() {
        TestDataFactory.createStandardProducts();
    }
    
    @IsTest
    static void testLogRowErrors() {
        
        Upload_Process__c process =
            UploadProcessService.createProcess(1,2);
        
        RowError err = new RowError();
        err.rowNumber = 1;
        err.quoteNumber = 'Q001';
        err.productName = 'Laptop';
        err.message = 'Quantity Error';
        err.rawRowJson = '{}';
        
        List<RowError> errors =
            new List<RowError>{err};
                
                Test.startTest();
        
        UploadErrorService.logRowErrors(
            process.Id,
            errors
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testLogRowErrorsEmptyList() {
        
        Upload_Process__c process =
            UploadProcessService.createProcess(1,1);
        
        Test.startTest();
        
        UploadErrorService.logRowErrors(
            process.Id,
            new List<RowError>()
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testLogQuoteFailure() {
        
        Upload_Process__c process =
            UploadProcessService.createProcess(1,2);
        
        Test.startTest();
        
        UploadErrorService.logQuoteFailure(
            process.Id,
            'Q001',
            'CPQ Failure'
        );
        
        Test.stopTest();
    }
    
}