/**
 * @description Narrow seam over box.DocGenToolkit so tests can substitute a stub instead of performing a
 *              real Box callout or relying on HTTP-level mocking of managed-package internals.
 * @group MyBox
 */
public interface MyBox_DocGenBoxAdapter {
    box.DocGenResponse submitDocGenBatch(box.DocGenRequest request);
    box.DocGenResponse getDocGenBatch(String batchId);
}
