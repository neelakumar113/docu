public with sharing class V2_HomePageController {
  private class applicationException extends Exception {
  }

  @AuraEnabled
  public static void reopenCase(Id caseId, Id userIdToAssign, String reopenReason) {
    PatientPortalAPIHelper apiHelper = new PatientPortalAPIHelper();
    string reopenORSComment = 'Naviguard has reopened the ORS';

    //create payload
    Case caseFields = [SELECT ORS_Number__r.Name FROM Case WHERE Id = :caseId];
    User callingAssociate = [SELECT Name, ORS_Ind__c, TOPS_User_ID__c, TOPS_Password__c, ORS_Office__c FROM User WHERE Id = :UserInfo.getUserId()];
    if(callingAssociate.TOPS_User_ID__c == null || callingAssociate.TOPS_Password__c == null) {
      System.debug('Current user does not have a valid TOPS User Id and Password set');
      throw new AuraHandledException('Current user does not have a valid TOPS User Id and Password set');
    }
    User routeToUser = [SELECT Name, ORS_Office__c, ORS_Dept__c, ORS_Ind__c, ORS_Team__c FROM User WHERE Id = :userIdToAssign];
    if (!V2_Utility.isTrainingModeOn())
    {
      PatientPortalAPIHelper.ReopenORSIssuePayload payload = generateReopenPayload(caseFields, callingAssociate, routeToUser, reopenORSComment);

      //make call
      HttpResponse httpRes = apiHelper.reopenORSIssue(payload);
      PatientPortalAPIHelper.ReopenResponse apiResponse = (PatientPortalAPIHelper.ReopenResponse)JSON.deserialize(httpRes.getBody(), PatientPortalAPIHelper.ReopenResponse.class);

      if(apiResponse == null) {
        System.debug('Reopen in ors failed');
        System.debug('http response code: ' + httpRes.getStatusCode());
        throw new AuraHandledException('Call to reopen case in ORS failed');
      }

      //log responses for all steps
      for(PatientPortalAPIHelper.ReopenResponseStep step : apiResponse.results) {
        if(step.success == false) {
          System.debug('Ors Reopen step ' + step.stepNumber + ' ' + step.name + ' failed');
          System.debug(apiResponse.results[0].message);
          //if step 1 fails, do not perform any other transactions and fail out
          //other errors can be resolved manually but should be logged
          if(step.stepNumber == 1) {
            throw new AuraHandledException('Case is not closed in ORS');
          }
        }
      }
    }

    //reopen case in SF if call succeeds
    //this happens after the REST request because you can't callout after DML
    try {
      Case_Progress_Log__c cpl = getLastProgressLogBeforeClosed(caseId);
      Case caseToUpdate = new Case(Id = caseId);
      //reset disposition and status to what it was
      //caseToUpdate.Disposition__c = cpl.Original_Disposition__c;
      caseToUpdate.Disposition__c = '';
      caseToUpdate.Status = 'In Progress';
      caseToUpdate.Milestone__c = cpl.Milestone__c;
      caseToUpdate.Can_Click_Complete__c = false;
      caseToUpdate.Reopen_Reason__c = reopenReason;
      update caseToUpdate;
      
      cpl = getLastProgressLogBeforeClosed(caseId);
      cpl.Action__c = 'Case Reopened';
      cpl.Action_Reason__c = reopenReason;
      update cpl;


      V2_TasksController.CreateAlertTask(caseId, userIdToAssign, 'Case has been re-opened.  Please follow SOP to determine appropriate steps.', 'Case Re-Opened', false, true, false);
        } catch(Exception e) {
        System.debug('Ors reopen was successful but Salesforce commit failed');
        System.debug(e.getMessage());
        System.debug(e.getStackTraceString());
    }
  }

  /**
   * Returns true if the case can be reopened
   * @param {string} caseId id of the case to check reopen eligibility for
   */
  @AuraEnabled
  public static Boolean checkReopenEligibility(Id caseId) {
    Case caseRecord = [SELECT Id, Milestone__c, Origin, Can_Click_Negotiation_Results__c FROM Case WHERE Id = :caseId];
    Case_Progress_Log__c cpl = getLastProgressLogBeforeClosed(caseId);

    Boolean milestoneEligibility = (cpl.Milestone__c == 'Negotiation' && !caseRecord.Can_Click_Negotiation_Results__c)
                                   || cpl.Milestone__c == 'Engagement';

    Boolean originEligibility = false;
    if(cpl.Milestone__c == 'Negotiation') {
      originEligibility = caseRecord.Origin == 'Provider';
    } else if(cpl.Milestone__c == 'Engagement') {
      originEligibility = caseRecord.Origin == 'Patient' || caseRecord.Origin == 'Provider Old';
    }

    Map<Id, Profile> profiles = new Map<Id, Profile>([SELECT Id FROM Profile WHERE Name = 'OPS Manager' OR Name = 'System Administrator']);
    Boolean userEligibility = profiles.keySet().contains(UserInfo.getProfileId());

    return userEligibility && milestoneEligibility && originEligibility;
  }

  @AuraEnabled
  public static Case_Progress_Log__c getLastProgressLogBeforeClosed(Id caseId) {
    List<Case_Progress_Log__c> cpls = V2_CaseDetailController.GetCaseProgressLog(caseId);
    //loop through backwards and find first cpl that was before the case was closed
    for(Integer i = cpls.size() - 1; i >= 0; i--) {
      Case_Progress_Log__c cpl = cpls.get(i);
      //return first milestone before complete
      //if(cpl.Milestone__c != 'Complete' && cpl.Milestone__c.Status__c != 'Completed') {
      if(cpl.Milestone__c != 'Complete') {
        return cpl;
      }
    }
    return null;
  }

  @AuraEnabled
  public static List<ListView> GetListViews(string objectName) {
    return Utility.getListViews(objectName);
  }

  @AuraEnabled
  public static List<Generic_Object__c> GetCaseOverviewForHomeScreen(string mode) {
    List<Generic_Object__c> toReturn = new List<Generic_Object__c>();
    Id userId = UserInfo.getUserId();
    List<String> validMileStones = new List<String>();
    String viewName;
    String whereClause;

    if (mode == 'Admin') {
      validMileStones = new List<string>{'Initiation','Engagement','Negotiation','Follow_Up','Complete'};
      whereClause = '';
    } else if (mode == 'Negotiator') {
      validMileStones = new List<string>{'Negotiation'};
      whereClause = ' AND Assigned_Negotiator__c = :userId';
    } else if (mode == 'Specialist') {
      validMileStones = new List<string>{'Negotiation'};
      whereClause = ' AND Assigned_Patient_Liaison_Specialist__c = :userId';
    } else if (mode == 'Advisor') {
      validMileStones = new List<string>{'Initiation','Engagement','Negotiation','Follow_Up','Complete'};
      whereClause = ' AND ((OwnerId = :userId) or (Assigned_Follow_Up_Advisor__c = :userId and Milestone__c in (\'Follow_Up\',\'Complete\')))';
    }

    List<string> mileStoneList = Utility.getPicklistvalues('Case', 'Milestone__c', false);
    List<ListView> listViews = Utility.getListViews('Case');

    for (string m : mileStoneList) {
      if (validMileStones.contains(m))
      {
          Generic_Object__c toAdd = new Generic_Object__c();
          toAdd.TextField1__c = m.replace('_', ' ');
  
          //patient count
          toAdd.NumberField1__c = 0;

          //provider count
          toAdd.NumberField2__c = 0;

          //totals count
          toAdd.NumberField3__c = 0;
  
          for (ListView lv : listViews) {
          if (m == 'Unassigned' && lv.DeveloperName == 'All_Unassigned_Cases') {
              toadd.URLField1__c = '/lightning/o/Case/list?filterName=' + lv.Id;
              toadd.TextField3__c = '/lightning/o/Case/list?filterName=' + lv.Id;
          } else {
              if (lv.DeveloperName == viewName) {
                if(mode == 'Advisor') {
                  viewName = 'V2_My_Cases_Milestone_' + m.replace(' ', '_');
                } else {
                  viewName ='V2_All_Cases_Milestone_' + m.replace(' ', '_');
                }
                toadd.URLField1__c = '/lightning/o/Case/list?filterName=' + lv.Id;
                toadd.TextField3__c = '/lightning/o/Case/list?filterName=' + lv.Id;
              }
          }
          }
  
          toReturn.Add(toAdd);
      }
    }

    // for (AggregateResult a : [SELECT Milestone__c, Origin, COUNT(Id) thecount FROM Case where Milestone__c in :validMileStones and V2_Case__c = true and OwnerId = :userId GROUP BY Milestone__c, Origin]) {
    for (AggregateResult a : Database.query('SELECT Milestone__c, Origin, COUNT(Id) thecount FROM Case WHERE Milestone__c in :validMileStones and V2_Case__c = true' + whereClause + ' GROUP BY Milestone__c, Origin')) {
      for (Generic_Object__c b : toReturn) {
        if (b.TextField1__c == String.valueOf(a.get('Milestone__c')).replace('_', ' '))
          if (a.get('Origin') == 'Patient' || a.get('Origin') == 'Member Call (ORS Record)' || a.get('Origin') == 'Provider Old') {  
              b.NumberField1__c += Integer.valueOf(a.get('thecount'));
          }
          else if (a.get('Origin') == 'Provider') {
              b.NumberField2__c = Integer.valueOf(a.get('thecount'));
          }
          b.NumberField3__c = b.NumberField1__c + b.NumberField2__c;
       }
    }

    return toReturn;
  }

  @AuraEnabled
  public static CaseDataTableWrapper GetCaseRecordsByMilestone(string mode, string mileStone, Integer pageNumber, Integer pageSize) {
      
		//Offset for SOQL
    Integer offset = (pageNumber - 1) * pageSize;
         
    //Total Records
    Integer totalRecords;
    Integer recordEnd = pageSize * pageNumber;
 
    //Instance of Contact DataTable Wrapper Class
    CaseDataTableWrapper objDT =  new CaseDataTableWrapper();  
    objDT.pageSize = pageSize;
    objDT.pageNumber = pageNumber;
    objDT.recordStart = offset + 1;
		objDT.mode = mode;
		objDT.mileStone = mileStone;
	  
    if (mileStone == 'Follow Up')
    {
      mileStone = 'Follow_Up';
    }

    String whereClause;
    if (mode == 'Admin') {
      whereClause = ' LIMIT :pageSize OFFSET :offset';
    } else if (mode == 'Negotiator') {
      whereClause = ' AND Assigned_Negotiator__c = :userId LIMIT :pageSize OFFSET :offset';
    } else if (mode == 'Specialist') {
      whereClause = ' AND Assigned_Patient_Liaison_Specialist__c = :userId LIMIT :pageSize OFFSET :offset';
    } else if (mode == 'Advisor') {
      whereClause = ' AND ((OwnerId = :userId) or (Assigned_Follow_Up_Advisor__c = :userId and Milestone__c in (\'Follow_Up\',\'Complete\'))) LIMIT :pageSize OFFSET :offset';
    }

    List<Case> toReturn = new List<Case>();
    string userId = UserInfo.getUserId();

    if (mileStone == 'All Open Cases')
    {
	    totalRecords = Database.countQuery('SELECT count() FROM Case WHERE IsClosed = false and V2_Case__c = true'); 	
        if(ceiling(totalRecords,pageSize) < pageNumber){
              pageNumber = 1;
              offset = (1 - 1) * pageSize;
              recordEnd = pageSize * 1;
          } 
        toReturn = Database.query('SELECT Digital__c, Aging_Reason__c, Aging_Business_Days__c, Active_Business_Days__c, CreatedDate, Disposition__c, ClosedDate, IsClosed, CaseNumber ,ToLabel(Milestone__c) ,Status , Type ,Origin,On_Hold__c,Patient_Name__c ,Billing_Provider_Group__r.Billing_Provider_Group_Name__c ,Employer_Name__c ,Aging_Days__c ,Assigned_Negotiator__c ,Assigned_Patient_Liaison_Specialist__r.Name, Assigned_Negotiator__r.Name , Assigned_Follow_Up_Advisor__c, Assigned_Follow_Up_Advisor__r.Name, Billing_Provider_Group__c ,Id ,OwnerId ,Owner.Name,  ORS_Number__r.Name, ORS_Number__r.ORS_URL_LINK__c FROM Case WHERE IsClosed = false and V2_Case__c = true' + whereClause);
    }
    else if (mileStone == 'Recently Viewed')
    {
      List<RecentlyViewed> rv = new List<RecentlyViewed>();
      rv = [Select Id from RecentlyViewed where Type = 'Case'];
      List<string> caseIds = new List<string>();
      for (RecentlyViewed r: rv)
      {
        caseIds.add(r.Id);
      }
	    totalRecords = [SELECT COUNT() FROM Case where V2_Case__c = true and Id in :caseIds];
        if(ceiling(totalRecords,pageSize) < pageNumber){
          pageNumber = 1;
          offset = (1 - 1) * pageSize;
          recordEnd = pageSize * 1;
      } 
      toReturn = [SELECT Digital__c, CreatedDate, Disposition__c, ClosedDate, IsClosed, CaseNumber ,ToLabel(Milestone__c) ,Status , Type ,Origin ,Patient_Name__c ,Billing_Provider_Group__r.Billing_Provider_Group_Name__c , Employer_Name__c ,Aging_Days__c ,Assigned_Negotiator__c , Assigned_Patient_Liaison_Specialist__r.Name, Assigned_Negotiator__r.Name , Assigned_Follow_Up_Advisor__c, Assigned_Follow_Up_Advisor__r.Name, Billing_Provider_Group__c ,Id ,OwnerId ,Owner.Name,  ORS_Number__r.Name, ORS_Number__r.ORS_URL_LINK__c FROM Case where V2_Case__c = true and Id in :caseIds LIMIT :pageSize OFFSET :offset];
    }
    else {
        totalRecords = Database.countQuery('SELECT count() FROM Case where Milestone__c = :mileStone and V2_Case__c = true' );		
        if(ceiling(totalRecords,pageSize) < pageNumber){
            pageNumber = 1;
            offset = (1 - 1) * pageSize;
            recordEnd = pageSize * 1;
        } 
        toReturn = Database.query('SELECT Digital__c, Aging_Reason__c, Aging_Business_Days__c, Active_Business_Days__c, CreatedDate, Disposition__c, ClosedDate, IsClosed, CaseNumber ,ToLabel(Milestone__c) ,Status , Type ,Origin ,On_Hold__c, Patient_Name__c ,Billing_Provider_Group__r.Billing_Provider_Group_Name__c , Employer_Name__c ,Aging_Days__c ,Assigned_Negotiator__c , Assigned_Patient_Liaison_Specialist__r.Name, Assigned_Negotiator__r.Name , Assigned_Follow_Up_Advisor__c, Assigned_Follow_Up_Advisor__r.Name, Billing_Provider_Group__c ,Id ,OwnerId ,Owner.Name,  ORS_Number__r.Name, ORS_Number__r.ORS_URL_LINK__c FROM Case where Milestone__c = :mileStone and V2_Case__c = true' + whereClause);
    }


    if (toReturn != null && toReturn.size() > 0)
    {
      if (V2_Utility.isTrainingModeOn())
      {
        for (Case c : toReturn)
        {
          if (!string.isblank(c.ORS_Number__r.Name))
          {
            c.ORS_Number__r.ORS_URL_LINK__c = 'about:blank';
          }
        }      
      }
      else {
        External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
        External_Configurations__c benchmarkURL = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_API_Root_URL' LIMIT 1];
        
        User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c FROM User WHERE Id = :userId LIMIT 1];
  
        Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
        string url = 'https://' + benchmarkURL.ConfigValue__c + '/ors-research?';
        string fullStringToEcrypt = '';
         
        string tops_user_id = '';
        string tops_password = '';
          
        if (!string.isblank(user.TOPS_User_ID__c) && !string.isblank(user.TOPS_User_ID__c)) {
          tops_user_id = user.TOPS_User_ID__c;
          tops_password = user.TOPS_Password__c;
        }
    
        for (Case c : toReturn)
        {
          if (!string.isblank(c.ORS_Number__r.Name))
          {
            fullStringToEcrypt = 'ors_id=' + c.ORS_Number__r.Name + '&tops_user_id=' + tops_user_id + '&tops_password=' + tops_password;
            Blob cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(fullStringToEcrypt));
            String encodedCipherText = EncodingUtil.base64Encode(cipherText);
            c.ORS_Number__r.ORS_URL_LINK__c = url + encodingUtil.URLEncode(encodedCipherText, 'UTF-8');
          }
        }              
      }
    }
    objDT.recordStart = offset + 1;  
    objDT.recordEnd = totalRecords >= recordEnd ? recordEnd : totalRecords;
    objDT.totalRecords = totalRecords;
    objDT.caseList = toReturn;
    objDT.pageNumber = pageNumber;
    return objDT;
  }

  @AuraEnabled
  public static List<String> AssignAdvisorToCaseIdList(Id ownerId, List<string> caseIdList) {
    CasesSelector casesSelector = new CasesSelector();
    casesSelector.setSelectClause('Select Id, OwnerId, Status, Milestone__c');
    casesSelector.setWhereClause('WHERE Id in (' + SelectorUtilities.expandListForInClause(caseIdList) + ')');
    Map<Id, Case> casesToUpdate = new Map<Id, Case>(casesSelector.getCasesAsUser(ownerId));

    List<String> casesNotUpdated = new List<String>();
    for(String initialCaseId : caseIdList) {
      if(!casesToUpdate.keySet().contains(initialCaseId)) {
        casesNotUpdated.add(initialCaseId);
      }
    }

    for (Case c: casesToUpdate.values())
    {
      c.OwnerId = ownerId;

      if (c.Milestone__c == 'Initiation' && c.Status == 'Unassigned')
      {
        c.Status = 'Assigned';
      }
    }

    update casesToUpdate.values();
    return casesNotUpdated;
  }

  @AuraEnabled
  public static void AssignAdvisorFollowUpToCaseIdList(Id ownerId, List<string> caseIdList) {
    List<Case> casesToUpdate = [Select Id, OwnerId, Status, Milestone__c, Assigned_Follow_Up_Advisor__c  from Case where Id in :caseIdList];

    for (Case c: casesToUpdate)
    {
      c.Assigned_Follow_Up_Advisor__c  = ownerId;

      if (c.Milestone__c == 'Follow_Up' && c.Status == 'Unassigned')
      {
        c.Status = 'Pending';
      }
    }

    update casesToUpdate;
  }

  @AuraEnabled
  public static List<String> AssignNegotiatorToProviderCaseIdList(Id ownerId, List<string> caseIdList) {
    CasesSelector casesSelector = new CasesSelector();
    casesSelector.setSelectClause('Select Id, OwnerId, Status, Milestone__c');
    casesSelector.setWhereClause('WHERE Id in (' + SelectorUtilities.expandListForInClause(caseIdList) + ')');
    Map<Id, Case> casesToUpdate = new Map<Id, Case>(casesSelector.getCasesAsUser(ownerId));

    List<String> casesNotUpdated = new List<String>();
    for(String initialCaseId : caseIdList) {
      if(!casesToUpdate.keySet().contains(initialCaseId)) {
        casesNotUpdated.add(initialCaseId);
      }
    }

    for (Case c: casesToUpdate.values())
    {
      c.OwnerId = ownerId;

      if (c.Milestone__c == 'Initiation' && c.Status == 'Unassigned')
      {
        c.Status = 'Assigned';
      }
    }

    update casesToUpdate.values();
    return casesNotUpdated;
  }

  @AuraEnabled
  public static List<String> AssignNegotiatorToCaseIdList(Id negotiatorId, List<string> caseIdList) {
    CasesSelector casesSelector = new CasesSelector();
    casesSelector.setSelectClause('Select Id, Assigned_Negotiator__c, Milestone__c, Status');
    casesSelector.setWhereClause('WHERE Id in (' + SelectorUtilities.expandListForInClause(caseIdList) + ')');
    Map<Id, Case> casesToUpdate = new Map<Id, Case>(casesSelector.getCasesAsUser(negotiatorId));

    List<String> casesNotUpdated = new List<String>();
    for(String initialCaseId : caseIdList) {
      if(!casesToUpdate.keySet().contains(initialCaseId)) {
        casesNotUpdated.add(casesToUpdate.get(initialCaseId).CaseNumber);
      }
    }

    for (Case c: casesToUpdate.values())
    {
      c.Assigned_Negotiator__c = negotiatorId;

      if (c.Milestone__c == 'Negotiation' && c.Status == 'Unassigned')
      {
        c.Status = 'Assigned';
      }
    }

    update casesToUpdate.values();
    return casesNotUpdated;
  }

  @AuraEnabled
  public static List<String> AssignSpecialistToCaseIdList(Id negotiatorId, List<string> caseIdList) {
    CasesSelector casesSelector = new CasesSelector();
    casesSelector.setSelectClause('Select Id, Assigned_Patient_Liaison_Specialist__c, Milestone__c, Status');
    casesSelector.setWhereClause('WHERE Id in (' + SelectorUtilities.expandListForInClause(caseIdList) + ')');
    Map<Id, Case> casesToUpdate = new Map<Id, Case>(casesSelector.getCasesAsUser(negotiatorId));

    List<String> casesNotUpdated = new List<String>();
    for(String initialCaseId : caseIdList) {
      if(!casesToUpdate.keySet().contains(initialCaseId)) {
        casesNotUpdated.add(initialCaseId);
      }
    }

    for (Case c: casesToUpdate.values())
    {
      c.Assigned_Patient_Liaison_Specialist__c = negotiatorId;

      if (c.Milestone__c == 'Negotiation' && c.Status == 'Unassigned')
      {
        c.Status = 'Assigned';
      }
    }

    update casesToUpdate.values();
    return casesNotUpdated;
  }

  @AuraEnabled
  public static List<Generic_Object__c> GetCaseByIndividual(string filterOnProfileName, string mode) {
    //TextField1__c - Name
    //TextField2__c - Role
    //TextField3__c - Id
    //NumberField1__c - initiation patient count
    //NumberField2__c - initiation provider count
    //NumberField3__c - engagement patient count
    //NumberField4__c - engagement provider count
    //NumberField5__c - negotiation patient count
    //NumberField6__c - negotiation provider count
    //NumberField7__c - follow up patient count
    //NumberField8__c - follow up provider count

    List<string> profiles = new List<string>{'OPS Manager', 'Advisor User', 'Negotiator User','System Administrator', 'Liaison Specialist User'};
    List<string> filteredProfiles = new List<string>();
    List<String> filterOnProfileNameList = filterOnProfileName.split(',');
    
      for(string p: profiles)
      {
        if (filterOnProfileNameList.size() > 0)
        {
          for(string f: filterOnProfileNameList)
          {
            system.debug(f);
            if (p == f)
            {
              
              filteredProfiles.add(p);
              continue;
            }
          }
        }
        else {
          filteredProfiles.add(p);
        }
    }
    
    Map<Id, Generic_Object__c> userCaseCountMap = new Map<Id, Generic_Object__c>();
    if (mode != 'Admin')
    {
      Id userId = UserInfo.getUserId();  

      for(User u : [Select Id, Name, Profile.Name from User where IsActive = true and Id =:userId])
      {
        Generic_Object__c g = new Generic_Object__c();
        g.TextField1__c = u.Name;
        g.TextField2__c = u.Profile.Name;
        g.TextField3__c = u.Id;
        g.NumberField1__c = 0;
        g.NumberField2__c = 0;
        g.NumberField3__c = 0;
        g.NumberField4__c = 0;
        g.NumberField5__c = 0;
        g.NumberField6__c = 0;
        g.NumberField7__c = 0;
        g.NumberField8__c = 0;
        userCaseCountMap.put(u.Id, g);
      }
  
    }
    else {
      for(User u : [Select Id, Name, Profile.Name from User where IsActive = true and Profile.Name in :filteredProfiles order by Name])
      {
        Generic_Object__c g = new Generic_Object__c();
        g.TextField1__c = u.Name;
        g.TextField2__c = u.Profile.Name;
        g.TextField3__c = u.Id;
        g.NumberField1__c = 0;
        g.NumberField2__c = 0;
        g.NumberField3__c = 0;
        g.NumberField4__c = 0;
        g.NumberField5__c = 0;
        g.NumberField6__c = 0;
        g.NumberField7__c = 0;
        g.NumberField8__c = 0;
        userCaseCountMap.put(u.Id, g);
      }
        
    }

    

  if (mode == 'Admin' || mode == 'Advisor')
  {
    List<string> advIds = new List<string>();
    for (String Id : userCaseCountMap.keySet()){

      Generic_Object__c temp = userCaseCountMap.get(Id);
      if (temp.TextField2__c == 'Advisor User')
      {
        advIds.add(Id);
      }
    }


    for (AggregateResult aggRes : [SELECT COUNT(ID) numCases, OwnerId, Origin, Milestone__c
                                   FROM Case
                                   where Milestone__c in ('Initiation','Engagement','Negotiation','Follow_Up')
                                     and V2_Case__c = true
                                     and OwnerId in : advIds
                                   GROUP BY OwnerId, Origin, Milestone__c]) 
    {
      
      if (aggRes.get('Milestone__c') == 'Initiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)'|| aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField1__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField2__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Engagement')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)'|| aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField3__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField4__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Negotiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField5__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField6__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Follow_Up')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)'|| aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField7__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField8__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
    }

    //follow up assigned adivosr
    for (AggregateResult aggRes : [SELECT COUNT(ID) numCases, Assigned_Follow_Up_Advisor__c, Origin, Milestone__c
                                   FROM Case
                                   where Milestone__c in ('Initiation','Engagement','Negotiation','Follow_Up')
                                     and V2_Case__c = true
                                     and Assigned_Follow_Up_Advisor__c in : advIds
                                   GROUP BY Assigned_Follow_Up_Advisor__c, Origin, Milestone__c]) 
    {
      
      if (aggRes.get('Milestone__c') == 'Initiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Follow_Up_Advisor__c')).NumberField1__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Follow_Up_Advisor__c')).NumberField2__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Engagement')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Follow_Up_Advisor__c')).NumberField3__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Follow_Up_Advisor__c')).NumberField4__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Negotiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Follow_Up_Advisor__c')).NumberField5__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Follow_Up_Advisor__c')).NumberField6__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Follow_Up')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Follow_Up_Advisor__c')).NumberField7__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Follow_Up_Advisor__c')).NumberField8__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
    }    
  }

  if (mode == 'Admin' || mode == 'Negotiator') {
    List<string> negIds = new List<string>();
    for (String Id : userCaseCountMap.keySet()){

      Generic_Object__c temp = userCaseCountMap.get(Id);
      if (temp.TextField2__c == 'Negotiator User' || temp.TextField2__c == 'Liaison Specialist User')
      {
        negIds.add(Id);

        System.debug(id);
      }
    }


    //get the assigned negotiator's
    for (AggregateResult aggRes : [SELECT COUNT(ID) numCases, Assigned_Negotiator__c, Origin, Milestone__c
                                   FROM Case
                                   where Milestone__c in ('Initiation','Engagement','Negotiation','Follow_Up')
                                     and V2_Case__c = true
                                     and Assigned_Negotiator__c in : negIds

                                   GROUP BY Assigned_Negotiator__c, Origin, Milestone__c]) 
    {
      
      if (aggRes.get('Milestone__c') == 'Initiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField1__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField2__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Engagement')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField3__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField4__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Negotiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField5__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField6__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Follow_Up')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField7__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField8__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
    }    

    //get the Negotiators who own the case
    for (AggregateResult aggRes : [SELECT COUNT(ID) numCases, OwnerId, Origin, Milestone__c
                                   FROM Case
                                   where Milestone__c in ('Initiation','Engagement','Negotiation','Follow_Up')
                                     and V2_Case__c = true
                                     and OwnerId in : negIds
                                   GROUP BY OwnerId, Origin, Milestone__c]) 
    {
      
      if (aggRes.get('Milestone__c') == 'Initiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField1__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField2__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Engagement')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField3__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField4__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Negotiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField5__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField6__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Follow_Up')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField7__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField8__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
    }   
    
    //get the Specialists who own the case
    for (AggregateResult aggRes : [SELECT COUNT(ID) numCases, Assigned_Patient_Liaison_Specialist__c, Origin, Milestone__c
                                   FROM Case
                                   where Milestone__c in ('Initiation','Engagement','Negotiation','Follow_Up')
                                     and V2_Case__c = true
                                     and Assigned_Patient_Liaison_Specialist__c in : negIds
                                   GROUP BY Assigned_Patient_Liaison_Specialist__c, Origin, Milestone__c]) 
    {
      
      if (aggRes.get('Milestone__c') == 'Initiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField1__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField2__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Engagement')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField3__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField4__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Negotiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField5__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField6__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Follow_Up')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField7__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField8__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
    }        
  }

  return userCaseCountMap.Values();

}

