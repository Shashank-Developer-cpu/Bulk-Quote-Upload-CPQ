/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : QuoteValidationService
 * Description : Validates uploaded Excel data by checking required fields, products, quantities, and price book entries before processing.
 * Author      : Shashank
 */
public with sharing class QuoteValidationService {

    public static QuoteUploadResponse validate(List<ExcelRowWrapper> rows){

        QuoteUploadResponse response = new QuoteUploadResponse();
        response.totalRows = rows.size();

        Set<String> productNames = new Set<String>();
        for (ExcelRowWrapper row : rows) {
            if (!String.isBlank(row.productName)) productNames.add(row.productName.trim());
        }

        Map<String, Product2> productMap = new Map<String, Product2>();
        for (Product2 p : [SELECT Id, Name, IsActive FROM Product2 WHERE Name IN :productNames]) {
            productMap.put(p.Name, p);
        }

        Map<Id, PricebookEntry> pricebookEntryMap = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [SELECT Id, Product2Id FROM PricebookEntry
                                    WHERE Product2Id IN :productMap.values()
                                    AND Pricebook2.IsStandard = true AND IsActive = true]) {
            pricebookEntryMap.put(pbe.Product2Id, pbe);
        }

        Set<Integer> invalidRowNumbers = new Set<Integer>();

        for (ExcelRowWrapper row : rows) {

            String errorMsg = null;

            if (String.isBlank(row.quoteNumber)) errorMsg = 'Quote Number is required.';
            else if (String.isBlank(row.customerName)) errorMsg = 'Customer Name is required.';
            else if (String.isBlank(row.productName)) errorMsg = 'Product Name is required.';
            else {
                Product2 product = productMap.get(row.productName);
                if (product == null) errorMsg = 'Product does not exist.';
                else if (!product.IsActive) errorMsg = 'Product is inactive.';
                else if (!pricebookEntryMap.containsKey(product.Id)) errorMsg = 'Active Standard Price Book Entry not found.';
            }

            if (errorMsg == null && (row.quantity == null || row.quantity <= 0)) {
                errorMsg = 'Quantity must be greater than zero.';
            }

            if (errorMsg != null) {
                invalidRowNumbers.add(row.rowNumber);

                RowError re = new RowError();
                re.rowNumber = row.rowNumber;
                re.quoteNumber = row.quoteNumber;
                re.productName = row.productName;
                re.message = errorMsg;
                re.rawRowJson = JSON.serialize(row);

                response.rowErrors.add(re);
                response.errors.add('Row ' + row.rowNumber + ' : ' + errorMsg);
            }
        }

        response.invalidRows = invalidRowNumbers.size();
        response.validRows = response.totalRows - response.invalidRows;
        response.success = response.validRows > 0;
        response.message = response.invalidRows == 0
            ? 'All rows valid.'
            : response.validRows + ' of ' + response.totalRows + ' rows valid.';

        return response;
    }

    public static List<ExcelRowWrapper> getValidRows(List<ExcelRowWrapper> rows, QuoteUploadResponse response){
        Set<Integer> invalidRowNumbers = new Set<Integer>();
        for (RowError re : response.rowErrors) invalidRowNumbers.add(re.rowNumber);

        List<ExcelRowWrapper> validRows = new List<ExcelRowWrapper>();
        for (ExcelRowWrapper row : rows) {
            if (!invalidRowNumbers.contains(row.rowNumber)) validRows.add(row);
        }
        return validRows;
    }
}