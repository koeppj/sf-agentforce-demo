Account acc = new Account(Name = 'HR Demo Isolation B');
insert acc;
Contact con = new Contact(
    AccountId = acc.Id,
    FirstName = 'Riley',
    LastName = 'Chen',
    Email = 'riley.chen.hrdemo@example.test'
);
insert con;
System.debug(LoggingLevel.INFO, 'USER_B_SETUP account=' + acc.Id + ' contact=' + con.Id);
