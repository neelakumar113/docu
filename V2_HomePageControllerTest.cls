@isTest
private class V2_HomePageControllerTest {
    static void setup() {
        ORS__c ors = V2_TestDataFactory.createOrs();
        insert ors;

        Employer_Group__c eGroup = V2_TestDataFactory.createEmployerGroup();
        insert eGroup;

        Enrolee__c enrolee = V2_TestDataFactory.createEnrolee(eGroup.Id);
        insert enrolee;

        
        Contact contact = V2_TestDataFactory.createEnroleeContact(enrolee.Id);
        contact.Fax = '444-444-4444';
        insert contact;

        Patient__c patient = V2_TestDataFactory.createPatient(enrolee.Id);
        insert patient;

        Provider_Group__c pGroup = V2_TestDataFactory.createProviderGroup();
        insert pGroup;

        Provider__c provider = V2_TestDataFactory.createProvider(pGroup.Id);
        insert provider;

        Billing_Provider_Group__c bpg = V2_TestDataFactory.createBillingProvider();
        insert bpg;

        Case caseRecord = V2_TestDataFactory.createCase(
            ors.Id,
            patient.Id,
            provider.Id,
            bpg.Id
        );
        insert caseRecord;

        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;
    
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'NAVIGUARD_API_BASE_URL';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'USER_FILE_UPLOAD_PATH';
        c4.ConfigValue__c = '/blah/{0}/hello';
        insert c4;

        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'FAX COVER TEMPLATE';
        c5.ConfigValue__c = 'Cover Letter';
        insert c5;

        Case_Claim_Summary__c ccs = new Case_Claim_Summary__c();
        ccs.Case__c = caseRecord.Id;
        ccs.Claim_Case_Key__c = '00001229-AX40419342';
        ccs.Initial_Review__c =  CaseCompletionController.getOrCreateInitialReviewId(caseRecord.Id);
        ccs.CMS_Benchmark_Amount__c = 1;
        ccs.Claim_Billed_Amount__c = 1;
        ccs.Allowed__c = 1;
        ccs.Cost_Share__c = 1;
        ccs.Plan_Paid__c = 1;
        ccs.Negotiated_Allowed_Amount__c = 1;
        insert ccs;


        RecordType recTypeAttachAFile = [SELECT DeveloperName, Id, Name, SobjectType FROM RecordType WHERE DeveloperName = 'Attach_a_File' LIMIT 1];
        System.AssertNotEquals(null, recTypeAttachAFile);
    
        Task t = TaskOverlayController.InitTask(caseRecord.Id, recTypeAttachAFile, null);
        System.AssertNotEquals(null, t);
        t.Task_Attachment__c = 'Negotiated Terms';
        TaskOverlayController.CreateTask(t);

        Negotiation__c neg = V2_CaseDetailController.GetNegotiation(caseRecord.Id);
    
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
        
        User user = new User();
        user.Id = UserInfo.getUserId();
        user.TOPS_User_ID__c = '1';
        user.TOPS_Password__c = '1';
        user.ORS_Office__c = '1';
        user.ORS_Dept__c = '1';
        user.ORS_Team__c = '1';
        user.ORS_Ind__c = '1';
        update user;

        caseRecord.OwnerId = user.Id;                              
        update caseRecord;

        newFileList = V2_FileController.createPendingCaseFiles(caseRecord.Id, newFileList);
        for (Case_File__c c : newFileList)
        {
            c.File_Status__c = 'Uploaded';
            c.Smart_Doc__c = true;
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



        SD_File__c sdFile = new SD_File__c(Case__c = caseRecord.Id, Case_File__c = newFileList[0].Id, Cover_Letter__c = null, SD_Template__c = sdTemplate.Id);
        insert sdFile;

        CFax__c cFax = new CFax__c();
        cFax.CoverText__c = 'test';
        cFax.SD_File__r = SmartDocumentController.getSDFile(sdFile.Id);
        cFax.SD_File__c = sdFile.Id;
        cFax.Sent_By_User__c = UserInfo.getUserId();
        insert cFax;

        sdFile.CFax__c = cFax.Id;
        update sdFile;
        
        neg.Current_SD_File__c = sdFile.Id;
        update neg;

    }

    public static testMethod void test2() {
        Test.startTest();
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
        eg.Employer_Group_Name__c = 'blahdlkjfds';
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
        
        Billing_Provider_Group__c bpg = new Billing_Provider_Group__c();
        //bpg.Billing_Provider_Group_Name__c = 'Test';        
        bpg.MPIN__c = '123456';
        bpg.TIN__c = '123456';
        insert bpg;
        
        V2_ContactsController.GetBillingProviderGroupContacts(bpg.Id);
        V2_ContactsController.getPicklistvalues('Case', 'Status', false);
    
        Negotiation__c negotiation1 = new Negotiation__c();
        insert negotiation1;
        
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'Assigned';
        c.Milestone__c = 'Engagement';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
        c.Billing_Provider_Group__c = bpg.Id;
        c.V2_Case__c = true;     
        c.Negotiation__c = negotiation1.Id;
        insert c;
        
        Case case1 = new Case();
        case1.ORS_Number__c = o.Id;
        case1.Origin = 'ORS Record';
        case1.Status = 'Assigned';
        case1.Milestone__c = 'Engagement';
        case1.V2_Case__c = true;     
        case1.Negotiation__c = negotiation1.Id;
        insert case1;
    
        
        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';       
        insert c1;
    
        
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'NAVIGUARD_API_BASE_URL';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'USER_FILE_UPLOAD_PATH';
        c4.ConfigValue__c = '/blah/{0}/hello';
        insert c4;
    
        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'NAVIGUARD_API_BASE_URL';
        c5.ConfigValue__c = 'http://localhost.com';
        insert c5;
    
        External_Configurations__c c6 = new External_Configurations__c();
        c6.Name = 'SEND_EMAIL_ENDPOINT';
        c6.ConfigValue__c = 'BKADJD';
        insert c6;
    
        External_Configurations__c c7 = new External_Configurations__c();
        c7.Name = 'Benchmark_API_Root_URL';
        c7.ConfigValue__c = 'www.example.com';
        insert c7;
    
    
        External_Configurations__c c8 = new External_Configurations__c();
        c8.Name = 'QUALTRICS_Endpoint';
        c8.ConfigValue__c = 'www.google.com';
        insert c8;
    
        External_Configurations__c c9 = new External_Configurations__c();
        c9.Name = 'QUALTRICS_STATUS';
        c9.ConfigValue__c = 'ON';
        insert c9;
    
        External_Configurations__c c10 = new External_Configurations__c();
        c10.Name = 'QUALTRICS_token';
        c10.ConfigValue__c = 'ONdsfsdfsdfsd';
        insert c10;
    
    
        List<Patient_Bill__c> patientBillPre = V2_CaseDetailController.GetPatientBill(c.Id);
        c.Patient_ID__c = p.Id;
        Patient_Bill__c pbA = V2_CaseDetailController.GetPatientBillTotal(case1.Id);
        c.Patient_ID__c = p.Id;
    
        Patient_Bill__c pb = new Patient_Bill__c();
        pb.Actual_Balance_Bill_Amount__c = 0;
        pb.Case__c = c.Id;
        pb.Claim_Billed_Amount__c = 0;
        pb.Claim_Number__c = '1234';
        pb.Cost_Share_Overpayment__c = 0;
        pb.Patient_Paid_Amount__c = 0;
        pb.Patient_Total_Bill_Amount__c = 0;
        pb.Plan_Paid__c = 0;
        pb.Provider_Discount__c = 0;
        pb.Remaining_Cost_Share_Balance__c = 0;
        insert pb;
        
        Case_Claim_Summary__c ccs = new Case_Claim_Summary__c();
        ccs.Case__c = c.Id;
        ccs.Claim_Case_Key__c = '00001229-AX40419342';
        ccs.Initial_Review__c =  CaseCompletionController.getOrCreateInitialReviewId(c.Id);
        ccs.CMS_Benchmark_Amount__c = 1;
        ccs.Claim_Billed_Amount__c = 1;
        ccs.Allowed__c = 1;
        ccs.Cost_Share__c = 1;
        ccs.Plan_Paid__c = 1;
        ccs.Negotiated_Allowed_Amount__c = 1;
        insert ccs;
    
    
        c.Origin = 'Provider';
        c.Status = 'Assigned';
        c.Milestone__c = 'Initiation';
        c.OwnerId = UserInfo.getUserId();
        update c;
        V2_CaseDetailController.MoveStatusIfNeeded(c.Id, 'Follow Up');
        
        c.Origin = 'Patient';
        c.Status = 'Assigned';
        c.Milestone__c = 'Initiation';
        c.OwnerId = UserInfo.getUserId();
        update c;
        V2_CaseDetailController.MoveStatusIfNeeded(c.Id, 'Follow Up');
        


        Profile prf = [SELECT Id FROM Profile WHERE Name='Advisor User']; 
        User testUser = new User( Title= 'Test Account', LastName = 'LName', FirstName = 'FName',Alias = 'Alias',Email = 'test@naviguard.com',Username = 'test@naviguard.com',LocaleSidKey = 'en_US', EmailEncodingKey = 'ISO-8859-1', ProfileId = prf.Id, LanguageLocaleKey = 'en_US', TimeZoneSidKey = 'America/Los_Angeles'  );
        testUser.TOPS_User_ID__c = '1';
        testUser.TOPS_Password__c = '1';
        testUser.ORS_Office__c = '1';
        testUser.ORS_Dept__c = '1';
        testUser.ORS_Team__c = '1';
        testUser.ORS_Ind__c = '1';
        insert testUser;

        Profile prfN = [SELECT Id FROM Profile WHERE Name='Negotiator User']; 
        User testUserN = new User( Title= 'Test AccountN', LastName = 'LNameN', FirstName = 'FNameN',Alias = 'AliasN',Email = 'testN@naviguard.com',Username = 'testN@naviguard.com',LocaleSidKey = 'en_US', EmailEncodingKey = 'ISO-8859-1', ProfileId = prfN.Id, LanguageLocaleKey = 'en_US', TimeZoneSidKey = 'America/Los_Angeles'  );
        testUserN.TOPS_User_ID__c = '1';
        testUserN.TOPS_Password__c = '1';
        testUserN.ORS_Office__c = '1';
        testUserN.ORS_Dept__c = '1';
        testUserN.ORS_Team__c = '1'; 
        testUserN.ORS_Ind__c = '1';
        insert testUserN;


        c.OwnerId = testUser.Id;
        update c;

    	string userId = UserInfo.getUserId();
 		User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c,ORS_Office__c,ORS_Dept__c,ORS_Team__c,ORS_Ind__c FROM User WHERE Id = :userId LIMIT 1];
        user.TOPS_User_ID__c = 'test ysername';
        user.TOPS_Password__c = 'test1234';
        update user;
        List<string> caseList = new List<string>();
        caseList.add(c.Id);
        V2_HomePageController.AssignAdvisorFollowUpToCaseIdList(testUser.Id, caseList);
        V2_HomePageController.AssignNegotiatorToProviderCaseIdList(testUserN.Id, caseList);
        V2_HomePageController.AssignSpecialistToCaseIdList(testUser.Id, caseList);
        c.Milestone__c = 'Initiation';
        update c;

        V2_HomePageController.GetCaseByIndividual('','Admin');
        V2_HomePageController.GetCaseByIndividualWithRestrictions('','Admin', c.Id);
        V2_HomePageController.CreateIntegrationTaskForAdvisorReassign(c.Id,testUser.Id);
        V2_HomePageController.CreateIntegrationTaskForNegotiatorReassign(c.Id, testUserN.Id);
        V2_HomePageController.SearchForBillingAgenciesContactJoin(bpg.Id, 'test','','');
        V2_HomePageController.GetUserProfile();
        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        c.Milestone__c = 'Engagement';
        update c;
        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        
        c.Milestone__c = 'Negotiation';
        update c;
        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        Test.stopTest();
    } 