@AuraEnabled
  public static List<Generic_Object__c> GetCaseByIndividualWithRestrictions(string filterOnProfileName, string mode, String caseId) {
    //TextField1__c - Name
    //TextField2__c - Role
    //TextField3__c - Id
    //NumberField1__c - initiation patient count
    //NumberField2__c - initiation provider count
    //NumberField3__c - engagement patient count
    //NumberField4__c - engagement provider count
    //NumberField5__c - negotiation patient count
    //NumberField6__c - negotiation provider count
    //NumberField7__c - follow up patient count
    //NumberField8__c - follow up provider count

    List<string> profiles = new List<string>{'OPS Manager', 'Advisor User', 'Negotiator User','System Administrator', 'Liaison Specialist User'};
    List<string> filteredProfiles = new List<string>();
    List<String> filterOnProfileNameList = filterOnProfileName.split(',');

    List<Restriction__c> caseRestrictions = new List<Restriction__c>();
    for (Case caseRecord : [SELECT Id, (SELECT Id, Restriction__c FROM Case_Restrictions__r) FROM Case WHERE Id = :caseId]) {
      for (Case_Restriction__c restriction : caseRecord.Case_Restrictions__r) {
        caseRestrictions.add(new Restriction__c(Id = restriction.Restriction__c));
      }
    }
    
      for(string p: profiles)
      {
        if (filterOnProfileNameList.size() > 0)
        {
          for(string f: filterOnProfileNameList)
          {
            system.debug(f);
            if (p == f)
            {
              
              filteredProfiles.add(p);
              continue;
            }
          }
        }
        else {
          filteredProfiles.add(p);
        }
    }
    
    Map<Id, Generic_Object__c> userCaseCountMap = new Map<Id, Generic_Object__c>();
    if (mode != 'Admin')
    {
      Id userId = UserInfo.getUserId();
      UsersSelector usersSelector = new UsersSelector();
      usersSelector.setSelectClause('Select Id, Name, Profile.Name');
      usersSelector.setWhereClause('WHERE IsActive = true and Id = ' + userId);
      List<User> filteredUsers = usersSelector.getUsersBasedOnRestrictions(caseRestrictions);

      for(User u : filteredUsers)
      {
        Generic_Object__c g = new Generic_Object__c();
        g.TextField1__c = u.Name;
        g.TextField2__c = u.Profile.Name;
        g.TextField3__c = u.Id;
        g.NumberField1__c = 0;
        g.NumberField2__c = 0;
        g.NumberField3__c = 0;
        g.NumberField4__c = 0;
        g.NumberField5__c = 0;
        g.NumberField6__c = 0;
        g.NumberField7__c = 0;
        g.NumberField8__c = 0;
        userCaseCountMap.put(u.Id, g);
      }
  
    }
    else {
      UsersSelector usersSelector = new UsersSelector();
      usersSelector.setSelectClause('Select Id, Name, Profile.Name');
      usersSelector.setWhereClause('WHERE IsActive = true and Profile.Name in (' + SelectorUtilities.expandListForInClause(filteredProfiles) + ')');
      usersSelector.setOrderByClause('ORDER BY Name');
      List<User> filteredUsers = usersSelector.getUsersBasedOnRestrictions(caseRestrictions);
      for(User u : filteredUsers)
      {
        Generic_Object__c g = new Generic_Object__c();
        g.TextField1__c = u.Name;
        g.TextField2__c = u.Profile.Name;
        g.TextField3__c = u.Id;
        g.NumberField1__c = 0;
        g.NumberField2__c = 0;
        g.NumberField3__c = 0;
        g.NumberField4__c = 0;
        g.NumberField5__c = 0;
        g.NumberField6__c = 0;
        g.NumberField7__c = 0;
        g.NumberField8__c = 0;
        userCaseCountMap.put(u.Id, g);
      }
        
    }

    

  if (mode == 'Admin' || mode == 'Advisor')
  {
    
    for (AggregateResult aggRes : [SELECT COUNT(ID) numCases, OwnerId, Origin, Milestone__c
                                   FROM Case
                                   where Milestone__c in ('Initiation','Engagement','Negotiation','Follow_Up')
                                     and V2_Case__c = true
                                     and OwnerId in : userCaseCountMap.keySet()
                                   GROUP BY OwnerId, Origin, Milestone__c]) 
    {
      
      if (aggRes.get('Milestone__c') == 'Initiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField1__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField2__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Engagement')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField3__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField4__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Negotiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField5__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField6__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Follow_Up')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField7__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('OwnerId')).NumberField8__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
    }
  }

  if (mode == 'Admin' || mode == 'Negotiator') {
    List<string> negIds = new List<string>();
    for (String Id : userCaseCountMap.keySet()){

      Generic_Object__c temp = userCaseCountMap.get(Id);
      if (temp.TextField2__c == 'Negotiator User' || temp.TextField2__c == 'Liaison Specialist User')
      {
        negIds.add(Id);

        System.debug(id);
      }
    }



    for (AggregateResult aggRes : [SELECT COUNT(ID) numCases, Assigned_Negotiator__c, Origin, Milestone__c
                                   FROM Case
                                   where Milestone__c in ('Initiation','Engagement','Negotiation','Follow_Up')
                                     and V2_Case__c = true
                                     and Assigned_Negotiator__c in : negIds
                                   GROUP BY Assigned_Negotiator__c, Origin, Milestone__c]) 
    {
      
      if (aggRes.get('Milestone__c') == 'Initiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField1__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField2__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Engagement')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField3__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField4__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Negotiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField5__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField6__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Follow_Up')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField7__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Negotiator__c')).NumberField8__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
    }    
  }

  if (mode == 'Admin' || mode == 'Negotiator') {
    List<string> specIds = new List<string>();
    for (String Id : userCaseCountMap.keySet()){

      Generic_Object__c temp = userCaseCountMap.get(Id);
      if (temp.TextField2__c == 'Liaison Specialist User')
      {
        specIds.add(Id);

        System.debug(id);
      }
    }



    for (AggregateResult aggRes : [SELECT COUNT(ID) numCases, Assigned_Patient_Liaison_Specialist__c, Origin, Milestone__c
                                   FROM Case
                                   where Milestone__c in ('Initiation','Engagement','Negotiation','Follow_Up')
                                     and V2_Case__c = true
                                     and Assigned_Patient_Liaison_Specialist__c in : specIds
                                   GROUP BY Assigned_Patient_Liaison_Specialist__c, Origin, Milestone__c]) 
    {
      
      if (aggRes.get('Milestone__c') == 'Initiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField1__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField2__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Engagement')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField3__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField4__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Negotiation')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField5__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField6__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
      else if (aggRes.get('Milestone__c') == 'Follow_Up')
      {
        if (aggRes.get('Origin') == 'Patient' || aggRes.get('Origin') == 'Member Call (ORS Record)' || aggRes.get('Origin') == 'Provider Old')
        {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField7__c+= Integer.valueOf(aggRes.get('numCases'));
        }
        else {
          userCaseCountMap.get((Id) aggRes.get('Assigned_Patient_Liaison_Specialist__c')).NumberField8__c+= Integer.valueOf(aggRes.get('numCases'));
        }
      }
    }    
  }

    return userCaseCountMap.Values();

}

