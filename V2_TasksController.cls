@RestResource(urlMapping='/Task/*')

global with sharing class V2_TasksController {
    private class applicationException extends Exception {
    }

    @AuraEnabled
    public static List<Task> GetOpenTasks(Id caseId){
        return [SELECT Non_Contact_Entity__c, Non_Contact_Entity_Name__c, Id,FollowUpTaskID__c,RecordTypeId,RecordType.Name,Task_Occured_Due_Date__c, Task_Reason__c,Status, Owner.Name, Milestone__c FROM Task where WhatId = :caseId and RecordTypeId != null and IsClosed = false order by Task_Occured_Due_Date__c desc];
    }

    @AuraEnabled
    public static List<Task> GetCompletedTasks(Id caseId) 
    {
       return [SELECT Non_Contact_Entity__c, Non_Contact_Entity_Name__c,Id,FollowUpTaskID__c,RecordTypeId,RecordType.Name,Task_Occured_Due_Date__c, Task_Reason__c,Status, Owner.Name, Milestone__c,CompletedDateTime, Task_Disposition__c, Description FROM Task where WhatId = :caseId and RecordTypeId != null and IsClosed = true order by CompletedDateTime desc];
    }       
  
    @AuraEnabled
    public static List<RecordType> GetTaskRecordTypes() {
        return V2_Utility.GetRecordTypesForObject('Task');
    }
  
    @AuraEnabled
    public static List<RecordType> GetContactRecordTypes() {
        return V2_Utility.GetRecordTypesForObject('Contact');
    }
  
    @AuraEnabled
    public static List<String> getPicklistvalues(String objectName, String field_apiname, Boolean nullRequired) {
      return V2_Utility.getPicklistvalues(objectName, field_apiname, nullRequired);
    }

    @AuraEnabled
    public static List<String> getDocuSignTemplatePickListValuesSelectSingleForSmartDocument(String objectName, String field_apiname, String sdFileId) {
      string docuSignTemplateString = '';
      List<SD_Template_Distribution__c> distList = SmartDocumentController.GetDistributionListForSDFile(sdFileId);
      for (SD_Template_Distribution__c d: distList)
      {
        system.debug(d);

        if (d.Channel__c.toLowerCase()  == 'docusign')
        {
          docuSignTemplateString = d.DocuSign_Task_Template__c;
          
          break;
        }
      }


      List<String> pickListValues = new List<String>();
  
      for (string pvalue: V2_Utility.getPicklistvalues(objectName, field_apiname, false))
      {
        system.debug(pvalue);
        if (pvalue.toLowerCase() == docuSignTemplateString.toLowerCase()) {
          pickListValues.Add(pvalue);
            break;
        }
      }

      return pickListValues;
    }


    
    @AuraEnabled
    public static List<String> getDocuSignTemplatePickListValuesWithFilterOption(String objectName, String field_apiname, Boolean nullRequired, String caseId, Boolean filterOnCaseType) {
      Profile profile = V2_Utility.GetUserProfile();

      List<String> pickListValues = new List<String>();
      List<String> pickListValuesFiltered = new List<String>();
  
      pickListValues = V2_Utility.getPicklistvalues(objectName, field_apiname, nullRequired);
  
      if (filterOnCaseType) {
        Case c = [SELECT Id, Type FROM Case WHERE Id = :caseId];
  
        if (c.Type != 'Unknown') {
          for (String pvalue : pickListValues) {
            if (c.Type == 'ENRP') {
              if (pvalue.Contains('ENRP') || pvalue.Contains('HIPAA')) {
                  pickListValuesFiltered.Add(pvalue);
              }
            } else if (c.Type == 'MNRP') {
              if (pvalue.Contains('MNRP') || pvalue.Contains('HIPAA')) {
                  pickListValuesFiltered.Add(pvalue);
              }
            }
          }
          pickListValues = pickListValuesFiltered;
        }
      }
  
      return pickListValues;
    }
  
    @AuraEnabled
    public static task UpdateTask(Task task, Boolean docusignVoidRequested) {
      update task;
  
      RecordType recType = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE SobjectType = 'Task' AND Id = :task.RecordTypeId];
      Case cse = [SELECT Id, Origin FROM Case WHERE Id = :task.WhatId];
      
      if(recType.DeveloperName == 'Log_a_Call' &&
        task.Task_Reason__c == 'Provider Outreach' && 
        task.Task_Disposition__c == 'Spoke with Provider Billing' &&
        task.Status == 'Completed'){
          Negotiation_Prep__c negotiationPrep = V2_CaseDetailController.GetNegotiationPrep(cse.Id);
          if(negotiationPrep.Initial_Provider_Contact_Date__c == null){
              negotiationPrep.Initial_Provider_Contact_Date__c =date.valueof( task.Task_Occured_Due_Date__c);
              update negotiationPrep;                  
          }
      }
     //added by Yogi date:-03/25/21, task:- TA10128714
      if(recType.DeveloperName == 'Log_a_Call' && cse.Origin != 'Provider' &&
        task.Task_Reason__c == 'Member Outreach' && 
        task.Task_Disposition__c == 'Spoke with Member' &&
        task.Status == 'Completed'){
          Engagement__c engagement = V2_CaseDetailController.GetEngagement(cse.Id);
          if(engagement.Date_of_Patient_Contact__c == null){
              engagement.Date_of_Patient_Contact__c =date.valueof( task.Task_Occured_Due_Date__c);
              update engagement;                  
          }
      }

      if (recType.DeveloperName == 'DocuSign' && task.Status == 'Request Queued') {
        CDocuSign_Envelope_Artifact__c a = [SELECT Id, File_Name__c FROM CDocuSign_Envelope_Artifact__c WHERE CDocuSign_Envelope__c = :task.CDocuSign_Envelope__r.Id LIMIT 1];
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Id = task.CDocuSign_Envelope__r.Id;
        env.Task_ID__c = task.Id;
        update env;
  
        Integration_Task__c it;

        
        if (docusignVoidRequested == true) {
          it = V2_DocuSignController.CreateSPITRecordForDocusignVoid(task.CDocuSign_Envelope__r.Envelope_ID__c, task.CDocuSign_Envelope__r.Id, task.Id, a.File_Name__c);
        } else {
          it = V2_DocuSignController.CreateSPITRecordForDocusignSendDraft(task.CDocuSign_Envelope__r.Envelope_ID__c, task.CDocuSign_Envelope__r.Id, task.Id, a.File_Name__c);
        }

  
        task.Integration_Task__c = it.Id;
        update task;
        task.Integration_Task__r = it;
      }
      else if (string.isblank(task.Integration_Task__c) && recType.DeveloperName == 'Update_ORS' && task.Status == 'Request Queued') {
        task = CreateIntegrationTaskFroUpdateORS(task);
      }  

  
      Case toUpdateCase = new Case();
      toUpdateCase.Id = task.WhatId;
      update toUpdateCase;
  
      return task;
    }
  
    @AuraEnabled
    public static void UpdateTaskFollowUpId(Id taskIDToUpdate, String followUpTaskID) {
      Task toUpdate = GetTask(taskIDToUpdate);
  
      if (Schema.sObjectType.Task.fields.FollowUpTaskID__c.isUpdateable()) {
        toUpdate.FollowUpTaskID__c = followUpTaskID;
      }
  
      update toUpdate;
  
      //lets trigger an update on the related case JUST so the lastmodified date gets updated - therefore last activity forumla field also gets updated.
      Case toUpdateCase = new Case();
      toUpdateCase.Id = toUpdate.WhatId;
      update toUpdateCase;
    }
  
    @AuraEnabled
    public static Integration_Task__c GetSPITRecord(Id id) {
      Integration_Task__c it = IntegrationTask.GetIntegrationTask(id);
      return it;
    }
  
    @AuraEnabled
    public static Task CreateIntegrationTaskFroUpdateORS(Task task){
      
        Case cse = [SELECT Id, Case.ORS_Number__r.Name FROM Case WHERE Id = :task.WhatId];

        External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
        External_Configurations__c benchmarkURL = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_API_Root_URL' LIMIT 1];
        Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
  
        string encTOPSUserID;
        string encTOPSPass;
  
        string PARM1 = cse.ORS_Number__r.Name;
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
        string TaskType;
        string RelatedTask;
  
        string userId = UserInfo.getUserId();
        User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c FROM User WHERE Id = :userId LIMIT 1];
  
        if (user.TOPS_User_ID__c != null && user.TOPS_User_ID__c != '' && user.TOPS_Password__c != null && user.TOPS_Password__c != '') {
          string tops_user_id = user.TOPS_User_ID__c;
          string tops_password = user.TOPS_Password__c;
  
          Blob cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(tops_user_id));
          String encodedCipherText = EncodingUtil.base64Encode(cipherText);
          PARM2 = encodingUtil.URLEncode(encodedCipherText, 'UTF-8');
  
          cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(tops_password));
          encodedCipherText = EncodingUtil.base64Encode(cipherText);
          PARM3 = encodingUtil.URLEncode(encodedCipherText, 'UTF-8');
        }
  
        PARMBIG1 = task.Description;
        if (task.Task_Reason__c == 'Add Comments to ORS Record') {
          TaskType = 'ADD ORS COMMENT';
        } else if (task.Task_Reason__c == 'Route ORS Record') {
          TaskType = 'ROUTE ORS RECORD';
          PARM4 = task.V2_ORS_Route_To__c;
        } else if (task.Task_Reason__c == 'Change status of ORS Record') {
          TaskType = 'UPDATE ORS STATUS';
          if (task.ORS_Status__c == 'Closed') {
            PARM4 = 'C';
          }
        }
        RelatedTask = task.Id;
  
        Integration_Task__c it = IntegrationTask.createIntegrationTask(TaskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
        task.Integration_Task__c = it.Id;
        
        if (V2_Utility.isTrainingModeOn())
        {
          task.Task_Disposition__c = 'Completed';
          task.Status = 'Completed';
        }

        update task;
  
        task.Integration_Task__r = it;
  
        Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
        String encodedGUIDText = EncodingUtil.base64Encode(guidText);
        it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');

        return task;
      
    }
    
    @AuraEnabled
    public static Task CreateTask(Task task, string sdFileId) {
      Case cse = [SELECT Id, CaseNumber, Origin, Patient_Name__c, Case.ORS_Number__r.Name FROM Case WHERE Id = :task.WhatId];
      RecordType recType = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE SobjectType = 'Task' AND Id = :task.RecordTypeId];
      task.Subject = recType.Name + ' Case: ' + cse.CaseNumber + ' Patient: ' + cse.Patient_Name__c;
  
      insert task;

      if(recType.DeveloperName == 'Log_a_Call' &&
        task.Task_Reason__c == 'Provider Outreach' && 
        task.Task_Disposition__c == 'Spoke with Provider Billing' &&
        task.Status == 'Completed'){
          Negotiation_Prep__c negotiationPrep = V2_CaseDetailController.GetNegotiationPrep(cse.Id);
          if(negotiationPrep.Initial_Provider_Contact_Date__c == null){
              negotiationPrep.Initial_Provider_Contact_Date__c =date.valueof( task.Task_Occured_Due_Date__c);
              update negotiationPrep;                  
          }
      }      
  
      //added by Yogi date:-03/25/21, task:- TA10128714
      if(recType.DeveloperName == 'Log_a_Call' && cse.Origin != 'Provider' &&
        task.Task_Reason__c == 'Member Outreach' && 
        task.Task_Disposition__c == 'Spoke with Member' &&
        task.Status == 'Completed'){
          Engagement__c engagement = V2_CaseDetailController.GetEngagement(cse.Id);
          if(engagement.Date_of_Patient_Contact__c == null){
              engagement.Date_of_Patient_Contact__c =date.valueof( task.Task_Occured_Due_Date__c);
              update engagement;                  
          }
      }

      //lets trigger an update on the related case JUST so the lastmodified date gets updated - therefore last activity forumla field also gets updated.
      Case toUpdateCase = new Case();
      toUpdateCase.Id = cse.Id;
      update toUpdateCase;

      system.debug(sdFileId);
      //update the SD_File__c IF one is passed in
      if (string.isnotblank(sdFIleId))
      {
        SD_File__c sdFileObject = new SD_File__c();
        sdFileObject.Id = sdFileId;
        sdFileObject.DocuSign_Task__c = task.Id;
        update sdFileObject;
      }
  
      //create the integration task record IF needed
      if (recType.DeveloperName == 'Update_ORS' && task.Status == 'Request Queued') {

        task = CreateIntegrationTaskFroUpdateORS(task);

      } else if (recType.DeveloperName == 'DocuSign' && task.Status == 'Request Queued') {
        CDocuSign_Envelope_Artifact__c a = [SELECT Id, File_Name__c FROM CDocuSign_Envelope_Artifact__c WHERE CDocuSign_Envelope__c = :task.CDocuSign_Envelope__r.Id LIMIT 1];
  
        Integration_Task__c it = V2_DocuSignController.CreateSPITRecordForDocusignSendDraft(task.CDocuSign_Envelope__r.Envelope_ID__c, task.CDocuSign_Envelope__r.Id, task.Id, a.File_Name__c);
  
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Id = task.CDocuSign_Envelope__r.Id;
        env.Task_ID__c = task.Id;
        update env;
  
        task.Integration_Task__c = it.Id;
        update task;
        task.Integration_Task__r = it;
      }
  
      //lets make sure we are updating the envelope with the related task id
      if (recType.DeveloperName == 'DocuSign' && task.Status == 'Pending' && task.CDocuSign_Envelope__r.Envelope_Status__c == 'Created') {
        CDocuSign_Envelope__c env = new CDocuSign_Envelope__c();
        env.Task_ID__c = task.Id;
        env.Id = task.CDocuSign_Envelope__r.Id;
        update env;
        task.CDocuSign_Envelope__r.Task_ID__c = task.Id;
      }
  
      RecordType recTypeAttachAFile = [SELECT Id, DeveloperName FROM RecordType WHERE DeveloperName = 'Attach_a_File' LIMIT 1];
  
      //Attach a File
      if (task.RecordTypeId == recTypeAttachAFile.Id) {
        if (task.Task_Attachment__c == 'Provider Bill') {
  
          Id outreachId = CaseCompletionController.getOrCreateOutreachId(task.WhatId);
  
          Outreach__c out = [SELECT Id, Name, Balance_Bills_Received__c FROM Outreach__c WHERE Id = :outreachId LIMIT 1];
          out.Balance_Bills_Received__c = date.newinstance(task.Task_Occured_Due_Date__c.year(), task.Task_Occured_Due_Date__c.month(), task.Task_Occured_Due_Date__c.day());
  
          update out;
        }
  
        if (task.Task_Attachment__c == 'HIPPA Authorization') {
          Case c = [SELECT Id, HIPPA_Consent__c FROM Case WHERE Id = :task.WhatId LIMIT 1];
          c.HIPPA_Consent__c = true;
  
          update c;
        }
  
        if (task.Task_Attachment__c == 'Consent to Negotiate') {
          Case c = [SELECT Id, Authorization_for_Assistance__c FROM Case WHERE Id = :task.WhatId LIMIT 1];
          c.Authorization_for_Assistance__c = true;
  
          update c;
        }
      }


      return task;
    }
  
    @AuraEnabled
    public static Task GetTask(Id taskId) {
      Task toReturn = new Task();
  
      toReturn = [
        SELECT
          AccountId,
          ActivityDate,
          CallDisposition,
          CallDurationInSeconds,
          CallObject,
          CallType,
          Case_Number__c,
          Case__c,
          CDocuSign_Envelope__c,
          CDocuSign_Envelope__r.Id,
          CDocuSign_Envelope__r.Envelope_Status__c,
          CDocuSign_Envelope__r.Envelope_ID__c,
          CDocuSign_Envelope__r.CDocuSign_Template__c,
          CDocuSign_Envelope__r.Integration_Task__c,
          CDocuSign_Envelope__r.Ready_to_Send__c,
          CDocuSign_Envelope__r.Task_ID__c,
          CEmail_Message__c,
          CompletedDateTime,
          CreatedById,
          CreatedDate,
          Description,
          DocuSign_Template__c,
          Duration_minutes__c,
          Email_Address__c,
          FollowUpTaskID__c,
          Follow_Up_Comments__c,
          Follow_Up_Reminder_Date__c,
          Id,
          Integration_Task__c,
          IsArchived,
          IsClosed,
          IsDeleted,
          IsHighPriority,
          IsRecurrence,
          IsReminderSet,
          LastModifiedById,
          LastModifiedDate,
          Mailing_Address__c,
          Milestone__c,
          ORS_Route_To__c,
          V2_ORS_Route_To__c,
          ORS_Status__c,
          Other_Disposition_Comments__c,
          Other_Reason_Comment__c,
          OwnerId,
          Patient_Name__c,
          Phone_Number__c,
          Priority,
          RecordTypeId,
          RecurrenceActivityId,
          RecurrenceDayOfMonth,
          RecurrenceDayOfWeekMask,
          RecurrenceEndDateOnly,
          RecurrenceInstance,
          RecurrenceInterval,
          RecurrenceMonthOfYear,
          RecurrenceRegeneratedType,
          RecurrenceStartDateOnly,
          RecurrenceTimeZoneSidKey,
          RecurrenceType,
          ReminderDateTime,
          Status,
          Subject,
          SystemModstamp,
          TaskSubtype,
          Task_Attachment__c,
          Task_Comments__c,
          Task_Disposition__c,
          Task_Occured_Due_Date__c,
          Task_Reason__c,
          Task_Source__c,
          Type,
          WhatId,
          WhoId,
          Non_Contact_Entity__c, Non_Contact_Entity_Name__c
        FROM Task
        WHERE Id = :taskId
        LIMIT 1
      ];
  
      RecordType recType = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE SobjectType = 'Task' AND Id = :toReturn.RecordTypeId];
  
      if (recType.DeveloperName == 'DocuSign' && string.isBlank(toReturn.CDocuSign_Envelope__c)) {
        CDocuSign_Envelope__c e = new CDocuSign_Envelope__c();
        e.Envelope_Status__c = 'Not Created';
        e.Ready_to_Send__c = false;
        toReturn.CDocuSign_Envelope__r = e;
        toReturn.CDocuSign_Envelope__c = null;
      }
  
      return toReturn;
    }
  
    @AuraEnabled
    public static Task InitTask(Id CaseID, RecordType RecordTypeToSet, Id TaskID) {
      String taskReason;

  
      List<External_Configurations__c> extConfigs = GetExternalConfigs();
  
      Task t = new Task(RecordTypeId = RecordTypeToSet.Id, Task_Reason__c = taskReason, OwnerId = UserInfo.getUserId(), Task_Occured_Due_Date__c = System.Now(), WhatId = CaseID, Priority = 'Normal', Case__c = CaseID);
  
      if (RecordTypeToSet.DeveloperName == 'Alert') {
        //set our defaults
        t.Task_Attachment__c = 'Not Applicable';
        t.Task_Source__c = 'Inbound';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Pending';
      } else if (RecordTypeToSet.DeveloperName == 'Log_a_Call') {
        //set our defaults
        //t.Task_Disposition__c = 'Spoke with Member';
        t.Task_Attachment__c = 'Not Applicable';
        t.Task_Source__c = 'Outbound';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Completed';
      } else if (RecordTypeToSet.DeveloperName == 'Log_an_Email') {
        //set our defaults
        //t.Task_Disposition__c = 'Completed';
        t.Task_Attachment__c = 'Not Applicable';
        t.Task_Source__c = 'Outbound';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Completed';
      } else if (RecordTypeToSet.DeveloperName == 'Log_a_Letter') {
        //set our defaults
        //t.Task_Disposition__c = 'Completed';
        t.Task_Attachment__c = 'Not Applicable';
        t.Task_Source__c = 'Outbound';
        t.Mailing_Address__c = 'Primary Mailing Address';
        t.Status = 'Completed';
      } else if (RecordTypeToSet.DeveloperName == 'Post_a_Comment') {
        //set our defaults
        t.Task_Reason__c = 'Providing Status or Clarification';
        t.Task_Disposition__c = 'Completed';
        t.Task_Attachment__c = 'Not Applicable';
        t.Task_Source__c = 'User Activity';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Completed';
      } else if (RecordTypeToSet.DeveloperName == 'Attach_a_File') {
        //set our defaults
        // string userId = UserInfo.getUserId();
  
        // Id profileId = userinfo.getProfileId();
        // String profileName = [SELECT Id, Name FROM Profile WHERE Id = :profileId].Name;
  
        // if (profileName == 'Advisor User') {
        //   t.Task_Source__c = 'User Activity';
        // }
        // if (profileName == 'Negotiator User') {
        //   t.Task_Source__c = 'Negotiator Activity';
        // }
  
        t.Task_Reason__c = 'Load Reference File';
        t.Task_Disposition__c = 'Completed';
        //t.Task_Attachment__c = '--None--';
        t.Task_Source__c = 'User Activity';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Completed';
      } else if (RecordTypeToSet.DeveloperName == 'Update_ORS') {
        //set our defaults
        t.Task_Reason__c = 'Add Comments to ORS Record';
        t.Task_Disposition__c = 'Completed';
        t.Task_Attachment__c = 'Not Applicable';
        t.Task_Source__c = 'User Activity';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Request Queued';
  
        for (External_Configurations__c ec : extConfigs) {
          if (ec.Name == 'SPIT STATUS' && ec.ConfigValue__c == 'ON') {
            t.Status = 'Request Queued';
          }
        }
      } else if (RecordTypeToSet.DeveloperName == 'Schedule_a_Meeting') {
        //set our defaults
        t.Task_Reason__c = 'Request for Additional Info';
        t.Task_Disposition__c = 'Completed';
        t.Task_Attachment__c = 'Not Applicable';
        t.Task_Source__c = 'User Activity';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Completed';
      } else if (RecordTypeToSet.DeveloperName == 'Attend_a_Meeting') {
        //set our defaults
        t.Task_Reason__c = 'Request for Additional Info';
        t.Task_Disposition__c = 'Completed';
        t.Task_Attachment__c = 'Not Applicable';
        t.Task_Source__c = 'User Activity';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Completed';
      } else if (RecordTypeToSet.DeveloperName == 'DocuSign') {
        //set our defaults
        CDocuSign_Envelope__c e = new CDocuSign_Envelope__c();
        e.Envelope_Status__c = 'Not Created';
        e.Ready_to_Send__c = false;
        t.CDocuSign_Envelope__r = e;
        t.CDocuSign_Envelope__c = null;
        t.Task_Reason__c = 'DocuSign Sent';
        t.Task_Disposition__c = 'Pending';
        t.Task_Source__c = 'User Activity';
        t.Mailing_Address__c = 'Not Applicable';
        t.Status = 'Pending';
        t.Follow_Up_Reminder_Date__c = t.Task_Occured_Due_Date__c;
      }
  
      //if the incoming TaskID is SET then we are initializing a the task using the passed in TaskID's info
      if (!String.isBlank(TaskID)) {
        Task toCloneFrom = GetTask(TaskID);
  
        t.Email_Address__c = toCloneFrom.Email_Address__c;
        t.Phone_Number__c = toCloneFrom.Phone_Number__c;
        t.WhoId = toCloneFrom.WhoId;
        t.Status = 'Pending';
        t.Non_Contact_Entity__c = toCloneFrom.Non_Contact_Entity__c;
        t.Non_Contact_Entity_Name__c = toCloneFrom.Non_Contact_Entity_Name__c;
      }
  
      return t;
    }
  
    @AuraEnabled
    public static List<Contact> getEnroleeContactsForCaseId(id caseId) {
      List<Contact> contacts = new List<Contact>();
  
      Case cse = [SELECT Case.Id, Case.Provider_ID__r.id, Case.Patient_ID__r.id FROM Case WHERE Case.Id = :caseId];
  
      Patient__c[] patient = [SELECT id, name, Enrolee_ID__r.id FROM Patient__c WHERE id = :cse.Patient_ID__r.id];
  
      if (patient.size() > 0) {
        //System.debug('enrolee yup');
  
        Enrolee__c[] enrolee = [SELECT id, name, Employer_Group_ID__r.id FROM Enrolee__c WHERE id = :patient[0].Enrolee_ID__r.id];
  
        if (enrolee.size() > 0) {
          contacts = [SELECT id, name, Role__c, Email, Preferred_Phone_Type__c, HomePhone, MobilePhone, OtherPhone, Work_Phone__c FROM Contact WHERE Enrolee__r.id = :enrolee[0].id];
        }
      }
  
      return contacts;
    }
  
    @AuraEnabled
    public static List<Contact> getContactsForCaseId(id caseId) {
      List<Contact> contacts = new List<Contact>();
      Case cse = [Select Id, Patient_ID__c,Billing_Provider_Group__c ,Billing_Agency__c from Case where Id = :caseId];

      Profile profile = V2_Utility.GetUserProfile();

      if (profile.Name == 'Advisor User')
      {
        contacts = V2_ContactsController.GetFamilyContactsForPatient(cse.Patient_ID__c);
      }
      else if (profile.Name == 'Negotiator User' || profile.Name == 'Liaison Specialist User')
      {
        if (!string.isblank(cse.Billing_Provider_Group__c))
        {
          contacts = V2_ContactsController.GetBillingProviderGroupContacts(cse.Billing_Provider_Group__c);
        }

        if (!string.isblank(cse.Billing_Agency__c))
        {
          contacts.addAll(V2_ContactsController.GetBillingAgencyContacts(cse.Billing_Agency__c));
        }
      }
      else if (profile.Name == 'OPS Manager' ||
               profile.Name == 'System Administrator') 
      {
        contacts = V2_ContactsController.GetFamilyContactsForPatient(cse.Patient_ID__c);

        if (!string.isblank(cse.Billing_Provider_Group__c))
        {
          contacts.addAll(V2_ContactsController.GetBillingProviderGroupContacts(cse.Billing_Provider_Group__c));
        }

        if (!string.isblank(cse.Billing_Agency__c))
        {
          contacts.addAll(V2_ContactsController.GetBillingAgencyContacts(cse.Billing_Agency__c));
        }
      }
  
      return contacts;
    }


    @AuraEnabled
    public static List<Contact> getContactsForTaskId(id taskId) {
      List<Contact> contacts = new List<Contact>();
      Task tsk = [SELECT Id, WhatId FROM Task WHERE Id = :taskId];
  
      contacts = getContactsForCaseId(tsk.WhatId);
  
      return contacts;
    }

    @AuraEnabled
    public static List<Contact> GetNaviguardSigneeContacts() {
      return V2_ContactsController.GetNaviguardSigneeContacts();
    }

    // @AuraEnabled
    // public static List<Contact> getContactsForTaskId(id taskId) {
    //   List<Contact> contacts = new List<Contact>();
    //   Task tsk = [SELECT Id, WhatId FROM Task WHERE Id = :taskId];
  
    //   contacts = CustomRelatedContactsController.getContacts(tsk.WhatId, 'Case Related');
  
    //   return contacts;
    // }
  
    @AuraEnabled
    public static List<User> getUsers() {
      List<User> users = new List<User>();
      User currentuser = new User();
      string userId = UserInfo.getUserId();
  
      currentuser = [SELECT Id, Email, IsActive, FirstName, LastName, Name, Profile.Name, TOPS_User_ID__c, TOPS_Password__c FROM User WHERE Id = :userId];
  
      users.add(currentuser);
  
      users.addAll([SELECT Id, Email, IsActive, FirstName, LastName, Name, Profile.Name FROM User WHERE UserType = 'Standard' AND name != 'INT_USER' AND Id != :userId]);
  
      return users;
    }
  
    @AuraEnabled
    public static User getCurrentUserCredentials() {
      string userId = UserInfo.getUserId();
      User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c FROM User WHERE Id = :userId LIMIT 1];
  
      return user;
    }
  
    @AuraEnabled
    public static List<External_Configurations__c> GetExternalConfigs() {
      return V2_Utility.GetExternalConfigs();
    }
  
    @AuraEnabled
    public static string GenerateGUID() {
      return V2_Utility.NewGuid();
    }
  
    @AuraEnabled
    public static CDocuSign_Envelope__c GetEnvelopeByID(Id envelopeId) {
      try {
        return V2_DocuSignController.GetEnvelopeByID(envelopeId);
      } catch (Exception e) {
        return null;
      }
    }

    @AuraEnabled
    public static Task CreateTaskFromFollowUpORSAction(Follow_Up_ORS_Action__c orsAction) {
      Case cse = [Select Id, Origin,Assigned_Follow_Up_Advisor__c from Case where Id = :orsAction.Case__c];

      //if it s a provder type case, we need to make sure we use the assigned advisor when creating this task
      if (cse.Origin == 'Provider')
      {
        return CreateTaskUtility('Update_ORS', orsAction.Case__c, cse.Assigned_Follow_Up_Advisor__c, orsAction.ORS_Comments__c, orsAction.ORS_Action_Type__c, false, false, (orsAction.ORS_Action_Type__c == 'Route ORS Record'? GetORSRoute(orsAction.Case__c): ''), orsAction.ORS_Status__c, false);
      }
      else {
        return CreateTaskUtility('Update_ORS', orsAction.Case__c, '', orsAction.ORS_Comments__c, orsAction.ORS_Action_Type__c, true, false, (orsAction.ORS_Action_Type__c == 'Route ORS Record'? GetORSRoute(orsAction.Case__c): ''), orsAction.ORS_Status__c, false);
      }
    }   

    
    @AuraEnabled
    public static Task CreateTaskUtility(string taskType, Id caseId, string ownerId, string comments, string taskReason, boolean caseOwnerIsTaskOwner, boolean setReminder, string orsRouteTo, string orsStatus, boolean markTaskCompleted) {
      Task toReturn = new Task();

      if (taskType == 'Alert')
      {
        toReturn = CreateAlertTask(caseId, ownerId, comments, taskReason, caseOwnerIsTaskOwner, setReminder, markTaskCompleted);
      }
      else if (taskType == 'Update_ORS')
      {
        if (taskReason == 'Add Comments to ORS Record')
        {
          toReturn = CreateORSCommentTask(caseId, ownerId, comments, caseOwnerIsTaskOwner, setReminder, markTaskCompleted);
        }
        else if (taskReason == 'Route ORS Record')
        {
          toReturn = CreateORSRouteToTask(caseId, ownerId, comments, caseOwnerIsTaskOwner, setReminder, orsRouteTo, markTaskCompleted);
        }
        else if (taskReason == 'Change status of ORS Record')
        {
          toReturn = CreateORSChangeStatus(caseId, ownerId, comments, caseOwnerIsTaskOwner, setReminder, orsStatus, markTaskCompleted);
        }        
      }

      return toReturn;
    }

    @HttpPost
    @AuraEnabled
    global static Task_Queue__c QueueTask(Task_Queue__c qTask){
        insert qTask;
        return qTask;
    }

    @AuraEnabled
    public static void UpdateTaskQueueSpitStatusAsExecuted(Id taskQueueId, boolean errorEncountered) {
      Task_Queue__c toUpdate = new Task_Queue__c();
      toUpdate.Id = taskQueueId;
      toUpdate.Spit_Executed__c = true;
      toUpdate.Completed__c = true;
      toUpdate.Error_Encountered__c = errorEncountered;
      update toUpdate;
    }

    
    @AuraEnabled
    public static List<Task_Queue__c> GetTasksQueuedForCreation(Id caseId) {
      string userId = UserInfo.getUserId();

      Case cse = V2_CaseDetailController.GetCaseDetail(caseId);

      List<Task_Queue__c> queuedTaskList = [SELECT Case__c
                                         ,CreatedById
                                         ,CreatedDate
                                         ,Id
                                         ,Milestone_Trigger__c
                                         ,Set_Reminder__c
                                         ,Status_Trigger__c
                                         ,Task_Comments__c
                                         ,Task_Owner_Is_Case_Owner__c
                                         ,Task_Owner__c
                                         ,Task_Reason__c
                                         ,Task_Type__c
                                         ,ORS_Status__c
                                         ,ORS_Route_To_Override__c
                                         ,Created_Task__c           
                                         ,Integration_Task__c     
                                         ,Automation_Type__c
                                         ,Spit_Executed__c
                                    FROM Task_Queue__c 
                                    WHERE Case__c = :caseId 
                                      and Completed__c = false 
                                      and Voided__c = false 
                                      and ((Milestone_Trigger__c != '' and Milestone_Trigger__c = :cse.Milestone__c) OR Milestone_Trigger__c = '')
                                      and ((Status_Trigger__c != '' and Status_Trigger__c = :cse.Status) OR Status_Trigger__c = '')
                                      and ((Task_Owner__c != '' and Task_Owner__c = :userId) or Task_Owner__c = '')                                      
                                      and ((Task_Owner_Is_Case_Owner__c = true and Case__r.OwnerId = :userId) or Task_Owner_Is_Case_Owner__c = false)
                                      order by CreatedDate];

      //if there are ny queued tasks that meet the criteria and NOT in marked for IMMEDIATED EXECTION, that means we need to create them and leave them in an
      //open state now, so lets go ahead and do that.
      for (Task_Queue__c q: queuedTaskList)
      {

        if (q.Automation_Type__c == 'User' || q.Automation_Type__c == 'Logging Only')
        {
          boolean markTaskAsCompleted = (q.Automation_Type__c == 'User'? false : true);
          Task createdTask = CreateTaskUtility(q.Task_Type__c, caseId, q.Task_Owner__c, q.Task_Comments__c, q.Task_Reason__c, q.Task_Owner_Is_Case_Owner__c, q.Set_Reminder__c, (q.Task_Reason__c == 'Route ORS Record'?  (string.isblank(q.ORS_Route_To_Override__c) ? GetORSRoute(caseId): q.ORS_Route_To_Override__c) :''), q.ORS_Status__c, markTaskAsCompleted);
          q.Completed__c = true;
          q.Created_Task__c = createdTask.Id;
          update q;
        }
        else
        {
          //right now we only support autocreating ors tasks, if others are needed, code accordingly
          if (q.Task_Type__c == 'Update_ORS')
          {
            //check and see if a task was created for this queue item, if it was then we don't need to create another
            if (string.isblank(q.Created_Task__c))
            {
              Task createdTask = CreateTaskUtility(q.Task_Type__c, caseId, q.Task_Owner__c, q.Task_Comments__c, q.Task_Reason__c, q.Task_Owner_Is_Case_Owner__c, q.Set_Reminder__c, (q.Task_Reason__c == 'Route ORS Record'?  (string.isblank(q.ORS_Route_To_Override__c) ? GetORSRoute(caseId): q.ORS_Route_To_Override__c) :''), q.ORS_Status__c, false);
              q.Completed__c = false;
              q.Created_Task__c = createdTask.Id;
              createdTask = CreateIntegrationTaskFroUpdateORS(createdTask);
              q.Integration_Task__c = createdTask.Integration_Task__r.Id;              
              update q;
              q.Integration_Task__r = IntegrationTask.GetIntegrationTask(q.Integration_Task__c);  
            }
            else {              
              q.Integration_Task__r = IntegrationTask.GetIntegrationTask(q.Integration_Task__c);  
            }
          }
        }
      }

      return queuedTaskList;
    }



    @AuraEnabled
    global static Task CreateAlertTask(Id caseId, string ownerId, string comments, string taskReason, boolean caseOwnerIsTaskOwner, boolean setReminder, boolean markTaskAsCompleted) {
      RecordType recType = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'Alert' LIMIT 1];
      Case cse = [SELECT Id, CaseNumber, Patient_Name__c, Case.ORS_Number__r.Name, OwnerId FROM Case WHERE Id = :caseId];
      Task task = InitTask(caseId, recType, null);

      task.Subject = recType.Name + ' Case: ' + cse.CaseNumber + ' Patient: ' + cse.Patient_Name__c;
      task.OwnerId = ownerId;

      if (taskReason == 'Digital General' || 
          taskReason == 'Digital Invite Unsuccessful' ||
          taskReason == 'Digital Bill Upload' ||
          taskReason == 'Digital Bill Not Uploaded' ||
          taskReason == 'Signatures Received' ||
          taskReason == 'Forms Not Signed' ||
          taskReason == 'Fax Send Unsuccessful' ||
          taskReason == 'Case Re-Opened' ||
          taskReason == 'Forms Not Signed' ||
          taskReason == 'Written Agreement Signatures Received' ||
          taskReason == 'Request for Signatures Unsuccessful')
      {      
        task.Task_Reason__c = taskReason;
        if (markTaskAsCompleted)
        {
          task.Task_Disposition__c = 'Completed';
          task.Status = 'Completed';
        }
        else {
          task.Task_Disposition__c = 'Pending';
          task.Status = 'Pending';
        }
        task.Task_Attachment__c = 'Not Applicable';
        task.Task_Source__c = 'Inbound';
        task.Mailing_Address__c = 'Not Applicable';
        task.Description = comments ;        
        task.Task_Occured_Due_Date__c = System.Now();
        
        if (caseOwnerIsTaskOwner)
        {
          task.OwnerId = cse.OwnerId;
        }
        else {
          task.OwnerId = ownerId;
        }

        if (setReminder == true)
        {
          task.IsReminderSet = true;
          task.ReminderDateTime = task.Task_Occured_Due_Date__c;
          task.ActivityDate = date.newinstance(task.Task_Occured_Due_Date__c.year(), task.Task_Occured_Due_Date__c.month(), task.Task_Occured_Due_Date__c.day());
          task.Follow_Up_Reminder_Date__c = task.Task_Occured_Due_Date__c;
        }
      }
      return CreateTask(task,'');
    }   

   

    @AuraEnabled
    global static Task CreateORSRouteToTask(Id caseId, string ownerId, string comments, boolean caseOwnerIsTaskOwner, boolean setReminder, string orsRouteTo, boolean markTaskAsCompleted) {
      RecordType recType = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'Update_ORS' LIMIT 1];
      Case cse = [SELECT Id, CaseNumber, Patient_Name__c, Case.ORS_Number__r.Name, OwnerId FROM Case WHERE Id = :caseId];
      Task task = InitTask(caseId, recType, null);

      if (caseOwnerIsTaskOwner)
      {
        task.OwnerId = cse.OwnerId;
      }
      else {
        task.OwnerId = ownerId;
      }

      task.Subject = recType.Name + ' Case: ' + cse.CaseNumber + ' Patient: ' + cse.Patient_Name__c;
      task.Task_Reason__c = 'Route ORS Record';
      task.V2_ORS_Route_To__c = orsRouteTo;
      if (markTaskAsCompleted)
      {
        task.Task_Disposition__c = 'Completed';
        task.Status = 'Completed';
      }
      else {
        task.Task_Disposition__c = 'Pending';
        task.Status = 'Pending';
      }
      task.Task_Attachment__c = 'Not Applicable';
      task.Task_Source__c = 'User Activity';
      task.Mailing_Address__c = 'Not Applicable';
      task.Description = comments;        

      if (setReminder == true)
      {
        task.IsReminderSet = true;
        task.ReminderDateTime = task.Task_Occured_Due_Date__c;
        task.ActivityDate = date.newinstance(task.Task_Occured_Due_Date__c.year(), task.Task_Occured_Due_Date__c.month(), task.Task_Occured_Due_Date__c.day());
        task.Follow_Up_Reminder_Date__c = task.Task_Occured_Due_Date__c;
      }

      return CreateTask(task,'');
    }       

    @AuraEnabled
    global static Task CreateORSChangeStatus(Id caseId, string ownerId, string comments, boolean caseOwnerIsTaskOwner, boolean setReminder, string orsStatus, boolean markTaskAsCompleted) {
      RecordType recType = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'Update_ORS' LIMIT 1];
      Case cse = [SELECT Id, CaseNumber, Patient_Name__c, Case.ORS_Number__r.Name, OwnerId FROM Case WHERE Id = :caseId];
      Task task = InitTask(caseId, recType, null);

      if (caseOwnerIsTaskOwner)
      {
        task.OwnerId = cse.OwnerId;
      }
      else {
        task.OwnerId = ownerId;
      }

      task.Subject = recType.Name + ' Case: ' + cse.CaseNumber + ' Patient: ' + cse.Patient_Name__c;
      task.Task_Reason__c = 'Change status of ORS Record';
      task.ORS_Status__c = orsStatus;
      if (markTaskAsCompleted)
      {
        task.Task_Disposition__c = 'Completed';
        task.Status = 'Completed';
      }
      else {
        task.Task_Disposition__c = 'Pending';
        task.Status = 'Pending';
      }      
      task.Task_Attachment__c = 'Not Applicable';
      task.Task_Source__c = 'User Activity';
      task.Mailing_Address__c = 'Not Applicable';
      task.Description = comments;        

      if (setReminder == true)
      {
        task.IsReminderSet = true;
        task.ReminderDateTime = task.Task_Occured_Due_Date__c;
        task.ActivityDate = date.newinstance(task.Task_Occured_Due_Date__c.year(), task.Task_Occured_Due_Date__c.month(), task.Task_Occured_Due_Date__c.day());
        task.Follow_Up_Reminder_Date__c = task.Task_Occured_Due_Date__c;
      }

      return CreateTask(task,'');
    }           

    @AuraEnabled
    global static Task CreateORSCommentTask(Id caseId, string ownerId, string comments, boolean caseOwnerIsTaskOwner, boolean setReminder, boolean markTaskAsCompleted) {
      RecordType recType = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'Update_ORS' LIMIT 1];
      Case cse = [SELECT Id, CaseNumber, Patient_Name__c, Case.ORS_Number__r.Name, OwnerId FROM Case WHERE Id = :caseId];
      Task task = InitTask(caseId, recType, null);

      if (caseOwnerIsTaskOwner)
      {
        task.OwnerId = cse.OwnerId;
      }
      else {
        task.OwnerId = ownerId;
      }

      task.Subject = recType.Name + ' Case: ' + cse.CaseNumber + ' Patient: ' + cse.Patient_Name__c;
      task.Task_Reason__c = 'Add Comments to ORS Record';
      if (markTaskAsCompleted)
      {
        task.Task_Disposition__c = 'Completed';
        task.Status = 'Completed';
      }
      else {
        task.Task_Disposition__c = 'Pending';
        task.Status = 'Pending';
      }      
      task.Task_Attachment__c = 'Not Applicable';
      task.Task_Source__c = 'User Activity';
      task.Mailing_Address__c = 'Not Applicable';      
      task.Description = comments;      

      if (setReminder == true)
      {
        task.IsReminderSet = true;
        task.ReminderDateTime = task.Task_Occured_Due_Date__c;
        task.ActivityDate = date.newinstance(task.Task_Occured_Due_Date__c.year(), task.Task_Occured_Due_Date__c.month(), task.Task_Occured_Due_Date__c.day());
        task.Follow_Up_Reminder_Date__c = task.Task_Occured_Due_Date__c;
      }

      return CreateTask(task, '');
    }       

    public static String GetORSRoute(Id caseId)
    {
      Case_Claim_Summary__c ccs = [SELECT Case__c,LAST_ORS_DEPT__c,LAST_ORS_IND__c,LAST_ORS_OFF__c,LAST_ORS_TEAM__c,ORIG_ORS_DEPT__c,ORIG_ORS_IND__c,ORIG_ORS_OFF__c,ORIG_ORS_TEAM__c, Case__r.ORS_Number__r.Name FROM Case_Claim_Summary__c where Case__c = :caseId LIMIT 1];
      Case cse = [select id, origin from Case where Id = :caseId];
      ORS_Route_Map__c orsRouteMap = ORSRouteRecord(cse.origin, ccs.ORIG_ORS_OFF__c, ccs.ORIG_ORS_DEPT__c, ccs.ORIG_ORS_TEAM__c, ccs.ORIG_ORS_IND__c, ccs.LAST_ORS_OFF__c, ccs.LAST_ORS_DEPT__c, ccs.LAST_ORS_TEAM__c, ccs.LAST_ORS_IND__c);
      string orsRoute = '';

      if (orsRouteMap != null)
      {
        if (orsRouteMap.Action__c == 'ROUTE TO OUT MAP')
        {
          orsRoute = orsRouteMap.OUT_Off__c + ' ' + orsRouteMap.OUT_Dept__c + ' ' + orsRouteMap.OUT_Team__c;

          if (orsRouteMap.OUT_Ind__c != '-')
          {
            orsRoute += ' ' + orsRouteMap.OUT_Ind__c;
          }
        }
        else if (orsRouteMap.Action__c == 'ROUTE TO INBOUND INDIVDUAL')
        {
          orsRoute = ccs.LAST_ORS_OFF__c + ' ' +  ccs.LAST_ORS_DEPT__c + ' ' +  ccs.LAST_ORS_TEAM__c;

          if (!string.isBlank(ccs.LAST_ORS_IND__c))
          {
            orsRoute += ' ' + ccs.LAST_ORS_IND__c;
          }
        }
      }


      return orsRoute;
    }

    public static ORS_Route_Map__c ORSRouteRecord(string origin, string origOffice, string origDept, string origTeam, string origInd, string lastOffice, string lastDept, string lastTeam, string lastInd)
    {
      ORS_Route_Map__c orsRoute = null;

      List<ORS_Route_Map__c> orsMappingFull = [SELECT Case_Priority__c, ORS_Source__c, Action__c, Active__c,Id,LAST_Dept__c,LAST_Ind__c,LAST_Off__c,LAST_Team__c,ORIG_Dept__c,ORIG_Ind__c,ORIG_Off__c,ORIG_Team__c,OUT_Dept__c,OUT_Ind__c,OUT_Off__c,OUT_Team__c, Initiated_By__c FROM ORS_Route_Map__c];
      List<ORS_Route_Map__c> orsMappingByOriginator = new List<ORS_Route_Map__c>();
      List<ORS_Route_Map__c> orsMappingByLast = new List<ORS_Route_Map__c>();
      ORS_Route_Map__c providerDefault = null;
      ORS_Route_Map__c patientDefault = null;

      for(ORS_Route_Map__c o: orsMappingFull)
      {
        if (o.Active__c == true && o.Initiated_By__c == origin)
        {
          if (o.ORIG_Off__c + o.ORIG_Dept__c + o.ORIG_Team__c + o.ORIG_Ind__c != '----')
          {
            orsMappingByOriginator.Add(o);
          }
          else if (o.LAST_Off__c + o.LAST_Dept__c + o.LAST_Team__c + o.LAST_Ind__c != '----')
          {
            orsMappingByLast.Add(o);
          }
        }

        if (o.Active__c == true && o.Initiated_By__c == 'Patient Default')
        {
          patientDefault = o;
        }

        if (o.Active__c == true && o.Initiated_By__c == 'Provider Default')
        {
          providerDefault = o;
        }

      }
      
      boolean matchFound = false;

      for(ORS_Route_Map__c o: orsMappingByOriginator)
      {
        if (o.ORIG_Off__c == '-')
        {
          matchFound = true;
        }
        else if ( o.ORIG_Off__c == origOffice)
        {
          matchFound = true;
        }

        if (matchFound == true)
        {
          if (o.ORIG_Dept__c == '-')
          {
            matchFound = true;
          }
          else if ( o.ORIG_Dept__c == origDept)
          {
            matchFound = true;
          }
          else 
          {
            matchFound = false;
          }
        }


        if (matchFound == true)
        {
          if (o.ORIG_Team__c == '-')
          {
            matchFound = true;
          }
          else if ( o.ORIG_Team__c == origTeam)
          {
            matchFound = true;
          }
          else 
          {
            matchFound = false;
          }

        }

        if (matchFound == true)
        {
          if (o.ORIG_Ind__c == '-')
          {
            matchFound = true;
          }
          else if ( o.ORIG_Ind__c == origInd)
          {
            matchFound = true;
          }
          else 
          {
            matchFound = false;
          }

        }
        
        if (matchFound == true)
        {
          orsRoute = o;
          break;
        }
      }

      if (matchFound == false)
      {
        for(ORS_Route_Map__c o: orsMappingByLast)
        {
          if (o.LAST_Off__c == '-')
          {
            matchFound = true;
          }
          else if ( o.LAST_Off__c == lastOffice)
          {
            matchFound = true;
          }

          if (matchFound == true)
          {
            if (o.LAST_Dept__c == '-')
            {
              matchFound = true;
            }
            else if ( o.LAST_Dept__c == lastDept)
            {
              matchFound = true;
            }
            else 
            {
              matchFound = false;
            } 
          }


          if (matchFound == true)
          {
            if (o.LAST_Team__c == '-')
            {
              matchFound = true;
            }
            else if ( o.LAST_Team__c == lastTeam)
            {
              matchFound = true;
            }
            else 
            {
              matchFound = false;
            }
  
          }

          if (matchFound == true)
          {
            if (o.LAST_Ind__c == '-')
            {
              matchFound = true;
            }
            else if ( o.LAST_Ind__c == lastInd)
            {
              matchFound = true;
            }
            else 
            {
              matchFound = false;
            }
  
          }
          
          if (matchFound == true)
          {
            orsRoute = o;
            break;
          }
        }
      }

      if (orsRoute == null)
      {
        if (origin == 'Patient' && patientDefault != null)
        {
          orsRoute = patientDefault;
        }
        else if (origin == 'Provider' && providerDefault != null)
        {
          orsRoute = providerDefault;
        }
      }

      System.debug(orsRoute);
      return orsRoute;
    }    
  
    @AuraEnabled
    public static Boolean SetAndGetEnvelopeReadyToSend(ID sfEnvelopeID) {
      return V2_DocuSignController.SetAndGetEnvelopeReadyToSend(sfEnvelopeID);
    }
  
    @AuraEnabled
    public static Map<String, String> generateInitializePayload(Id caseID) {
      return WCFileUploadController.generateInitializePayload(caseID);
    }
  
    @AuraEnabled
    public static Map<String, String> generateInitializePayloadForFileList(Id caseID, string taskID) {
      return WCFileUploadController.generateInitializePayloadForFileList(caseID, taskID);
    }
  
    @AuraEnabled
    public static List<Case_File__c> createPendingCaseFiles(Id caseID, List<Case_File__c> newFileList) {
      return WCFileUploadController.createPendingCaseFiles(caseID, newFileList);
    }
  
    @AuraEnabled
    public static void updateCaseFiles(List<Case_File__c> caseFiles) {
      WCFileUploadController.updateCaseFiles(caseFiles);
    }
  
    @AuraEnabled
    public static CEmail_Message__c GetEmailMessageRec(Id emailId){    
      return V2_EmailController.GetEmailMessageRec(emailId);
    }
  
    @AuraEnabled
    public static CEmail_Message__c UpdateLastViewedBy(Id emailId){    
        return V2_EmailController.UpdateLastViewedBy(emailId);
    }    

    @AuraEnabled
    public static string getSDFileIdForTaskId(string taskId){      
      return SmartDocumentController.getSDFileIdForTaskId(taskId);
    }

    @AuraEnabled    
    public static Negotiation__c updateOverallSmartDocStatusNegotiation(string caseId, 
                                                              string negotiationId, 
                                                              string sdFileId, 
                                                              string negotiationStatus, 
                                                              string sdDistributionStatus, 
                                                              string sdDistributionMethod, 
                                                              string cFaxStatus, 
                                                              string emailMessageId,
                                                              string cFaxObjId)    {
          
        return SmartDocumentController.updateOverallSmartDocStatusNegotiation(caseId, 
                                negotiationId, 
                                sdFileId, 
                                negotiationStatus, 
                                sdDistributionStatus, 
                                sdDistributionMethod, 
                                cFaxStatus, 
                                emailMessageId,
                                cFaxObjId);                                  
    }
}