    static testmethod void test_getToDos1()
    {
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'Benchmark_API_Root_URL';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;

        
            
            ORS__c o = new ORS__c();
            o.Name = '123456';
            insert o;

            Patient__c p = new Patient__c();
            p.Name = '19394939393';
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
            c.V2_Case__c = true;

            Insert c;

            c.Milestone__c = 'Engagement';
        	c.Status = 'Assigned';
            update c;

            Contact con = new Contact();
            con.Email = 'John.Doe@mail.com';
            con.FirstName = 'John';
            con.LastName = 'Doe';
            insert con;

            List<string> cases = new List<string>();
            cases.add(c.Id);

            string userid = UserInfo.getUserId();
          	User user = new User();
        	user.id = UserInfo.getUserId();
            user.TOPS_User_ID__c = 'test ysername';
            user.TOPS_Password__c = 'test1234';
        	update user;
        
            test.startTest();
            V2_HomePageController.GetCaseOverviewForHomeScreen('Negotiator');
            V2_HomePageController.GetCaseOverviewForHomeScreen('Advisor');
        	V2_HomePageController.GetCaseOverviewForHomeScreen('Specialist');
            V2_HomePageController.GetListViews('Case');


            V2_HomePageController.AssignAdvisorToCaseIdList(userid, cases);
            V2_HomePageController.AssignNegotiatorToCaseIdList(userid, cases);
            V2_HomePageController.GetCaseByIndividual('','Advisor');
            V2_HomePageController.GetCaseByIndividual('','Negotiator');

            V2_HomePageController.GetUnassignedCases();
            V2_HomePageController.GetActiveCases('Advisor');
            V2_HomePageController.GetActiveCases('Negotiator');

            V2_HomePageController.GetCasesForTasksRequiringAttention('Advisor');
            V2_HomePageController.GetCasesForTasksRequiringAttention('Negotiator');
            V2_HomePageController.GetExternalConfigs();
            

            V2_HomePageController.SearchCasesV2('Hello', 'All');
            V2_HomePageController.SearchCasesV1('Hello', 'All');

            V2_HomePageController.GetCaseRecordsByMilestone('Negotiator', 'All Open Cases',1,2);
            V2_HomePageController.GetCaseRecordsByMilestone('Negotiator', 'Recently Viewed',1,10);
            V2_HomePageController.GetCaseRecordsByMilestone('Negotiator', 'Engagement',1,10);
        	V2_HomePageController.GetCaseRecordsByMilestone('Specialist', 'Engagement',1,1);

            V2_HomePageController.GetCaseRecordsByMilestone('Advisor', 'All Open Cases',1,100);
            V2_HomePageController.GetCaseRecordsByMilestone('Advisor', 'Recently Viewed',1,2);
            V2_HomePageController.GetCaseRecordsByMilestone('Advisor', 'Engagement',1,2);
        	c.Status = 'Closed';
        	update c;
         	V2_HomePageController.GetCaseRecordsByMilestone('Negotiator', 'All Open Cases',1,2);
        	c.Status = 'Assigned';
        	update c;
            test.stopTest();
        
        	V2_Utility.isTrainingModeOn();
            V2_Utility.getPicklistvalues('Case', 'Status', false);
            V2_Utility.getListViews('Case');
            V2_Utility.NewGuid();
            V2_Utility.Encrypt('hello', true);
            V2_Utility.formatPhone('4444444444');
            V2_Utility.GetMultiClaimURL(c.Id);
            V2_Utility.GetNegotiationURL(c.Id);
            CaseCompletionController.getEngagementPrepFields(c.Id);
            V2_CaseDetailController.MoveCaseToMilestone(c, 'Engagement');
            V2_CaseDetailController.MoveCaseToMilestone(c, 'Follow_Up');
            System.AssertNotEquals(null, 'test');  
    }

    
    static testmethod void test_GetCaseRecordsByMilestone() {
        setup();
        test.startTest();
        V2_HomePageController.GetCaseRecordsByMilestone('Admin', 'Follow Up',1,1);
        V2_HomePageController.GetCaseRecordsByMilestone('Advisor', 'Follow Up',1,1);
        V2_HomePageController.GetCaseRecordsByMilestone('Negotiator', 'Follow Up',1,1);
        test.stopTest();
    }