@AuraEnabled
public static List<Case> GetUnassignedCases() {
  CasesSelector caseSelector = new CasesSelector();
  caseSelector.setSelectClause('SELECT Digital__c,Aging_Days__c,Assigned_Negotiator__c,Assigned_Negotiator__r.Name, Assigned_Patient_Liaison_Specialist__r.Name, Billing_Provider_Group__c, Billing_Provider_Group__r.Billing_Provider_Group_Name__c,Billing_Provider_Group__r.Navigator_POI__c,CaseNumber,Employer_Name__c,Id,Origin,ToLabel(Milestone__c),OwnerId,Owner.Name,Patient_Name__c,Not_Covered_Amount_Sum__c,Specialty_Description__c, Type');
  caseSelector.setWhereClause('where Assigned_Negotiator__c = \'\' and V2_Case__c = true and Milestone__c =\'Negotiation\' and Status = \'Unassigned\' and Origin != \'Provider\'');
  return caseSelector.getCases();
}

@AuraEnabled
public static List<Case> GetUnassignedProviderCases() {
  CasesSelector caseSelector = new CasesSelector();
  caseSelector.setSelectClause('SELECT Digital__c,Aging_Days__c,Assigned_Negotiator__c,Assigned_Negotiator__r.Name, Assigned_Patient_Liaison_Specialist__r.Name, Billing_Provider_Group__c, Billing_Provider_Group__r.Billing_Provider_Group_Name__c,Billing_Provider_Group__r.Navigator_POI__c,CaseNumber,Employer_Name__c,Id,Origin,ToLabel(Milestone__c),OwnerId,Owner.Name,Patient_Name__c, Not_Covered_Amount_Sum__c, Specialty_Description__c, Type');
  caseSelector.setWhereClause('where Assigned_Follow_Up_Advisor__c = \'\' and V2_Case__c = true and Milestone__c =\'Follow_Up\' and Status = \'Unassigned\' and Origin = \'Provider\'');
  return caseSelector.getCases();
}

