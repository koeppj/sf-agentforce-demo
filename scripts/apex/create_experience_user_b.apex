Id profileId = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus Login User' LIMIT 1].Id;
Id contactId = '003gK000013SoSfQAK';

User u = new User(
    FirstName = 'Riley',
    LastName = 'Chen',
    Email = 'riley.chen.hrdemo@example.test',
    Username = 'riley.chen.hrdemo.b@example.test',
    Alias = 'rchen',
    CommunityNickname = 'rileychenhrb',
    ProfileId = profileId,
    ContactId = contactId,
    TimeZoneSidKey = 'America/Los_Angeles',
    LocaleSidKey = 'en_US',
    EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'en_US',
    IsActive = true
);
insert u;
System.debug(LoggingLevel.INFO, 'USER_B id=' + u.Id);
