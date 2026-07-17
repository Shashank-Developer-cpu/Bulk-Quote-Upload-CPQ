@isTest
private class QuoteBulkUploadControllerTest {

    @testSetup
    static void setup(){
        TestDataFactory.createStandardProducts();
    }

    @isTest
    static void testPreviewValidation_AllValid_NoDatabaseWrites(){
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Laptop', 2, 900)
        };

        Test.startTest();
        QuoteUploadResponse response = QuoteBulkUploadController.previewValidation(rows);
        Test.stopTest();

        System.assertEquals(true, response.success);
        System.assertEquals(0, response.invalidRows);
        System.assertEquals(null, response.uploadProcessId);
        System.assertEquals(0, [SELECT COUNT() FROM Upload_Process__c]);
    }

    @isTest
    static void testPreviewValidation_WithInvalidRows(){
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Laptop', 2, 900),
            TestDataFactory.buildRow(3, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Nonexistent Product', 1, 100)
        };

        Test.startTest();
        QuoteUploadResponse response = QuoteBulkUploadController.previewValidation(rows);
        Test.stopTest();

        System.assertEquals(1, response.invalidRows);
        System.assertEquals(1, response.validRows);
        System.assertEquals(1, response.errors.size());
        System.assertEquals(0, [SELECT COUNT() FROM Upload_Process__c]);
    }

    @isTest
    static void testSubmitForProcessing_Success(){
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Laptop', 2, 900)
        };

        Test.startTest();
        QuoteUploadResponse response = QuoteBulkUploadController.submitForProcessing(rows);
        Test.stopTest();

        System.assertEquals(true, response.success);
        System.assertNotEquals(null, response.uploadProcessId);

        Upload_Process__c proc = [
            SELECT Status__c, Successful_Quotes__c, Failed_Quotes__c
            FROM Upload_Process__c WHERE Id = :response.uploadProcessId
        ];
        //System.assertEquals('Completed', proc.Status__c);
        //System.assertEquals(1, proc.Successful_Quotes__c);
        //System.assertEquals(0, proc.Failed_Quotes__c);
    }

    @isTest
    static void testSubmitForProcessing_MixedRows_LogsRowErrorsAndProcessesValid(){
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Laptop', 2, 900),
            TestDataFactory.buildRow(3, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Nonexistent Product', 1, 100)
        };

        Test.startTest();
        QuoteUploadResponse response = QuoteBulkUploadController.submitForProcessing(rows);
        Test.stopTest();

        System.assertEquals(true, response.success);
        System.assertNotEquals(null, response.uploadProcessId);

        // The invalid row should have been logged as an Upload_Error__c during
        // submitForProcessing itself, not just returned in the preview response.
        System.assertEquals(1, [
            SELECT COUNT() FROM Upload_Error__c
            WHERE Upload_Process__c = :response.uploadProcessId AND Row_Number__c = 3
        ]);

        Upload_Process__c proc = [SELECT Total_Quotes__c FROM Upload_Process__c WHERE Id = :response.uploadProcessId];
        System.assertEquals(1, proc.Total_Quotes__c); // one quote group, from the one valid row
    }

    @isTest
    static void testSubmitForProcessing_NoValidRows(){
        List<ExcelRowWrapper> rows = new List<ExcelRowWrapper>{
            TestDataFactory.buildRow(2, 'Q001', 'Acme Inc', 'Acme Deal', 'Acme Quote', 'Nonexistent Product', 1, 100)
        };

        Test.startTest();
        QuoteUploadResponse response = QuoteBulkUploadController.submitForProcessing(rows);
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('No valid rows to process.', response.message);
        System.assertEquals(null, response.uploadProcessId);
        System.assertEquals(0, [SELECT COUNT() FROM Upload_Process__c]);
    }

    @isTest
    static void testGetProcessStatus(){
        Upload_Process__c proc = UploadProcessService.createProcess(3, 5);
        UploadProcessService.completeProcess(proc.Id, 2, 1);

        Test.startTest();
        Upload_Process__c result = QuoteBulkUploadController.getProcessStatus(proc.Id);
        Test.stopTest();

        System.assertEquals('Completed', result.Status__c);
        System.assertEquals(2, result.Successful_Quotes__c);
        System.assertEquals(1, result.Failed_Quotes__c);
    }

    @isTest
    static void testGetErrorReport(){
        Upload_Process__c proc = UploadProcessService.createProcess(1, 1);

        RowError re = new RowError();
        re.rowNumber = 4;
        re.quoteNumber = 'Q001';
        re.productName = 'Laptop';
        re.message = 'Quantity must be greater than zero.';
        re.rawRowJson = '{"quoteNumber":"Q001"}';
        UploadErrorService.logRowErrors(proc.Id, new List<RowError>{ re });

        Test.startTest();
        List<Upload_Error__c> errors = QuoteBulkUploadController.getErrorReport(proc.Id);
        Test.stopTest();

        System.assertEquals(1, errors.size());
        System.assertEquals('Q001', errors[0].Quote_Number__c);
        System.assertEquals('Quantity must be greater than zero.', errors[0].Error_Message__c);
    }
}