    static testmethod void test_getToDos2()
    {
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'Benchmark_API_Root_URL';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;

        
            
            ORS__c o = new ORS__c();
            o.Name = '123456';
            insert o;

            Patient__c p = new Patient__c();
            p.Name = '19394939393';
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
            c.V2_Case__c = true;

            Insert c;

            c.Milestone__c = 'Engagement';
            c.Status = 'In Progress';
            update c;

            Contact con = new Contact();
            con.Email = 'John.Doe@mail.com';
            con.FirstName = 'John';
            con.LastName = 'Doe';
            insert con;

            List<string> cases = new List<string>();
            cases.add(c.Id);

            string userid = UserInfo.getUserId();
			test.startTest();
            V2_HomePageController.GetCaseOverviewForHomeScreen('Admin');

            V2_HomePageController.AssignAdvisorToCaseIdList(userid, cases);
            V2_HomePageController.AssignNegotiatorToCaseIdList(userid, cases);
            V2_HomePageController.GetCaseByIndividual('','Admin');

            V2_HomePageController.GetUnassignedCases();
            V2_HomePageController.GetActiveCases('Admin');

            V2_HomePageController.GetCasesForTasksRequiringAttention('Admin');
            V2_HomePageController.GetExternalConfigs();

            V2_HomePageController.GetCaseRecordsByMilestone('Admin', 'All Open Cases',1,1);
            V2_HomePageController.GetCaseRecordsByMilestone('Admin', 'Recently Viewed',1,1);
            V2_HomePageController.GetCaseRecordsByMilestone('Admin', 'Engagement',1,1);
			test.stopTest();
            System.AssertNotEquals(null, 'test');  
    }

