/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : OpportunityService
 * Description : Finds existing Opportunities and creates only missing Opportunities. Dedupes
 *               both against Opportunities already in the org AND against Opportunities being
 *               created earlier in the SAME batch (same Account + Opportunity Name) - the
 *               newly-queued Opportunity is registered into existingOpportunityMap immediately
 *               so a later Quote group in this same upload reuses the same in-memory object;
 *               its Id populates on that shared reference once the bulk insert below runs.
 * Author      : Shashank
 */

public with sharing class OpportunityService {

    public static Map<String, Opportunity> createOpportunities(Map<String, QuoteGroupWrapper> groupedQuotes, Map<String, Account> accountMap){

        Map<String, Opportunity> opportunityMap = new Map<String, Opportunity>();

        Set<Id> accountIds = new Set<Id>();
        for(Account acc : accountMap.values()){
            accountIds.add(acc.Id);
        }

        Map<String, Opportunity> existingOpportunityMap = new Map<String, Opportunity>();
        for(Opportunity opp : [SELECT Id, Name, AccountId FROM Opportunity WHERE AccountId IN :accountIds]){
            String key = opp.AccountId + '-' + opp.Name;
            existingOpportunityMap.put(key, opp);
        }

        List<Opportunity> opportunitiesToInsert = new List<Opportunity>();

        for(QuoteGroupWrapper quoteGroup : groupedQuotes.values()){

            Account accountRecord = accountMap.get(quoteGroup.customerName);
            String key = accountRecord.Id + '-' + quoteGroup.opportunityName;

            if(existingOpportunityMap.containsKey(key)){
                opportunityMap.put(quoteGroup.quoteNumber, existingOpportunityMap.get(key));
            } else {
                Opportunity opp = new Opportunity(
                    Name = quoteGroup.opportunityName,
                    AccountId = accountRecord.Id,
                    StageName = 'Prospecting',
                    CloseDate = Date.today().addDays(30)
                );

                opportunitiesToInsert.add(opp);
                opportunityMap.put(quoteGroup.quoteNumber, opp);
                existingOpportunityMap.put(key, opp); // register immediately - dedupe within this batch
            }
        }

        if(!opportunitiesToInsert.isEmpty()){
            insert opportunitiesToInsert;
        }
        return opportunityMap;
    }
}