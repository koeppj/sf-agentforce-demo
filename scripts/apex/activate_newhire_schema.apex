Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
cmd.fullName = 'HR_DocGen_Schema.NewHire_1_0';
cmd.label = 'New Hire/Rehire 1.0';

Map<String, Object> fields = new Map<String, Object>{
    'Schema_Key__c' => 'newHire',
    'Version__c' => '1.0',
    'Lifecycle_Status__c' => 'Active',
    'Request_Type__c' => 'New Hire/Rehire',
    'Box_DocGen_Template_File_Id__c' => '2456566806586',
    'Box_DocGen_Template_Version_Id__c' => '2724134783386',
    'Output_Type__c' => 'pdf',
    'Output_File_Name_Pattern__c' => 'HR Request - {caseNumber}',
    'Max_Payload_Bytes__c' => 200000
};
for (String fieldName : fields.keySet()) {
    Metadata.CustomMetadataValue v = new Metadata.CustomMetadataValue();
    v.field = fieldName;
    v.value = fields.get(fieldName);
    cmd.values.add(v);
}

Metadata.DeployContainer container = new Metadata.DeployContainer();
container.addMetadata(cmd);
Id jobId = Metadata.Operations.enqueueDeployment(container, null);
System.debug(LoggingLevel.INFO, 'CMD_DEPLOY jobId=' + jobId);