    @isTest
    public static void testReopenCase() {
        Test.setMock(HttpCalloutMock.class, new PatientPortalAPIHelperMock());

        /** Setup */
        ORS__c ors = V2_TestDataFactory.createOrs();
        ors.Name = 'successReopenResponse';
        insert ors;

        Employer_Group__c eGroup = V2_TestDataFactory.createEmployerGroup();
        insert eGroup;

        Enrolee__c enrolee = V2_TestDataFactory.createEnrolee(eGroup.Id);
        insert enrolee;
        
        Contact contact = V2_TestDataFactory.createEnroleeContact(enrolee.Id);
        contact.Fax = '444-444-4444';
        insert contact;

        Patient__c patient = V2_TestDataFactory.createPatient(enrolee.Id);
        insert patient;

        Provider_Group__c pGroup = V2_TestDataFactory.createProviderGroup();
        insert pGroup;

        Provider__c provider = V2_TestDataFactory.createProvider(pGroup.Id);
        insert provider;

        Billing_Provider_Group__c bpg = V2_TestDataFactory.createBillingProvider();
        insert bpg;

        Case caseRecord = V2_TestDataFactory.createCase(
            ors.Id,
            patient.Id,
            provider.Id,
            bpg.Id
        );
        caseRecord.Type = 'ENRP';
        caseRecord.Milestone__c = 'Complete';
        caseRecord.Origin = 'Provider';
        insert caseRecord;

        Engagement__c engagement = V2_TestDataFactory.createEngagement(
            caseRecord.Id,
            'Reprocessed as INN'
        );
        insert engagement;

        caseRecord.Engagement__c = engagement.Id;
        update caseRecord;

        Initial_Review__c ir = V2_TestDataFactory.createInitialReview(caseRecord.Id);
        insert ir;
        Case_Claim_Summary__c ccs = V2_TestDataFactory.createCaseClaimSummary(caseRecord.Id, ir.Id);
        insert ccs;

        CDocuSign_Template__c temp = V2_TestDataFactory.createDocuSignTemplate('ENRP Welcome Package');
        insert temp;

        CDocuSign_Template_Recipient__c tempRec = V2_TestDataFactory.createDocuSignTemplateRecipient(temp.Id);
        insert tempRec;

        CDocuSign_Envelope__c env = V2_TestDataFactory.createDocuSignEnvelope(caseRecord.Id, temp.Id);
        insert env;

        CDocuSign_Envelope_Recipient__c envRec = V2_TestDataFactory.createDocuSignEnvelopeRecipient(env.Id, tempRec.Id);
        insert envRec;

        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;

        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;

        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'PP_Route_URL';
        c3.ConfigValue__c = 'PPRoute';
        insert c3;

        Case_Progress_Log__c cpl = new Case_Progress_Log__c(
            Original_Disposition__c = 'testDispo',
            Status__c = 'In Progress',
            Milestone__c = 'Negotiation',
            Case__c = caseRecord.Id
        );
        insert cpl;

        Case_Progress_Log__c cpl2 = new Case_Progress_Log__c(
            Original_Disposition__c = 'testDispo2',
            Status__c = 'In Progress',
            Milestone__c = 'Complete',
            Case__c = caseRecord.Id
        );
        insert cpl2;

		
        User user = new User();
        user.Id = UserInfo.getUserId();
        user.TOPS_User_ID__c = '1';
        user.TOPS_Password__c = '1';
        update user;        

        Test.startTest();
        V2_HomePageController.reopenCase(caseRecord.Id, user.Id, 'successReopenResponse');
        Test.stopTest();

        Case updatedCase = [SELECT Id, Disposition__c, Milestone__c, Assigned_Negotiator__c, OwnerId FROM Case WHERE Id = :caseRecord.Id];
        System.assertEquals('Negotiation', updatedCase.Milestone__c);
    }

