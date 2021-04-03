@IsTest
private class V2_DocusignControllerTest {
  static testMethod void templateCoverLetter() {
    ORS__c o = new ORS__c();
    o.Name = '123456';
    o.Policy__c = '2929234';
    o.Member_Number__c = '3939393933';
    insert o;

    ORS_ICNs__c icns = new ORS_ICNs__c();
    icns.ORS__c = o.Id;
    icns.ICN__c = '123849393';
    insert icns;

    Employer_Group__c eg = new Employer_Group__c();
    eg.Name = 'kdkdjfjfdkdf';
    insert eg;

    Enrolee__c en = new Enrolee__c();
    en.Name = 'd9394893843';
    en.Employer_Group_ID__c = eg.Id;
    en.Address_Line_1__c = '123 main';
    en.Address_Line_2__c = '';
    en.City__c = 'Saint Louis Park';
    en.State__c = 'MN';
    en.Zip__c = '55426';
    insert en;

    Contact con = new Contact();
    con.Email = 'John.Doe@mail.com';
    con.FirstName = 'John';
    con.LastName = 'Doe';
    con.Role__c = 'Unspecified';
    con.Enrolee__c = en.Id;
    con.MobilePhone = '444-444-4444';
    con.HomePHone = '444-444-4444';
    con.Work_Phone__c = '444-444-4444';
    con.Preferred_Phone_Type__c = 'Mobile';
    insert con;

    V2_DocuSignController.GetPhoneNumberForContact(con.Id);
    con.Preferred_Phone_Type__c = 'Mobile';

    Patient__c p = new Patient__c();
    p.Name = '19394939393';
    p.Enrolee_ID__c = en.Id;
    p.Relationship__c = 'SP - Spouse';
    p.First_Name__c = 'John';
    p.Last_Name__c = 'Doe';
    p.Date_of_Birth__c = Date.today();
    insert p;

    Provider_Group__c prg = new Provider_Group__c();
    prg.Provider_Group_Name__c = 'blahblah';
    insert prg;

    Provider__c pr = new Provider__c();
    pr.Name = '29494394955';
    pr.Provider_Group__c = prg.Id;
    insert pr;

    Case c = new Case();
    c.ORS_Number__c = o.Id;
    c.Origin = 'ORS Record';
    c.Status = 'New';
    c.Milestone__c = 'Assigned';
    c.Patient_ID__c = p.Id;
    c.Provider_ID__c = pr.Id;

    insert c;

    External_Configurations__c c1 = new External_Configurations__c();
    c1.Name = 'OSS_BUCKET';
    c1.ConfigValue__c = 'www.google.com';
    insert c1;

    External_Configurations__c c2 = new External_Configurations__c();
    c2.Name = 'Benchmark_AES_256_Key';
    c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
    insert c2;

    External_Configurations__c c3 = new External_Configurations__c();
    c3.Name = 'GET SALESFORCE FILE BYTES ENDPOINT';
    c3.ConfigValue__c = 'http://localhost.com';
    insert c3;

    External_Configurations__c c4 = new External_Configurations__c();
    c4.Name = 'GET SALESFORCE PATIENT ADDR ENDPOINT';
    c4.ConfigValue__c = 'http://localhost.com';
    insert c4;

    External_Configurations__c c5 = new External_Configurations__c();
    c5.Name = 'GET DOCUSIGN ARTIFACT ENDPOINT';
    c5.ConfigValue__c = 'http://localhost.com';
    insert c5;

    External_Configurations__c c6 = new External_Configurations__c();
    c6.Name = 'NAVIGUARD_API_BASE_URL';
    c6.ConfigValue__c = 'http://localhost.com';
    insert c6;

    External_Configurations__c c7 = new External_Configurations__c();
    c7.Name = 'USER_FILE_UPLOAD_PATH';
    c7.ConfigValue__c = 'http://localhost.com';
    insert c7;
    

    RecordType recTypeDocuSign = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'DocuSign' LIMIT 1];
    System.AssertNotEquals(null, recTypeDocuSign);

    Task t = TaskOverlayController.InitTask(c.Id, recTypeDocuSign, null);
    System.AssertNotEquals(null, t);

    Negotiation__c neg = V2_CaseDetailController.GetNegotiation(c.Id);
    List<Case_File__c> newFileList = new List<Case_File__c>();
    Case_File__c newCaseFile = new Case_File__c();
    newCaseFile.File_Hash__c = 'blalkdsfjlsakdfjsdf';
    newCaseFile.Original_File_Name__c = 'test.pdf';
    newCaseFile.File_Extension__c = 'pdf';
    newCaseFile.File_Type__c = 'Negotiated Terms';
    newFileList.Add(newCaseFile);

    Case_File__c newCaseFile3 = new Case_File__c();
    newCaseFile3.File_Hash__c = 'blalkdsfjlsakdfjsdf';
    newCaseFile3.Original_File_Name__c = 'pp.pdf';
    newCaseFile3.File_Extension__c = 'pdf';
    newCaseFile3.File_Type__c = 'Provider Bill';
    newFileList.Add(newCaseFile3);

