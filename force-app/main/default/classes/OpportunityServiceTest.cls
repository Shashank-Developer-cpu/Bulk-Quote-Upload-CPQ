@IsTest
public class OpportunityServiceTest {
    
    @testSetup
    static void setupData() {
        
        TestDataFactory.createStandardProducts();
        
        List<Account> accounts = new List<Account>{
            new Account(Name='ABC Technologies'),
                new Account(Name='XYZ Pvt Ltd')
                };
                    insert accounts;
        
        insert new Opportunity(
            Name='Existing Opportunity',
            AccountId=accounts[0].Id,
            StageName='Prospecting',
            CloseDate=Date.today().addDays(10)
        );
    }
    
    @IsTest
    static void testCreateOpportunities_NewAndExisting() {
        
        Map<String, Account> accountMap = new Map<String, Account>();
        
        for(Account acc : [
            SELECT Id,Name
            FROM Account
        ]){
            accountMap.put(acc.Name, acc);
        }
        
        Map<String, QuoteGroupWrapper> groupedQuotes = new Map<String, QuoteGroupWrapper>();
        
        QuoteGroupWrapper q1 = new QuoteGroupWrapper();
        q1.quoteNumber='Q001';
        q1.customerName='ABC Technologies';
        q1.opportunityName='Existing Opportunity';
        
        QuoteGroupWrapper q2 = new QuoteGroupWrapper();
        q2.quoteNumber='Q002';
        q2.customerName='XYZ Pvt Ltd';
        q2.opportunityName='New Opportunity';
        
        groupedQuotes.put(q1.quoteNumber,q1);
        groupedQuotes.put(q2.quoteNumber,q2);
        
        Test.startTest();
        OpportunityService.createOpportunities(groupedQuotes,accountMap);
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateOpportunities_OnlyNew() {
        
        Map<String, Account> accountMap = new Map<String, Account>();
        
        for(Account acc : [
            SELECT Id,Name
            FROM Account
        ]){
            accountMap.put(acc.Name,acc);
        }
        
        Map<String, QuoteGroupWrapper> groupedQuotes = new Map<String, QuoteGroupWrapper>();
        
        QuoteGroupWrapper q1 = new QuoteGroupWrapper();
        q1.quoteNumber='Q003';
        q1.customerName='ABC Technologies';
        q1.opportunityName='Another Opportunity';
        
        groupedQuotes.put(q1.quoteNumber,q1);
        
        Test.startTest();
        OpportunityService.createOpportunities(groupedQuotes,accountMap);
        Test.stopTest();
    }
    
    @IsTest
    static void testCreateOpportunities_EmptyInput() {
        
        Test.startTest();
        OpportunityService.createOpportunities(
            new Map<String, QuoteGroupWrapper>(),
            new Map<String, Account>()
        );
        Test.stopTest();
    }
    
}