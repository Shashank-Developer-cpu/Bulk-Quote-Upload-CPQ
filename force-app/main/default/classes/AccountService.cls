/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : AccountService
 * Description : Finds existing Accounts and creates only missing Accounts in bulk.
 * Author      : Shashank
 */

public with sharing class AccountService {

    public static Map<String, Account> getOrCreateAccounts(Map<String, QuoteGroupWrapper> groupedQuotes){

        Set<String> customerNames = new Set<String>();

        for(QuoteGroupWrapper quote : groupedQuotes.values()){
            customerNames.add(quote.customerName);
        }

        Map<String, Account> accountMap = new Map<String, Account>();

        for(Account acc : [SELECT Id, Name FROM Account WHERE Name IN :customerNames]){
            System.debug('Existing Accounts : ' + accountMap.size());
            accountMap.put(acc.Name, acc);
        }

        List<Account> accountsToInsert = new List<Account>();

        for(String customerName : customerNames){
            if(!accountMap.containsKey(customerName)){
                accountsToInsert.add(new Account(Name = customerName));
            }
        }

        if(!accountsToInsert.isEmpty()){
            System.debug('Accounts To Insert : ' + accountsToInsert.size());
            insert accountsToInsert;
            System.debug('Final Account Map : ' + accountMap.size());

            for(Account acc : accountsToInsert){
                accountMap.put(acc.Name, acc);
            }
        }
        return accountMap;
    }
}