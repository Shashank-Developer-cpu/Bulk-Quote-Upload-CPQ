/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : ExcelRowWrapper
 * Description : Represents a single row of uploaded Excel data and transfers data between LWC and Apex.
 * Author      : Shashank
 */
public class ExcelRowWrapper {

    @AuraEnabled public Integer rowNumber {get; set;}
    @AuraEnabled public String quoteNumber {get; set;}
    @AuraEnabled public String customerName {get; set;}
    @AuraEnabled public String opportunityName {get; set;}
    @AuraEnabled public String quoteName {get; set;}
    @AuraEnabled public String productName {get; set;}
    @AuraEnabled public Decimal quantity {get; set;}
    @AuraEnabled public Decimal salesPrice {get; set;}
    @AuraEnabled public Date quoteStartDate {get; set;}
    @AuraEnabled public Date quoteEndDate {get; set;}
    @AuraEnabled public String notes {get; set;}

}