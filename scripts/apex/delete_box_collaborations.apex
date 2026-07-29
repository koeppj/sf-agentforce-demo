List<box__FRUP__c> recordsWithCollaboration = [
    SELECT box__CollaborationID__c
    FROM box__FRUP__c
    WHERE box__CollaborationID__c != null
    WITH USER_MODE
];

box.Toolkit toolkit = new box.Toolkit();
Integer deletedCount = 0;
Integer failedCount = 0;

try {
    for (box__FRUP__c frupRecord : recordsWithCollaboration) {
        Boolean deleted = toolkit.deleteCollaboration(
            frupRecord.box__CollaborationID__c,
            null
        );

        if (deleted) {
            deletedCount++;
        } else {
            failedCount++;
            System.debug(LoggingLevel.ERROR,
                'Failed to delete collaboration ' + frupRecord.box__CollaborationID__c
                + ': ' + toolkit.mostRecentError
            );
        }
    }

    toolkit.commitChanges();
    System.debug(LoggingLevel.INFO,
        'Box collaboration cleanup complete. Deleted: ' + deletedCount
        + ', Failed: ' + failedCount
    );
} catch (Exception toolkitException) {
    System.debug(LoggingLevel.ERROR,
        'Box collaboration cleanup failed: ' + toolkitException.getMessage()
    );
    throw toolkitException;
}
