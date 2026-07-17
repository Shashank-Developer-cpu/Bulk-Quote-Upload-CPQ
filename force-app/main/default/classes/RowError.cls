/*
 * Project     : Bulk Quote Upload using Salesforce CPQ
 * Class       : RowError
 * Description : Stores validation error details for a single Excel row including row number, quote information, and error message.
 * Author      : Shashank
 */
public class RowError {
    public Integer rowNumber;
    public String quoteNumber;
    public String productName;
    public String message;
    public String rawRowJson;
}