    User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c, ORS_Office__c FROM User WHERE Id = :[Select id from User where Name = 'Int_User' Limit 1].Id LIMIT 1];
    user.TOPS_User_ID__c = '1';
    user.TOPS_Password__c = '1';
    user.ORS_Office__c = '1';
    user.ORS_Dept__c = '1';
    user.ORS_Team__c = '1';
    user.ORS_Ind__c = '1';
    update user;

    c.OwnerId = user.Id;                              
    update c;

    newFileList = V2_FileController.createPendingCaseFiles(c.Id, newFileList);
    for (Case_File__c cf : newFileList)
    {
        cf.File_Status__c = 'Uploaded';
        cf.Smart_Doc__c = true;
    }
    update newFileList;


    SD_Template__c sdTemplate = new SD_Template__c(Active__c = true, Case_File_Type__c = 'Cover Letter', File_Name__c = 'test.pdf', Name = 'Cover Letter', Template_Name__c = 'Cover Letter');
    insert sdTemplate;

    SD_Template_Field__c templateField = new SD_Template_Field__c(Display_In_Overlay__c = false, Editable__c = false, Hard_Coded__c = true, Name = 'NaviguardAddressStreet', Order_Number__c = 0, Preloaded__c = true, Required__c = false, SD_Template__c = sdTemplate.Id);
    insert templateField;

    SD_Template_Distribution__c td = new SD_Template_Distribution__c();
    td.Channel__c = 'Fax';
    td.Cover_Template__c  = sdTemplate.Id;
    td.SD_Template__c = sdTemplate.Id;
    insert td;



    SD_File__c sdFile = new SD_File__c(Case__c = c.Id, Case_File__c = newFileList[0].Id, Cover_Letter__c = null, SD_Template__c = sdTemplate.Id);
    insert sdFile;

    CFax__c cFax = new CFax__c();
    cFax.CoverText__c = 'test';
    cFax.SD_File__r = SmartDocumentController.getSDFile(sdFile.Id);
    cFax.SD_File__c = sdFile.Id;
    cFax.Sent_By_User__c = UserInfo.getUserId();
    insert cFax;

    V2_TasksController.getDocuSignTemplatePickListValuesSelectSingleForSmartDocument('Task','DocuSign_Template__c', sdFile.Id);

    sdFile.CFax__c = cFax.Id;
    update sdFile;
    
    neg.Current_SD_File__c = sdFile.Id;
    update neg;
        
    string templateName = 'Written Agreement V2';

    CDocuSign_Template__c template = new CDocuSign_Template__c();
    template.Active__c = true;
    template.Description__c = 'blah';
    template.Page_Count__c = 1;
    template.Template_ID__c = 'blahblah';
    template.Template_Name__c = templateName;
    insert template;
    template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];

    CDocuSign_Template_Recipient__c templateRecipient = new CDocuSign_Template_Recipient__c();
    templateRecipient.CDocuSign_Template__c = template.Id;
    templateRecipient.Recipient_ID__c = '1';
    templateRecipient.Recipient_Type__c = 'Signer';
    templateRecipient.Role_Name__c = 'Patient';
    templateRecipient.Template_Recipient_ID__c = 'blahblahblah';
    insert templateRecipient;

    CDocuSign_Template_Tab__c tab = new CDocuSign_Template_Tab__c();
    tab.Active__c = true;
    tab.CDocuSign_Template_Recipient__c = templateRecipient.Id;
    tab.Display_In_Overlay__c = true;
    tab.Display_Label__c = 'blahlbah';
    tab.Document_ID__c = 'blahlbah';
    tab.Editable__c = true;
    tab.Input_Type__c = 'text';
    tab.Max_Length__c = 100;
    tab.Order_Number__c = 1;
    tab.Page_Number__c = 1;
    tab.Preloaded__c = false;
    tab.Required__c = true;
    tab.Required_For_Send__c = true;
    tab.Tab_Group__c = 'TextTabs';
    tab.Tab_ID__c = '1234';
    tab.Tab_Label__c = 'blah';
    insert tab;

    CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
    env.Envelope_ID__c = 'blahlbhalbha';
    env.Envelope_Status__c = 'Created';
    env.CDocuSign_Template__c = template.Id;
    env.Case__c = c.Id;
    insert env;

    env = V2_DocuSignController.GetEnvelopeByID(env.Id);

    t.CDocuSign_Envelope__r = env;
    t.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;

    t.Status = 'Pending';
    TaskOverlayController.CreateTask(t);
    t = TaskOverlayController.GetTask(t.Id);

    List<CDocuSign_Envelope_Recipient__c> recipientList = V2_DocuSignController.InitRecipientsForSFTemplateName(c.Id, templateName);
    recipientList[0].Contact__c = con.Id;
    recipientList[0].Authentication_Phone_Number__c = '6127088889';
    recipientList[0].Use_Phone__c = true;
    recipientList[0].Email_Address__c = con.Email;
    recipientList[0].First_Name__c = con.FirstName;
    recipientList[0].Last_Name__c = con.LastName;
    recipientList[0].CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    recipientList[0].Use_Digital__c = true;
    Test.startTest();
    V2_DocuSignController.CreateSPITRecordForDocusignCreateDraft(t.Id, c.Id, templateName, recipientList);
    V2_DocuSignController.CreateSPITRecordForDocusignDiscardDraft('1234', '56789');
    V2_DocuSignController.CreateSPITRecordForDocusignGetDocuments('dfkjsdfkjsdf');
    V2_DocuSignController.CreateSPITRecordForDocusignSendDraft('kdfjsldkfj', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
    V2_DocuSignController.CreateSPITRecordForDocusignVoid('sfdlkjdf', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');

    List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
    List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];

    if (tabs.size() > 0) {
      for (CDocuSign_Template_Tab__c itm : tabs) {
        CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
        toAdd.CDocuSign_Template_Tab__c = itm.Id;
        toAdd.CDocuSign_Template_Tab__r = itm;
        toAdd.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        toAdd.Value__c = 'test';
        eTabs.Add(toAdd);
      }
    }

    insert eTabs;

    Integration_Task__c it3 =  V2_DocuSignController.CreateSPITRecordForDocusignCreateSmartDocumentDraft(t.Id, c.Id, templateName, recipientList, sdFile.Id, true);

    System.AssertNotEquals(null, t);
      Test.stopTest();
  }
  
    static testMethod void templateENRPWelcome() {
        ORS__c o = new ORS__c();
        o.Name = '123456';
        o.Policy__c = '2929234';
        o.Member_Number__c = '3939393933';
        insert o;
    
        ORS_ICNs__c icns = new ORS_ICNs__c();
        icns.ORS__c = o.Id;
        icns.ICN__c = '123849393';
        insert icns;
    
        Employer_Group__c eg = new Employer_Group__c();
        eg.Name = 'kdkdjfjfdkdf';
        insert eg;
    
        Enrolee__c en = new Enrolee__c();
        en.Name = 'd9394893843';
        en.Employer_Group_ID__c = eg.Id;
        en.Address_Line_1__c = '123 main';
        en.Address_Line_2__c = '';
        en.City__c = 'Saint Louis Park';
        en.State__c = 'MN';
        en.Zip__c = '55426';
        insert en;
    
        Contact con = new Contact();
        con.Email = 'John.Doe@mail.com';
        con.FirstName = 'John';
        con.LastName = 'Doe';
        con.Role__c = 'Unspecified';
        con.Enrolee__c = en.Id;
        con.MobilePhone = '444-444-4444';
        con.HomePHone = '444-444-4444';
        con.Work_Phone__c = '444-444-4444';
        con.Preferred_Phone_Type__c = 'Mobile';
        insert con;
    
        V2_DocuSignController.GetPhoneNumberForContact(con.Id);
        con.Preferred_Phone_Type__c = 'Mobile';

        Patient__c p = new Patient__c();
        p.Name = '19394939393';
        p.Enrolee_ID__c = en.Id;
        p.Relationship__c = 'SP - Spouse';
        p.First_Name__c = 'John';
        p.Last_Name__c = 'Doe';
        p.Date_of_Birth__c = Date.today();
        insert p;
    
        Provider_Group__c prg = new Provider_Group__c();
        prg.Provider_Group_Name__c = 'blahblah';
        insert prg;
    
        Provider__c pr = new Provider__c();
        pr.Name = '29494394955';
        pr.Provider_Group__c = prg.Id;
        insert pr;
    
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'New';
        c.Milestone__c = 'Assigned';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
    
        insert c;
    
        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;
    
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'GET SALESFORCE FILE BYTES ENDPOINT';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'GET SALESFORCE PATIENT ADDR ENDPOINT';
        c4.ConfigValue__c = 'http://localhost.com';
        insert c4;
    
        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'GET DOCUSIGN ARTIFACT ENDPOINT';
        c5.ConfigValue__c = 'http://localhost.com';
        insert c5;
    
        RecordType recTypeDocuSign = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'DocuSign' LIMIT 1];
    
        Task t = TaskOverlayController.InitTask(c.Id, recTypeDocuSign, null);
    
        string templateName = 'ENRP Welcome Package';
    
        CDocuSign_Template__c template = new CDocuSign_Template__c();
        template.Active__c = true;
        template.Description__c = 'blah';
        template.Page_Count__c = 1;
        template.Template_ID__c = 'blahblah';
        template.Template_Name__c = templateName;
        insert template;
        template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];
    
        CDocuSign_Template_Recipient__c templateRecipient = new CDocuSign_Template_Recipient__c();
        templateRecipient.CDocuSign_Template__c = template.Id;
        templateRecipient.Recipient_ID__c = '1';
        templateRecipient.Recipient_Type__c = 'Signer';
        templateRecipient.Role_Name__c = 'Patient';
        templateRecipient.Template_Recipient_ID__c = 'blahblahblah';
        insert templateRecipient;
    
        CDocuSign_Template_Tab__c tab = new CDocuSign_Template_Tab__c();
        tab.Active__c = true;
        tab.CDocuSign_Template_Recipient__c = templateRecipient.Id;
        tab.Display_In_Overlay__c = true;
        tab.Display_Label__c = 'blahlbah';
        tab.Document_ID__c = 'blahlbah';
        tab.Editable__c = true;
        tab.Input_Type__c = 'text';
        tab.Max_Length__c = 100;
        tab.Order_Number__c = 1;
        tab.Page_Number__c = 1;
        tab.Preloaded__c = false;
        tab.Required__c = true;
        tab.Required_For_Send__c = true;
        tab.Tab_Group__c = 'TextTabs';
        tab.Tab_ID__c = '1234';
        tab.Tab_Label__c = 'blah';
        insert tab;
    
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Envelope_ID__c = 'blahlbhalbha';
        env.Envelope_Status__c = 'Created';
        env.CDocuSign_Template__c = template.Id;
        env.Case__c = c.Id;
        insert env;
    
        env = V2_DocuSignController.GetEnvelopeByID(env.Id);
    
        t.CDocuSign_Envelope__r = env;
        t.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        t.Status = 'Pending';
        TaskOverlayController.CreateTask(t);
        t = TaskOverlayController.GetTask(t.Id);
    
        List<CDocuSign_Envelope_Recipient__c> recipientList = V2_DocuSignController.InitRecipientsForSFTemplateName(c.Id, templateName);
        recipientList[0].Contact__c = con.Id;
        recipientList[0].Authentication_Phone_Number__c = '6127088889';
        recipientList[0].Use_Phone__c = true;
        recipientList[0].Email_Address__c = con.Email;
        recipientList[0].First_Name__c = con.FirstName;
        recipientList[0].Last_Name__c = con.LastName;
        recipientList[0].CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        recipientList[0].Use_Digital__c = true;
    	  Test.startTest();
        V2_DocuSignController.CreateSPITRecordForDocusignCreateDraft(t.Id, c.Id, 'ENRP Welcome Package', recipientList);
        V2_DocuSignController.CreateSPITRecordForDocusignDiscardDraft('1234', '56789');
        V2_DocuSignController.CreateSPITRecordForDocusignGetDocuments('dfkjsdfkjsdf');
        V2_DocuSignController.CreateSPITRecordForDocusignSendDraft('kdfjsldkfj', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
        V2_DocuSignController.CreateSPITRecordForDocusignVoid('sfdlkjdf', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
    
        List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
        List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
    
        if (tabs.size() > 0) {
          for (CDocuSign_Template_Tab__c itm : tabs) {
            CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
            toAdd.CDocuSign_Template_Tab__c = itm.Id;
            toAdd.CDocuSign_Template_Tab__r = itm;
            toAdd.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
            toAdd.Value__c = 'test';
            eTabs.Add(toAdd);
          }
        }
    
        insert eTabs;
    
    
        

        Integration_Task__c it = V2_DocuSignController.CreateSPITRecordForDocusignUpdate('sfdlkjdf', t.CDocuSign_Envelope__r.Id, eTabs, 'sldfjlskdjf');
        Integration_Task__c it2 = V2_FileController.CreateSPITRecordForDocusignGetDocuments('sldfjlskdjf');
        V2_DocuSignController.SetAndGetEnvelopeReadyToSend(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.GetContentViewerData(c.Id);
        V2_DocuSignController.GetSPITRecord(it.Id);
        V2_FileController.GetSPITRecord(it2.Id);
        V2_DocuSignController.GetExternalConfigs();
        V2_DocuSignController.GetTaskRecordTypes();
        V2_DocuSignController.GetEnvelopeTabsByEnvelopeID(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.InitTabsForTemplateName(c.Id, templateName);
        V2_DocuSignController.WriteAndReturnRecipients(t.CDocuSign_Envelope__r.Id, recipientList);
        V2_DocuSignController.GetRecipientsForSFEnvelopeID(t.CDocuSign_Envelope__r.Id);
    
        CDocuSign_Envelope_Artifact__c artifact = new CDocuSign_Envelope_Artifact__c();
        artifact.Downloaded__c = false;
        artifact.Artifact_Type__c = 'Envelope Sent';
        artifact.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        artifact.File_Extension__c = 'PDF';
        artifact.File_Name__c = 'test';
        insert artifact;

        c.Origin = 'Patient';
        c.Digital__c = 'Yes';
        update c;
        // env.Envelope_Status__c = 'Sent';
        // update env;

        // env.Envelope_Status__c = 'Completed';
        // update env;

        V2_FileController.GetEnvelopeArtifactsByCaseID(c.Id);
        V2_FileController.GetEnvelopeArtifactByArtifactID(artifact.Id);
        
        V2_DocuSignController.GetEnvelopeArtifactByEnvelopeIDAndArtifactType(t.CDocuSign_Envelope__r.Id, 'Envelope Sent');
        env.Envelope_Status__c = 'Completed';
        update env;

        V2_DocuSignController.DiscardDraftPostCleanUp(t);
        V2_DocuSignController.GenerateAccessToken(5, false);
        System.AssertNotEquals(null, t);
        test.stoptest();
      }
    
      static testMethod void templateENRPWelcomeTest2() {
        ORS__c o = new ORS__c();
        o.Name = '123456';
        o.Policy__c = '2929234';
        o.Member_Number__c = '3939393933';
        insert o;
    
        ORS_ICNs__c icns = new ORS_ICNs__c();
        icns.ORS__c = o.Id;
        icns.ICN__c = '123849393';
        insert icns;
    
        Employer_Group__c eg = new Employer_Group__c();
        eg.Name = 'kdkdjfjfdkdf';
        insert eg;
    
        Enrolee__c en = new Enrolee__c();
        en.Name = 'd9394893843';
        en.Employer_Group_ID__c = eg.Id;
        en.Address_Line_1__c = '123 main';
        en.Address_Line_2__c = '';
        en.City__c = 'Saint Louis Park';
        en.State__c = 'MN';
        en.Zip__c = '55426';
        insert en;
    
        Contact con = new Contact();
        con.Email = 'John.Doe@mail.com';
        con.FirstName = 'John';
        con.LastName = 'Doe';
        con.Role__c = 'Unspecified';
        con.Enrolee__c = en.Id;
        con.MobilePhone = '444-444-4444';
        con.HomePHone = '444-444-4444';
        con.Work_Phone__c = '444-444-4444';
        con.Preferred_Phone_Type__c = 'Mobile';
        insert con;
    
        V2_DocuSignController.GetPhoneNumberForContact(con.Id);
        con.Preferred_Phone_Type__c = 'Mobile';

        Patient__c p = new Patient__c();
        p.Name = '19394939393';
        p.Enrolee_ID__c = en.Id;
        p.Relationship__c = 'SP - Spouse';
        p.First_Name__c = 'John';
        p.Last_Name__c = 'Doe';
        p.Date_of_Birth__c = Date.today();
        insert p;
    
        Provider_Group__c prg = new Provider_Group__c();
        prg.Provider_Group_Name__c = 'blahblah';
        insert prg;
    
        Provider__c pr = new Provider__c();
        pr.Name = '29494394955';
        pr.Provider_Group__c = prg.Id;
        insert pr;
    
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'New';
        c.Milestone__c = 'Assigned';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
    
        insert c;
    
        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;
    
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'GET SALESFORCE FILE BYTES ENDPOINT';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'GET SALESFORCE PATIENT ADDR ENDPOINT';
        c4.ConfigValue__c = 'http://localhost.com';
        insert c4;
    
        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'GET DOCUSIGN ARTIFACT ENDPOINT';
        c5.ConfigValue__c = 'http://localhost.com';
        insert c5;
    
        RecordType recTypeDocuSign = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'DocuSign' LIMIT 1];
    
        Task t = TaskOverlayController.InitTask(c.Id, recTypeDocuSign, null);
    
        
        string templateName = 'ENRP Welcome Package';
    
        CDocuSign_Template__c template = new CDocuSign_Template__c();
        template.Active__c = true;
        template.Description__c = 'blah';
        template.Page_Count__c = 1;
        template.Template_ID__c = 'blahblah';
        template.Template_Name__c = templateName;
        insert template;
        template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];
    
        CDocuSign_Template_Recipient__c templateRecipient = new CDocuSign_Template_Recipient__c();
        templateRecipient.CDocuSign_Template__c = template.Id;
        templateRecipient.Recipient_ID__c = '1';
        templateRecipient.Recipient_Type__c = 'Signer';
        templateRecipient.Role_Name__c = 'Patient';
        templateRecipient.Template_Recipient_ID__c = 'blahblahblah';
        insert templateRecipient;
    
        CDocuSign_Template_Tab__c tab = new CDocuSign_Template_Tab__c();
        tab.Active__c = true;
        tab.CDocuSign_Template_Recipient__c = templateRecipient.Id;
        tab.Display_In_Overlay__c = true;
        tab.Display_Label__c = 'blahlbah';
        tab.Document_ID__c = 'blahlbah';
        tab.Editable__c = true;
        tab.Input_Type__c = 'text';
        tab.Max_Length__c = 100;
        tab.Order_Number__c = 1;
        tab.Page_Number__c = 1;
        tab.Preloaded__c = false;
        tab.Required__c = true;
        tab.Required_For_Send__c = true;
        tab.Tab_Group__c = 'TextTabs';
        tab.Tab_ID__c = '1234';
        tab.Tab_Label__c = 'blah';
        insert tab;
    
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Envelope_ID__c = 'blahlbhalbha';
        env.Envelope_Status__c = 'Created';
        env.CDocuSign_Template__c = template.Id;
        env.Case__c = c.Id;
        insert env;
    
        env = V2_DocuSignController.GetEnvelopeByID(env.Id);
    
        t.CDocuSign_Envelope__r = env;
        t.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        t.Status = 'Pending';
        TaskOverlayController.CreateTask(t);
        t = TaskOverlayController.GetTask(t.Id);
    
        List<CDocuSign_Envelope_Recipient__c> recipientList = V2_DocuSignController.InitRecipientsForSFTemplateName(c.Id, templateName);
        recipientList[0].Contact__c = con.Id;
        recipientList[0].Authentication_Phone_Number__c = '6127088889';
        recipientList[0].Use_Phone__c = true;
        recipientList[0].Email_Address__c = con.Email;
        recipientList[0].First_Name__c = con.FirstName;
        recipientList[0].Last_Name__c = con.LastName;
        recipientList[0].CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        recipientList[0].Use_Digital__c = true;
    
        V2_DocuSignController.CreateSPITRecordForDocusignCreateDraft(t.Id, c.Id, 'ENRP Welcome Package', recipientList);
        V2_DocuSignController.CreateSPITRecordForDocusignDiscardDraft('1234', '56789');
        V2_DocuSignController.CreateSPITRecordForDocusignGetDocuments('dfkjsdfkjsdf');
        V2_DocuSignController.CreateSPITRecordForDocusignSendDraft('kdfjsldkfj', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
        V2_DocuSignController.CreateSPITRecordForDocusignVoid('sfdlkjdf', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
    
        List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
        List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
    
        if (tabs.size() > 0) {
          for (CDocuSign_Template_Tab__c itm : tabs) {
            CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
            toAdd.CDocuSign_Template_Tab__c = itm.Id;
            toAdd.CDocuSign_Template_Tab__r = itm;
            toAdd.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
            toAdd.Value__c = 'test';
            eTabs.Add(toAdd);
          }
        }
    
        insert eTabs;
    
    
        

        Integration_Task__c it = V2_DocuSignController.CreateSPITRecordForDocusignUpdate('sfdlkjdf', t.CDocuSign_Envelope__r.Id, eTabs, 'sldfjlskdjf');
        Integration_Task__c it2 = V2_FileController.CreateSPITRecordForDocusignGetDocuments('sldfjlskdjf');
        V2_DocuSignController.SetAndGetEnvelopeReadyToSend(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.GetContentViewerData(c.Id);
        V2_DocuSignController.GetSPITRecord(it.Id);
        V2_FileController.GetSPITRecord(it2.Id);
        V2_DocuSignController.GetExternalConfigs();
        V2_DocuSignController.GetTaskRecordTypes();
        V2_DocuSignController.GetEnvelopeTabsByEnvelopeID(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.InitTabsForTemplateName(c.Id, templateName);
        V2_DocuSignController.WriteAndReturnRecipients(t.CDocuSign_Envelope__r.Id, recipientList);
        V2_DocuSignController.GetRecipientsForSFEnvelopeID(t.CDocuSign_Envelope__r.Id);
    
        test.starttest();

        CDocuSign_Envelope_Artifact__c artifact = new CDocuSign_Envelope_Artifact__c();
        artifact.Downloaded__c = false;
        artifact.Artifact_Type__c = 'Envelope Sent';
        artifact.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        artifact.File_Extension__c = 'PDF';
        artifact.File_Name__c = 'test';
        insert artifact;



        
    
        c.Origin = 'Patient';
        c.Digital__c = 'Yes';
        update c;
        // env.Envelope_Status__c = 'Sent';
        // update env;

        // env.Envelope_Status__c = 'Completed';
        // update env;

        V2_FileController.GetEnvelopeArtifactsByCaseID(c.Id);
        V2_FileController.GetEnvelopeArtifactByArtifactID(artifact.Id);
        
        V2_DocuSignController.GetEnvelopeArtifactByEnvelopeIDAndArtifactType(t.CDocuSign_Envelope__r.Id, 'Envelope Sent');
        env.Envelope_Status__c = 'Completed';
        update env;

        CDocuSign_Envelope_Artifact__c artifact2 = new CDocuSign_Envelope_Artifact__c();
        artifact2.Downloaded__c = true;
        artifact2.Artifact_Type__c = 'Envelope ZIP';
        artifact2.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        artifact2.File_Extension__c = 'PDF';
        artifact2.File_Name__c = 'test';
        insert artifact2;

        artifact2.Downloaded__c = true;
        update artifact2;        
    
        V2_DocuSignController.DiscardDraftPostCleanUp(t);
        V2_DocuSignController.GenerateAccessToken(5, false);
        System.AssertNotEquals(null, t);
        test.stoptest();
      }

      static testMethod void templateENRPConsent() {
        ORS__c o = new ORS__c();
        o.Name = '123456';
        o.Policy__c = '2929234';
        o.Member_Number__c = '3939393933';
        insert o;
    
        ORS_ICNs__c icns = new ORS_ICNs__c();
        icns.ORS__c = o.Id;
        icns.ICN__c = '123849393';
        insert icns;
    
        Employer_Group__c eg = new Employer_Group__c();
        eg.Name = 'kdkdjfjfdkdf';
        insert eg;
    
        Enrolee__c en = new Enrolee__c();
        en.Name = 'd9394893843';
        en.Employer_Group_ID__c = eg.Id;
        en.Address_Line_1__c = '123 main';
        en.Address_Line_2__c = '';
        en.City__c = 'Saint Louis Park';
        en.State__c = 'MN';
        en.Zip__c = '55426';
        insert en;
    
        Contact con = new Contact();
        con.Email = 'John.Doe@mail.com';
        con.FirstName = 'John';
        con.LastName = 'Doe';
        con.Role__c = 'Unspecified';
        con.Enrolee__c = en.Id;
        insert con;
    
        Patient__c p = new Patient__c();
        p.Name = '19394939393';
        p.Enrolee_ID__c = en.Id;
        p.Relationship__c = 'SP - Spouse';
        p.First_Name__c = 'John';
        p.Last_Name__c = 'Doe';
        p.Date_of_Birth__c = Date.today();
        insert p;
    
        Provider_Group__c prg = new Provider_Group__c();
        prg.Provider_Group_Name__c = 'blahblah';
        insert prg;
    
        Provider__c pr = new Provider__c();
        pr.Name = '29494394955';
        pr.Provider_Group__c = prg.Id;
        insert pr;
    
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'New';
        c.Milestone__c = 'Assigned';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
    
        insert c;
    
        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;
    
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'GET SALESFORCE FILE BYTES ENDPOINT';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'GET SALESFORCE PATIENT ADDR ENDPOINT';
        c4.ConfigValue__c = 'http://localhost.com';
        insert c4;
    
        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'GET DOCUSIGN ARTIFACT ENDPOINT';
        c5.ConfigValue__c = 'http://localhost.com';
        insert c5;
    
        RecordType recTypeDocuSign = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'DocuSign' LIMIT 1];
    
        //Test.StartTest();
        Task t = TaskOverlayController.InitTask(c.Id, recTypeDocuSign, null);
        string templateName = 'ENRP Consent to Negotiate';
    

        CDocuSign_Template__c template = new CDocuSign_Template__c();
        template.Active__c = true;
        template.Description__c = 'blah';
        template.Page_Count__c = 1;
        template.Template_ID__c = 'blahblah';
        template.Template_Name__c = templateName;
        insert template;
        template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];
    
        CDocuSign_Template_Recipient__c templateRecipient = new CDocuSign_Template_Recipient__c();
        templateRecipient.CDocuSign_Template__c = template.Id;
        templateRecipient.Recipient_ID__c = '1';
        templateRecipient.Recipient_Type__c = 'Signer';
        templateRecipient.Role_Name__c = 'Patient';
        templateRecipient.Template_Recipient_ID__c = 'blahblahblah';
        insert templateRecipient;
    
        CDocuSign_Template_Tab__c tab = new CDocuSign_Template_Tab__c();
        tab.Active__c = true;
        tab.CDocuSign_Template_Recipient__c = templateRecipient.Id;
        tab.Display_In_Overlay__c = true;
        tab.Display_Label__c = 'blahlbah';
        tab.Document_ID__c = 'blahlbah';
        tab.Editable__c = true;
        tab.Input_Type__c = 'text';
        tab.Max_Length__c = 100;
        tab.Order_Number__c = 1;
        tab.Page_Number__c = 1;
        tab.Preloaded__c = false;
        tab.Required__c = true;
        tab.Required_For_Send__c = true;
        tab.Tab_Group__c = 'TextTabs';
        tab.Tab_ID__c = '1234';
        tab.Tab_Label__c = 'blah';
        insert tab;
    
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Envelope_ID__c = 'blahlbhalbha';
        env.Envelope_Status__c = 'Created';
        env.CDocuSign_Template__c = template.Id;
        env.Case__c = c.Id;
        insert env;
    
        env = V2_DocuSignController.GetEnvelopeByID(env.Id);
    
        t.CDocuSign_Envelope__r = env;
        t.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        t.Status = 'Pending';
        TaskOverlayController.CreateTask(t);
        t = TaskOverlayController.GetTask(t.Id);
    
        List<CDocuSign_Envelope_Recipient__c> recipientList = V2_DocuSignController.InitRecipientsForSFTemplateName(c.Id, templateName);
        recipientList[0].Contact__c = con.Id;
        recipientList[0].Authentication_Phone_Number__c = '6127088889';
        recipientList[0].Use_Phone__c = true;
        recipientList[0].Email_Address__c = con.Email;
        recipientList[0].First_Name__c = con.FirstName;
        recipientList[0].Last_Name__c = con.LastName;
        recipientList[0].CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        V2_DocuSignController.CreateSPITRecordForDocusignCreateDraft(t.Id, c.Id, templateName, recipientList);
        V2_DocuSignController.CreateSPITRecordForDocusignDiscardDraft('1234', '56789');
        V2_DocuSignController.CreateSPITRecordForDocusignGetDocuments('dfkjsdfkjsdf');
        V2_DocuSignController.CreateSPITRecordForDocusignSendDraft('kdfjsldkfj', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
        V2_DocuSignController.CreateSPITRecordForDocusignVoid('sfdlkjdf', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
    	//Test.stopTest();    
    
        List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
        List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
    
        if (tabs.size() > 0) {
          for (CDocuSign_Template_Tab__c itm : tabs) {
            CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
            toAdd.CDocuSign_Template_Tab__c = itm.Id;
            toAdd.CDocuSign_Template_Tab__r = itm;
            toAdd.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
            toAdd.Value__c = 'test';
            eTabs.Add(toAdd);
          }
        }
    
        insert eTabs;
        Test.startTest();
        Integration_Task__c it = V2_DocuSignController.CreateSPITRecordForDocusignUpdate('sfdlkjdf', t.CDocuSign_Envelope__r.Id, eTabs, 'sldfjlskdjf');
        V2_DocuSignController.SetAndGetEnvelopeReadyToSend(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.GetContentViewerData(c.Id);
        V2_DocuSignController.GetSPITRecord(it.Id);
        V2_DocuSignController.GetExternalConfigs();
        V2_DocuSignController.GetTaskRecordTypes();
        V2_DocuSignController.GetEnvelopeTabsByEnvelopeID(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.InitTabsForTemplateName(c.Id, templateName);
        V2_DocuSignController.WriteAndReturnRecipients(t.CDocuSign_Envelope__r.Id, recipientList);
        V2_DocuSignController.GetRecipientsForSFEnvelopeID(t.CDocuSign_Envelope__r.Id);
    
        CDocuSign_Envelope_Artifact__c artifact = new CDocuSign_Envelope_Artifact__c();
        artifact.Downloaded__c = false;
        artifact.Artifact_Type__c = 'Envelope Sent';
        artifact.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        artifact.File_Extension__c = 'PDF';
        artifact.File_Name__c = 'test';
        insert artifact;
    
        V2_DocuSignController.GetEnvelopeArtifactsByCaseID(c.Id);
        V2_DocuSignController.GetEnvelopeArtifactByArtifactID(artifact.Id);
        V2_DocuSignController.GetEnvelopeArtifactByEnvelopeIDAndArtifactType(t.CDocuSign_Envelope__r.Id, 'Envelope Sent');
        c.Origin = 'Patient';
        c.Digital__c = 'Yes';
        update c;
        env.Envelope_Status__c = 'Sent';
        update env;

        env.Envelope_Status__c = 'Completed';
        update env;
    
        t.Status = 'Request Queued';        
        update t;
        V2_TasksController.UpdateTask(t, true);


        V2_DocuSignController.DiscardDraftPostCleanUp(t);
        V2_DocuSignController.GenerateAccessToken(5, false);
        System.AssertNotEquals(null, t);
        Test.StopTest();
      }
    
      static testMethod void templateMNRPWelcome() {
        ORS__c o = new ORS__c();
        o.Name = '123456';
        o.Policy__c = '2929234';
        o.Member_Number__c = '3939393933';
        insert o;
    
        ORS_ICNs__c icns = new ORS_ICNs__c();
        icns.ORS__c = o.Id;
        icns.ICN__c = '123849393';
        insert icns;
    
        Employer_Group__c eg = new Employer_Group__c();
        eg.Name = 'kdkdjfjfdkdf';
        insert eg;
    
        Enrolee__c en = new Enrolee__c();
        en.Name = 'd9394893843';
        en.Employer_Group_ID__c = eg.Id;
        en.Address_Line_1__c = '123 main';
        en.Address_Line_2__c = '';
        en.City__c = 'Saint Louis Park';
        en.State__c = 'MN';
        en.Zip__c = '55426';
        insert en;
    
        Contact con = new Contact();
        con.Email = 'John.Doe@mail.com';
        con.FirstName = 'John';
        con.LastName = 'Doe';
        con.Role__c = 'Unspecified';
        con.Enrolee__c = en.Id;
        insert con;
    
        Patient__c p = new Patient__c();
        p.Name = '19394939393';
        p.Enrolee_ID__c = en.Id;
        p.Relationship__c = 'SP - Spouse';
        p.First_Name__c = 'John';
        p.Last_Name__c = 'Doe';
        p.Date_of_Birth__c = Date.today();
        insert p;
    
        Provider_Group__c prg = new Provider_Group__c();
        prg.Provider_Group_Name__c = 'blahblah';
        insert prg;
    
        Provider__c pr = new Provider__c();
        pr.Name = '29494394955';
        pr.Provider_Group__c = prg.Id;
        insert pr;
    
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'New';
        c.Milestone__c = 'Assigned';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
    
        insert c;
    
        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;
    
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'GET SALESFORCE FILE BYTES ENDPOINT';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'GET SALESFORCE PATIENT ADDR ENDPOINT';
        c4.ConfigValue__c = 'http://localhost.com';
        insert c4;
    
        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'GET DOCUSIGN ARTIFACT ENDPOINT';
        c5.ConfigValue__c = 'http://localhost.com';
        insert c5;
    
        RecordType recTypeDocuSign = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'DocuSign' LIMIT 1];
        System.AssertNotEquals(null, recTypeDocuSign);
    
        Task t = TaskOverlayController.InitTask(c.Id, recTypeDocuSign, null);
        System.AssertNotEquals(null, t);
    
        string templateName = 'MNRP Welcome Package';
    
        CDocuSign_Template__c template = new CDocuSign_Template__c();
        template.Active__c = true;
        template.Description__c = 'blah';
        template.Page_Count__c = 1;
        template.Template_ID__c = 'blahblah';
        template.Template_Name__c = templateName;
        insert template;
        template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];
    
        CDocuSign_Template_Recipient__c templateRecipient = new CDocuSign_Template_Recipient__c();
        templateRecipient.CDocuSign_Template__c = template.Id;
        templateRecipient.Recipient_ID__c = '1';
        templateRecipient.Recipient_Type__c = 'Signer';
        templateRecipient.Role_Name__c = 'Patient';
        templateRecipient.Template_Recipient_ID__c = 'blahblahblah';
        insert templateRecipient;
    
        CDocuSign_Template_Tab__c tab = new CDocuSign_Template_Tab__c();
        tab.Active__c = true;
        tab.CDocuSign_Template_Recipient__c = templateRecipient.Id;
        tab.Display_In_Overlay__c = true;
        tab.Display_Label__c = 'blahlbah';
        tab.Document_ID__c = 'blahlbah';
        tab.Editable__c = true;
        tab.Input_Type__c = 'text';
        tab.Max_Length__c = 100;
        tab.Order_Number__c = 1;
        tab.Page_Number__c = 1;
        tab.Preloaded__c = false;
        tab.Required__c = true;
        tab.Required_For_Send__c = true;
        tab.Tab_Group__c = 'TextTabs';
        tab.Tab_ID__c = '1234';
        tab.Tab_Label__c = 'blah';
        insert tab;
    
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Envelope_ID__c = 'blahlbhalbha';
        env.Envelope_Status__c = 'Created';
        env.CDocuSign_Template__c = template.Id;
        env.Case__c = c.Id;
        insert env;
    
        env = V2_DocuSignController.GetEnvelopeByID(env.Id);
    
        t.CDocuSign_Envelope__r = env;
        t.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        t.Status = 'Pending';
        TaskOverlayController.CreateTask(t);
        t = TaskOverlayController.GetTask(t.Id);
    
        List<CDocuSign_Envelope_Recipient__c> recipientList = V2_DocuSignController.InitRecipientsForSFTemplateName(c.Id, templateName);
        recipientList[0].Contact__c = con.Id;
        recipientList[0].Authentication_Phone_Number__c = '6127088889';
        recipientList[0].Use_Phone__c = true;
        recipientList[0].Email_Address__c = con.Email;
        recipientList[0].First_Name__c = con.FirstName;
        recipientList[0].Last_Name__c = con.LastName;
        recipientList[0].CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        V2_DocuSignController.CreateSPITRecordForDocusignCreateDraft(t.Id, c.Id, templateName, recipientList);
        V2_DocuSignController.CreateSPITRecordForDocusignDiscardDraft('1234', '56789');
        V2_DocuSignController.CreateSPITRecordForDocusignGetDocuments('dfkjsdfkjsdf');
        V2_DocuSignController.CreateSPITRecordForDocusignSendDraft('kdfjsldkfj', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
        V2_DocuSignController.CreateSPITRecordForDocusignVoid('sfdlkjdf', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
    
        List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
        List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
    
        if (tabs.size() > 0) {
          for (CDocuSign_Template_Tab__c itm : tabs) {
            CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
            toAdd.CDocuSign_Template_Tab__c = itm.Id;
            toAdd.CDocuSign_Template_Tab__r = itm;
            toAdd.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
            toAdd.Value__c = 'test';
            eTabs.Add(toAdd);
          }
        }
    
        insert eTabs;
    
        Integration_Task__c it = V2_DocuSignController.CreateSPITRecordForDocusignUpdate('sfdlkjdf', t.CDocuSign_Envelope__r.Id, eTabs, 'sldfjlskdjf');
        V2_DocuSignController.SetAndGetEnvelopeReadyToSend(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.GetContentViewerData(c.Id);
        V2_DocuSignController.GetSPITRecord(it.Id);
        V2_DocuSignController.GetExternalConfigs();
        V2_DocuSignController.GetTaskRecordTypes();
        V2_DocuSignController.GetEnvelopeTabsByEnvelopeID(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.InitTabsForTemplateName(c.Id, templateName);
        V2_DocuSignController.WriteAndReturnRecipients(t.CDocuSign_Envelope__r.Id, recipientList);
        V2_DocuSignController.GetRecipientsForSFEnvelopeID(t.CDocuSign_Envelope__r.Id);
    
        CDocuSign_Envelope_Artifact__c artifact = new CDocuSign_Envelope_Artifact__c();
        artifact.Downloaded__c = false;
        artifact.Artifact_Type__c = 'Envelope Sent';
        artifact.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        artifact.File_Extension__c = 'PDF';
        artifact.File_Name__c = 'test';
        insert artifact;
    
        V2_DocuSignController.GetEnvelopeArtifactsByCaseID(c.Id);
        V2_DocuSignController.GetEnvelopeArtifactByArtifactID(artifact.Id);
        V2_DocuSignController.GetEnvelopeArtifactByEnvelopeIDAndArtifactType(t.CDocuSign_Envelope__r.Id, 'Envelope Sent');
        env.Envelope_Status__c = 'Completed';
        update env;
    
        V2_DocuSignController.DiscardDraftPostCleanUp(t);
        V2_DocuSignController.GenerateAccessToken(5, false);
        System.AssertNotEquals(null, t);
      }
    
      static testMethod void templateHIPAA() {
        ORS__c o = new ORS__c();
        o.Name = '123456';
        o.Policy__c = '2929234';
        o.Member_Number__c = '3939393933';
        insert o;
    
        ORS_ICNs__c icns = new ORS_ICNs__c();
        icns.ORS__c = o.Id;
        icns.ICN__c = '123849393';
        insert icns;
    
        Employer_Group__c eg = new Employer_Group__c();
        eg.Name = 'kdkdjfjfdkdf';
        insert eg;
    
        Enrolee__c en = new Enrolee__c();
        en.Name = 'd9394893843';
        en.Employer_Group_ID__c = eg.Id;
        en.Address_Line_1__c = '123 main';
        en.Address_Line_2__c = '';
        en.City__c = 'Saint Louis Park';
        en.State__c = 'MN';
        en.Zip__c = '55426';
        insert en;
    
        Contact con = new Contact();
        con.Email = 'John.Doe@mail.com';
        con.FirstName = 'John';
        con.LastName = 'Doe';
        con.Role__c = 'Unspecified';
        con.Enrolee__c = en.Id;
        insert con;
    
        Patient__c p = new Patient__c();
        p.Name = '19394939393';
        p.Enrolee_ID__c = en.Id;
        p.Relationship__c = 'SP - Spouse';
        p.First_Name__c = 'John';
        p.Last_Name__c = 'Doe';
        p.Date_of_Birth__c = Date.today();
        insert p;
    
        Provider_Group__c prg = new Provider_Group__c();
        prg.Provider_Group_Name__c = 'blahblah';
        insert prg;
    
        Provider__c pr = new Provider__c();
        pr.Name = '29494394955';
        pr.Provider_Group__c = prg.Id;
        insert pr;
    
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'New';
        c.Milestone__c = 'Assigned';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
    
        insert c;
    
        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;
    
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'GET SALESFORCE FILE BYTES ENDPOINT';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'GET SALESFORCE PATIENT ADDR ENDPOINT';
        c4.ConfigValue__c = 'http://localhost.com';
        insert c4;
    
        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'GET DOCUSIGN ARTIFACT ENDPOINT';
        c5.ConfigValue__c = 'http://localhost.com';
        insert c5;
    
        RecordType recTypeDocuSign = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'DocuSign' LIMIT 1];
    
        Task t = TaskOverlayController.InitTask(c.Id, recTypeDocuSign, null);
    
        string templateName = 'HIPAA Authorization';
    
        CDocuSign_Template__c template = new CDocuSign_Template__c();
        template.Active__c = true;
        template.Description__c = 'blah';
        template.Page_Count__c = 1;
        template.Template_ID__c = 'blahblah';
        template.Template_Name__c = templateName;
        insert template;
        template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];
    
        CDocuSign_Template_Recipient__c templateRecipient = new CDocuSign_Template_Recipient__c();
        templateRecipient.CDocuSign_Template__c = template.Id;
        templateRecipient.Recipient_ID__c = '1';
        templateRecipient.Recipient_Type__c = 'Signer';
        templateRecipient.Role_Name__c = 'Patient';
        templateRecipient.Template_Recipient_ID__c = 'blahblahblah';
        insert templateRecipient;
    
        CDocuSign_Template_Tab__c tab = new CDocuSign_Template_Tab__c();
        tab.Active__c = true;
        tab.CDocuSign_Template_Recipient__c = templateRecipient.Id;
        tab.Display_In_Overlay__c = true;
        tab.Display_Label__c = 'blahlbah';
        tab.Document_ID__c = 'blahlbah';
        tab.Editable__c = true;
        tab.Input_Type__c = 'text';
        tab.Max_Length__c = 100;
        tab.Order_Number__c = 1;
        tab.Page_Number__c = 1;
        tab.Preloaded__c = false;
        tab.Required__c = true;
        tab.Required_For_Send__c = true;
        tab.Tab_Group__c = 'TextTabs';
        tab.Tab_ID__c = '1234';
        tab.Tab_Label__c = 'blah';
        insert tab;
    
        test.starttest();
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Envelope_ID__c = 'blahlbhalbha';
        env.Envelope_Status__c = 'Created';
        env.CDocuSign_Template__c = template.Id;
        env.Case__c = c.Id;
        insert env;
    
        env = V2_DocuSignController.GetEnvelopeByID(env.Id);
    
        t.CDocuSign_Envelope__r = env;
        t.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        t.Status = 'Pending';
        TaskOverlayController.CreateTask(t);
        t = TaskOverlayController.GetTask(t.Id);
    
        List<CDocuSign_Envelope_Recipient__c> recipientList = V2_DocuSignController.InitRecipientsForSFTemplateName(c.Id, templateName);
        recipientList[0].Contact__c = con.Id;
        recipientList[0].Authentication_Phone_Number__c = '6127088889';
        recipientList[0].Use_Phone__c = true;
        recipientList[0].Email_Address__c = con.Email;
        recipientList[0].First_Name__c = con.FirstName;
        recipientList[0].Last_Name__c = con.LastName;
        recipientList[0].CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        V2_DocuSignController.CreateSPITRecordForDocusignCreateDraft(t.Id, c.Id, templateName, recipientList);
        V2_DocuSignController.CreateSPITRecordForDocusignDiscardDraft('1234', '56789');
        V2_DocuSignController.CreateSPITRecordForDocusignGetDocuments('dfkjsdfkjsdf');
        V2_DocuSignController.CreateSPITRecordForDocusignSendDraft('kdfjsldkfj', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
        V2_DocuSignController.CreateSPITRecordForDocusignVoid('sfdlkjdf', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
    
        List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
        List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
    
        if (tabs.size() > 0) {
          for (CDocuSign_Template_Tab__c itm : tabs) {
            CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
            toAdd.CDocuSign_Template_Tab__c = itm.Id;
            toAdd.CDocuSign_Template_Tab__r = itm;
            toAdd.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
            toAdd.Value__c = 'test';
            eTabs.Add(toAdd);
          }
        }
    
        insert eTabs;
    
        Integration_Task__c it = V2_DocuSignController.CreateSPITRecordForDocusignUpdate('sfdlkjdf', t.CDocuSign_Envelope__r.Id, eTabs, 'sldfjlskdjf');
        V2_DocuSignController.SetAndGetEnvelopeReadyToSend(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.GetContentViewerData(c.Id);
        V2_DocuSignController.GetSPITRecord(it.Id);
        V2_DocuSignController.GetExternalConfigs();
        V2_DocuSignController.GetTaskRecordTypes();
        V2_DocuSignController.GetEnvelopeTabsByEnvelopeID(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.InitTabsForTemplateName(c.Id, templateName);
        V2_DocuSignController.WriteAndReturnRecipients(t.CDocuSign_Envelope__r.Id, recipientList);
        V2_DocuSignController.GetRecipientsForSFEnvelopeID(t.CDocuSign_Envelope__r.Id);
    
        CDocuSign_Envelope_Artifact__c artifact = new CDocuSign_Envelope_Artifact__c();
        artifact.Downloaded__c = false;
        artifact.Artifact_Type__c = 'Envelope Sent';
        artifact.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        artifact.File_Extension__c = 'PDF';
        artifact.File_Name__c = 'test';
        insert artifact;
    
        env.Envelope_Status__c = 'Completed';
        update env;
    
        V2_DocuSignController.GetEnvelopeArtifactsByCaseID(c.Id);
        V2_DocuSignController.GetEnvelopeArtifactByArtifactID(artifact.Id);
        V2_DocuSignController.GetEnvelopeArtifactByEnvelopeIDAndArtifactType(t.CDocuSign_Envelope__r.Id, 'Envelope Sent');
    
        V2_DocuSignController.DiscardDraftPostCleanUp(t);
        V2_DocuSignController.GenerateAccessToken(5, false);
        System.AssertNotEquals(null, t);
        test.stoptest();
      }
    
      static testMethod void taskOverlayRelated() {
        ORS__c o = new ORS__c();
        o.Name = '123456';
        o.Policy__c = '2929234';
        o.Member_Number__c = '3939393933';
        insert o;
    
        ORS_ICNs__c icns = new ORS_ICNs__c();
        icns.ORS__c = o.Id;
        icns.ICN__c = '123849393';
        insert icns;
    
        Employer_Group__c eg = new Employer_Group__c();
        eg.Name = 'kdkdjfjfdkdf';
        insert eg;
    
        Enrolee__c en = new Enrolee__c();
        en.Name = 'd9394893843';
        en.Employer_Group_ID__c = eg.Id;
        en.Address_Line_1__c = '123 main';
        en.Address_Line_2__c = '';
        en.City__c = 'Saint Louis Park';
        en.State__c = 'MN';
        en.Zip__c = '55426';
        insert en;
    
        Contact con = new Contact();
        con.Email = 'John.Doe@mail.com';
        con.FirstName = 'John';
        con.LastName = 'Doe';
        con.Role__c = 'Unspecified';
        con.Enrolee__c = en.Id;
        insert con;
    
        Patient__c p = new Patient__c();
        p.Name = '19394939393';
        p.Enrolee_ID__c = en.Id;
        p.Relationship__c = 'SP - Spouse';
        p.First_Name__c = 'John';
        p.Last_Name__c = 'Doe';
        p.Date_of_Birth__c = Date.today();
        insert p;
    
        Provider_Group__c prg = new Provider_Group__c();
        prg.Provider_Group_Name__c = 'blahblah';
        insert prg;
    
        Provider__c pr = new Provider__c();
        pr.Name = '29494394955';
        pr.Provider_Group__c = prg.Id;
        insert pr;
    
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'New';
        c.Milestone__c = 'Assigned';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
    
        insert c;
    
        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;
    
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'GET SALESFORCE FILE BYTES ENDPOINT';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'GET SALESFORCE PATIENT ADDR ENDPOINT';
        c4.ConfigValue__c = 'http://localhost.com';
        insert c4;
    
        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'GET DOCUSIGN ARTIFACT ENDPOINT';
        c5.ConfigValue__c = 'http://localhost.com';
        insert c5;
    
        RecordType recTypeDocuSign = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'DocuSign' LIMIT 1];
        
    
        test.starttest();
        Task t = TaskOverlayController.InitTask(c.Id, recTypeDocuSign, null);
        System.AssertNotEquals(null, t);
    
        string templateName = 'HIPAA Authorization';
    
        CDocuSign_Template__c template = new CDocuSign_Template__c();
        template.Active__c = true;
        template.Description__c = 'blah';
        template.Page_Count__c = 1;
        template.Template_ID__c = 'blahblah';
        template.Template_Name__c = templateName;
        insert template;
        template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];
    
        CDocuSign_Template_Recipient__c templateRecipient = new CDocuSign_Template_Recipient__c();
        templateRecipient.CDocuSign_Template__c = template.Id;
        templateRecipient.Recipient_ID__c = '1';
        templateRecipient.Recipient_Type__c = 'Signer';
        templateRecipient.Role_Name__c = 'Patient';
        templateRecipient.Template_Recipient_ID__c = 'blahblahblah';
        insert templateRecipient;
    
        CDocuSign_Template_Tab__c tab = new CDocuSign_Template_Tab__c();
        tab.Active__c = true;
        tab.CDocuSign_Template_Recipient__c = templateRecipient.Id;
        tab.Display_In_Overlay__c = true;
        tab.Display_Label__c = 'blahlbah';
        tab.Document_ID__c = 'blahlbah';
        tab.Editable__c = true;
        tab.Input_Type__c = 'text';
        tab.Max_Length__c = 100;
        tab.Order_Number__c = 1;
        tab.Page_Number__c = 1;
        tab.Preloaded__c = false;
        tab.Required__c = true;
        tab.Required_For_Send__c = true;
        tab.Tab_Group__c = 'TextTabs';
        tab.Tab_ID__c = '1234';
        tab.Tab_Label__c = 'blah';
        insert tab;
    
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Envelope_ID__c = 'blahlbhalbha';
        env.Envelope_Status__c = 'Created';
        env.CDocuSign_Template__c = template.Id;
        env.Case__c = c.Id;
        insert env;
    
        env = V2_DocuSignController.GetEnvelopeByID(env.Id);
    
        t.CDocuSign_Envelope__r = env;
        t.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        t.Status = 'Pending';
        TaskOverlayController.CreateTask(t);
        t = TaskOverlayController.GetTask(t.Id);
    
        List<CDocuSign_Envelope_Recipient__c> recipientList = V2_DocuSignController.InitRecipientsForSFTemplateName(c.Id, templateName);
        recipientList[0].Contact__c = con.Id;
        recipientList[0].Authentication_Phone_Number__c = '6127088889';
        recipientList[0].Use_Phone__c = true;
        recipientList[0].Email_Address__c = con.Email;
        recipientList[0].First_Name__c = con.FirstName;
        recipientList[0].Last_Name__c = con.LastName;
        recipientList[0].CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
    
        V2_DocuSignController.CreateSPITRecordForDocusignCreateDraft(t.Id, c.Id, templateName, recipientList);
        V2_DocuSignController.CreateSPITRecordForDocusignDiscardDraft('1234', '56789');
        V2_DocuSignController.CreateSPITRecordForDocusignGetDocuments('dfkjsdfkjsdf');
        V2_DocuSignController.CreateSPITRecordForDocusignSendDraft('kdfjsldkfj', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
        V2_DocuSignController.CreateSPITRecordForDocusignVoid('sfdlkjdf', t.CDocuSign_Envelope__r.Id, t.Id, 'sldfjlskdjf');
    
        List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
        List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
    
        if (tabs.size() > 0) {
          for (CDocuSign_Template_Tab__c itm : tabs) {
            CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
            toAdd.CDocuSign_Template_Tab__c = itm.Id;
            toAdd.CDocuSign_Template_Tab__r = itm;
            toAdd.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
            toAdd.Value__c = 'test';
            eTabs.Add(toAdd);
          }
        }
    
        insert eTabs;
    
        Integration_Task__c it = V2_DocuSignController.CreateSPITRecordForDocusignUpdate('sfdlkjdf', t.CDocuSign_Envelope__r.Id, eTabs, 'sldfjlskdjf');
        V2_DocuSignController.SetAndGetEnvelopeReadyToSend(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.GetContentViewerData(c.Id);
        V2_DocuSignController.GetSPITRecord(it.Id);
        V2_DocuSignController.GetExternalConfigs();
        V2_DocuSignController.GetTaskRecordTypes();
        V2_DocuSignController.GetEnvelopeTabsByEnvelopeID(t.CDocuSign_Envelope__r.Id);
        V2_DocuSignController.InitTabsForTemplateName(c.Id, templateName);
        V2_DocuSignController.WriteAndReturnRecipients(t.CDocuSign_Envelope__r.Id, recipientList);
        V2_DocuSignController.GetRecipientsForSFEnvelopeID(t.CDocuSign_Envelope__r.Id);
    
        CDocuSign_Envelope_Artifact__c artifact = new CDocuSign_Envelope_Artifact__c();
        artifact.Downloaded__c = false;
        artifact.Artifact_Type__c = 'Envelope Sent';
        artifact.CDocuSign_Envelope__c = t.CDocuSign_Envelope__r.Id;
        artifact.File_Extension__c = 'PDF';
        artifact.File_Name__c = 'test';
        insert artifact;
    
        env.Envelope_Status__c = 'Completed';
        update env;
    
        V2_DocuSignController.GetEnvelopeArtifactsByCaseID(c.Id);
        V2_DocuSignController.GetEnvelopeArtifactByArtifactID(artifact.Id);
        V2_DocuSignController.GetEnvelopeArtifactByEnvelopeIDAndArtifactType(t.CDocuSign_Envelope__r.Id, 'Envelope Sent');
    
        TaskOverlayController.GenerateGUID();
        TaskOverlayController.GetEnvelopeByID(t.CDocuSign_Envelope__r.Id);
        TaskOverlayController.SetAndGetEnvelopeReadyToSend(t.CDocuSign_Envelope__r.Id);
    
        V2_DocuSignController.DiscardDraftPostCleanUp(t);
        V2_DocuSignController.GenerateAccessToken(5, false);
        System.AssertNotEquals(null, t);
        test.stoptest();
      }

      
}
