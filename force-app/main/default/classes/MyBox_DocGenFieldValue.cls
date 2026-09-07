/**
 * @description Transient, Flow-visible typed value descriptor for one HR intake Doc Gen JSON path.
 *              For a nonblank entry exactly one of textValue/dateValue/numberValue/booleanValue is
 *              populated; path and valueType are treated as untrusted input and are validated against
 *              HR_DocGen_Field__mdt by MyBox_DocGenSchemaService before use. Instances are held only in
 *              active Flow variables and Apex heap memory; never insert, cache, or log this type.
 * @group MyBox
 */
public with sharing class MyBox_DocGenFieldValue {
    @AuraEnabled
    public String path;

    @AuraEnabled
    public String valueType;

    @AuraEnabled
    public String textValue;

    @AuraEnabled
    public Date dateValue;

    @AuraEnabled
    public Decimal numberValue;

    @AuraEnabled
    public Boolean booleanValue;

    public MyBox_DocGenFieldValue() {
    }
}
