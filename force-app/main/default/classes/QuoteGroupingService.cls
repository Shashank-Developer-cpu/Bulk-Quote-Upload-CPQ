/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : QuoteGroupingService
 * Description : Groups validated Excel rows by Quote Number so each Quote can contain multiple Quote Lines.
 * Author      : Shashank
 */

public with sharing class QuoteGroupingService {

    public static Map<String, QuoteGroupWrapper> groupByQuoteNumber(List<ExcelRowWrapper> rows){

        Map<String, QuoteGroupWrapper> groupedQuotes = new Map<String, QuoteGroupWrapper>();

        for(ExcelRowWrapper row : rows){

            if(!groupedQuotes.containsKey(row.quoteNumber)){

                QuoteGroupWrapper quoteGroup = new QuoteGroupWrapper();

                quoteGroup.quoteNumber = row.quoteNumber;
                quoteGroup.customerName = row.customerName;
                quoteGroup.opportunityName = row.opportunityName;
                quoteGroup.quoteName = row.quoteName;
                quoteGroup.quoteStartDate = row.quoteStartDate;
                quoteGroup.quoteEndDate = row.quoteEndDate;
                quoteGroup.notes = row.notes;

                groupedQuotes.put(row.quoteNumber, quoteGroup);

            }
            groupedQuotes.get(row.quoteNumber).quoteLines.add(row);
        }
        return groupedQuotes;
    }
}