    @isTest
    public static void testReopenCaseError() {
        Test.setMock(HttpCalloutMock.class, new PatientPortalAPIHelperMock());

        /** Setup */
        ORS__c ors = V2_TestDataFactory.createOrs();
        ors.Name = 'errorReopenResponse';
        insert ors;

        Employer_Group__c eGroup = V2_TestDataFactory.createEmployerGroup();
        insert eGroup;

        Enrolee__c enrolee = V2_TestDataFactory.createEnrolee(eGroup.Id);
        insert enrolee;
        
        Contact contact = V2_TestDataFactory.createEnroleeContact(enrolee.Id);
        contact.Fax = '444-444-4444';
        insert contact;

        Patient__c patient = V2_TestDataFactory.createPatient(enrolee.Id);
        insert patient;

        Provider_Group__c pGroup = V2_TestDataFactory.createProviderGroup();
        insert pGroup;

        Provider__c provider = V2_TestDataFactory.createProvider(pGroup.Id);
        insert provider;

        Billing_Provider_Group__c bpg = V2_TestDataFactory.createBillingProvider();
        insert bpg;

        Case caseRecord = V2_TestDataFactory.createCase(
            ors.Id,
            patient.Id,
            provider.Id,
            bpg.Id
        );
        caseRecord.Type = 'ENRP';
        caseRecord.Milestone__c = 'Complete';
        caseRecord.Origin = 'Provider';
        insert caseRecord;

        Engagement__c engagement = V2_TestDataFactory.createEngagement(
            caseRecord.Id,
            'Reprocessed as INN'
        );
        insert engagement;

        caseRecord.Engagement__c = engagement.Id;
        update caseRecord;

        Initial_Review__c ir = V2_TestDataFactory.createInitialReview(caseRecord.Id);
        insert ir;
        Case_Claim_Summary__c ccs = V2_TestDataFactory.createCaseClaimSummary(caseRecord.Id, ir.Id);
        insert ccs;

        CDocuSign_Template__c temp = V2_TestDataFactory.createDocuSignTemplate('ENRP Welcome Package');
        insert temp;

        CDocuSign_Template_Recipient__c tempRec = V2_TestDataFactory.createDocuSignTemplateRecipient(temp.Id);
        insert tempRec;

        CDocuSign_Envelope__c env = V2_TestDataFactory.createDocuSignEnvelope(caseRecord.Id, temp.Id);
        insert env;

        CDocuSign_Envelope_Recipient__c envRec = V2_TestDataFactory.createDocuSignEnvelopeRecipient(env.Id, tempRec.Id);
        insert envRec;

        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;

        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;

        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'PP_Route_URL';
        c3.ConfigValue__c = 'PPRoute';
        insert c3;

        Case_Progress_Log__c cpl = new Case_Progress_Log__c(
            Original_Disposition__c = 'testDispo',
            Status__c = 'Completed',
            Milestone__c = 'Negotiation',
            Case__c = caseRecord.Id
        );
        insert cpl;

        Case_Progress_Log__c cpl2 = new Case_Progress_Log__c(
            Original_Disposition__c = 'testDispo2',
            Status__c = 'In Progress',
            Milestone__c = 'Complete',
            Case__c = caseRecord.Id
        );
        insert cpl2;


        Test.startTest();
        try{
            V2_HomePageController.reopenCase(caseRecord.Id, UserInfo.getUserId(), 'errorReopenResponse');
        } catch(Exception e) {
            System.assertNotEquals(null, e);
            return;
        }
        Test.stopTest();

        //should never get here because an exception should be thrown
        System.assertEquals(true, false);
    }

