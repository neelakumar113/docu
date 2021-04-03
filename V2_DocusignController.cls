public with sharing class V2_DocusignController {
    @AuraEnabled
    public static Integration_Task__c CreateSPITRecordForDocusignCreateDraft(String taskObjectId, Id caseID, string templateName, List<CDocuSign_Envelope_Recipient__c> recipients) {
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
      Case c = [SELECT ID, CaseNumber FROM Case WHERE Id = :caseID];
  
      String taskType = 'DOCUSIGN CREATE DRAFT';
      string PARM1;
      string PARM2;
      string PARM3;
      string PARM4;
      string PARM5;
      string PARM6;
      string PARM7;
      string PARM8;
      string PARM9;
      string PARM10;
      string PARMBIG1;
      string PARMBIG2;
  
      string RelatedTask;
  
      List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
      List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
  
      if (tabs.size() > 0) {
        for (CDocuSign_Template_Tab__c itm : tabs) {
          CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
          toAdd.CDocuSign_Template_Tab__r = itm;
          eTabs.Add(toAdd);
        }
      }
  
      eTabs = PrepopulateTabsForTemplate(caseID, templateName, eTabs);
      JSONGenerator gen = JSON.createGenerator(true);
  
      gen.writeStartObject();
      gen.writeFieldName('tabValues');
      gen.writeStartArray();
      for (CDocuSign_Envelope_Tab__c itm : eTabs) {
        itm.Value__c = SetTabValueToBlankIfEmpty(itm).Value__c;
  
        gen.writeStartObject();
        gen.writeStringField('tabLabel', itm.CDocuSign_Template_Tab__r.Tab_Label__c);
        gen.writeStringField('value', itm.Value__c);
        gen.writeStringField('CDocuSign_Template_Tab__c', itm.CDocuSign_Template_Tab__r.Id);
        gen.writeStringField('recipientId', itm.CDocuSign_Template_Tab__r.CDocuSign_Template_Recipient__r.Recipient_ID__c);
        gen.writeStringField('tabGroup', itm.CDocuSign_Template_Tab__r.Tab_Group__c);
        gen.writeEndObject();
      }
      gen.writeEndArray();
      gen.writeEndObject();
  
      JSONGenerator genRecip = JSON.createGenerator(true);
  
      system.debug('start recipients');
      genRecip.writeStartObject();
      genRecip.writeFieldName('recipients');
      genRecip.writeStartArray();
      for (CDocuSign_Envelope_Recipient__c itm : recipients) {
        if (string.isBlank(itm.Email_Address__c)) {
          itm.Email_Address__c = '';
        }
        if (string.isBlank(itm.First_Name__c)) {
          itm.First_Name__c = '';
        }
        if (string.isBlank(itm.Last_Name__c)) {
          itm.Last_Name__c = '';
        }
        if (string.isBlank(itm.Authentication_SMS_Number__c)) {
          itm.Authentication_SMS_Number__c = '';
        }
        if (string.isBlank(itm.Authentication_Access_Token__c)) {
          itm.Authentication_Access_Token__c = '';
        }
        if (string.isBlank(itm.Authentication_Phone_Number__c)) {
          itm.Authentication_Phone_Number__c = '';
        }
  
        genRecip.writeStartObject();
        genRecip.writeStringField('email', itm.Email_Address__c);
        genRecip.writeStringField('firstName', itm.First_Name__c);
        genRecip.writeStringField('lastName', itm.Last_Name__c);
        genRecip.writeStringField('sms', itm.Authentication_SMS_Number__c);
        genRecip.writeStringField('phone', itm.Authentication_Phone_Number__c);
        genRecip.writeStringField('token', itm.Authentication_Access_Token__c);
        genRecip.writeStringField('role', itm.Role__c);
        genRecip.writeStringField('useToken', string.valueOf(itm.Use_Access_Code_Auth__c));
        genRecip.writeStringField('useSMS', string.valueOf(itm.Use_SMS_Auth__c));
        genRecip.writeStringField('digitalSign', string.valueOf(itm.Use_Digital__c));
        genRecip.writeStringField('usePhone', string.valueOf(itm.Use_Phone__c));
        genRecip.writeStringField('recipientId', itm.CDocuSign_Template_Recipient__r.Recipient_ID__c);
        genRecip.writeStringField('contactId', itm.Contact__c);
        genRecip.writeStringField('recipientType', itm.CDocuSign_Template_Recipient__r.Recipient_Type__c);
        genRecip.writeStringField('CDocuSign_Template_Recipient__c', itm.CDocuSign_Template_Recipient__r.Id);

        if (itm.Is_Signing_Group__c == true)
        {
          genRecip.writeStringField('signingGroupId', itm.CDocuSign_Template_Recipient__r.Signing_Group_Id__c);
        }
  
        genRecip.writeEndObject();
      }
      genRecip.writeEndArray();
      genRecip.writeEndObject();
  
      CDocuSign_Template__c template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];
  
      PARM1 = template.Template_ID__c;
      PARM2 = template.Id;
      PARM3 = caseID;
      PARM5 = instanceName.ConfigValue__c;
      PARM6 = c.CaseNumber;
  
      try {
        if (!string.isBlank(taskObjectId)) {
          PARM4 = taskObjectId;
        }
      } catch (Exception ex) {
      }
  
      PARMBIG1 = gen.getAsString();
      PARMBIG2 = genRecip.getAsString();
  
      Integration_Task__c it = IntegrationTask.createIntegrationTask(taskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
  
      Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
      String encodedGUIDText = EncodingUtil.base64Encode(guidText);
      it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');
  
      return it;
    }

    @AuraEnabled
    public static Integration_Task__c CreateSPITRecordForDocusignCreateSmartDocumentDraft(String taskObjectId, Id caseID, string templateName, List<CDocuSign_Envelope_Recipient__c> recipients, string sdFileId, boolean isTest) {
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
      Case c = [SELECT ID, CaseNumber FROM Case WHERE Id = :caseID];

      String taskType = 'DOCUSIGN CREATE SMART DOC DRAFT';
      string PARM1;
      string PARM2;
      string PARM3;
      string PARM4;
      string PARM5;
      string PARM6;
      string PARM7;
      string PARM8;
      string PARM9 = 'Liaison';
      string PARM10;
      string PARMBIG1;
      string PARMBIG2;
  
      string RelatedTask;
  
      List<CDocuSign_Template_Tab__c> tabs = [SELECT Auto_Place_Required__c, Auto_Place_Width__c, Anchor_String__c, Anchor_X_Offset__c, Anchor_Y_Offset__c, Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
  
      JSONGenerator gen = JSON.createGenerator(true);
  
      gen.writeStartObject();
      gen.writeFieldName('tabValues');
      gen.writeStartArray();
      for (CDocuSign_Template_Tab__c itm : tabs) {
        gen.writeStartObject();
        if (isTest == false)
        {
          gen.writeStringField('anchorString', itm.Anchor_String__c);
          gen.writeStringField('AnchorYOffset', string.valueof(itm.Anchor_X_Offset__c));
          gen.writeStringField('AnchorXOffset', string.valueof(itm.Anchor_Y_Offset__c));
          gen.writeStringField('anchorUnits', 'pixels');
          gen.writeStringField('autoPlaceRequired', (itm.Auto_Place_Required__c == true? 'true' : 'false'));
          gen.writeStringField('autoPlaceWidth', string.valueof(itm.Auto_Place_Width__c));
          gen.writeStringField('tabLabel', itm.Tab_Label__c);
          
          gen.writeStringField('CDocuSign_Template_Tab__c', itm.Id);
          gen.writeStringField('recipientId', itm.CDocuSign_Template_Recipient__r.Recipient_ID__c);
          gen.writeStringField('tabGroup', itm.Tab_Group__c);
        }
        gen.writeEndObject();
      }
      gen.writeEndArray();
      gen.writeEndObject();
  
      JSONGenerator genRecip = JSON.createGenerator(true);
  
      system.debug('start recipients');
      genRecip.writeStartObject();
      genRecip.writeFieldName('recipients');
      genRecip.writeStartArray();
      for (CDocuSign_Envelope_Recipient__c itm : recipients) {
        if (string.isBlank(itm.Email_Address__c)) {
          itm.Email_Address__c = '';
        }
        if (string.isBlank(itm.First_Name__c)) {
          itm.First_Name__c = '';
        }
        if (string.isBlank(itm.Last_Name__c)) {
          itm.Last_Name__c = '';
        }
        if (string.isBlank(itm.Authentication_SMS_Number__c)) {
          itm.Authentication_SMS_Number__c = '';
        }
        if (string.isBlank(itm.Authentication_Access_Token__c)) {
          itm.Authentication_Access_Token__c = '';
        }
        if (string.isBlank(itm.Authentication_Phone_Number__c)) {
          itm.Authentication_Phone_Number__c = '';
        }
  
        genRecip.writeStartObject();
        genRecip.writeStringField('email', itm.Email_Address__c);
        genRecip.writeStringField('firstName', itm.First_Name__c);
        genRecip.writeStringField('lastName', itm.Last_Name__c);
        genRecip.writeStringField('sms', itm.Authentication_SMS_Number__c);
        genRecip.writeStringField('phone', itm.Authentication_Phone_Number__c);
        genRecip.writeStringField('token', itm.Authentication_Access_Token__c);
        genRecip.writeStringField('role', itm.Role__c);

        if (itm.Role__c == 'Naviguard Representative')
        {
          genRecip.writeStringField('emailSubject', 'Naviguard Written Agreement - Signature Required');           
          if (isTest == false)
          {
            //genRecip.writeStringField('emailBody', SmartDocumentController.GenerateCoverLetterForDocuSignNaviRecipient_WrittenAgreement(caseID, itm.First_Name__c + ' ' + itm.Last_Name__c, false));
            genRecip.writeStringField('emailBody', SmartDocumentController.GenerateCoverLetterForDocuSignNaviRecipient_WrittenAgreement(caseID, 'Naviguard Representative', false));
          }
        }
        else {
          genRecip.writeStringField('emailSubject', 'Naviguard Written Agreement - Signature Required');           
          if (isTest == false)
          {
            genRecip.writeStringField('emailBody', SmartDocumentController.GenerateCoverLetterForCase(caseID, 'DocuSign', false));
          }
        }

        genRecip.writeStringField('useToken', string.valueOf(itm.Use_Access_Code_Auth__c));
        genRecip.writeStringField('useSMS', string.valueOf(itm.Use_SMS_Auth__c));
        genRecip.writeStringField('digitalSign', string.valueOf(itm.Use_Digital__c));
        genRecip.writeStringField('usePhone', string.valueOf(itm.Use_Phone__c));
        genRecip.writeStringField('recipientId', itm.CDocuSign_Template_Recipient__r.Recipient_ID__c);        
        genRecip.writeStringField('recipientType', itm.CDocuSign_Template_Recipient__r.Recipient_Type__c);
        genRecip.writeStringField('CDocuSign_Template_Recipient__c', itm.CDocuSign_Template_Recipient__r.Id);

        if (itm.Is_Signing_Group__c == true)
        {
          genRecip.writeStringField('signingGroupId', itm.Signing_Group_Id__c);
        }        
        else {
          genRecip.writeStringField('contactId', itm.Contact__c);
        }
  
        genRecip.writeEndObject();
      }
      genRecip.writeEndArray();
      genRecip.writeEndObject();
  
      CDocuSign_Template__c template = [SELECT Active__c, CreatedById, CreatedDate, Description__c, Id, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, OwnerId, Page_Count__c, SystemModstamp, Template_ID__c, Template_Name__c FROM CDocuSign_Template__c WHERE Template_Name__c = :templateName LIMIT 1];
  
      SD_File__c sdFile = SmartDocumentController.getSDFile(sdFileId);

      PARM1 = V2_Utility.Encrypt(sdFile.Case_File__c,true);
      PARM2 = template.Id;
      PARM3 = caseID;
      PARM5 = instanceName.ConfigValue__c;
      PARM6 = c.CaseNumber;
      PARM7 = 'Naviguard Written Agreement - Signature Required';
  
      try {
        if (!string.isBlank(taskObjectId)) {
          PARM4 = taskObjectId;
        }
      } catch (Exception ex) {
      }
  
      PARMBIG1 = gen.getAsString();
      PARMBIG2 = genRecip.getAsString();
  
      Integration_Task__c it = IntegrationTask.createIntegrationTask(taskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
  
      Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
      String encodedGUIDText = EncodingUtil.base64Encode(guidText);
      it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');
  
      return it;
    }
    
    @AuraEnabled
    public static Integration_Task__c CreateSPITRecordForDocusignDiscardDraft(string envelopeID, string fileName) {
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  
      String taskType = 'DOCUSIGN DISCARD DRAFT';
      string PARM1 = envelopeID;
      string PARM2 = instanceName.ConfigValue__c;
      string PARM3 = fileName;
      string PARM4;
      string PARM5;
      string PARM6;
      string PARM7;
      string PARM8;
      string PARM9;
      string PARM10;
      string PARMBIG1;
      string PARMBIG2;
  
      string RelatedTask;
  
      Integration_Task__c it = IntegrationTask.createIntegrationTask(taskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
  
      Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
      String encodedGUIDText = EncodingUtil.base64Encode(guidText);
      it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');
  
      return it;
    }
  
    @AuraEnabled
    public static Integration_Task__c CreateSPITRecordForDocusignGetDocuments(string artifactID) {
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  
      String taskType = 'DOCUSIGN GET DOCUMENTS';
      string PARM1 = artifactID;
      string PARM2 = instanceName.ConfigValue__c;
      string PARM3;
      string PARM4;
      string PARM5;
      string PARM6;
      string PARM7;
      string PARM8;
      string PARM9;
      string PARM10;
      string PARMBIG1;
      string PARMBIG2;
  
      string RelatedTask;
  
      Integration_Task__c it = IntegrationTask.createIntegrationTask(taskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
  
      Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
      String encodedGUIDText = EncodingUtil.base64Encode(guidText);
      it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');
  
      return it;
    }
  
    @AuraEnabled
    public static Integration_Task__c CreateSPITRecordForDocusignSendDraft(string envelopeID, Id sfEnvelopeID, Id taskID, string fileName) {
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  
      String taskType = 'DOCUSIGN SEND';
      string PARM1 = envelopeID;
      string PARM2 = sfEnvelopeID;
      string PARM3 = taskID;
      string PARM4 = instanceName.ConfigValue__c;
      string PARM5 = fileName;
      string PARM6;
      string PARM7;
      string PARM8;
      string PARM9;
      string PARM10;
      string PARMBIG1;
      string PARMBIG2;
  
      string RelatedTask = taskID;
  
      Integration_Task__c it = IntegrationTask.createIntegrationTask(taskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
  
      Task task = new Task();
      task.Integration_Task__c = it.Id;
      task.Id = taskID;
      update task;
      task.Integration_Task__r = it;
  
      Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
      String encodedGUIDText = EncodingUtil.base64Encode(guidText);
      it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');
  
      return it;
    }
  
    @AuraEnabled
    public static Integration_Task__c CreateSPITRecordForDocusignVoid(string envelopeID, Id sfEnvelopeID, Id taskID, string fileName) {
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  
      String taskType = 'DOCUSIGN VOID';
      string PARM1 = envelopeID;
      string PARM2 = sfEnvelopeID;
      string PARM3 = taskID;
      string PARM4 = instanceName.ConfigValue__c;
      string PARM5 = fileName;
      string PARM6 = 'Voided by Naviguard';
      string PARM7;
      string PARM8;
      string PARM9;
      string PARM10;
      string PARMBIG1;
      string PARMBIG2;
  
      string RelatedTask = taskID;
  
      Integration_Task__c it = IntegrationTask.createIntegrationTask(taskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
  
      Task task = new Task();
      task.Integration_Task__c = it.Id;
      task.Id = taskID;
      update task;
      task.Integration_Task__r = it;
  
      Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
      String encodedGUIDText = EncodingUtil.base64Encode(guidText);
      it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');
  
      return it;
    }
  
    @AuraEnabled
    public static Boolean SetAndGetEnvelopeReadyToSend(ID sfEnvelopeID) {
      List<CDocuSign_Envelope_Tab__c> eTabs = GetEnvelopeTabsByEnvelopeID(sfEnvelopeID);
      Boolean isReady = true;
  
      for (CDocuSign_Envelope_Tab__c t : eTabs) {
        if (t.CDocuSign_Template_Tab__r.Required_For_Send__c == true) {
          if (string.isBlank(t.Value__c)) {
            isReady = false;
            break;
          }
        }
      }
  
      CDocuSign_Envelope__c e = [SELECT Id, Ready_to_Send__c FROM CDocuSign_Envelope__c WHERE Id = :sfEnvelopeID];
      e.Ready_to_Send__c = isReady;
      update e;
  
      return isReady;
    }
  
    @AuraEnabled
    public static List<CDocuSignRelatedContent__c> GetContentViewerData(Id caseID) {
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
      External_Configurations__c endpoint = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'GET SALESFORCE FILE BYTES ENDPOINT' LIMIT 1];
      External_Configurations__c endpointMailingAddress = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'GET SALESFORCE PATIENT ADDR ENDPOINT' LIMIT 1];
      Case cse = [SELECT Id, Patient_ID__c FROM Case WHERE Id = :caseID];
  
      // List<ContentDocumentLink> fileUploads = GetContentDocumentLinksForCaseID(caseID);
      List<Case_File__c> fileUploadsWC = WCFileUploadController.getCaseFiles(caseID);
      List<CDocuSignRelatedContent__c> toReturn = new List<CDocuSignRelatedContent__c>();
  
      Integer orderNum = 1;
  
      CDocuSignRelatedContent__c docusign = new CDocuSignRelatedContent__c();
      docusign.Display_Name__c = 'DocuSign';
      docusign.File_Type__c = 'DocuSign';
      docusign.URL__c = 'about:blank';
      docusign.Order_Num__c = 0;
      toReturn.Add(docusign);
  
      CDocuSignRelatedContent__c mailingAddress = new CDocuSignRelatedContent__c();
      mailingAddress.Display_Name__c = 'Patient Mailing Address';
      mailingAddress.File_Type__c = 'Patient Mailing Address';
      mailingAddress.URL__c = endpointMailingAddress.ConfigValue__c + '?token1=' + encodingUtil.URLEncode(EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(cse.Patient_ID__c))), 'UTF-8') + '#toolbar=0';
      mailingAddress.Order_Num__c = 1;
      toReturn.Add(mailingAddress);
  
      // for (ContentDocumentLink c : fileUploads) {
      //   orderNum += 1;
      //   CDocuSignRelatedContent__c toAdd = new CDocuSignRelatedContent__c();
      //   toAdd.Display_Name__c = c.ContentDocument.Title;
      //   toAdd.URL__c = endpoint.ConfigValue__c + '?token1=' + encodingUtil.URLEncode(EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(c.ContentDocument.LatestPublishedVersionId))), 'UTF-8') + '#toolbar=0';
      //   toAdd.Order_Num__c = orderNum;
      //   toAdd.File_Type__c = 'File Upload';
      //   toReturn.Add(toAdd);
      // }
  
      for (Case_File__c c : fileUploadsWC) {
        orderNum += 1;
        CDocuSignRelatedContent__c toAdd = new CDocuSignRelatedContent__c();
        toAdd.Display_Name__c = c.File_Name__c;
        toAdd.URL__c = c.File_Link__c;
        toAdd.Order_Num__c = orderNum;
        toAdd.File_Type__c = 'File Upload';
        toReturn.Add(toAdd);
      }
  
      return toReturn;
    }
  
    private static List<ContentDocumentLink> GetContentDocumentLinksForCaseID(Id caseID) {
      return [SELECT id, ContentDocument.Description, ContentDocument.Title, ContentDocument.FileType, ContentDocument.FileExtension, ContentDocumentId, ContentDocument.LatestPublishedVersionId FROM ContentDocumentLink WHERE LinkedEntityId = :caseID];
    }
  
    
    private static CDocuSign_Envelope_Tab__c SetTabValueToBlankIfEmpty(CDocuSign_Envelope_Tab__c tab) {
      if (string.isBlank(tab.Value__c)) {
        tab.Value__c = '';
      }
  
      return tab;
    }
  
    public static string GetPhoneNumberForContact(Id contactId) {
      string phoneNumber;
  
      Contact contact = [SELECT Id, Name, MobilePhone, HomePhone, Work_Phone__c, OtherPhone, Preferred_Phone_Type__c FROM Contact WHERE Id = :contactId];
  
      if (!string.isBlank(contact.MobilePhone)) {
        phoneNumber = contact.MobilePhone;
      } else if (!string.isBlank(contact.HomePhone)) {
        phoneNumber = contact.HomePhone;
      } else if (!string.isBlank(contact.Work_Phone__c)) {
        phoneNumber = contact.Work_Phone__c;
      } else if (!string.isBlank(contact.OtherPhone)) {
        phoneNumber = contact.OtherPhone;
      }
  
      if (string.isBlank(contact.Preferred_Phone_Type__c)) {
      } else {
        if (contact.Preferred_Phone_Type__c == 'Home Phone') {
          if (!string.isBlank(contact.HomePhone)) {
            phoneNumber = contact.HomePhone;
          }
        } else if (contact.Preferred_Phone_Type__c == 'Mobile') {
          if (!string.isBlank(contact.MobilePhone)) {
            phoneNumber = contact.MobilePhone;
          }
        } else if (contact.Preferred_Phone_Type__c == 'Work Phone') {
          if (!string.isBlank(contact.Work_Phone__c)) {
            phoneNumber = contact.Work_Phone__c;
          }
        } else if (contact.Preferred_Phone_Type__c == 'Other Phone') {
          if (!string.isBlank(contact.OtherPhone)) {
            phoneNumber = contact.OtherPhone;
          }
        }
      }
  
      return V2_Utility.formatPhoneFormat2(phoneNumber);
    }
  
    

    @AuraEnabled
    public static List<CDocuSign_Envelope_Tab__c> PrepopulateTabsForTemplate(Id caseID, string templateName, List<CDocuSign_Envelope_Tab__c> eTabs) {
      if (eTabs.size() > 0) {
        if (templateName == 'ENRP Welcome Package') {
          Case c = [SELECT Id, Patient_ID__c FROM Case WHERE id = :caseID];
          Patient__c p = [SELECT Id, Name, Enrolee_ID__c, Relationship__c, First_Name__c, Last_Name__c, Date_of_Birth__c, Enrolee_ID__r.Address_Line_1__c, Enrolee_ID__r.Address_Line_2__c, Enrolee_ID__r.City__c, Enrolee_ID__r.State__c, Enrolee_ID__r.Zip__c, Enrolee_ID__r.Zip_4__c FROM Patient__c WHERE Id = :c.Patient_ID__c];          
          Patient_Bill_Extra__c  pbx = V2_CaseDetailController.GetPatientBillExtra(caseID);
          
          string convertedRole = p.Relationship__c.replaceAll(' - ', '_');
  
          List<Contact> contact = [SELECT Id FROM Contact WHERE FirstName = :p.First_Name__c AND LastName = :p.Last_Name__c AND Role__c = :convertedRole AND Enrolee__c = :p.Enrolee_ID__c];
          string patientPhoneNumber;
  
          if (contact.size() > 0) {
            patientPhoneNumber = GetPhoneNumberForContact(contact[0].Id);
          }
  
          eTabs = SetTabValue(eTabs, 'PlanName', 'United Healthcare');
          eTabs = SetTabValue(eTabs, 'Patient_Last', p.Last_Name__c);
          eTabs = SetTabValue(eTabs, 'Patient_First', p.First_Name__c);
          eTabs = SetTabValue(eTabs, 'DOB_Month', string.valueOf(p.Date_of_Birth__c.month()));
          eTabs = SetTabValue(eTabs, 'DOB_Day', string.valueOf(p.Date_of_Birth__c.day()));
          eTabs = SetTabValue(eTabs, 'DOB_Year', string.valueOf(p.Date_of_Birth__c.year()));
          eTabs = SetTabValue(eTabs, 'Patient_Addr1', p.Enrolee_ID__r.Address_Line_1__c);
          eTabs = SetTabValue(eTabs, 'Patient_City', p.Enrolee_ID__r.City__c);
          eTabs = SetTabValue(eTabs, 'Patient_State', p.Enrolee_ID__r.State__c);
          eTabs = SetTabValue(eTabs, 'Patient_Zip5', p.Enrolee_ID__r.Zip__c);
          eTabs = SetTabValue(eTabs, 'Patient_Phone', patientPhoneNumber);          
          if (!string.isBlank(pbx.Patient_Bill_Name__c))
          {
            eTabs = SetTabValue(eTabs, 'ProviderName', pbx.Patient_Bill_Name__c);
          }
          system.debug(pbx.Patient_Bill_Name__c);
          
          eTabs = SetTabValue(eTabs, 'PatientName', p.First_Name__c + ' ' + p.Last_Name__c);

          List<Case_Claim_Summary__c> ccs = V2_CaseDetailController.GetCaseOriginalClaims(caseID);

          if (ccs != null && ccs.size() > 0)
          {
            decimal dedAmt = 0.00;
            decimal coinsAmt = 0.00;
            decimal copayAmt = 0.00;
            decimal allowedAmt = 0.00;
            decimal billedAmt = 0.00;
            decimal paidAmt = 0.00;
            decimal discountAmt = 0.00;
            decimal ncAmount = 0.00;
            decimal balanceAmt = 0.00;

            for(Case_Claim_Summary__c ccsItm : ccs)
            {
              if (ccsItm.Claim_Number__c == 'Total Case')              
              {
                dedAmt = ccsItm.Ded__c;
                coinsAmt = ccsItm.Coins__c;
                allowedAmt = ccsItm.Allowed__c;
                billedAmt = ccsItm.Claim_Billed_Amount__c;
                paidAmt = ccsItm.Plan_Paid__c;
                discountAmt = ccsItm.Plan_Discount__c;
                ncAmount = ccsItm.Not_Covered_Amount__c;
                balanceAmt = ccsItm.Potential_Balance_Bill__c;
              }
            }

            eTabs = SetTabValue(eTabs, 'Ded_Amt', string.valueOf(dedAmt));
            eTabs = SetTabValue(eTabs, 'Coins_Amt', string.valueOf(coinsAmt));
            eTabs = SetTabValue(eTabs, 'Copay_Amt', string.valueOf(copayAmt));
  
            //eTabs = SetTabValue(eTabs, 'ServiceType', string.valueOf(ir.Type_of_Claims_Services__c));
            eTabs = SetTabValue(eTabs, 'Billed_Amt', string.valueOf(billedAmt));
            eTabs = SetTabValue(eTabs, 'Allow_Amt', string.valueOf(allowedAmt));
            eTabs = SetTabValue(eTabs, 'Paid_Amt', string.valueOf(paidAmt));
            eTabs = SetTabValue(eTabs, 'Discount_Amt', string.valueOf(discountAmt));
            eTabs = SetTabValue(eTabs, 'NC_Amt', string.valueOf(ncAmount));
            eTabs = SetTabValue(eTabs, 'Balance_Amt', string.valueOf(balanceAmt));
          }
        } else if (templateName == 'ENRP Consent to Negotiate') {
          Case c = [SELECT Id, Patient_ID__c FROM Case WHERE id = :caseID];
          Patient_Bill_Extra__c  pbx = V2_CaseDetailController.GetPatientBillExtra(caseID);
          Patient__c p = [SELECT Id, Name, Enrolee_ID__c, Relationship__c, First_Name__c, Last_Name__c, Date_of_Birth__c, Enrolee_ID__r.Address_Line_1__c, Enrolee_ID__r.Address_Line_2__c, Enrolee_ID__r.City__c, Enrolee_ID__r.State__c, Enrolee_ID__r.Zip__c, Enrolee_ID__r.Zip_4__c FROM Patient__c WHERE Id = :c.Patient_ID__c];
  
          eTabs = SetTabValue(eTabs, 'PlanName', 'United Healthcare');
          if (!string.isBlank(pbx.Patient_Bill_Name__c))
          {
            eTabs = SetTabValue(eTabs, 'ProviderName', pbx.Patient_Bill_Name__c);
          }
          eTabs = SetTabValue(eTabs, 'PatientName', p.First_Name__c + ' ' + p.Last_Name__c);
  
          List<Case_Claim_Summary__c> ccs = V2_CaseDetailController.GetCaseOriginalClaims(caseID);

          if (ccs != null && ccs.size() > 0)
          {
            decimal dedAmt = 0.00;
            decimal coinsAmt = 0.00;
            decimal copayAmt = 0.00;
            decimal allowedAmt = 0.00;
            decimal billedAmt = 0.00;
            decimal paidAmt = 0.00;
            decimal discountAmt = 0.00;
            decimal ncAmount = 0.00;
            decimal balanceAmt = 0.00;

            for(Case_Claim_Summary__c ccsItm : ccs)
            {
              if (ccsItm.Claim_Number__c == 'Total Case')              
              {
                dedAmt = ccsItm.Ded__c;
                coinsAmt = ccsItm.Coins__c;
                allowedAmt = ccsItm.Allowed__c;
                billedAmt = ccsItm.Claim_Billed_Amount__c;
                paidAmt = ccsItm.Plan_Paid__c;
                discountAmt = ccsItm.Plan_Discount__c;
                ncAmount = ccsItm.Not_Covered_Amount__c;
                balanceAmt = ccsItm.Potential_Balance_Bill__c;
              }
            }

            eTabs = SetTabValue(eTabs, 'Ded_Amt', string.valueOf(dedAmt));
            eTabs = SetTabValue(eTabs, 'Coins_Amt', string.valueOf(coinsAmt));
            eTabs = SetTabValue(eTabs, 'Copay_Amt', string.valueOf(copayAmt));
  
            //eTabs = SetTabValue(eTabs, 'ServiceType', string.valueOf(ir.Type_of_Claims_Services__c));
            eTabs = SetTabValue(eTabs, 'Billed_Amt', string.valueOf(billedAmt));
            eTabs = SetTabValue(eTabs, 'Allow_Amt', string.valueOf(allowedAmt));
            eTabs = SetTabValue(eTabs, 'Paid_Amt', string.valueOf(paidAmt));
            eTabs = SetTabValue(eTabs, 'Discount_Amt', string.valueOf(discountAmt));
            eTabs = SetTabValue(eTabs, 'NC_Amt', string.valueOf(ncAmount));
            eTabs = SetTabValue(eTabs, 'Balance_Amt', string.valueOf(balanceAmt));
          }
        } else if (templateName == 'MNRP Welcome Package') {
          Case c = [SELECT Id, Patient_ID__c, Provider_ID__c, Initial_Review__c FROM Case WHERE id = :caseID LIMIT 1];
          Patient__c p = [SELECT Id, Name, Enrolee_ID__c, Relationship__c, First_Name__c, Last_Name__c, Date_of_Birth__c, Enrolee_ID__r.Address_Line_1__c, Enrolee_ID__r.Address_Line_2__c, Enrolee_ID__r.City__c, Enrolee_ID__r.State__c, Enrolee_ID__r.Zip__c, Enrolee_ID__r.Zip_4__c FROM Patient__c WHERE Id = :c.Patient_ID__c];
  
          string convertedRole = p.Relationship__c.replaceAll(' - ', '_');
  
          List<Contact> contact = [SELECT Id FROM Contact WHERE FirstName = :p.First_Name__c AND LastName = :p.Last_Name__c AND Role__c = :convertedRole AND Enrolee__c = :p.Enrolee_ID__c];
          string patientPhoneNumber;
  
          if (contact.size() > 0) {
            patientPhoneNumber = GetPhoneNumberForContact(contact[0].Id);
          }
  
          eTabs = SetTabValue(eTabs, 'Patient_Last', p.Last_Name__c);
          eTabs = SetTabValue(eTabs, 'Patient_First', p.First_Name__c);
          eTabs = SetTabValue(eTabs, 'DOB_Month', string.valueOf(p.Date_of_Birth__c.month()));
          eTabs = SetTabValue(eTabs, 'DOB_Day', string.valueOf(p.Date_of_Birth__c.day()));
          eTabs = SetTabValue(eTabs, 'DOB_Year', string.valueOf(p.Date_of_Birth__c.year()));
          eTabs = SetTabValue(eTabs, 'Patient_Addr1', p.Enrolee_ID__r.Address_Line_1__c);
          eTabs = SetTabValue(eTabs, 'Patient_City', p.Enrolee_ID__r.City__c);
          eTabs = SetTabValue(eTabs, 'Patient_State', p.Enrolee_ID__r.State__c);
          eTabs = SetTabValue(eTabs, 'Patient_Zip5', p.Enrolee_ID__r.Zip__c);
          eTabs = SetTabValue(eTabs, 'Patient_Phone', patientPhoneNumber);
          eTabs = SetTabValue(eTabs, 'Patient_Addr2', p.Enrolee_ID__r.City__c + ', ' + p.Enrolee_ID__r.State__c + '  ' + p.Enrolee_ID__r.Zip__c);
          eTabs = SetTabValue(eTabs, 'Patient_FullName', p.First_Name__c + ' ' + p.Last_Name__c);
        } else if (templateName == 'HIPAA Authorization') {
          Case c = [SELECT Id, Patient_ID__c, Provider_ID__c, Initial_Review__c FROM Case WHERE id = :caseID LIMIT 1];
          Patient__c p = [SELECT Id, Name, Enrolee_ID__c, Relationship__c, First_Name__c, Last_Name__c, Date_of_Birth__c, Enrolee_ID__r.Address_Line_1__c, Enrolee_ID__r.Address_Line_2__c, Enrolee_ID__r.City__c, Enrolee_ID__r.State__c, Enrolee_ID__r.Zip__c, Enrolee_ID__r.Zip_4__c FROM Patient__c WHERE Id = :c.Patient_ID__c];
  
          string convertedRole = p.Relationship__c.replaceAll(' - ', '_');
  
          List<Contact> contact = [SELECT Id FROM Contact WHERE FirstName = :p.First_Name__c AND LastName = :p.Last_Name__c AND Role__c = :convertedRole AND Enrolee__c = :p.Enrolee_ID__c];
          string patientPhoneNumber;
  
          if (contact.size() > 0) {
            patientPhoneNumber = GetPhoneNumberForContact(contact[0].Id);
          }
  
          eTabs = SetTabValue(eTabs, 'Patient_Last', p.Last_Name__c);
          eTabs = SetTabValue(eTabs, 'Patient_First', p.First_Name__c);
          eTabs = SetTabValue(eTabs, 'DOB_Month', string.valueOf(p.Date_of_Birth__c.month()));
          eTabs = SetTabValue(eTabs, 'DOB_Day', string.valueOf(p.Date_of_Birth__c.day()));
          eTabs = SetTabValue(eTabs, 'DOB_Year', string.valueOf(p.Date_of_Birth__c.year()));
          eTabs = SetTabValue(eTabs, 'Patient_Addr1', p.Enrolee_ID__r.Address_Line_1__c);
          eTabs = SetTabValue(eTabs, 'Patient_City', p.Enrolee_ID__r.City__c);
          eTabs = SetTabValue(eTabs, 'Patient_State', p.Enrolee_ID__r.State__c);
          eTabs = SetTabValue(eTabs, 'Patient_Zip5', p.Enrolee_ID__r.Zip__c);
          eTabs = SetTabValue(eTabs, 'Patient_Phone', patientPhoneNumber);
        } else if (templateName == 'HIPAA Authorization V2') {
          eTabs = SetETabsForHIPAAV2(caseID, eTabs);
        } else if (templateName == 'MNRP Consent to Negotiate V2' ||
                   templateName == 'MNRP Consent to Negotiate V2 WOEC' ||
                   templateName == 'ENRP Consent to Negotiate V2' ||
                   templateName == 'ENRP Consent to Negotiate V2 WOEC') {
          eTabs = SetETabsForConsentToNegV2(caseID, eTabs);
        }else if (templateName == 'ENRP Welcome Package V2' ||
          templateName == 'ENRP Welcome Package V2 WOEC' ||
          templateName == 'MNRP Welcome Package V2' ||
          templateName == 'MNRP Welcome Package V2 WOEC') {
          eTabs = SetETabsForHIPAAV2(caseID, eTabs);
          eTabs = SetETabsForConsentToNegV2(caseID, eTabs);
        }
      }
  
      return eTabs;
    }

    private static List<CDocuSign_Envelope_Tab__c> SetETabsForConsentToNegV2(Id caseID, List<CDocuSign_Envelope_Tab__c> eTabs)
    {
      Case c = [SELECT Id, Patient_ID__c FROM Case WHERE id = :caseID];    
      Patient__c p = [SELECT Id, Name, Enrolee_ID__c, Relationship__c, First_Name__c, Last_Name__c, Middle_Initial__c, Date_of_Birth__c, Enrolee_ID__r.Address_Line_1__c, Enrolee_ID__r.Address_Line_2__c, Enrolee_ID__r.City__c, Enrolee_ID__r.State__c, Enrolee_ID__r.Zip__c, Enrolee_ID__r.Zip_4__c FROM Patient__c WHERE Id = :c.Patient_ID__c];
      List<Case_Claim_Summary__c> claimSummaryList = V2_CaseDetailController.GetCaseClaimSummaryForCase(c.Id);

      eTabs = SetTabValue(eTabs, 'PlanName', 'United Healthcare');
      eTabs = SetTabValue(eTabs, 'PatientName', (string.isblank(p.First_Name__c)?'':p.First_Name__c) + ' ' + (string.isblank(p.Last_Name__c)?'':p.Last_Name__c));

      if (claimSummaryList != null && claimSummaryList.size()> 0)
      {
        
        List<date> dosS = new List<date>();
        for (Case_Claim_Summary__c cl : claimSummaryList)
        {
          if (String.isNotBlank(string.ValueOf(cl.First_DOS__c)))
          {
            boolean dateExists = false;
            for (Date d: dosS)
            {
              if (d == cl.First_DOS__c)
              {
                dateExists = true;
              }
            }
            
            if (!dateExists)
            {
              dosS.add(cl.First_DOS__c);
            }
          }
        }

        if (dosS.size() > 0)
        {
          dosS.sort();
          List<string> dosStringVersion = new List<String>();
          for (Date d : dosS)
          {
            dosStringVersion.add(d.format());
          }

          eTabs = SetTabValue(eTabs, 'DOS', String.join(dosStringVersion, ', '));                  
        }
        for (Case_Claim_Summary__c cl : claimSummaryList)
        {
          if (!string.isblank(cl.Rendering_Provider_Name__c ))
          {
            eTabs = SetTabValue(eTabs, 'ProviderName', cl.Rendering_Provider_Name__c);                  
          }
          break;
        } 
      }

      eTabs = SetTabValue(eTabs, 'Patient_Addr1_BB', (string.isblank(p.Enrolee_ID__r.Address_Line_1__c)?'':p.Enrolee_ID__r.Address_Line_1__c));
      
      string addressLine2 = string.isblank(p.Enrolee_ID__r.City__c)?'':p.Enrolee_ID__r.City__c;
      if (string.isnotblank(p.Enrolee_ID__r.State__c))
      {
        addressLine2 += ', ' + p.Enrolee_ID__r.State__c;
      }

      if (string.isnotblank(p.Enrolee_ID__r.Zip__c))
      {
        addressLine2 += ' ' + p.Enrolee_ID__r.Zip__c;
      }

      eTabs = SetTabValue(eTabs, 'Patient_Addr2', addressLine2);

      return eTabs;
    }

    private static List<CDocuSign_Envelope_Tab__c> SetETabsForHIPAAV2(Id caseID, List<CDocuSign_Envelope_Tab__c> eTabs)
    {
      Case c = [SELECT Id, Patient_ID__c, Provider_ID__c, Patient_Contact__c, Primary_Patient_Contact__c FROM Case WHERE id = :caseID LIMIT 1];
      Patient__c p = [SELECT Id, Name, Enrolee_ID__c, Relationship__c, First_Name__c, Last_Name__c, Middle_Initial__c, Date_of_Birth__c, Enrolee_ID__r.Address_Line_1__c, Enrolee_ID__r.Address_Line_2__c, Enrolee_ID__r.City__c, Enrolee_ID__r.State__c, Enrolee_ID__r.Zip__c, Enrolee_ID__r.Zip_4__c FROM Patient__c WHERE Id = :c.Patient_ID__c];
      Patient_Bill_Extra__c pbx = V2_CaseDetailController.GetPatientBillExtra(c.Id);
      List<Case_Claim_Summary__c> claimSummaryList = V2_CaseDetailController.GetCaseClaimSummaryForCase(c.Id);

      string convertedRole = p.Relationship__c.replaceAll(' - ', ' ');

      List<Contact> contact = [SELECT Id FROM Contact WHERE FirstName = :p.First_Name__c AND LastName = :p.Last_Name__c AND Role__c = :convertedRole AND Enrolee__c = :p.Enrolee_ID__c];
      string patientPhoneNumber;

      if (contact.size() > 0) {
        patientPhoneNumber = GetPhoneNumberForContact(contact[0].Id);

        if (string.isBlank(patientPhoneNumber))
        {
            if (!string.isBlank(c.Primary_Patient_Contact__c))
            {
              if (c.Primary_Patient_Contact__c != contact[0].Id)
              {
                patientPhoneNumber = GetPhoneNumberForContact(c.Primary_Patient_Contact__c);
              }
            }
        }
      }

      //patient info
      eTabs = SetTabValue(eTabs, 'Patient_Last', (string.isblank(p.Last_Name__c)?'':p.Last_Name__c));
      eTabs = SetTabValue(eTabs, 'Patient_First', (string.isblank(p.First_Name__c)?'':p.First_Name__c));
      if (!string.isblank(p.Middle_Initial__c))
      {
        eTabs = SetTabValue(eTabs, 'Patient_Middle', (string.isblank(p.Middle_Initial__c)?'':p.Middle_Initial__c));
      }
      eTabs = SetTabValue(eTabs, 'DOB_Month', string.valueOf(p.Date_of_Birth__c.month()));
      eTabs = SetTabValue(eTabs, 'DOB_Day', string.valueOf(p.Date_of_Birth__c.day()));
      eTabs = SetTabValue(eTabs, 'DOB_Year', string.valueOf(p.Date_of_Birth__c.year()));
      eTabs = SetTabValue(eTabs, 'Patient_Addr1', (string.isblank(p.Enrolee_ID__r.Address_Line_1__c)?'':p.Enrolee_ID__r.Address_Line_1__c));
      eTabs = SetTabValue(eTabs, 'Patient_City', string.isblank(p.Enrolee_ID__r.City__c)?'':p.Enrolee_ID__r.City__c);
      eTabs = SetTabValue(eTabs, 'Patient_State', string.isblank(p.Enrolee_ID__r.State__c)?'':p.Enrolee_ID__r.State__c);
      eTabs = SetTabValue(eTabs, 'Patient_Zip5', string.isblank(p.Enrolee_ID__r.Zip__c)?'':p.Enrolee_ID__r.Zip__c);
      eTabs = SetTabValue(eTabs, 'Patient_Phone', patientPhoneNumber);

      //provider Info
      if (pbx != null)
      {
        if (!string.isblank(pbx.Patient_Bill_Name__c))
        {
          eTabs = SetTabValue(eTabs, 'Disclose_OrgName', pbx.Patient_Bill_Name__c);
        }

        if (!string.isblank(pbx.Patient_Bill_MailingStreet__c))
        {
          eTabs = SetTabValue(eTabs, 'Disclose_Address', pbx.Patient_Bill_MailingStreet__c);
        }

        if (!string.isblank(pbx.Patient_Bill_MailingCity__c))
        {
          eTabs = SetTabValue(eTabs, 'Disclose_City', pbx.Patient_Bill_MailingCity__c);
        }

        if (!string.isblank(pbx.Patient_Bill_MailingState__c))
        {
          eTabs = SetTabValue(eTabs, 'Disclose_State', pbx.Patient_Bill_MailingState__c);
        }

        if (!string.isblank(pbx.Patient_Bill_MailingPostalCode__c))
        {
          eTabs = SetTabValue(eTabs, 'Disclose_Zip5', pbx.Patient_Bill_MailingPostalCode__c.left(5));
        }

        if (!string.isblank(pbx.Patient_Bill_Phone__c))
        {
          eTabs = SetTabValue(eTabs, 'Disclose_Phone', pbx.Patient_Bill_Phone__c);
        }

        if (!string.isblank(pbx.Patient_Bill_Fax__c))
        {
          eTabs = SetTabValue(eTabs, 'Disclose_Fax', pbx.Patient_Bill_Fax__c);
        }

        List<string> accountNumbers = new List<string>();

        if (!string.isblank(pbx.Patient_Account_Num_1__c))
        {
          accountNumbers.add(pbx.Patient_Account_Num_1__c);             
        }

        if (!string.isblank(pbx.Patient_Account_Num_2__c))
        {
          accountNumbers.add(pbx.Patient_Account_Num_2__c);             
        }

        if (accountNumbers.size() > 0)
        {
          eTabs = SetTabValue(eTabs, 'Account_Number', String.join(accountNumbers, ', '));
        }

        if (claimSummaryList != null && claimSummaryList.size()> 0)
        {
          
          List<date> dosS = new List<date>();
          for (Case_Claim_Summary__c cl : claimSummaryList)
          {
            if (String.isNotBlank(string.ValueOf(cl.First_DOS__c)))
            {
              boolean dateExists = false;
              for (Date d: dosS)
              {
                if (d == cl.First_DOS__c)
                {
                  dateExists = true;
                }
              }
              
              if (!dateExists)
              {
                dosS.add(cl.First_DOS__c);
              }
            }
          }

          if (dosS.size() > 0)
          {
            dosS.sort();
            List<string> dosStringVersion = new List<String>();
            for (Date d : dosS)
            {
              dosStringVersion.add(d.format());
            }

            eTabs = SetTabValue(eTabs, 'Dates_Of_Service', String.join(dosStringVersion, ', '));                  
          }
        for (Case_Claim_Summary__c cl : claimSummaryList)
          {
            if (!string.isblank(cl.Rendering_Provider_Name__c ))
            {
              eTabs = SetTabValue(eTabs, 'Provider_Name', cl.Rendering_Provider_Name__c);                  
            }
            break;
          } 
          for (Case_Claim_Summary__c cl : claimSummaryList)
          {
            if (!string.isblank(cl.Service_Location_Group_Name__c ))
            {
              eTabs = SetTabValue(eTabs, 'Service_Location', cl.Service_Location_Group_Name__c);                  
            }
            break;
          }
        }
      }

      return eTabs;
    }

    private static List<CDocuSign_Envelope_Tab__c> SetTabValue(List<CDocuSign_Envelope_Tab__c> tabs, string tabLabel, string value) {
      for (CDocuSign_Envelope_Tab__c itm : tabs) {
        if (itm.CDocuSign_Template_Tab__r.Tab_Label__c.toUpperCase() == tabLabel.toUpperCase()) {
          if (value == 'null')
          {
            value = '';
          }

          itm.Value__c = value;
        }
      }
  
      return tabs;
    }
  
    @AuraEnabled
    public static Integration_Task__c CreateSPITRecordForDocusignUpdate(string envelopeID, Id envelopeSFID, List<CDocuSign_Envelope_Tab__c> tabValues, string artifactID) {
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  
      string PARM1;
      string PARM2;
      string PARM3;
      string PARM4;
      string PARM5;
      string PARM6;
      string PARM7;
      string PARM8;
      string PARM9;
      string PARM10;
      string PARMBIG1;
      string PARMBIG2;
      string taskType = 'DOCUSIGN UPDATE DRAFT TAB VALUES';
      string RelatedTask;
  
      JSONGenerator gen = JSON.createGenerator(true);
  
      gen.writeStartObject();
      gen.writeFieldName('tabValues');
      gen.writeStartArray();
  
      for (CDocuSign_Envelope_Tab__c itm : tabValues) {
        if (string.isBlank(itm.Value__c)) {
          itm.Value__c = '';
        }
  
        gen.writeStartObject();
        gen.writeStringField('tabLabel', itm.CDocuSign_Template_Tab__r.Tab_Label__c);
        gen.writeStringField('value', itm.Value__c);
        gen.writeStringField('recipientId', itm.CDocuSign_Template_Tab__r.CDocuSign_Template_Recipient__r.Recipient_ID__c);
        gen.writeStringField('CDocuSign_Template_Tab__c', itm.CDocuSign_Template_Tab__r.Id);
        gen.writeStringField('tabGroup', itm.CDocuSign_Template_Tab__r.Tab_Group__c);
        gen.writeStringField('tabIdSF', itm.Id);
        gen.writeEndObject();
      }
  
      gen.writeEndArray();
      gen.writeEndObject();
  
      PARM1 = envelopeID;
      PARM2 = envelopeSFID;
      PARM3 = instanceName.ConfigValue__c;
      PARM4 = artifactID;
      PARMBIG1 = gen.getAsString();
  
      Integration_Task__c it = IntegrationTask.createIntegrationTask(taskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
  
      Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
      String encodedGUIDText = EncodingUtil.base64Encode(guidText);
      it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');
  
      return it;
    }
  
    @AuraEnabled
    public static Integration_Task__c GetSPITRecord(Id id) {
      Integration_Task__c it = IntegrationTask.GetIntegrationTask(id);
      return it;
    }
  
    @AuraEnabled
    public static List<External_Configurations__c> GetExternalConfigs() {
      return Utility.GetExternalConfigs();
    }
  
    @AuraEnabled
    public static List<RecordType> GetTaskRecordTypes() {
      return [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE SobjectType = 'Task'];
    }
  
    @AuraEnabled
    public static CDocuSign_Envelope__c GetEnvelopeByID(Id envelopeId) {
      CDocuSign_Envelope__c envelope = [SELECT Ready_To_Send__c, Case__c, CDocuSign_Template__c, CreatedById, CreatedDate, Envelope_ID__c, Envelope_Status__c, Id, Integration_Task__c, IsDeleted, LastActivityDate, LastModifiedById, LastModifiedDate, LastReferencedDate, LastViewedDate, Name, SystemModstamp, Task_ID__c FROM CDocuSign_Envelope__c WHERE Id = :envelopeId];
      return envelope;
    }
  
    @AuraEnabled
    public static List<CDocuSign_Envelope_Tab__c> GetEnvelopeTabsByEnvelopeID(Id envelopeID) {
      List<CDocuSign_Envelope_Tab__c> envTabs = [
        SELECT CDocuSign_Template_Tab__r.Preloaded__c, CDocuSign_Template_Tab__r.Display_In_Overlay__c, CDocuSign_Template_Tab__r.Required_For_Send__c, CDocuSign_Envelope__c, CDocuSign_Template_Tab__c, FInal_Value__c, Id, Is_Valid__c, Name, Value__c, CDocuSign_Template_Tab__r.Active__c, CDocuSign_Template_Tab__r.CDocuSign_Template_Recipient__c, CDocuSign_Template_Tab__r.CDocuSign_Template_Recipient__r.Recipient_ID__c, CDocuSign_Template_Tab__r.Display_Label__c, CDocuSign_Template_Tab__r.Max_Length__c, CDocuSign_Template_Tab__r.Order_Number__c, CDocuSign_Template_Tab__r.Required__c, CDocuSign_Template_Tab__r.Tab_Label__c, CDocuSign_Template_Tab__r.Validation_Message__c, CDocuSign_Template_Tab__r.Validation_Pattern__c, CDocuSign_Template_Tab__r.Input_Type__c, CDocuSign_Template_Tab__r.Placeholder__c, CDocuSign_Template_Tab__r.Editable__c, CDocuSign_Template_Tab__r.Tab_Group__c
        FROM CDocuSign_Envelope_Tab__c
        WHERE CDocuSign_Envelope__c = :envelopeID
        ORDER BY CDocuSign_Template_Tab__r.Order_Number__c
      ];
      return envTabs;
    }
  
    @AuraEnabled
    public static List<CDocuSign_Envelope_Tab__c> WriteAndReturnEnvTabs(Id sfEnvelopeID, List<CDocuSign_Envelope_Tab__c> eTabs) {
      for (CDocuSign_Envelope_Tab__c t : eTabs) {
        try {
          if (string.isBlank(t.CDocuSign_Envelope__c)) {
            t.CDocuSign_Envelope__c = sfEnvelopeID;
          }
        } catch (Exception ex) {
        }
      }
      upsert eTabs;
  
      return GetEnvelopeTabsByEnvelopeID(sfEnvelopeID);
    }
  
    @AuraEnabled
    public static List<CDocuSign_Envelope_Tab__c> InitTabsForTemplateName(Id caseID, string templateName) {
      List<CDocuSign_Envelope_Tab__c> eTabs = new List<CDocuSign_Envelope_Tab__c>();
      List<CDocuSign_Template_Tab__c> tabs = [SELECT Preloaded__c, Display_In_Overlay__c, Editable__c, Required_For_Send__c, CDocuSign_Template_Recipient__r.Recipient_ID__c, Active__c, CreatedById, CreatedDate, Display_Label__c, Id, IsDeleted, LastModifiedById, LastModifiedDate, Max_Length__c, Name, Order_Number__c, Required__c, SystemModstamp, Tab_Label__c, Tab_Group__c, Validation_Message__c, Validation_Pattern__c FROM CDocuSign_Template_Tab__c WHERE CDocuSign_Template_Recipient__r.CDocuSign_Template__r.Template_Name__c = :templateName];
  
      if (tabs.size() > 0) {
        for (CDocuSign_Template_Tab__c itm : tabs) {
          CDocuSign_Envelope_Tab__c toAdd = new CDocuSign_Envelope_Tab__c();
          toAdd.CDocuSign_Template_Tab__r = itm;
          toAdd.CDocuSign_Template_Tab__c = itm.Id;
          eTabs.Add(toAdd);
        }
      }
  
      return PrepopulateTabsForTemplate(caseID, templateName, eTabs);
    }
  
    @AuraEnabled
    public static List<CDocuSign_Envelope_Recipient__c> InitRecipientsForSFTemplateName(string caseId, String templateName) {
      List<CDocuSign_Template_Recipient__c> recRefList = [SELECT Is_Signing_Group__c, Signing_Group_Name__c, Signing_Group_Id__c, Filter_By_Naviguard_Signee__c, Filter_By_OPS_Manager_Contact__c, Filter_By_Employer_Group_Contact__c, Filter_By_Advisor_Contact__c, Filter_By_Family_Contact__c, Filter_By_Negotiator_Contact__c, Filter_By_Provider_Contact__c, CDocuSign_Template__c, Id, Name, Recipient_ID__c, Role_Name__c, Recipient_Type__c FROM CDocuSign_Template_Recipient__c WHERE CDocuSign_Template__r.Template_Name__c = :templateName ORDER BY Recipient_ID__c];
      List<CDocuSign_Envelope_Recipient__c> recEnvList = new List<CDocuSign_Envelope_Recipient__c>();
  
      for (CDocuSign_Template_Recipient__c r : recRefList) {
        CDocuSign_Envelope_Recipient__c toAdd = new CDocuSign_Envelope_Recipient__c();
        toAdd.Role__c = r.Role_Name__c;
        toAdd.Use_Access_Code_Auth__c = false;
        toAdd.Use_SMS_Auth__c = false;
        toAdd.Use_Digital__c = false;
        toAdd.Use_Phone__c = false;
        toAdd.CDocuSign_Template_Recipient__c = r.Id;
        toAdd.CDocuSign_Template_Recipient__r = r;
        toAdd.Email_Address__c = '';
        toAdd.First_Name__c = '';
        toAdd.Last_Name__c = '';
        toAdd.Authentication_SMS_Number__c = '';
        toAdd.Authentication_Phone_Number__c = '';
        toAdd.Authentication_Access_Token__c = '';
        toAdd.Is_Signing_Group__c = r.Is_Signing_Group__c;
        toAdd.Signing_Group_Name__c = r.Signing_Group_Name__c;
        toAdd.Signing_Group_Id__c = r.Signing_Group_Id__c;

        if (toAdd.Is_Signing_Group__c == true)
        {
          System.Debug('GOING IN');
          if (toAdd.Signing_Group_Id__c == 'COUNTER SIGNATURE LOGIC')
          {
            decimal originalAllowed = 0;
            decimal negotiatedAllowed = 0;
            decimal diffAmount = 0;

            Case_Claim_Summary__c ccsAdjusted = V2_CaseDetailController.GetClaimAdjustmentResults(caseId)[0];
           
            if (ccsAdjusted != null)
            {
              if (ccsAdjusted.Allowed__c != null)
              {
                originalAllowed = ccsAdjusted.Allowed__c;
              }

              if (ccsAdjusted.Negotiated_Allowed_Amount__c != null)
              {
                negotiatedAllowed = ccsAdjusted.Negotiated_Allowed_Amount__c;
              }
            }

            diffAmount = negotiatedAllowed - originalAllowed;
            System.Debug('DiffAmount: ' + diffAmount);

            if (diffAmount <= 750)
            {

              toAdd.Signing_Group_Name__c = 'Group 0-750';
              toAdd.Signing_Group_Id__c = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'DOCUSIGN GROUP 0-750' LIMIT 1].ConfigValue__c;
            }
            else if (diffAmount > 750 && diffAmount <= 2000)
            {
              toAdd.Signing_Group_Name__c = 'Group 751-2000';
              toAdd.Signing_Group_Id__c = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'DOCUSIGN GROUP 751-2000' LIMIT 1].ConfigValue__c;
            }
            else if (diffAmount > 2000 && diffAmount <= 5000)
            {
              toAdd.Signing_Group_Name__c = 'Group 2001-5000';
              toAdd.Signing_Group_Id__c = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'DOCUSIGN GROUP 2001-5000' LIMIT 1].ConfigValue__c;
            }
            else if (diffAmount > 5000)
            {
              toAdd.Signing_Group_Name__c = 'Group 5001+';
              toAdd.Signing_Group_Id__c = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'DOCUSIGN GROUP 5001+' LIMIT 1].ConfigValue__c;
            }
            System.Debug(toAdd.Signing_Group_Name__c);            
          }
        }
  
        recEnvList.add(toAdd);
      }
  
      return recEnvList;
    }
  
    @AuraEnabled
    public static List<CDocuSign_Envelope_Recipient__c> WriteAndReturnRecipients(Id sfEnvelopeID, List<CDocuSign_Envelope_Recipient__c> recipients) {
      for (CDocuSign_Envelope_Recipient__c t : recipients) {
        try {
          if (string.isBlank(t.CDocuSign_Envelope__c)) {
            t.CDocuSign_Envelope__c = sfEnvelopeID;
          }
        } catch (Exception ex) {
        }
      }
  
      upsert recipients;
  
      return GetRecipientsForSFEnvelopeID(sfEnvelopeID);
    }
  
    @AuraEnabled
    public static List<CDocuSign_Envelope_Recipient__c> GetRecipientsForSFEnvelopeID(Id sfEnvelopeID) {
      List<CDocuSign_Envelope_Recipient__c> toReturn = [
        SELECT Signing_Group_Id__c, Signing_Group_Name__c, Is_Signing_Group__c, CDocuSign_Template_Recipient__r.Filter_By_OPS_Manager_Contact__c, CDocuSign_Template_Recipient__r.Filter_By_Naviguard_Signee__c, CDocuSign_Template_Recipient__r.Filter_By_Employer_Group_Contact__c, CDocuSign_Template_Recipient__r.Filter_By_Advisor_Contact__c, CDocuSign_Template_Recipient__r.Filter_By_Family_Contact__c, CDocuSign_Template_Recipient__r.Filter_By_Negotiator_Contact__c, CDocuSign_Template_Recipient__r.Filter_By_Provider_Contact__c, CDocuSign_Template_Recipient__r.CDocuSign_Template__c, CDocuSign_Template_Recipient__r.Id, CDocuSign_Template_Recipient__r.Name, CDocuSign_Template_Recipient__r.Recipient_ID__c, CDocuSign_Template_Recipient__r.Role_Name__c, CDocuSign_Template_Recipient__r.Recipient_Type__c, Authentication_Access_Token__c, Authentication_SMS_Number__c, CDocuSign_Envelope__c, CDocuSign_Template_Recipient__c, Contact__c, Email_Address__c, First_Name__c, Id, Last_Name__c, Name, Role__c, Use_Access_Code_Auth__c, Use_Digital__c, Use_SMS_Auth__c, Use_Phone__c, Authentication_Phone_Number__c
        FROM CDocuSign_Envelope_Recipient__c
        WHERE CDocuSign_Envelope__c = :sfEnvelopeID
        ORDER BY CDocuSign_Template_Recipient__r.Recipient_ID__c
      ];
  
      return toReturn;
    }
  
    @AuraEnabled
    public static Task DiscardDraftPostCleanUp(Task taskObject) {
      List<CDocuSign_Envelope_Tab__c> eTabs = [SELECT Id FROM CDocuSign_Envelope_Tab__c WHERE CDocuSign_Envelope__c = :taskObject.CDocuSign_Envelope__c];
      List<CDocuSign_Envelope_Recipient__c> recipients = [SELECT Id FROM CDocuSign_Envelope_Recipient__c WHERE CDocuSign_Envelope__c = :taskObject.CDocuSign_Envelope__c];
      List<CDocuSign_Envelope_Artifact__c> artifacts = [SELECT Id FROM CDocuSign_Envelope_Artifact__c WHERE CDocuSign_Envelope__c = :taskObject.CDocuSign_Envelope__c];
      CDocuSign_Envelope__c env = new CDocuSign_Envelope__c(Id = taskObject.CDocuSign_Envelope__c);
  
      delete eTabs;
      delete recipients;
      delete artifacts;
      delete env;
  
      taskObject.CDocuSign_Envelope__c = null;
      taskObject.CDocuSign_Envelope__r = null;
  
      try {
        if (!string.isBlank(taskObject.Id)) {
          update taskObject;
        }
      } catch (Exception ex) {
      }
  
      CDocuSign_Envelope__c e = new CDocuSign_Envelope__c();
      e.Envelope_Status__c = 'Not Created';
      e.Ready_to_Send__c = false;
      taskObject.CDocuSign_Envelope__r = e;
  
      return taskObject;
    }
  
    @AuraEnabled
    public static List<CDocuSign_Envelope_Artifact__c> GetEnvelopeArtifactsByCaseID(ID caseID) {
      Id profileId = userinfo.getProfileId();
      String profileName = [SELECT Id, Name FROM Profile WHERE Id = :profileId].Name;
      Boolean includeZip = false;
  
      if (profileName == 'System Administrator' || profileName == 'OPS Manager') {
        includeZip = true;
      }

      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      External_Configurations__c endpoint = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'GET DOCUSIGN ARTIFACT ENDPOINT' LIMIT 1];
  
      List<CDocuSign_Envelope_Artifact__c> toReturn  = new List<CDocuSign_Envelope_Artifact__c> ();

      if (includeZip)
      {
        toReturn = [SELECT Auto_Download_Failed__c, Downloaded__c, Artifact_Type__c, CreatedDate, CDocuSign_Envelope__c, CDocuSign_Envelope__r.Name, CDocuSign_Envelope__r.Envelope_ID__c, CDocuSign_Envelope__r.CDocuSign_Template__r.Template_Name_Short__c, CDocuSign_Envelope__r.CDocuSign_Template__r.Template_Name__c, CDocuSign_Envelope__r.Envelope_Status__c, File_Extension__c, File_Name__c, Id, Name, URL__c FROM CDocuSign_Envelope_Artifact__c WHERE CDocuSign_Envelope__r.Case__c = :caseID AND CDocuSign_Envelope__r.Task_ID__c != ''];
      }
      else {
        toReturn = [SELECT Auto_Download_Failed__c, Downloaded__c, Artifact_Type__c, CreatedDate, CDocuSign_Envelope__c, CDocuSign_Envelope__r.Name, CDocuSign_Envelope__r.Envelope_ID__c, CDocuSign_Envelope__r.CDocuSign_Template__r.Template_Name_Short__c, CDocuSign_Envelope__r.CDocuSign_Template__r.Template_Name__c, CDocuSign_Envelope__r.Envelope_Status__c, File_Extension__c, File_Name__c, Id, Name, URL__c FROM CDocuSign_Envelope_Artifact__c WHERE CDocuSign_Envelope__r.Case__c = :caseID AND CDocuSign_Envelope__r.Task_ID__c != '' AND (Artifact_Type__c != 'Envelope ZIP' or Auto_Download_Failed__c = true)];
      }
  
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  


      for (CDocuSign_Envelope_Artifact__c a : toReturn) {
        if (string.isBlank(a.URL__c)) {
          //a.URL__c = endpoint.ConfigValue__c + '?sfInstanceName=' + instanceName.ConfigValue__c + '&envelopeID=' + a.CDocuSign_Envelope__r.Envelope_ID__c + '&artifactType=' + EncodingUtil.urlEncode(a.Artifact_Type__c, 'UTF-8') + '#toolbar=0';
          a.URL__c = endpoint.ConfigValue__c + '?token1=' + encodingUtil.URLEncode(EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(instanceName.ConfigValue__c))), 'UTF-8') + '&token2=' + encodingUtil.URLEncode(EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(a.File_Name__c))), 'UTF-8') + '&artifactID=' + encodingUtil.URLEncode(a.Id, 'UTF-8') + '&queue=true' + '#toolbar=0';
        }
      }
      return toReturn;
    }
  
    @AuraEnabled
    public static CDocuSign_Envelope_Artifact__c GetEnvelopeArtifactByArtifactID(ID artifactID) {
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      CDocuSign_Envelope_Artifact__c toReturn = [SELECT Downloaded__c, Artifact_Type__c, CreatedDate, CDocuSign_Envelope__c, CDocuSign_Envelope__r.Name, CDocuSign_Envelope__r.Envelope_ID__c, CDocuSign_Envelope__r.CDocuSign_Template__r.Template_Name_Short__c, CDocuSign_Envelope__r.CDocuSign_Template__r.Template_Name__c, CDocuSign_Envelope__r.Envelope_Status__c, File_Extension__c, File_Name__c, Id, Name, URL__c FROM CDocuSign_Envelope_Artifact__c WHERE Id = :artifactID];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  
      External_Configurations__c endpoint = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'GET DOCUSIGN ARTIFACT ENDPOINT' LIMIT 1];
  
      if (string.isBlank(toReturn.URL__c)) {
        toReturn.URL__c = endpoint.ConfigValue__c + '?token1=' + encodingUtil.URLEncode(EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(instanceName.ConfigValue__c))), 'UTF-8') + '&token2=' + encodingUtil.URLEncode(EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(toReturn.File_Name__c))), 'UTF-8') + '&artifactID=' + encodingUtil.URLEncode(toReturn.Id, 'UTF-8') + '&queue=true' + '#toolbar=0';
      }
  
      return toReturn;
    }
  
    @AuraEnabled
    public static CDocuSign_Envelope_Artifact__c GetEnvelopeArtifactByEnvelopeIDAndArtifactType(ID envelopeID, string artifactType) {
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      External_Configurations__c instanceName = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'OSS_BUCKET' LIMIT 1];
      CDocuSign_Envelope_Artifact__c toReturn = [SELECT Downloaded__c, Artifact_Type__c, CreatedDate, CDocuSign_Envelope__c, CDocuSign_Envelope__r.Name, CDocuSign_Envelope__r.Envelope_ID__c, CDocuSign_Envelope__r.CDocuSign_Template__r.Template_Name_Short__c, CDocuSign_Envelope__r.CDocuSign_Template__r.Template_Name__c, CDocuSign_Envelope__r.Envelope_Status__c, File_Extension__c, File_Name__c, Id, Name, URL__c FROM CDocuSign_Envelope_Artifact__c WHERE CDocuSign_Envelope__c = :envelopeID AND Artifact_Type__c = :artifactType];
      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  
      External_Configurations__c endpoint = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'GET DOCUSIGN ARTIFACT ENDPOINT' LIMIT 1];
  
      if (string.isBlank(toReturn.URL__c)) {
        toReturn.URL__c = endpoint.ConfigValue__c + '?token1=' + encodingUtil.URLEncode(EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(instanceName.ConfigValue__c))), 'UTF-8') + '&token2=' + encodingUtil.URLEncode(EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(toReturn.File_Name__c))), 'UTF-8') + '&artifactID=' + encodingUtil.URLEncode(toReturn.Id, 'UTF-8') + '&queue=true' + '#toolbar=0';
        //toReturn.URL__c = endpoint.ConfigValue__c + '?sfInstanceName=' + instanceName.ConfigValue__c + '&envelopeID=' + toReturn.CDocuSign_Envelope__r.Envelope_ID__c + '&artifactType=' + EncodingUtil.urlEncode(toReturn.Artifact_Type__c, 'UTF-8') + '#toolbar=0';
      }
  
      return toReturn;
    }
  
    @AuraEnabled
    public static string GenerateAccessToken(Integer len, Boolean exludeOandZero) {
      String chars = '';
  
      if (exludeOandZero) {
        chars = 'ABCDEFGHIJKMNPQRSTUVWXYZ123456789';
      } else {
        chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      }
  
      String randStr = '';
      while (randStr.length() < len) {
        Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
        randStr += chars.substring(idx, idx + 1);
      }
      return randStr;
    }
}
