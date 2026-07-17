@isTest
public class TestDataFactory {

    public static Map<String, Product2> createStandardProducts(){
        Id standardPricebookId = Test.getStandardPricebookId();

        // Known Apex testing quirk: Pricebook2.IsStandard doesn't reliably resolve to true
        // when queried via a relationship (e.g. "PricebookEntry.Pricebook2.IsStandard = true")
        // in test context unless the Standard Pricebook record is explicitly touched with a
        // DML update first. Without this, QuoteValidationService's PricebookEntry query
        // returns zero rows for every product, and every row fails validation with "Active
        // Standard Price Book Entry not found." even when the entry was inserted correctly.
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Laptop', IsActive = true, SBQQ__QuantityEditable__c = true, SBQQ__PriceEditable__c = true),
            new Product2(Name = 'Mouse', IsActive = true, SBQQ__QuantityEditable__c = true, SBQQ__PriceEditable__c = true),
            new Product2(Name = 'Inactive Widget', IsActive = false, SBQQ__QuantityEditable__c = true, SBQQ__PriceEditable__c = true),
            new Product2(Name = 'No Pricebook Widget', IsActive = true, SBQQ__QuantityEditable__c = true, SBQQ__PriceEditable__c = true)
        };
        insert products;

        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Product2 p : products) {
            if (p.Name == 'Inactive Widget' || p.Name == 'No Pricebook Widget') continue;
            entries.add(new PricebookEntry(
                Pricebook2Id = standardPricebookId, Product2Id = p.Id,
                UnitPrice = 100, IsActive = true
            ));
        }
        insert entries;

        Map<String, Product2> byName = new Map<String, Product2>();
        for (Product2 p : products) byName.put(p.Name, p);
        return byName;
    }

    public static ExcelRowWrapper buildRow(
        Integer rowNumber, String quoteNumber, String customerName, String opportunityName,
        String quoteName, String productName, Decimal quantity, Decimal salesPrice
    ){
        ExcelRowWrapper row = new ExcelRowWrapper();
        row.rowNumber = rowNumber;
        row.quoteNumber = quoteNumber;
        row.customerName = customerName;
        row.opportunityName = opportunityName;
        row.quoteName = quoteName;
        row.productName = productName;
        row.quantity = quantity;
        row.salesPrice = salesPrice;
        row.quoteStartDate = Date.today();
        row.quoteEndDate = Date.today().addDays(30);
        row.notes = 'Test row';
        return row;
    }
}