@AuraEnabled
public static List<Case> GetActiveCases(string mode) {
  List<Case> toReturn = new List<Case>();

  if (mode == 'Admin')
  {
    CasesSelector caseSelector = new CasesSelector();
    caseSelector.setSelectClause('SELECT Digital__c,Aging_Business_Days__c,Active_Business_Days__c,Aging_Days__c,Aging_Reason__c,Assigned_Negotiator__c,Assigned_Negotiator__r.Name, Assigned_Patient_Liaison_Specialist__r.Name, Assigned_Follow_Up_Advisor__r.Name, Billing_Provider_Group__c, Billing_Provider_Group__r.Billing_Provider_Group_Name__c,CaseNumber,CreatedDate,Employer_Name__c,Id,Initiated_By__c,On_Hold__c,Origin,ToLabel(Milestone__c),OwnerId,Owner.Name,Patient_Name__c,Status, Type');
    caseSelector.setWhereClause('where IsClosed = false and V2_Case__c = true order by CaseNumber');
    toReturn = caseSelector.getCases();
  }
  else if (mode == 'Advisor')
  {
    Id userId = UserInfo.getUserId();  
    CasesSelector caseSelector = new CasesSelector();  
    caseSelector.setSelectClause('SELECT Digital__c,Aging_Business_Days__c,Active_Business_Days__c,Aging_Days__c,Aging_Reason__c,Assigned_Negotiator__c,Assigned_Negotiator__r.Name, Assigned_Patient_Liaison_Specialist__r.Name, Assigned_Follow_Up_Advisor__r.Name, Billing_Provider_Group__c, Billing_Provider_Group__r.Billing_Provider_Group_Name__c,CaseNumber,CreatedDate,Employer_Name__c,Id,Initiated_By__c,On_Hold__c,Origin,ToLabel(Milestone__c),OwnerId,Owner.Name,Patient_Name__c,Status, Type ');
    caseSelector.setWhereClause('where IsClosed = false and V2_Case__c = true and (OwnerId = ' + userId + ' or Assigned_Follow_Up_Advisor__c = ' + userId + ') order by CaseNumber');
    toReturn = caseSelector.getCases();
  }
  else if (mode == 'Negotiator')
  {
    Id userId = UserInfo.getUserId();    
    CasesSelector caseSelector = new CasesSelector();
    caseSelector.setSelectClause('SELECT Digital__c,Aging_Business_Days__c,Active_Business_Days__c,Aging_Days__c,Aging_Reason__c,Assigned_Negotiator__c,Assigned_Negotiator__r.Name, Assigned_Patient_Liaison_Specialist__r.Name, Assigned_Follow_Up_Advisor__r.Name, Billing_Provider_Group__c, Billing_Provider_Group__r.Billing_Provider_Group_Name__c,CaseNumber,CreatedDate,Employer_Name__c,Id,Initiated_By__c,On_Hold__c,Origin,ToLabel(Milestone__c),OwnerId,Owner.Name,Patient_Name__c,Status, Type');
    caseSelector.setWhereClause('where IsClosed = false and V2_Case__c = true and (Assigned_Negotiator__c = ' + userId + ' or (OwnerId = ' + userId +' and Origin=\'Provider\'))  order by CaseNumber');
    toReturn = caseSelector.getCases();
    
  }
  else if (mode == 'Specialist')
  {
    Id userId = UserInfo.getUserId();
    CasesSelector caseSelector = new CasesSelector();    	
    caseSelector.setSelectClause('SELECT Digital__c,Aging_Business_Days__c,Active_Business_Days__c,Aging_Days__c,Aging_Reason__c,Assigned_Negotiator__c,Assigned_Negotiator__r.Name, Assigned_Patient_Liaison_Specialist__r.Name, Assigned_Follow_Up_Advisor__r.Name, Billing_Provider_Group__c, Billing_Provider_Group__r.Billing_Provider_Group_Name__c,CaseNumber,CreatedDate,Employer_Name__c,Id,Initiated_By__c,On_Hold__c,Origin,ToLabel(Milestone__c),OwnerId,Owner.Name,Patient_Name__c,Status, Type');
    caseSelector.setWhereClause(' IsClosed = false and V2_Case__c = true and (Assigned_Patient_Liaison_Specialist__c = ' + userId + ' or (OwnerId = ' + userId + ' and Origin=\'Provider\'))  order by CaseNumber');
    toReturn = caseSelector.getCases();
  }
  
  return toReturn;
}

