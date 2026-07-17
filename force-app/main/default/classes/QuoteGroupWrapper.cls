/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : QuoteGroupWrapper
 * Description : Represents one Quote along with all its Quote Lines after grouping the uploaded Excel data.
 * Author      : Shashank
 */

public class QuoteGroupWrapper {

    @AuraEnabled
    public String quoteNumber;

    @AuraEnabled
    public String customerName;

    @AuraEnabled
    public String opportunityName;

    @AuraEnabled
    public String quoteName;

    @AuraEnabled
    public Date quoteStartDate;

    @AuraEnabled
    public Date quoteEndDate;

    @AuraEnabled
    public String notes;

    @AuraEnabled
    public List<ExcelRowWrapper> quoteLines = new List<ExcelRowWrapper>();

}