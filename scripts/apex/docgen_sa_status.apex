// Poll the Toolkit service-account Doc Gen smoke batch. IDs only; no payload/error body.

String batchId = 'dfadffe5-250e-43d9-a0ab-beb8dcbb5f5b';
box.DocGenResponse response = new box.DocGenToolkit().getDocGenBatch(batchId);
if (response == null) {
    System.debug(LoggingLevel.ERROR, 'SA_SMOKE status=null');
} else {
    System.debug(LoggingLevel.INFO, 'SA_SMOKE status_id=' + response.id);
    System.debug(LoggingLevel.INFO, 'SA_SMOKE status_status=' + response.status);
    System.debug(LoggingLevel.INFO, 'SA_SMOKE status_job_status=' + response.job_status);
    System.debug(LoggingLevel.INFO, 'SA_SMOKE status_output_file=' + response.output_file_ID);
    if (response.entries != null && !response.entries.isEmpty()) {
        box.DocGenResponse.Jobs job = response.entries[0];
        System.debug(LoggingLevel.INFO, 'SA_SMOKE job_status=' + job.status);
        String outputId = (job.output_file == null) ? null : job.output_file.id;
        System.debug(LoggingLevel.INFO, 'SA_SMOKE job_output_file=' + outputId);
    } else {
        System.debug(LoggingLevel.INFO, 'SA_SMOKE job_entries=empty');
    }
}