@AuraEnabled
public static List<Task> GetCasesForTasksRequiringAttention(string mode) {
    List<Task> tasks = new List<Task>();
    List<Task> overDueTasks = new List<Task>();
    Id userId = UserInfo.getUserId();

    if (mode == 'Admin')
    {
        tasks = [SELECT Case__r.Digital__c,Id,FollowUpTaskID__c,RecordTypeId,RecordType.Name,Task_Occured_Due_Date__c, Task_Reason__c,Status,  Case__c, Case__r.CaseNumber,Case__r.Milestone__c, Case__r.Status, Owner.Name FROM Task where Case__r.V2_Case__c = true and Case__c != null and Case__r.CaseNumber != null and RecordTypeId != null and Task_Occured_Due_Date__c != null and IsClosed = false and Task_Occured_Due_Date__c <= TODAY order by Task_Occured_Due_Date__c asc];
    }
    else {
        tasks = [SELECT Case__r.Digital__c,Id,FollowUpTaskID__c,RecordTypeId,RecordType.Name,Task_Occured_Due_Date__c, Task_Reason__c,Status,  Case__c, Case__r.CaseNumber,Case__r.Milestone__c, Case__r.Status, Owner.Name FROM Task where Case__r.V2_Case__c = true and OwnerId = :userId and Case__c != null and Case__r.CaseNumber != null and RecordTypeId != null and Task_Occured_Due_Date__c != null and IsClosed = false and  Task_Occured_Due_Date__c <= TODAY order by Task_Occured_Due_Date__c asc];
    }

    for(Task t :tasks){
      date dueDate;
      date today;

      dueDate = date.newInstance(t.Task_Occured_Due_Date__c.year(), t.Task_Occured_Due_Date__c.month(), t.Task_Occured_Due_Date__c.day()) ;
      today = date.newInstance(System.Now().year(), System.Now().month(), System.Now().day()) ;

      if (dueDate <= today)
      {
          Integer  iDays =  dueDate.daysBetween(today);

          if (iDays == 0)
          {
              t.Status = 'Due Today';
          }
          else {

              if (iDays == 1)
              {
                  t.Status = 'Overdue by (1) Day';
              }
              else {
                  t.Status = 'Overdue by (' + iDays + ') Days';
              }
          }
      }
  }


    return tasks;
}