    @isTest
    public static void testCheckReopenEligibility() {
        /** Setup */
        ORS__c ors = V2_TestDataFactory.createOrs();
        insert ors;

        Employer_Group__c eGroup = V2_TestDataFactory.createEmployerGroup();
        insert eGroup;

        Enrolee__c enrolee = V2_TestDataFactory.createEnrolee(eGroup.Id);
        insert enrolee;
        
        Contact contact = V2_TestDataFactory.createEnroleeContact(enrolee.Id);
        contact.Fax = '444-444-4444';
        insert contact;

        Patient__c patient = V2_TestDataFactory.createPatient(enrolee.Id);
        insert patient;

        Provider_Group__c pGroup = V2_TestDataFactory.createProviderGroup();
        insert pGroup;

        Provider__c provider = V2_TestDataFactory.createProvider(pGroup.Id);
        insert provider;

        Billing_Provider_Group__c bpg = V2_TestDataFactory.createBillingProvider();
        insert bpg;

        Case caseRecord = V2_TestDataFactory.createCase(
            ors.Id,
            patient.Id,
            provider.Id,
            bpg.Id
        );
        caseRecord.Type = 'ENRP';
        caseRecord.Milestone__c = 'Complete';
        caseRecord.Origin = 'Provider';
        insert caseRecord;

        Engagement__c engagement = V2_TestDataFactory.createEngagement(
            caseRecord.Id,
            'Reprocessed as INN'
        );
        insert engagement;

        caseRecord.Engagement__c = engagement.Id;
        update caseRecord;

        Initial_Review__c ir = V2_TestDataFactory.createInitialReview(caseRecord.Id);
        insert ir;
        Case_Claim_Summary__c ccs = V2_TestDataFactory.createCaseClaimSummary(caseRecord.Id, ir.Id);
        insert ccs;

        CDocuSign_Template__c temp = V2_TestDataFactory.createDocuSignTemplate('ENRP Welcome Package');
        insert temp;

        CDocuSign_Template_Recipient__c tempRec = V2_TestDataFactory.createDocuSignTemplateRecipient(temp.Id);
        insert tempRec;

        CDocuSign_Envelope__c env = V2_TestDataFactory.createDocuSignEnvelope(caseRecord.Id, temp.Id);
        insert env;

        CDocuSign_Envelope_Recipient__c envRec = V2_TestDataFactory.createDocuSignEnvelopeRecipient(env.Id, tempRec.Id);
        insert envRec;

        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';
        insert c1;

        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;

        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'PP_Route_URL';
        c3.ConfigValue__c = 'PPRoute';
        insert c3;

        Case_Progress_Log__c cpl = new Case_Progress_Log__c(
            Original_Disposition__c = 'testDispo',
            Status__c = 'Completed',
            Milestone__c = 'Negotiation',
            Case__c = caseRecord.Id
        );
        insert cpl;

        Case_Progress_Log__c cpl2 = new Case_Progress_Log__c(
            Original_Disposition__c = 'testDispo2',
            Status__c = 'In Progress',
            Milestone__c = 'Complete',
            Case__c = caseRecord.Id
        );
        insert cpl2;

        Test.startTest();
        Boolean eligible = V2_HomePageController.checkReopenEligibility(caseRecord.Id);
        cpl2.Milestone__c = 'Engagement';
        update cpl2;
        Boolean eligible1 = V2_HomePageController.checkReopenEligibility(caseRecord.Id);
        Test.stopTest();
        System.assertEquals(true, eligible);
    }
    
    @isTest
    public static void testGetCaseByIndividual()
    {
        setup();
        Integration_Task__c itg = new Integration_Task__c(GUID__c = 'test', Task_Type__c = 'ADD ORS COMMENT');
        insert itg;
        Test.startTest();
        User usr = [SELECT Id, ProfileId, Profile.Name FROM User WHERE Id =: userinfo.getUserId()];
        V2_HomePageController.GetCaseByIndividual(usr.Profile.Name,'Admin');
        V2_HomePageController.GetUnassignedProviderCases();
        V2_HomePageController.GetSPITRecord(itg.id);
        
        Test.stopTest();
    }
    
    @isTest
    public static void testGetCaseByIndividual2()
    {
        setup();
        Profile prof = [SELECT ID FROM Profile WHERE Name = 'Advisor User' LIMIT 1];
        //User usr = [SELECT Id, ProfileId, Profile.Name FROM User WHERE ProfileId =: prof.id LIMIT 1];
        //Profile prof = [SELECT Id FROM Profile WHERE Name='Standard User']; 
        User usr = new User(lastName ='Int_User',email = 'Int_User@test.com', profileId = prof.id,username = 'Int_User@test.com');
        usr.Alias =  'test1234';
        usr.TimeZoneSidKey = 'America/Los_Angeles';
            usr.LocaleSidKey = 'en_US';
            usr.EmailEncodingKey = 'UTF-8';
            usr.LanguageLocaleKey = 'en_US';
            insert usr;
        Test.startTest();
        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        Test.stopTest();
    }
    
