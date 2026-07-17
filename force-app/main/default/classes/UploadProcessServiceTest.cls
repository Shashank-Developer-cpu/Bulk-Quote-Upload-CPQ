@IsTest
public class UploadProcessServiceTest {
    
    @testSetup
    static void setupData() {
        TestDataFactory.createStandardProducts();
    }
    
    @IsTest
    static void testCreateProcess() {
        
        Test.startTest();
        
        Upload_Process__c process =
            UploadProcessService.createProcess(2,5);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testMarkProcessing() {
        
        Upload_Process__c process =
            UploadProcessService.createProcess(1,2);
        
        Test.startTest();
        
        UploadProcessService.markProcessing(process.Id);
        
        Test.stopTest();
    }
    
    @IsTest
    static void testUpdateProgress() {
        
        Upload_Process__c process =
            UploadProcessService.createProcess(5,20);
        
        Test.startTest();
        
        UploadProcessService.updateProgress(
            process.Id,
            3,
            2
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCompleteProcessSuccess() {
        
        Upload_Process__c process =
            UploadProcessService.createProcess(3,10);
        
        Test.startTest();
        
        UploadProcessService.completeProcess(
            process.Id,
            3,
            0
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCompleteProcessFailed() {
        
        Upload_Process__c process =
            UploadProcessService.createProcess(3,10);
        
        Test.startTest();
        
        UploadProcessService.completeProcess(
            process.Id,
            0,
            3
        );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFailProcess() {
        
        Upload_Process__c process =
            UploadProcessService.createProcess(1,2);
        
        Test.startTest();
        
        UploadProcessService.failProcess(
            process.Id,
            'Unexpected Error'
        );
        
        Test.stopTest();
    }
    
}