// US3118060 - CasesRequiringAttention
@AuraEnabled
public static List<casesReqWrap> GetCasesForCasesRequiringAttention(string mode) {
    
	List<Case> caseLst = new List<Case>();
	List<casesReqWrap> wrapList = new List<casesReqWrap>();
    Id userId = UserInfo.getUserId();
	
	User user = [SELECT Id, UserRole.Name FROM User WHERE Id =: userId];

    caseLst = [SELECT Id, Type, Origin, CaseNumber, Owner.Name, CreatedDate, Milestone__c, Status, Digital__c, OwnerId, Assigned_Negotiator__c, 			
				Assigned_Follow_Up_Advisor__c, (SELECT Milestone__c, Status__c, Occured_Date__c FROM Case_Progress_Logs__r ORDER BY Occured_Date__c DESC LIMIT 1) 
				FROM Case 
				WHERE  
				Milestone__c IN ('Initiation', 'Negotiation', 'Follow_Up') AND 
				Status IN ('Assigned', 'Pending')];
    
	if(!caseLst.isEmpty()){
		Boolean isToCaseAdd;
		date dueDate;
		date today = date.newInstance(System.Now().year(), System.Now().month(), System.Now().day()) ;
		for(Case cse : caseLst){	
		  isToCaseAdd = false;	
		  dueDate = null;
		  String action='', mileStoneStr = '', statusStr = '';
			
		  for(Case_Progress_Log__c cseLog: cse.Case_Progress_Logs__r){
			dueDate = date.newInstance(cseLog.Occured_Date__c.year(), cseLog.Occured_Date__c.month(), cseLog.Occured_Date__c.day()) ;
      mileStoneStr = cseLog.Milestone__c;
			statusStr = cseLog.Status__c;

		  }
		  
		  casesReqWrap wrapObj = new casesReqWrap();
		  
		  wrapObj.CaseNumber = cse.CaseNumber;
			wrapObj.Type = cse.Type;
			wrapObj.InitiatedBy = cse.Origin;
			wrapObj.CreatedDate = cse.CreatedDate;
			wrapObj.Milestone = cse.Milestone__c;
			wrapObj.Status = cse.Status;
			wrapObj.Digital = cse.Digital__c;
			wrapObj.OwnerName = cse.Owner.Name;
			wrapObj.Id = cse.Id;
		  
		  if( ((mode == 'Advisor' && cse.Origin == 'Patient' && cse.OwnerId == userId &&  user.UserRole.Name == 'Advisor') || mode == 'Admin')  && mileStoneStr == 'Initiation' && statusStr == 'Assigned'){
			action = 'Begin Engagement Activities';
			//overdue = 'After 1 Business Day update the Overdue by 1 day and subsequently for each day the Milestone is '+ cse.Milestone__c +' and Status is '+ cse.Status + '.';
			isToCaseAdd = true;
		  }
		  else if(((mode == 'Negotiator' && cse.Origin == 'Patient' && cse.Assigned_Negotiator__c == userId && user.UserRole.Name == 'Negotiator' ) || mode == 'Admin') && mileStoneStr == 'Negotiation' && statusStr == 'Assigned'){
			action = 'Begin Negotiation Activities';
			isToCaseAdd = true;
		  }
		  else if(((mode == 'Advisor' && user.UserRole.Name == 'Advisor' && ((cse.Origin == 'Provider' && cse.Assigned_Follow_Up_Advisor__c == userId)
				|| (cse.Origin == 'Patient' && cse.OwnerId == userId) ) ) || mode == 'Admin') && mileStoneStr == 'Follow_Up' && statusStr == 'Pending'){
			action = 'Begin Follow Up Activities';
			isToCaseAdd = true;
		  }
		  else if(((mode == 'Negotiator' && cse.Origin == 'Patient' && cse.OwnerId == userId &&  user.UserRole.Name == 'Negotiator') || mode == 'Admin') && mileStoneStr == 'Initiation' && statusStr == 'Assigned'){
			action = 'Begin Negotiation Activities';
			isToCaseAdd = true;
		  }
		  if (dueDate != null && dueDate <= today && isToCaseAdd)
		  {
			  Integer  iDays =  calculateBusinessDaysBetween(dueDate, Date.today());

			  if (iDays == 0)
			  {
				  wrapObj.Action = action;
			  }
			  else {

				  if (iDays == 1)
				  {
					  wrapObj.Action = action + ' - overdue by 1 day';
				  }
				  else {
					  wrapObj.Action = action +' - overdue by '+ iDays +' days';
				  }
			  }
			  wrapList.add(wrapObj);
		  }
		  
		}
	}
	    return wrapList;
}

  @AuraEnabled
  public static List<External_Configurations__c> GetExternalConfigs() {
      return V2_Utility.GetExternalConfigs();
  }

  @AuraEnabled
  public static CaseDataTableWrapper SearchCasesV2(string searchString, string searchType) {
    
	  //Offset for SOQL
	  Integer pageNumber = 1, pageSize = 50;
    Integer offset = (pageNumber - 1) * pageSize;
         
    //Total Records
    Integer totalRecords;
    Integer recordEnd = pageSize * pageNumber;
 
    //Instance of Contact DataTable Wrapper Class
    CaseDataTableWrapper objDT =  new CaseDataTableWrapper();  
    objDT.pageSize = pageSize;
    objDT.pageNumber = pageNumber;
    objDT.recordStart = offset + 1;
	  
    // LIMIT :pageSize OFFSET :offset	
	  List<Case> matchingCaseIds = new List<Case>();
    List<Case> matchingRecords = new List<Case>();
    CasesSelector caseSelector = new CasesSelector();

    searchString = string.escapeSingleQuotes(searchString.Replace('\'', '\\\''));

    string primarySQL = 'SELECT Id FROM Case ' ; 
    caseSelector.setSelectClause('SELECT Id');
    
    Map<string, string> mapSubQuery = new Map<string, string>();
    mapSubQuery.put('Case Number',' CaseNumber like \'%<<>>%\'');
    mapSubQuery.put('Patient Name',' Patient_ID__r.Name like \'%<<>>%\'');
    mapSubQuery.put('Billing Group Name',' Billing_Provider_Group__r.Billing_Provider_Group_Name__c  like \'%<<>>%\'');
    mapSubQuery.put('Billing Agency Name',' Billing_Agency__r.Billing_Agency_Name__c   like \'%<<>>%\'');
    mapSubQuery.put('Employer Name',' Employer_Name__c like \'%<<>>%\'');
    //mapSubQuery.put('Advisor Name',' Owner.Name like \'%<<>>%\'');
    mapSubQuery.put('Advisor Name',' ( (Owner.Name like \'%<<>>%\' and Origin != \'Provider\') or (Assigned_Follow_Up_Advisor__r.Name like \'%<<>>%\' and Origin = \'Provider\'))');    
    mapSubQuery.put('Negotiator Name',' ( (Assigned_Negotiator__r.Name like \'%<<>>%\' and Origin != \'Provider\') or (Owner.Name like \'%<<>>%\' and Origin = \'Provider\'))');    
    mapSubQuery.put('Liaison Specialist Name',' ( (Assigned_Patient_Liaison_Specialist__r.Name like \'%<<>>%\') or (Owner.Name like \'%<<>>%\' AND Owner.Profile.Name = \'Liaison Specialist User\'))');
    mapSubQuery.put('ORS Number',' ORS_Number__r.Name like \'<<>>%\'');
    

    List<string> primarySubSQL = new List<string>();
    

    if (searchType == 'All')
    {
      for (String Id : mapSubQuery.keySet()){
        primarySubSQL.add(mapSubQuery.get(Id).replace('<<>>', searchString));
      }
    }
    else {
      if (mapSubQuery.containsKey(searchType))
      {
        primarySubSQL.add(mapSubQuery.get(searchType).replace('<<>>', searchString));
      }
    }
    String whereClause = '';

    if (primarySubSQL.size() >  0)
    {
      
      whereClause+= ' WHERE (';
      boolean firstTime = true;

      for (string s: primarySubSQL)
      {
        if (!firstTime)
        {
          whereClause += ' OR ';
        }
        whereClause += ' ' + s;

        firstTime = false;
      }

      whereClause += ') and V2_Case__c = true ';
      caseSelector.setWhereClause(whereClause);

      matchingCaseIds =  caseSelector.getCases();
    }

    if (searchType == 'All' || searchType == 'Family Contact')
    {
      primarySQL = 'SELECT Enrolee__c FROM Contact where name like \'%<<>>%\' and Enrolee__c != null';
      primarySQL = primarySQL.replace('<<>>', searchString);
      system.debug('Family Contact SQL:' + primarySQL);

      List<Contact> contacts = Database.query(primarySQL);
      List<string> enroleeIds = new List<string>();

      if (contacts != null && contacts.size()> 0)
      {
        for(Contact c: contacts)
        {
          enroleeIds.Add(c.Enrolee__c);
        }
        caseSelector.setSelectClause('SELECT Id'); 
        caseSelector.setWhereClause('WHERE Patient_Id__r.Enrolee_Id__c in (' + SelectorUtilities.expandListForInClause(enroleeIds) + ')' + 'and V2_Case__c = true'); 
        matchingCaseIds.addAll(caseSelector.getCases());
      }

    }

// Added by Praneeth as part of US3303806 on 2/21/2021--> Changes Start 
   	if (searchType == 'All' || searchType == 'ICN Number'){
        primarySQL = 'select Id,Claim_Number__c,Case__r.Id from Case_Claim_Summary__c where Claim_Number__c like \'%<<>>%\'';
        primarySQL = primarySQL.replace('<<>>', searchString);
        List<String>claimIds = new List<String>();
        List<Case_Claim_Summary__c> claimSummaryRecs = Database.query(primarySQL);
        if(claimSummaryRecs !=null && claimSummaryRecs.size()>0) {
          for(Case_Claim_Summary__c claims : claimSummaryRecs) {
                claimIds.add(claims.Case__r.Id);
          }
          caseSelector.setSelectClause('SELECT Id'); 
          caseSelector.setWhereClause('WHERE Id in (' + SelectorUtilities.expandListForInClause(claimIds) + ')' + 'and V2_Case__c = true'); 
       	  matchingCaseIds.addAll(caseSelector.getCases());
     	 }
    } 
	  
    if (searchType == 'All' || searchType == 'Rendering Provider'){
        primarySQL = 'select Id,Case__r.Id,Rendering_Provider_Name__c from Case_Claim_Summary__c where Rendering_Provider_Name__c  like \'%<<>>%\'';
        primarySQL = primarySQL.replace('<<>>', searchString);
        List<String>renderingCaseIds = new List<String>();
        List<Case_Claim_Summary__c> claimSummaryRecs = Database.query(primarySQL);
        if(claimSummaryRecs !=null && claimSummaryRecs.size()>0) {
            for(Case_Claim_Summary__c claims : claimSummaryRecs) {
                renderingCaseIds.add(claims.Case__r.Id);
            }
        caseSelector.setSelectClause('SELECT Id'); 
        caseSelector.setWhereClause('WHERE Id in (' + SelectorUtilities.expandListForInClause(renderingCaseIds) + ')' + 'and V2_Case__c = true'); 
        matchingCaseIds.addAll(caseSelector.getCases());
        }
    } 
  // US3303806 Changes END
    
    if (searchType == 'All' || searchType == 'Provider Contact')
    {
      primarySQL = 'SELECT Billing_Agency__c FROM Contact where name like \'%<<>>%\' and Billing_Agency__c != null';
      primarySQL = primarySQL.replace('<<>>', searchString);
      system.debug('Provider Contact SQL:' + primarySQL);
      List<Contact> contacts = Database.query(primarySQL);
      List<string> billingAgencyIds = new List<string>();

      if (contacts != null && contacts.size()> 0)
      {
        for(Contact c: contacts)
        {
          billingAgencyIds.Add(c.Billing_Agency__c);
        }
        caseSelector.setSelectClause('SELECT Id'); 
        caseSelector.setWhereClause('WHERE Billing_Agency__c in (' + SelectorUtilities.expandListForInClause(billingAgencyIds) + ')' + 'and V2_Case__c = true'); 
        matchingCaseIds.addAll([SELECT Id FROM Case where Billing_Agency__c in :billingAgencyIds and V2_Case__c = true]);
      }

      primarySQL = 'SELECT Billing_Provider_Group__c FROM Contact where name like \'%<<>>%\' and Billing_Provider_Group__c != null';
      primarySQL = primarySQL.replace('<<>>', searchString);
      contacts = Database.query(primarySQL);
      List<string> billingProviderGroupIds = new List<string>();

      if (contacts != null && contacts.size()> 0)
      {
        for(Contact c: contacts)
        {
          billingProviderGroupIds.Add(c.Billing_Provider_Group__c);
        }
        caseSelector.setSelectClause('SELECT Id'); 
        caseSelector.setWhereClause('WHERE Billing_Provider_Group__c in (' + SelectorUtilities.expandListForInClause(billingProviderGroupIds) + ')');
        matchingCaseIds.addAll([SELECT Id FROM Case where Billing_Provider_Group__c in :billingProviderGroupIds and V2_Case__c = true]);
      }
    }


    if (matchingCaseIds != null)
    {
	  matchingRecords = getSearchCaseV2(matchingCaseIds, pageSize, offset);
	  totalRecords = [SELECT COUNT() FROM Case where Id in :matchingCaseIds];
	  objDT.matchingCaseIds = matchingCaseIds;
    }
    
	  objDT.recordEnd = totalRecords >= recordEnd ? recordEnd : totalRecords;
    objDT.totalRecords = totalRecords;
    objDT.caseList = matchingRecords;
    return objDT;
	
  }
  
  @AuraEnabled
  public static CaseDataTableWrapper getSearchBarCaseList(List<Case> matchingCaseIds, Integer pageNumber, Integer pageSize, Integer totalRecords){
	
	//Offset for SOQL
    Integer offset = (pageNumber - 1) * pageSize;
         
    //Total Records
    //Integer totalRecords;
    Integer recordEnd = pageSize * pageNumber;
     
    if(ceiling(totalRecords,pageSize) < pageNumber) {
          pageNumber = 1;
          offset = (1 - 1) * pageSize;
          recordEnd = pageSize * 1;
      }  
 
    //Instance of Contact DataTable Wrapper Class
    CaseDataTableWrapper objDT =  new CaseDataTableWrapper();  
    objDT.pageSize = pageSize;
    objDT.pageNumber = pageNumber;
    objDT.recordStart = offset + 1;
    // LIMIT :pageSize OFFSET :offset
    List<case> matchingRecords = new List<case>();
	
	  if (matchingCaseIds != null)
		{
		  matchingRecords = getSearchCaseV2(matchingCaseIds, pageSize, offset);
		  //totalRecords = [SELECT COUNT() FROM Case where Id in :matchingCaseIds];
		  //objDT.matchingCaseIds = matchingCaseIds;
		}
      
        
		objDT.recordEnd = totalRecords >= recordEnd ? recordEnd : totalRecords;
		objDT.totalRecords = totalRecords;
		objDT.caseList = matchingRecords;
		return objDT;	
  }
    
  //ceiling 
  public static Decimal ceiling(Integer x, Integer y){
    return Math.ceil(Decimal.valueOf(x).divide(y, 4));
  }  
  
  //to get matchingCaseIds for SearchCasesV2
  public static List<case> getSearchCaseV2(List<Case> matchingCaseIds, Integer pageSize, Integer offset){
	
	List<Case> matchingRecords = new List<Case>();
	
	 
      matchingRecords = [SELECT Aging_Reason__c, Aging_Business_Days__c, Active_Business_Days__c, Assigned_Follow_Up_Advisor__c, Assigned_Follow_Up_Advisor__r.Name, Digital__c, CreatedDate, ClosedDate, Disposition__c, IsClosed, CaseNumber ,ToLabel(Milestone__c) ,Status , Type ,Origin, On_Hold__c,Patient_Name__c ,Billing_Provider_Group__r.Billing_Provider_Group_Name__c ,Employer_Name__c ,Aging_Days__c ,Assigned_Negotiator__c ,Assigned_Negotiator__r.Name, Assigned_Patient_Liaison_Specialist__r.Name ,Billing_Provider_Group__c ,Id ,OwnerId ,Owner.Name,  ORS_Number__r.Name, ORS_Number__r.ORS_URL_LINK__c FROM Case where Id in :matchingCaseIds LIMIT :pageSize OFFSET :offset];

      if (V2_Utility.isTrainingModeOn())
      {
        for (Case c : matchingRecords)
        {
          if (!string.isblank(c.ORS_Number__r.Name))
          {
            c.ORS_Number__r.ORS_URL_LINK__c = 'about:blank';
          }
        }      
      }
      else {
        External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
        External_Configurations__c benchmarkURL = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_API_Root_URL' LIMIT 1];
  
        string userId = UserInfo.getUserId();
        User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c FROM User WHERE Id = :userId LIMIT 1];
  
        Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
        string url = 'https://' + benchmarkURL.ConfigValue__c + '/ors-research?';
        string fullStringToEcrypt = '';
         
        string tops_user_id = '';
        string tops_password = '';
          
        if (user.TOPS_User_ID__c != null && user.TOPS_User_ID__c != '' && user.TOPS_Password__c != null && user.TOPS_Password__c != '') {
          tops_user_id = user.TOPS_User_ID__c;
          tops_password = user.TOPS_Password__c;
        }
    
        for (Case c : matchingRecords)
        {
          if (!string.isblank(c.ORS_Number__r.Name))
          {
            fullStringToEcrypt = 'ors_id=' + c.ORS_Number__r.Name + '&tops_user_id=' + tops_user_id + '&tops_password=' + tops_password;
            Blob cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(fullStringToEcrypt));
            String encodedCipherText = EncodingUtil.base64Encode(cipherText);
            c.ORS_Number__r.ORS_URL_LINK__c = url + encodingUtil.URLEncode(encodedCipherText, 'UTF-8');
          }
        }      
          
      }
      
      // List<Patient_Bill__c> patientBills = [SELECT Actual_Balance_Bill_Amount__c, Case__c FROM Patient_Bill__c WHERE Case__c in :matchingCaseIds];
      // if (patientBills != null)
      // {
      //   Map<string, decimal> mapPatientBills = new Map<string, decimal>();
      //   for (Patient_Bill__c pb: patientBills)
      //   {
      //     mapPatientBills.put(pb.Case__c, pb.Actual_Balance_Bill_Amount__c);
      //   }

      //   for(Case c : matchingRecords)
      //   {
      //     if (mapPatientBills.containsKey(c.Id))
      //     {
      //       c.Cause_Code__c = String.valueOf(mapPatientBills.get(c.Id));
      //     }
      //   }
      // }
		
	return matchingRecords;	
	  
  }

  @AuraEnabled
  public static List<Case> SearchCasesV1(string searchString, string searchType) {
    List<Case> matchingCaseIds = new List<Case>();
    List<Case> matchingRecords = new List<Case>();
    CasesSelector caseSelector = new CasesSelector();
    searchString = string.escapeSingleQuotes (searchString.Replace('\'', '\\\''));

    string primarySQL = 'SELECT Id FROM Case ' ; 
    
    Map<string, string> mapSubQuery = new Map<string, string>();
    mapSubQuery.put('Case Number',' CaseNumber like \'%<<>>%\'');
    mapSubQuery.put('Patient Name',' Patient_ID__r.Name like \'%<<>>%\'');
    mapSubQuery.put('Provider Name',' Provider_ID__r.Provider_Name__c  like \'%<<>>%\'');
    mapSubQuery.put('Employer Name',' Employer_Name__c like \'%<<>>%\'');
    mapSubQuery.put('Advisor Name',' Owner.Name like \'%<<>>%\'');
    mapSubQuery.put('Negotiator Name',' Engagement__r.Negotiator_Name__r.Name like \'%<<>>%\'');
    mapSubQuery.put('ORS Number',' ORS_Number__r.Name like \'<<>>%\'');
    

    List<string> primarySubSQL = new List<string>();

    if (searchType == 'All')
    {
      for (String Id : mapSubQuery.keySet()){
        primarySubSQL.add(mapSubQuery.get(Id).replace('<<>>', searchString));
      }
    }
    else {
      if (mapSubQuery.containsKey(searchType))
      {
        primarySubSQL.add(mapSubQuery.get(searchType).replace('<<>>', searchString));
      }
    }

    

    if (primarySubSQL.size() >  0)
    {
      primarySQL+= ' WHERE (';
      boolean firstTime = true;

      for (string s: primarySubSQL)
      {
        if (!firstTime)
        {
          primarySQL += ' OR ';
        }
        primarySQL += ' ' + s;

        firstTime = false;
      }

      primarySQL+= ') and V2_Case__c = false ';

      system.debug(primarySQL);

      matchingCaseIds =  Database.query(primarySQL);
    }

    if (searchType == 'All' || searchType == 'Family Contact')
    {
      primarySQL = 'SELECT Enrolee__c FROM Contact where name like \'%<<>>%\' and Enrolee__c != null';
      primarySQL = primarySQL.replace('<<>>', searchString);
      system.debug('Family Contact SQL:' + primarySQL);

      List<Contact> contacts = Database.query(primarySQL);
      List<string> enroleeIds = new List<string>();

      if (contacts != null && contacts.size()> 0)
      {
        for(Contact c: contacts)
        {
          enroleeIds.Add(c.Enrolee__c);
        }
        matchingCaseIds.addAll([SELECT Id FROM Case where Patient_ID__r.Enrolee_ID__c in :enroleeIds and V2_Case__c = false]);
      }

    }

// Added by Praneeth as part of US3303806 on 2/21/2021--> Changes Start 
   	if (searchType == 'All' || searchType == 'ICN Number'){
        primarySQL = 'select Id,Claim_Number__c,Case__r.Id from Case_Claim_Summary__c where Claim_Number__c like \'%<<>>%\'';
        primarySQL = primarySQL.replace('<<>>', searchString);
        List<String>claimIds = new List<String>();
        List<Case_Claim_Summary__c> claimSummaryRecs = Database.query(primarySQL);
        if(claimSummaryRecs !=null && claimSummaryRecs.size()>0) {
          for(Case_Claim_Summary__c claims : claimSummaryRecs) {
                claimIds.add(claims.Case__r.Id);
          }
          caseSelector.setSelectClause('SELECT Id'); 
          caseSelector.setWhereClause('WHERE Id in (' + SelectorUtilities.expandListForInClause(claimIds) + ')' + 'and V2_Case__c = true'); 
       	  matchingCaseIds.addAll(caseSelector.getCases());
     	 }
    } 
	  
    if (searchType == 'All' || searchType == 'Rendering Provider'){
        primarySQL = 'select Id,Case__r.Id,Rendering_Provider_Name__c from Case_Claim_Summary__c where Rendering_Provider_Name__c  like \'%<<>>%\'';
        primarySQL = primarySQL.replace('<<>>', searchString);
        List<String>renderingCaseIds = new List<String>();
        List<Case_Claim_Summary__c> claimSummaryRecs = Database.query(primarySQL);
        if(claimSummaryRecs !=null && claimSummaryRecs.size()>0) {
            for(Case_Claim_Summary__c claims : claimSummaryRecs) {
                renderingCaseIds.add(claims.Case__r.Id);
            }
        caseSelector.setSelectClause('SELECT Id'); 
        caseSelector.setWhereClause('WHERE Id in (' + SelectorUtilities.expandListForInClause(renderingCaseIds) + ')' + 'and V2_Case__c = true'); 
        matchingCaseIds.addAll(caseSelector.getCases());
        }
    } 
  // US3303806 Changes END
    
    if (searchType == 'All' || searchType == 'Provider Contact')
    {
      primarySQL = 'SELECT Provider_Group__c FROM Contact where name like \'%<<>>%\' and Provider_Group__c != null';
      primarySQL = primarySQL.replace('<<>>', searchString);
      system.debug('Provider Contact SQL:' + primarySQL);
      List<Contact> contacts = Database.query(primarySQL);
      List<string> providerGroupIds = new List<string>();

      if (contacts != null && contacts.size()> 0)
      {
        for(Contact c: contacts)
        {
          providerGroupIds.Add(c.Provider_Group__c);
        }
        matchingCaseIds.addAll([SELECT Id FROM Case where Provider_ID__r.Provider_Group__c in :providerGroupIds and V2_Case__c = false]);
      }
    }


    if (matchingCaseIds != null)
    {
      matchingRecords = [SELECT CreatedDate, ClosedDate, Disposition__c, IsClosed, CaseNumber ,ToLabel(Milestone__c) ,Status , Type ,Origin ,Patient_Name__c , Provider_ID__r.Full_Name__c,  Employer_Name__c ,Aging_Days__c ,Engagement__r.Negotiator_Name__r.Name,Id ,OwnerId ,Owner.Name,  ORS_Number__r.Name, ORS_Number__r.ORS_URL_LINK__c FROM Case where Id in :matchingCaseIds];
      External_Configurations__c key256FromConfig = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_AES_256_Key' LIMIT 1];
      External_Configurations__c benchmarkURL = [SELECT ConfigValue__c FROM External_Configurations__c WHERE Name = 'Benchmark_API_Root_URL' LIMIT 1];
      string userId = UserInfo.getUserId();
      User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c FROM User WHERE Id = :userId LIMIT 1];

      Blob key256 = Blob.valueOf(key256FromConfig.ConfigValue__c);
      string url = 'https://' + benchmarkURL.ConfigValue__c + '/ors-research?';
      string fullStringToEcrypt = '';
       
      string tops_user_id = '';
      string tops_password = '';
        
      if (user.TOPS_User_ID__c != null && user.TOPS_User_ID__c != '' && user.TOPS_Password__c != null && user.TOPS_Password__c != '') {
        tops_user_id = user.TOPS_User_ID__c;
        tops_password = user.TOPS_Password__c;
      }
  
      for (Case c : matchingRecords)
      {
        if (!string.isblank(c.ORS_Number__r.Name))
        {
          fullStringToEcrypt = 'ors_id=' + c.ORS_Number__r.Name + '&tops_user_id=' + tops_user_id + '&tops_password=' + tops_password;
          Blob cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(fullStringToEcrypt));
          String encodedCipherText = EncodingUtil.base64Encode(cipherText);
          c.ORS_Number__r.ORS_URL_LINK__c = url + encodingUtil.URLEncode(encodedCipherText, 'UTF-8');
        }
      }      
      
      // List<Patient_Bill__c> patientBills = [SELECT Actual_Balance_Bill_Amount__c, Case__c FROM Patient_Bill__c WHERE Case__c in :matchingCaseIds];
      // if (patientBills != null)
      // {
      //   Map<string, decimal> mapPatientBills = new Map<string, decimal>();
      //   for (Patient_Bill__c pb: patientBills)
      //   {
      //     mapPatientBills.put(pb.Case__c, pb.Actual_Balance_Bill_Amount__c);
      //   }

      //   for(Case c : matchingRecords)
      //   {
      //     if (mapPatientBills.containsKey(c.Id))
      //     {
      //       c.Cause_Code__c = String.valueOf(mapPatientBills.get(c.Id));
      //     }
      //   }
      // }

    }
    
    
    return matchingRecords;    
  }


  @AuraEnabled
  public static Integration_Task__c GetSPITRecord(Id id) {
    Integration_Task__c it = IntegrationTask.GetIntegrationTask(id);
    return it;
  }
  

  @AuraEnabled
  public static Integration_Task__c CreateIntegrationTaskForAdvisorReassign(Id caseId, Id advisorIdToReassign){
    
    Case cse = [SELECT Id, Case.ORS_Number__r.Name, OwnerId, Milestone__c, Status FROM Case WHERE Id = :caseId];

    // if (cse.Milestone__c == 'Initiation' && cse.Status == 'Unassigned')
    // {
    //   throw new applicationException('UNASSIGNED');
    // }

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
    User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c,ORS_Office__c,ORS_Dept__c,ORS_Team__c,ORS_Ind__c FROM User WHERE Id = :userId LIMIT 1];
    User userToRoute = [SELECT Id, ORS_Office__c,ORS_Dept__c,ORS_Team__c,ORS_Ind__c FROM User WHERE Id = :advisorIdToReassign LIMIT 1];
    if (!string.isblank(user.TOPS_User_ID__c) && !string.isblank(user.TOPS_Password__c)) {
      string tops_user_id = user.TOPS_User_ID__c;
      string tops_password = user.TOPS_Password__c;

      Blob cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(tops_user_id));
      String encodedCipherText = EncodingUtil.base64Encode(cipherText);
      PARM2 = encodingUtil.URLEncode(encodedCipherText, 'UTF-8');

      cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(tops_password));
      encodedCipherText = EncodingUtil.base64Encode(cipherText);
      PARM3 = encodingUtil.URLEncode(encodedCipherText, 'UTF-8');
    }
    else {
      throw new applicationException('MISSING TOPS CREDENTIALS');
    }

    if (string.isblank(userToRoute.ORS_Office__c) || string.isblank(userToRoute.ORS_Dept__c) || string.isblank(userToRoute.ORS_Team__c) || string.isblank(userToRoute.ORS_Ind__c))
    {
      throw new applicationException('MISSING ROUTE');
    }

    PARMBIG1 = 'Naviguard Advisor Reassignment';
    TaskType = 'ROUTE ORS RECORD';
    PARM4 = userToRoute.ORS_Office__c + ' ' + userToRoute.ORS_Dept__c + ' ' + userToRoute.ORS_Team__c + ' ' + userToRoute.ORS_Ind__c;

    Integration_Task__c it = IntegrationTask.createIntegrationTask(TaskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
    Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
    String encodedGUIDText = EncodingUtil.base64Encode(guidText);
    it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');

    return it;
  }

  @AuraEnabled
  public static Integration_Task__c CreateIntegrationTaskForNegotiatorReassign(Id caseId, Id negotiatorIdToReassign){
    
    Case cse = [SELECT Id, Case.ORS_Number__r.Name, OwnerId, Milestone__c, Status FROM Case WHERE Id = :caseId];

    // if (cse.Milestone__c == 'Initiation' && cse.Status == 'Unassigned')
    // {
    //   throw new applicationException('UNASSIGNED');
    // }

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
    User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c,ORS_Office__c,ORS_Dept__c,ORS_Team__c,ORS_Ind__c FROM User WHERE Id = :userId LIMIT 1];
    User userToRoute = [SELECT Id, ORS_Office__c,ORS_Dept__c,ORS_Team__c,ORS_Ind__c FROM User WHERE Id = :negotiatorIdToReassign LIMIT 1];

    if (!string.isblank(user.TOPS_User_ID__c) && !string.isblank(user.TOPS_User_ID__c)) {
      string tops_user_id = user.TOPS_User_ID__c;
      string tops_password = user.TOPS_Password__c;

      Blob cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(tops_user_id));
      String encodedCipherText = EncodingUtil.base64Encode(cipherText);
      PARM2 = encodingUtil.URLEncode(encodedCipherText, 'UTF-8');

      cipherText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(tops_password));
      encodedCipherText = EncodingUtil.base64Encode(cipherText);
      PARM3 = encodingUtil.URLEncode(encodedCipherText, 'UTF-8');
    }
    else {
      throw new applicationException('MISSING TOPS CREDENTIALS');
    }

    if (string.isblank(userToRoute.ORS_Office__c) || string.isblank(userToRoute.ORS_Dept__c) || string.isblank(userToRoute.ORS_Team__c) || string.isblank(userToRoute.ORS_Ind__c))
    {
      throw new applicationException('MISSING ROUTE');
    }

    PARMBIG1 = 'Naviguard Patient Liaison Reassignment';
    TaskType = 'ROUTE ORS RECORD';
    PARM4 = userToRoute.ORS_Office__c + ' ' + userToRoute.ORS_Dept__c + ' ' + userToRoute.ORS_Team__c + ' ' + userToRoute.ORS_Ind__c;

    Integration_Task__c it = IntegrationTask.createIntegrationTask(TaskType, RelatedTask, PARM1, PARM2, PARM3, PARM4, PARM5, PARM6, PARM7, PARM8, PARM9, PARM10, PARMBIG1, PARMBIG2);
    Blob guidText = Crypto.encryptWithManagedIV('AES256', key256, Blob.valueOf(it.GUID__c));
    String encodedGUIDText = EncodingUtil.base64Encode(guidText);
    it.GUID__c = encodingUtil.URLEncode(encodedGUIDText, 'UTF-8');

    return it;
  }


  @AuraEnabled
  public static List<Contact> SearchForBillingAgenciesContactJoin(string billingGroupId, string billingAgencyNameSearchString, string contactNameSearchString, string phoneNumberSearchString){
    List<Contact> matchingRecords = new List<Contact>();

    string primarySQL = '';
    List<string> primarySubSQL = new List<string>();
    
    
    billingAgencyNameSearchString = billingAgencyNameSearchString.Replace('\'', '\\\'');
    contactNameSearchString = contactNameSearchString.Replace('\'', '\\\'');

    primarySQL = 'Select Preferred_Phone_Type__c, Id,HomePhone, MobilePhone, Work_Phone__c, OtherPhone, Name , Billing_Agency__c, Billing_Agency__r.Billing_Agency_Name__c, Role__c from Contact ';
    
    primarySubSQL.add(' Billing_Agency__c != null ');

    if (string.isNotBlank(billingGroupId))
    {
      primarySubSQL.add(' Billing_Agency__c in (Select Billing_Agency__c from Case where Billing_Provider_Group__c = :billingGroupId) ');
    }
    
    if (string.isNotBlank(billingAgencyNameSearchString))
    {
      primarySubSQL.add(' Billing_Agency__r.Billing_Agency_Name__c like \'' + billingAgencyNameSearchString + '%\' ');
    }

    if (string.isNotBlank(contactNameSearchString)){
      primarySubSQL.add(' Name LIKE \'' + contactNameSearchString + '%\' ');
    }

    if (string.isNotBlank(phoneNumberSearchString)){
      primarySubSQL.add(' (HomePhone LIKE \'' + phoneNumberSearchString + '%\' or MobilePhone LIKE \'' + phoneNumberSearchString + '%\' or Work_Phone__c LIKE \'' + phoneNumberSearchString + '%\' or OtherPhone LIKE \'' + phoneNumberSearchString + '%\')');
    }

    if (primarySubSQL.size() >  0)
    {
      
      primarySQL+= ' WHERE ';
      boolean firstTime = true;

      for (string s: primarySubSQL)
      {
        if (!firstTime)
        {
          primarySQL += ' AND ';
        }
        primarySQL += ' ' + s;

        firstTime = false;
      }


      matchingRecords =  Database.query(primarySQL);
    }
    return matchingRecords;
  }

  @AuraEnabled
  public static Profile GetUserProfile(){
    return V2_Utility.GetUserProfile();
  }

  //Helper method to generate a reopen payload
  private static PatientPortalAPIHelper.ReopenORSIssuePayload generateReopenPayload(Case caseFields, User callingAssociate, User routeToUser, String reopenReason) {
    return new PatientPortalAPIHelper.ReopenORSIssuePayload(
      //issueId
      caseFields.Ors_Number__r.Name,
      //topsuserid
      callingAssociate.TOPS_User_Id__c, 
      //topspassword
      callingAssociate.TOPS_Password__c,
      //callingassociate
      callingAssociate.Name,
      //callingoffice
      callingAssociate.ORS_Office__c,
      //routeToOffice 
      routeToUser.ORS_Office__c,
      //routeToDept 
      routeToUser.ORS_Dept__c,
      //routeToTeam 
      routeToUser.ORS_Team__c,
      //routeToInd 
      routeToUser.ORS_Ind__c,
      //routeComments 
      'Naviguard Reassignment',
      //statusUpdateComments 
      reopenReason
    );
  }
  
  //Wrapper Class For Case DataTable  
    public class CaseDataTableWrapper {
      @AuraEnabled
      public Integer pageSize {get;set;}
      @AuraEnabled
      public Integer pageNumber {get;set;}
      @AuraEnabled
      public Integer totalRecords {get;set;}
      @AuraEnabled
      public Integer recordStart {get;set;}
      @AuraEnabled
      public Integer recordEnd {get;set;}
      @AuraEnabled
      public List<Case> caseList {get;set;}
	    @AuraEnabled
      public List<Case> matchingCaseIds {get;set;}
	    @AuraEnabled
      public String mode {get;set;}
	    @AuraEnabled
      public String mileStone {get;set;}
    }
	//Wrapper Class For Case CasesRequiringAttention
	public class casesReqWrap{
		
		@AuraEnabled
		public String CaseNumber {get;set;}
		@AuraEnabled
		public String Type {get;set;}
		@AuraEnabled
		public String InitiatedBy {get;set;}
		@AuraEnabled
		public DateTime CreatedDate {get;set;}
		@AuraEnabled
		public String Milestone {get;set;}
		@AuraEnabled
		public String Status {get;set;}
		@AuraEnabled
		public String Digital {get;set;}
		@AuraEnabled
		public String OwnerName {get;set;}
		@AuraEnabled
		public String Id {get;set;}
		@AuraEnabled
		public String Action {get;set;}
		@AuraEnabled
		public String Overdue {get;set;}
	}
  
  private static Integer calculateBusinessDaysBetween(Date startDate, Date endDate) {
    Integer workingDays = 0;
    for(Integer i = 0; i <= startDate.daysBetween(endDate); i++) {
        Date dt = startDate + i;
        DateTime currentDate = DateTime.newInstance(dt.year(), dt.month(), dt.day());
        String todayDay = currentDate.format('EEEE');
        if(todayDay != 'Saturday' && todayDay != 'Sunday') {
            workingDays += 1;
        }
    }
    return workingDays;
  }
}