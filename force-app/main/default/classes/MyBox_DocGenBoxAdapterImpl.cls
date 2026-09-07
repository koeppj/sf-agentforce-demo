/**
 * @description Default MyBox_DocGenBoxAdapter implementation, delegating directly to the installed
 *              box.DocGenToolkit. Contains no logic beyond that delegation.
 * @group MyBox
 */
public with sharing class MyBox_DocGenBoxAdapterImpl implements MyBox_DocGenBoxAdapter {
    public box.DocGenResponse submitDocGenBatch(box.DocGenRequest request) {
        return new box.DocGenToolkit().submitDocGenBatch(request);
    }

    public box.DocGenResponse getDocGenBatch(String batchId) {
        return new box.DocGenToolkit().getDocGenBatch(batchId);
    }
}
