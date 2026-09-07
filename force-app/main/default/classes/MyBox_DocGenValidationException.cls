/**
 * @description Thrown for every pre-callout authorization/schema/validation rejection raised while
 *              preparing a transient HR intake Doc Gen submission. errorCode is one of the sanitized,
 *              allow-listed values Apex returns to Flow; the message may reference non-sensitive contract
 *              paths/types for test/diagnostic purposes only and must never be surfaced to a receipt,
 *              log, or Case field. Apex does not allow chaining to the built-in Exception constructors via
 *              super(), so use the of() factory rather than "new" to set both the message and errorCode.
 * @group MyBox
 */
public class MyBox_DocGenValidationException extends Exception {
    public String errorCode;

    public static MyBox_DocGenValidationException of(String errorCode, String message) {
        MyBox_DocGenValidationException ex = new MyBox_DocGenValidationException(message);
        ex.errorCode = errorCode;
        return ex;
    }
}
