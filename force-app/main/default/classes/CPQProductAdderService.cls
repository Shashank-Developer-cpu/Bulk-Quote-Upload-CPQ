/*
* Project     : Bulk Quote Upload using Salesforce CPQ
* Class       : CPQProductAdderService
* Description : Uses Salesforce CPQ ServiceRouter APIs to add products to Quotes, calculate
*               pricing, save Quote Lines, and correct quantities/prices to match the
*               uploaded Excel data.
*
*               IMPORTANT - SBQQ.TriggerControl usage: per Salesforce's own documentation,
*               updating a Quote Line field via Apex "from outside of the Line Editor" is a
*               documented trigger for CPQ's managed package to enqueue its own background
*               recalculation job (see Salesforce Help article 000383160, "Error 'Too many
*               queueable jobs' in the Salesforce CPQ Package"). That is what was causing the
*               recurring "hasMaxStackDepth is not allowed outside a Queueable or Finalizer
*               execution" errors - CPQ's own SBQQ.QuoteLineAfter trigger was reacting to our
*               correction update and trying to chain its own job, separate from anything our
*               code does. SBQQ.TriggerControl.disable()/enable() is Salesforce's own
*               documented API for exactly this situation (Salesforce CPQ Developer Guide,
*               "Disable CPQ Triggers in Apex") - it suppresses CPQ's managed-package triggers
*               for the wrapped DML only. It is used ONLY around the manual correction update
*               below, never around the calculate/save step, since CPQ's own triggers are
*               supposed to run as part of its pricing engine.
*
* Author      : Shashank
*/
public with sharing class CPQProductAdderService {
    
    public static void addLinesToQuote(Id quoteId, Id pricebookId, List<ExcelRowWrapper> lines){
        if (lines.isEmpty()) return;
        String currencyCode = UserInfo.getDefaultCurrency();
        
        Set<String> productNames = new Set<String>();
        for (ExcelRowWrapper row : lines) productNames.add(row.productName);
        
        Map<String, Product2> productMap = new Map<String, Product2>();
        for (Product2 p : [
            SELECT Id, Name, SBQQ__PriceEditable__c, SBQQ__QuantityEditable__c
            FROM Product2 WHERE Name IN :productNames
        ]) {
            productMap.put(p.Name, p);
        }
        
        // Step 1: add products via CPQ's own API.
        String quoteJSON = getQuoteModel(quoteId);
        
        List<String> productJsonList = new List<String>();
        for (ExcelRowWrapper row : lines) {
            Product2 product = productMap.get(row.productName);
            if (product == null) continue;
            productJsonList.add(loadProduct(product.Id, pricebookId, currencyCode));
        }
        
        if (!productJsonList.isEmpty()) {
            quoteJSON = addProducts(quoteJSON, productJsonList);
        }
        
        // Step 2: calculate + save - this is CPQ's own pricing engine. Its triggers are
        // SUPPOSED to run here (that's how Quote Lines actually get created), so
        // TriggerControl is intentionally NOT used for this step.
        calculateQuote(quoteJSON);
        // Quote Lines are saved by CPQQuoteCalculatorCallback. Do NOT call QuoteSaver again.
        
        // Step 3: correct quantity/price with plain DML on the lines CPQ just created.
        // Wrapped in TriggerControl - see class header comment for why.
        Map<Id, SBQQ__QuoteLine__c> lineByProductId = new Map<Id, SBQQ__QuoteLine__c>();
        for (SBQQ__QuoteLine__c ql : [
            SELECT Id, SBQQ__Product__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
        ]) {
            lineByProductId.put(ql.SBQQ__Product__c, ql);
        }
        
        List<SBQQ__QuoteLine__c> toUpdate = new List<SBQQ__QuoteLine__c>();
        
        for (ExcelRowWrapper row : lines) {
            Product2 product = productMap.get(row.productName);
            if (product == null) continue;
            
            SBQQ__QuoteLine__c ql = lineByProductId.get(product.Id);
            if (ql == null) continue;
            
            SBQQ__QuoteLine__c upd = new SBQQ__QuoteLine__c(Id = ql.Id);
            Boolean needsUpdate = false;
            
            if (row.quantity != null && product.SBQQ__QuantityEditable__c) {
                upd.SBQQ__Quantity__c = row.quantity;
                needsUpdate = true;
            }
            if (row.salesPrice != null && product.SBQQ__PriceEditable__c) {
                upd.SBQQ__NetPrice__c = row.salesPrice;
                needsUpdate = true;
            }
            if (needsUpdate) toUpdate.add(upd);
        }
        
        if (!toUpdate.isEmpty()) {
            SBQQ.TriggerControl.disable();
            try {
                update toUpdate;
            } finally {
                SBQQ.TriggerControl.enable();
            }
        }
    }
    
    private static String getQuoteModel(Id quoteId){
        return SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader', quoteId);
    }
    
    private static String loadProduct(Id productId, Id pricebookId, String currencyCode){
        return SBQQ.ServiceRouter.load(
            'SBQQ.ProductAPI.ProductLoader', productId,
            '{"pricebookId":"' + pricebookId + '","currencyCode":"' + currencyCode + '"}'
        );
    }
    
    private static String addProducts(String quoteModel, List<String> productModels){
        String context = '{"quote":' + quoteModel + ',"products":[' + String.join(productModels, ',') + '],"ignoreCalculate":true}';
        return SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteProductAdder', null, context);
    }
    
    private static String calculateQuote(String quoteModel){
        String context = '{"quote":' + quoteModel + ',"callbackClass":"CPQQuoteCalculatorCallback"}';
        return SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteCalculator', null, context);
    }
}