@IsTest
public class AccountServiceTest {
    
    @testSetup
    static void setupData() {
        
        // Create Products
        TestDataFactory.createStandardProducts();
        
        // Existing Account
        insert new Account(Name = 'ABC Technologies');
    }
    
    @IsTest
    static void testGetOrCreateAccounts_WithExistingAndNewAccounts() {
        
        Map<String, QuoteGroupWrapper> groupedQuotes = new Map<String, QuoteGroupWrapper>();
        
        QuoteGroupWrapper q1 = new QuoteGroupWrapper();
        q1.quoteNumber = 'Q001';
        q1.customerName = 'ABC Technologies';
        groupedQuotes.put(q1.quoteNumber, q1);
        
        QuoteGroupWrapper q2 = new QuoteGroupWrapper();
        q2.quoteNumber = 'Q002';
        q2.customerName = 'XYZ Pvt Ltd';
        groupedQuotes.put(q2.quoteNumber, q2);
        
        Test.startTest();
        AccountService.getOrCreateAccounts(groupedQuotes);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetOrCreateAccounts_AllExisting() {
        
        insert new Account(Name = 'XYZ Pvt Ltd');
        
        Map<String, QuoteGroupWrapper> groupedQuotes = new Map<String, QuoteGroupWrapper>();
        
        QuoteGroupWrapper q1 = new QuoteGroupWrapper();
        q1.quoteNumber = 'Q001';
        q1.customerName = 'ABC Technologies';
        
        QuoteGroupWrapper q2 = new QuoteGroupWrapper();
        q2.quoteNumber = 'Q002';
        q2.customerName = 'XYZ Pvt Ltd';
        
        groupedQuotes.put(q1.quoteNumber, q1);
        groupedQuotes.put(q2.quoteNumber, q2);
        
        Test.startTest();
        AccountService.getOrCreateAccounts(groupedQuotes);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetOrCreateAccounts_EmptyInput() {
        
        Test.startTest();
        AccountService.getOrCreateAccounts(new Map<String, QuoteGroupWrapper>());
        Test.stopTest();
    }
}