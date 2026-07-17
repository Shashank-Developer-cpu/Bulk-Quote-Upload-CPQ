/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : CPQQuoteCalculatorCallback
 * Description : Implements Salesforce CPQ's SBQQ.CalculateCallback interface. QuoteCalculator
 *               invokes this class's callback() once pricing calculation finishes, passing
 *               back the fully-priced quote model as JSON; this is where the actual Quote Line
 *               records get saved via SBQQ.QuoteAPI.QuoteSaver. Referenced by name (not by
 *               direct instantiation) in CPQProductAdderService.calculateQuote() via the
 *               "callbackClass" key in the request context CPQ's ServiceRouter expects.
 * Author      : Shashank
 */
global with sharing class CPQQuoteCalculatorCallback implements SBQQ.CalculateCallback {

    global void callback(String quoteJSON) {

        System.debug('===== CALLBACK RECEIVED =====');

        SBQQ.ServiceRouter.save(
            'SBQQ.QuoteAPI.QuoteSaver',
            quoteJSON
        );

        System.debug('===== QUOTE SAVED =====');
    }
}