    public static testMethod void testGetCaseByIndividual3() {
        Test.startTest();
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
        eg.Employer_Group_Name__c = 'blahdlkjfds';
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
        
        Billing_Provider_Group__c bpg = new Billing_Provider_Group__c();
        //bpg.Billing_Provider_Group_Name__c = 'Test';        
        bpg.MPIN__c = '123456';
        bpg.TIN__c = '123456';
        insert bpg;
        
        Negotiation__c negotiation1 = new Negotiation__c();
        insert negotiation1;
        
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'Assigned';
        c.Milestone__c = 'Engagement';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
        c.Billing_Provider_Group__c = bpg.Id;
        c.V2_Case__c = true;     
        c.Negotiation__c = negotiation1.Id;
        insert c;
        
        Case case1 = new Case();
        case1.ORS_Number__c = o.Id;
        case1.Origin = 'ORS Record';
        case1.Status = 'Assigned';
        case1.Milestone__c = 'Engagement';
        case1.V2_Case__c = true;     
        case1.Negotiation__c = negotiation1.Id;
        insert case1;
    
        
        External_Configurations__c c1 = new External_Configurations__c();
        c1.Name = 'OSS_BUCKET';
        c1.ConfigValue__c = 'www.google.com';       
        insert c1;
    
        
        External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
    
        External_Configurations__c c3 = new External_Configurations__c();
        c3.Name = 'NAVIGUARD_API_BASE_URL';
        c3.ConfigValue__c = 'http://localhost.com';
        insert c3;
    
        External_Configurations__c c4 = new External_Configurations__c();
        c4.Name = 'USER_FILE_UPLOAD_PATH';
        c4.ConfigValue__c = '/blah/{0}/hello';
        insert c4;
    
        External_Configurations__c c5 = new External_Configurations__c();
        c5.Name = 'NAVIGUARD_API_BASE_URL';
        c5.ConfigValue__c = 'http://localhost.com';
        insert c5;
    
        External_Configurations__c c6 = new External_Configurations__c();
        c6.Name = 'SEND_EMAIL_ENDPOINT';
        c6.ConfigValue__c = 'BKADJD';
        insert c6;
    
        External_Configurations__c c7 = new External_Configurations__c();
        c7.Name = 'Benchmark_API_Root_URL';
        c7.ConfigValue__c = 'www.example.com';
        insert c7;
    
    
        External_Configurations__c c8 = new External_Configurations__c();
        c8.Name = 'QUALTRICS_Endpoint';
        c8.ConfigValue__c = 'www.google.com';
        insert c8;
    
        External_Configurations__c c9 = new External_Configurations__c();
        c9.Name = 'QUALTRICS_STATUS';
        c9.ConfigValue__c = 'ON';
        insert c9;
    
        External_Configurations__c c10 = new External_Configurations__c();
        c10.Name = 'QUALTRICS_token';
        c10.ConfigValue__c = 'ONdsfsdfsdfsd';
        insert c10;
    
        Patient_Bill__c pb = new Patient_Bill__c();
        pb.Actual_Balance_Bill_Amount__c = 0;
        pb.Case__c = c.Id;
        pb.Claim_Billed_Amount__c = 0;
        pb.Claim_Number__c = '1234';
        pb.Cost_Share_Overpayment__c = 0;
        pb.Patient_Paid_Amount__c = 0;
        pb.Patient_Total_Bill_Amount__c = 0;
        pb.Plan_Paid__c = 0;
        pb.Provider_Discount__c = 0;
        pb.Remaining_Cost_Share_Balance__c = 0;
        insert pb;
        
        Case_Claim_Summary__c ccs = new Case_Claim_Summary__c();
        ccs.Case__c = c.Id;
        ccs.Claim_Case_Key__c = '00001229-AX40419342';
        ccs.Initial_Review__c =  CaseCompletionController.getOrCreateInitialReviewId(c.Id);
        ccs.CMS_Benchmark_Amount__c = 1;
        ccs.Claim_Billed_Amount__c = 1;
        ccs.Allowed__c = 1;
        ccs.Cost_Share__c = 1;
        ccs.Plan_Paid__c = 1;
        ccs.Negotiated_Allowed_Amount__c = 1;
        insert ccs;
    
    
        c.Origin = 'Provider';
        c.Status = 'Assigned';
        c.Milestone__c = 'Initiation';
        c.OwnerId = UserInfo.getUserId();
        update c; 
        
        c.Origin = 'Patient';
        c.Status = 'Assigned';
        c.Milestone__c = 'Initiation';
        c.OwnerId = UserInfo.getUserId();
        update c; 
        
        Profile prf = [SELECT Id FROM Profile WHERE Name='Advisor User']; 
        User testUser = new User( Title= 'Test Account', LastName = 'LName', FirstName = 'FName',Alias = 'Alias',Email = 'test@naviguard.com',Username = 'test@naviguard.com',LocaleSidKey = 'en_US', EmailEncodingKey = 'ISO-8859-1', ProfileId = prf.Id, LanguageLocaleKey = 'en_US', TimeZoneSidKey = 'America/Los_Angeles'  );
        testUser.TOPS_User_ID__c = '1';
        testUser.TOPS_Password__c = '1';
        testUser.ORS_Office__c = '1';
        testUser.ORS_Dept__c = '1';
        testUser.ORS_Team__c = '1';
        testUser.ORS_Ind__c = '1';
        insert testUser;
        

        Profile prfN = [SELECT Id FROM Profile WHERE Name='Negotiator User']; 
        User testUserN = new User( Title= 'Test AccountN', LastName = 'LNameN', FirstName = 'FNameN',Alias = 'AliasN',Email = 'testN@naviguard.com',Username = 'testN@naviguard.com',LocaleSidKey = 'en_US', EmailEncodingKey = 'ISO-8859-1', ProfileId = prfN.Id, LanguageLocaleKey = 'en_US', TimeZoneSidKey = 'America/Los_Angeles'  );
        testUserN.TOPS_User_ID__c = '1';
        testUserN.TOPS_Password__c = '1';
        testUserN.ORS_Office__c = '1';
        testUserN.ORS_Dept__c = '1';
        testUserN.ORS_Team__c = '1'; 
        testUserN.ORS_Ind__c = '1';
        insert testUserN;
        
        Profile prfL = [SELECT Id FROM Profile WHERE Name='Liaison Specialist User']; 
        User testUserL = new User( Title= 'Test AccountL', LastName = 'LiaisonNameL', FirstName = 'LiaisonFNameL',Alias = 'Liaison',Email = 'LiaisonL@naviguard.com',Username = 'Liaison@naviguard.com',LocaleSidKey = 'en_US', EmailEncodingKey = 'ISO-8859-1', ProfileId = prfL.Id, LanguageLocaleKey = 'en_US', TimeZoneSidKey = 'America/Los_Angeles'  );
        testUserL.TOPS_User_ID__c = '1';
        testUserL.TOPS_Password__c = '1';
        testUserL.ORS_Office__c = '1';
        testUserL.ORS_Dept__c = '1';
        testUserL.ORS_Team__c = '1'; 
        testUserL.ORS_Ind__c = '1';
        insert testUserL;
        
        


        c.OwnerId = testUser.Id;
        c.Milestone__c = 'Initiation';
        c.Assigned_Patient_Liaison_Specialist__c = testUserL.id;
        update c;
        
        

    	string userId = UserInfo.getUserId();
 		User user = [SELECT Id, TOPS_User_ID__c, TOPS_Password__c,ORS_Office__c,ORS_Dept__c,ORS_Team__c,ORS_Ind__c FROM User WHERE Id = :userId LIMIT 1];
        user.TOPS_User_ID__c = 'test ysername';
        user.TOPS_Password__c = 'test1234';
        update user;
        List<string> caseList = new List<string>();
        caseList.add(c.Id);
        
        

        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        c.Milestone__c = 'Engagement';
        update c;
        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        
        c.Milestone__c = 'Negotiation';
        update c;
        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        
        c.Milestone__c = 'Follow_Up';
        update c;
        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        
        c.Milestone__c = 'Negotiation_Prep';
        update c;
        V2_HomePageController.GetCaseByIndividual('Advisor User','Admin');
        
        
        c.OwnerId = testUserN.Id;
        c.Assigned_Negotiator__c = testUserN.Id;
        c.Assigned_Patient_Liaison_Specialist__c = testUserN.Id;
        c.V2_Case__c = true;
        update c;
        c.Milestone__c = 'Initiation';
        update c;
        V2_HomePageController.GetCaseByIndividual('Negotiator User','Admin');
        
        c.Milestone__c = 'Follow_Up';
        update c;
        V2_HomePageController.GetCaseByIndividual('Negotiator User','Admin');
        
        c.Milestone__c = 'Negotiation';
        update c;
        V2_HomePageController.GetCaseByIndividual('Negotiator User','Admin');

		c.Milestone__c = 'Engagement';
        update c;
        
        V2_HomePageController.GetCaseByIndividual('Negotiator User','Admin');
        
        Test.stopTest();
    } 
    
    public static testMethod void testgetSearchBarCaseList() {
        Test.startTest();
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
        eg.Employer_Group_Name__c = 'blahdlkjfds';
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
        
        Billing_Provider_Group__c bpg = new Billing_Provider_Group__c();
        //bpg.Billing_Provider_Group_Name__c = 'Test';        
        bpg.MPIN__c = '123456';
        bpg.TIN__c = '123456';
        insert bpg;
        
        Negotiation__c negotiation1 = new Negotiation__c();
        insert negotiation1;
        
        Case c = new Case();
        c.ORS_Number__c = o.Id;
        c.Origin = 'ORS Record';
        c.Status = 'Assigned';
        c.Milestone__c = 'Engagement';
        c.Patient_ID__c = p.Id;
        c.Provider_ID__c = pr.Id;
        c.Billing_Provider_Group__c = bpg.Id;
        c.V2_Case__c = true;     
        c.Negotiation__c = negotiation1.Id;
        insert c;
		
		External_Configurations__c c7 = new External_Configurations__c();
        c7.Name = 'Benchmark_API_Root_URL';
        c7.ConfigValue__c = 'www.example.com';
        insert c7;
		
		External_Configurations__c c2 = new External_Configurations__c();
        c2.Name = 'Benchmark_AES_256_Key';
        c2.ConfigValue__c = 'MaytheSalesForcebeWithYou2QCnoox';
        insert c2;
		
        V2_HomePageController.getSearchBarCaseList(new List<case>{c},20,20,1);
        V2_HomePageController.GetCasesForCasesRequiringAttention('Admin');
        Test.stopTest();
    }  
}