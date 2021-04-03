({
    setSDFileIfNeeded: function (cmp) {
        var hlp = this;

        try {
            if (cmp.get('v.viewModifyTask') === true) {
                var action = cmp.get("c.getSDFileIdForTaskId");
                action.setParams({
                    taskId: cmp.get('v.TaskID')
                });
                action.setCallback(this, function (response) {
                    var state = response.getState();
                    if (state === "SUCCESS") {
                        var sdFileId = response.getReturnValue();
                        if (sdFileId) {
                            cmp.set("v.sdFile", sdFileId);
                        }
                        hlp.doInit(cmp);
                    } else if (state === "ERROR") {
                        hlp.handleErrors(response.getError());
                    }
                });
                $A.enqueueAction(action);
            } else {
                hlp.doInit(cmp);
            }
        } catch (err) {
            console.error(err);
            hlp.handleErrors(err);

        }

    },

    doInit: function (cmp) {
        try {
            var hlp = this;
            var recordHomeMode = cmp.get('v.recordHomeMode');
            var taskId = cmp.get('v.TaskID');
            var sdFile = cmp.get('v.sdFile');
            var contacts = [];

            if (recordHomeMode == false) {

                cmp.set('v.showSpinner', true);

                var recType = cmp.get('v.recordType');
                var viewModifyTask = cmp.get('v.viewModifyTask');

                var caseId = cmp.get('v.CaseID');
                var followUpTaskMode = cmp.get('v.followUpTaskMode');

                cmp.set('v.recordTypeDisplayName', recType.Name);

                this.apex(cmp, 'getContactsForCaseId', {
                        caseId: caseId
                    })
                    .then(function (result) {
                        contacts = result;
                        contacts.forEach(function (item) {
                            item.label = item.Name + ' - ' + item.Role__c;
                            item.value = item.Id;
                        });

                        return hlp.apex(cmp, 'GetContactRecordTypes', {});
                    }).then(function (result) {
                        cmp.set('v.contactRecordTypes', result);
                        return hlp.apex(cmp, 'GetNaviguardSigneeContacts', {});
                    }).then(function (result) {
                        if (sdFile) {
                            result.forEach(function (item) {
                                item.label = item.Name + ' - ' + item.Role__c;
                                item.value = item.Id;
                                contacts.push(item);
                            });
                        }
                        cmp.set('v.contacts', contacts);
                        return hlp.apex(cmp, 'GetExternalConfigs', {});
                    }).then(function (result) {
                        cmp.set('v.externalConfigs', result);
                        //now we can load our picklist dropdowns.
                        hlp.loadPicklistsHardCoded(cmp, recType.DeveloperName);

                        var filtered = false;
                        if (viewModifyTask == false) {
                            filtered = true;
                        }

                        if (sdFile) {
                            return hlp.apex(cmp, 'getDocuSignTemplatePickListValuesSelectSingleForSmartDocument', {
                                objectName: 'Task',
                                field_apiname: 'DocuSign_Template__c',
                                sdFileId: sdFile
                            });
                        } else {
                            return hlp.apex(cmp, 'getDocuSignTemplatePickListValuesWithFilterOption', {
                                objectName: 'Task',
                                field_apiname: 'DocuSign_Template__c',
                                nullRequired: 'false',
                                caseId: caseId,
                                filterOnCaseType: filtered
                            });
                        }

                    }).then(function (result) {
                        var docuSignTemplates = result;

                        var options = [];
                        var optionsV2 = [];
                        var profile = cmp.get('v._profile');

                        docuSignTemplates.forEach(function (item) {
                            if (sdFile) {
                                options.push(item);
                            } else {
                                if (item.includes(' V2')) {
                                    if (item.includes('WOEC')) {
                                        if (profile.Name == 'OPS Manager' ||
                                            profile.Name == 'System Administrator') {
                                            options.push(item);
                                        }
                                    } else {
                                        options.push(item);
                                    }
                                }
                            }
                            // if (item.includes(' V2')) {
                            //     if (item.includes('WOEC')) {
                            //         if (profile.Name == 'OPS Manager' ||
                            //             profile.Name == 'System Administrator') {
                            //             optionsV2.push(item);
                            //         }
                            //     } else {
                            //         optionsV2.push(item);
                            //     }
                            // } else {
                            //     if (item.includes('WOEC')) {
                            //         if (profile.Name == 'OPS Manager' ||
                            //             profile.Name == 'System Administrator') {
                            //             options.push(item);
                            //         }
                            //     } else {
                            //         options.push(item);
                            //     }
                            // }
                        });
                        cmp.set('v.optionsDocuSignTemplates', options);
                        //cmp.set('v.optionsDocuSignTemplatesV2', optionsV2);

                        return hlp.apex(cmp, 'getUsers', {});
                    })
                    .then(function (result) {
                        var users = result;

                        users.forEach(function (item) {
                            item.label = item.Name;
                            item.value = item.Id;
                        });

                        cmp.set('v.users', users);

                        if (viewModifyTask === true) {
                            return hlp.apex(cmp, 'GetTask', {
                                taskId: taskId
                            });
                        } else {
                            if (followUpTaskMode === true) {
                                return hlp.apex(cmp, 'InitTask', {
                                    CaseID: caseId,
                                    RecordTypeToSet: recType,
                                    TaskID: cmp.get('v.taskObject').Id
                                });
                            } else {
                                return hlp.apex(cmp, 'InitTask', {
                                    CaseID: caseId,
                                    RecordTypeToSet: recType,
                                    TaskID: null
                                });
                            }
                        }
                    })
                    .then(function (result) {
                        var taskObject = result;
                        cmp.set('v.taskObject', taskObject);
                        cmp.set('v.envelope', taskObject.CDocuSign_Envelope__r);
                        return hlp.apex(cmp, 'GetEnvelopeByID', {
                            envelopeId: taskObject.CDocuSign_Envelope__c
                        });
                    })
                    .then(function (result) {
                        var envelope = result;
                        if (envelope) {
                            cmp.set('v.envelope', envelope);
                        }
                        //                        var taskObject = result;

                        var taskObject = cmp.get('v.taskObject');

                        if (viewModifyTask === true) {
                            cmp.set('v.selectedContact', taskObject.WhoId);
                            if (taskObject.Integration_Task__c) {
                                hlp.getSPITMessage(cmp, taskObject.Integration_Task__c);
                            }
                        }

                        cmp.set('v.taskObject', taskObject);
                        cmp.set('v.casePageRef', "/lightning/r/" + taskObject.WhatId + '/view');
                        cmp.set('v.selectedUser', taskObject.OwnerId);

                        if (followUpTaskMode === true) {
                            //cmp.set('v.inEditMode', true);
                            hlp.setEditMode(cmp, true);
                        } else {
                            if (viewModifyTask == true) {
                                //cmp.set('v.inEditMode', false);
                                hlp.setEditMode(cmp, false);
                            } else {
                                //cmp.set('v.inEditMode', true);
                                hlp.setEditMode(cmp, true);
                                taskObject.RecordTypeId = recType.Id;
                            }
                        }
                        //below is being done in the InitTask Controller Method
                        //hlp.initSetDefaults(cmp, taskObject, recType);
                        hlp.applyBusinessRules(cmp);

                        if (viewModifyTask) {
                            if (cmp.find("Email_Address__c")) {
                                cmp.find("Email_Address__c").set("v.value", taskObject.Email_Address__c);
                            }

                            if (cmp.find("Phone_Number__c")) {
                                cmp.find("Phone_Number__c").set("v.value", taskObject.Phone_Number__c);
                            }
                        } else {
                            if (!!cmp.get('v.selectedContact')) {
                                var selectedContact = cmp.get("v.selectedContact");
                                var selItem;

                                cmp.get("v.contacts").forEach(function (item) {
                                    if (item.Id == selectedContact) {
                                        selItem = item;
                                    }
                                });

                                if (selItem) {
                                    if (cmp.find("Email_Address__c")) {
                                        cmp.find("Email_Address__c").set("v.value", selItem.Email);
                                    }
                                    var contactNumber = hlp.processContactNumber(selItem);

                                    if (cmp.find("Phone_Number__c")) {
                                        cmp.find("Phone_Number__c").set("v.value", contactNumber);
                                    }
                                }
                            }
                        }


                        cmp.set('v.showSpinner', false);

                        if ((recType.DeveloperName === 'Update_ORS' || recType.DeveloperName === 'DocuSign') && viewModifyTask === false) {
                            if (hlp.getExternalConfigValue(cmp, 'SPIT STATUS') !== 'ON') {
                                hlp.handleWarning("Automation Temporarily Not Available For Task", "Setting the Status to 'Request Queued' will queue the task to be processed once automation is available again.");
                                //cmp.find("overlayLib").notifyClose();
                            }
                        }

                        if (recType.DeveloperName === 'Log_an_Email') {
                            if (viewModifyTask === true) {
                                if (taskObject.CEmail_Message__c) {

                                    var action = cmp.get("c.GetEmailMessageRec");
                                    action.setParams({
                                        emailId: taskObject.CEmail_Message__c
                                    });
                                    action.setCallback(this, function (response) {
                                        var state = response.getState();
                                        cmp.set('v.emailMessage', response.getReturnValue());
                                        if (state === "SUCCESS") {
                                            cmp.set('v.showEmailLink', true);
                                        } else if (state === "ERROR") {
                                            hlp.handleErrors(response.getError());
                                        }
                                    });
                                    $A.enqueueAction(action);
                                }
                            }
                        }

                        if (recType.DeveloperName == 'DocuSign' &&
                            sdFile &&
                            taskObject.DocuSign_Template__c &&
                            viewModifyTask === false) {
                            cmp.set('v.showDocuSignOverlay', true);
                            var taskWrapper = cmp.find('TaskWrapper');
                            if (taskWrapper) {
                                var el = taskWrapper.getElement();

                                if (el) {
                                    el.style.display = 'none';
                                }
                            }

                        }

                        if (recType.DeveloperName === 'Attach_a_File') {
                            if (viewModifyTask === false) {
                                window.addEventListener("message", $A.getCallback(function (event) {
                                    hlp.handleIncomingWCFileUploadMessage(cmp, event);
                                }));

                                var action = cmp.get("c.generateInitializePayload");
                                action.setParams({
                                    caseID: caseId
                                });
                                action.setCallback(this, function (response) {
                                    var state = response.getState();
                                    if (state === "SUCCESS") {
                                        cmp.set('v.showFileUploader', true);
                                        var initPayload = response.getReturnValue();
                                        var prefetchFilesByURL = cmp.get('v.prefetchFilesByURL');
                                        if (prefetchFilesByURL && prefetchFilesByURL.length > 0) {
                                            initPayload["prefetchFilesByURL"] = prefetchFilesByURL;
                                        }

                                        console.log('initializeFileUploader: ' + initPayload);

                                        hlp.sendMessage(cmp, 'initializeFileUploader', initPayload, true);
                                    } else if (state === "ERROR") {
                                        hlp.handleErrors(response.getError());
                                    }
                                });

                                $A.enqueueAction(action);

                            } else {
                                var action2 = cmp.get("c.generateInitializePayloadForFileList");
                                action2.setParams({
                                    caseID: caseId,
                                    taskID: taskObject.Id
                                });

                                action2.setCallback(this, function (response) {
                                    var state = response.getState();
                                    if (state === "SUCCESS") {
                                        var initPayload = response.getReturnValue();

                                        initPayload["canDelete"] = false;
                                        initPayload.linkToTask = false;

                                        cmp.set('v.showFileLister', true);
                                        hlp.sendMessage(cmp, 'initializeFileLister', initPayload, true);

                                    } else if (state === "ERROR") {
                                        this.handleErrors(response.getError());
                                    }
                                });
                                $A.enqueueAction(action2);

                            }

                        }
                    })
                    .catch(function (err) {
                        cmp.set('v.showSpinner', false);
                        console.error(err);
                        hlp.handleErrors(err);

                    });

            } else {
                //recordHomeMode
                if (!taskId) {
                    taskId = cmp.get('v.recordId');
                }
                this.apex(cmp, 'GetTaskRecordTypes', {})
                    .then(function (result) {
                        cmp.set('v.recordTypes', result);
                        return hlp.apex(cmp, 'getContactsForTaskId', {
                            taskId: taskId
                        });
                    })
                    .then(function (result) {
                        var contacts = result;
                        contacts.forEach(function (item) {
                            item.label = item.Name + ' - ' + item.Role__c;
                            item.value = item.Id;
                        });
                        cmp.set('v.contacts', contacts);
                        return hlp.apex(cmp, 'GetContactRecordTypes', {});
                    }).then(function (result) {
                        cmp.set('v.contactRecordTypes', result);
                        return hlp.apex(cmp, 'getPicklistvalues', {
                            objectName: 'Task',
                            field_apiname: 'DocuSign_Template__c',
                            nullRequired: 'false'
                        });

                    }).then(function (result) {
                        var docuSignTemplates = result;

                        var options = [];
                        //var optionsV2 = [];
                        //var profile = cmp.get('v._profile');

                        //when in record home mode, its always read only, so show ALL options which is why we are loading both here
                        docuSignTemplates.forEach(function (item) {
                            //optionsV2.push(item);
                            options.push(item);
                        });
                        cmp.set('v.optionsDocuSignTemplates', options);
                        //cmp.set('v.optionsDocuSignTemplatesV2', optionsV2);

                        return hlp.apex(cmp, 'GetExternalConfigs', {});
                    }).then(function (result) {
                        cmp.set('v.externalConfigs', result);
                        return hlp.apex(cmp, 'getUsers', {});
                    })
                    .then(function (result) {
                        var users = result;

                        users.forEach(function (item) {
                            item.label = item.Name;
                            item.value = item.Id;
                        });

                        cmp.set('v.users', users);

                        return hlp.apex(cmp, 'GetTask', {
                            taskId: taskId
                        });
                    })
                    .then(function (result) {
                        var taskObject = result;
                        cmp.set('v.taskObject', taskObject);
                        cmp.set('v.envelope', taskObject.CDocuSign_Envelope__r);
                        return hlp.apex(cmp, 'GetEnvelopeByID', {
                            envelopeId: taskObject.CDocuSign_Envelope__c
                        });
                    }).then(function (result) {
                        var envelope = result;
                        if (envelope) {
                            cmp.set('v.envelope', envelope);
                        }

                        var taskObject = cmp.get('v.taskObject');
                        cmp.set('v.TaskID', taskObject.Id);
                        var caseId = taskObject.WhatId;
                        cmp.set('v.CaseID', caseId);
                        var viewModifyTask = true;

                        var recType;

                        cmp.get("v.recordTypes").forEach(function (itm) {
                            if (itm.Id == taskObject.RecordTypeId) {
                                recType = itm;
                            }
                        });

                        cmp.set('v.recordType', recType);
                        cmp.set('v.recordTypeDisplayName', recType.Name);
                        cmp.set("v.viewModifyTask", viewModifyTask);
                        hlp.setEditMode(cmp, false);

                        hlp.loadPicklistsHardCoded(cmp, recType.DeveloperName);

                        cmp.set('v.taskObject', taskObject);
                        cmp.set('v.selectedContact', taskObject.WhoId);
                        cmp.set('v.selectedUser', taskObject.OwnerId);
                        cmp.set('v.casePageRef', "/lightning/r/" + taskObject.WhatId + '/view');

                        if (taskObject.Integration_Task__c) {
                            hlp.getSPITMessage(cmp, taskObject.Integration_Task__c);
                        }
                        //below is being done in the InitTask Controller Method
                        //hlp.initSetDefaults(cmp, taskObject, recType);
                        hlp.applyBusinessRules(cmp);

                        if (viewModifyTask) {
                            if (cmp.find("Email_Address__c")) {
                                cmp.find("Email_Address__c").set("v.value", taskObject.Email_Address__c);
                            }

                            if (cmp.find("Phone_Number__c")) {
                                cmp.find("Phone_Number__c").set("v.value", taskObject.Phone_Number__c);
                            }
                        } else {
                            if (!!cmp.get('v.selectedContact')) {
                                var selectedContact = cmp.get("v.selectedContact");
                                var selItem;

                                cmp.get("v.contacts").forEach(function (item) {
                                    if (item.Id == selectedContact) {
                                        selItem = item;
                                    }
                                });

                                if (selItem) {
                                    if (cmp.find("Email_Address__c")) {
                                        cmp.find("Email_Address__c").set("v.value", selItem.Email);
                                    }
                                    var contactNumber = hlp.processContactNumber(selItem);

                                    if (cmp.find("Phone_Number__c")) {
                                        cmp.find("Phone_Number__c").set("v.value", contactNumber);
                                    }
                                }
                            }
                        }

                        if (recType.DeveloperName === 'Log_an_Email') {
                            if (viewModifyTask === true) {
                                if (taskObject.CEmail_Message__c) {

                                    var action = cmp.get("c.GetEmailMessageRec");
                                    action.setParams({
                                        emailId: taskObject.CEmail_Message__c
                                    });
                                    action.setCallback(this, function (response) {
                                        var state = response.getState();
                                        cmp.set('v.emailMessage', response.getReturnValue());
                                        if (state === "SUCCESS") {
                                            cmp.set('v.showEmailLink', true);
                                        } else if (state === "ERROR") {
                                            hlp.handleErrors(response.getError());
                                        }
                                    });
                                    $A.enqueueAction(action);
                                }
                            }
                        }

                        if (recType.DeveloperName === 'Attach_a_File') {
                            if (viewModifyTask === false) {
                                window.addEventListener("message", $A.getCallback(function (event) {
                                    hlp.handleIncomingWCFileUploadMessage(cmp, event);
                                }));

                                var action = cmp.get("c.generateInitializePayload");
                                action.setParams({
                                    caseID: caseId
                                });
                                action.setCallback(this, function (response) {
                                    var state = response.getState();
                                    if (state === "SUCCESS") {
                                        cmp.set('v.showFileUploader', true);
                                        hlp.sendMessage(cmp, 'initializeFileUploader', response.getReturnValue(), true);
                                    } else if (state === "ERROR") {
                                        hlp.handleErrors(response.getError());
                                    }
                                });

                                $A.enqueueAction(action);

                            } else {
                                var action2 = cmp.get("c.generateInitializePayloadForFileList");
                                action2.setParams({
                                    caseID: caseId,
                                    taskID: taskObject.Id
                                });

                                action2.setCallback(this, function (response) {
                                    var state = response.getState();
                                    if (state === "SUCCESS") {
                                        var initPayload = response.getReturnValue();

                                        initPayload["canDelete"] = false;
                                        initPayload.linkToTask = false;

                                        cmp.set('v.showFileLister', true);
                                        hlp.sendMessage(cmp, 'initializeFileUploader', initPayload, true);

                                    } else if (state === "ERROR") {
                                        this.handleErrors(response.getError());
                                    }
                                });
                                $A.enqueueAction(action2);

                            }

                        }


                        cmp.set('v.showSpinner', false);
                    })
                    .catch(function (err) {
                        cmp.set('v.showSpinner', false);
                        console.error(err);
                        hlp.handleErrors(err);

                    });
            }
        } catch (err) {
            console.error(err);
            this.handleErrors(err);

        }
    },


    getExternalConfigValue: function (cmp, configName) {
        var returnValue;

        var externalConfigs = cmp.get('v.externalConfigs');

        externalConfigs.forEach(function (config) {
            if (config.Name == configName) {
                returnValue = config.ConfigValue__c;
            }
        });

        return returnValue;
    },

    createTask: function (cmp, taskToCreate) {

        var hlp = this;
        var sdFile = cmp.get('v.sdFile');

        var action = cmp.get("c.CreateTask");

        if (taskToCreate.CDocuSign_Envelope__r) {
            if (taskToCreate.CDocuSign_Envelope__r.Envelope_Status__c == 'Not Created') {
                taskToCreate.CDocuSign_Envelope__r = null;
            }
        }

        taskToCreate.Milestone__c = cmp.get('v._milestone');

        action.setParams({
            task: taskToCreate,
            sdFileId: sdFile
        });

        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                try {
                    hlp.setEditMode(cmp, false);
                    cmp.set('v.newTaskCreated', true);
                    var taskObject = response.getReturnValue();
                    cmp.set('v.taskObject', taskObject);

                    if (cmp.get('v.recordType').DeveloperName == 'Log_a_Call' &&
                        taskObject.Task_Reason__c == 'Provider Outreach' &&
                        taskObject.Task_Disposition__c == 'Spoke with Provider Billing' &&
                        taskObject.Status == 'Completed') {
                        var appEvent = $A.get("e.c:evtInitialProviderDateUpdated");
                        appEvent.fire();
                    }
                    if (cmp.get('v.recordType').DeveloperName == 'Log_a_Call' &&
                        taskObject.Task_Reason__c == 'Member Outreach' &&
                        taskObject.Task_Disposition__c == 'Spoke with Member' &&
                        taskObject.Status == 'Completed') {
                        var appEvent = $A.get("e.c:evtInitialMemberDateUpdated");
                        appEvent.fire();
                    }

                    if (cmp.get('v.recordType').DeveloperName == 'Attach_a_File') {

                        var fileList = cmp.get('v.wcFileList');

                        fileList.forEach(function (file) {
                            file.sftaskid = taskObject.Id;
                            file.sftaskurl = window.location.href.replace('Case', 'Task').replace(cmp.get('v.CaseID'), taskObject.Id);
                        });

                        hlp.sendMessage(cmp, 'UploadFilesRequest', fileList, true);

                        if (cmp.find('Task_Attachment__c').get('v.value') == 'Provider Bill' || cmp.find('Task_Attachment__c').get('v.value') == 'Revised Provider Bill') {
                            var appEvent = $A.get("e.c:evtTaskOverlay");

                            var changedFields = {
                                Balance_Bills_Received__c: $A.localizationService.formatDate(cmp.find('Task_Occured_Due_Date__c').get('v.value'), "yyyy-MM-dd")
                            }

                            appEvent.setParams({
                                "updatedFields": changedFields
                            });
                            appEvent.fire();
                        } else if (cmp.find('Task_Attachment__c').get('v.value') == 'HIPPA Authorization') {
                            var appEvent = $A.get("e.c:evtTaskOverlay");

                            var changedFields = {
                                HIPPA_Consent__c: true
                            }

                            appEvent.setParams({
                                "updatedFields": changedFields
                            });
                            appEvent.fire();
                        } else if (cmp.find('Task_Attachment__c').get('v.value') == 'Consent to Negotiate') {
                            var appEvent = $A.get("e.c:evtTaskOverlay");

                            var changedFields = {
                                Authorization_for_Assistance__c: true
                            }

                            appEvent.setParams({
                                "updatedFields": changedFields
                            });
                            appEvent.fire();
                        }
                    }


                    if (cmp.get('v.followUpTaskMode') == true) {
                        cmp.set('v.newTaskCreated', true);
                        this.updateFollowUpID(cmp, cmp.get('v.taskIDToUpdateForFollowUp'), taskObject.Id);
                    } else {


                        //if this was a Log a Call and the disposition was not successful, ask the user if they want to create a new task.//#endregion
                        taskObject = cmp.get('v.taskObject');
                        if (cmp.get('v.recordType').DeveloperName == 'Log_a_Call' &&
                            taskObject.Status == 'Completed') {
                            cmp.set('v.showSpinner', false);
                            cmp.set('v.showPromptToCreateNewTask', true);

                            var appEvent = $A.get("e.c:evtNewTask");
                            appEvent.fire();

                        } else if (cmp.get('v.recordType').DeveloperName == 'Update_ORS' && taskObject.Status == 'Request Queued' && this.getExternalConfigValue(cmp, 'SPIT STATUS') == 'ON') {
                            //lets call our iframe to execute the endpoint to process this SPIT, if the SPIT STATUS is OFF then we just go ahead and create this task which will be queued for processing once spit is turned back on
                            if (cmp.get('v._trainingMode') == false) {
                                cmp.set('v.iframePageRef', this.getExternalConfigValue(cmp, 'SPIT Endpoint') + '?id=' + taskObject.Integration_Task__r.Id + '&token=' + taskObject.Integration_Task__r.GUID__c);
                            }
                            //now lets poll the SPIT table until our SPIT task is completed, OR we execeed the maximum allowed wait period
                            var pollId = window.setInterval(
                                $A.getCallback(function () {
                                    hlp.getSPITstatus(cmp, taskObject.Integration_Task__r.Id, pollId);
                                }), this.getExternalConfigValue(cmp, 'SPIT Polling Interval')
                            );

                            cmp.set('v.pollId', pollId);

                        } else if (cmp.get('v.recordType').DeveloperName == 'DocuSign' && taskObject.Status == 'Request Queued' && this.getExternalConfigValue(cmp, 'SPIT STATUS') == 'ON') {
                            //lets call our iframe to execute the endpoint to process this SPIT, if the SPIT STATUS is OFF then we just go ahead and create this task which will be queued for processing once spit is turned back on
                            cmp.set('v.iframePageRef', this.getExternalConfigValue(cmp, 'SPIT Endpoint') + '?id=' + taskObject.Integration_Task__r.Id + '&token=' + taskObject.Integration_Task__r.GUID__c);
                            //now lets poll the SPIT table until our SPIT task is completed, OR we execeed the maximum allowed wait period
                            var pollId = window.setInterval(
                                $A.getCallback(function () {
                                    hlp.getSPITstatus(cmp, taskObject.Integration_Task__r.Id, pollId);
                                }), this.getExternalConfigValue(cmp, 'SPIT Polling Interval')
                            );

                            cmp.set('v.pollId', pollId);

                        } else {
                            if (cmp.get('v.recordType').DeveloperName == 'Attach_a_File') {
                                cmp.set('v.newTaskCreated', true);
                            } else {
                                cmp.set('v.showSpinner', false);
                                cmp.set('v.newTaskCreated', true);
                                cmp.find("overlayLib").notifyClose();
                                var appEvent = $A.get("e.c:evtNewTask");
                                appEvent.fire();
                            }
                        }
                    }


                } catch (err) {
                    var catchPolId = cmp.get('v.pollId');
                    if (catchPolId) {
                        cmp.set('v.pollId', '');
                        window.clearInterval(catchPolId);
                        cmp.set('v.showSpinner', false);
                    }
                    console.error(err);
                    hlp.handleErrors(err);

                }
            } else {
                cmp.set('v.showSpinner', false);
                cmp.set('v.newTaskCreated', false);
                hlp.handleErrors('Failed to Create Task');
            }

        });
        $A.enqueueAction(action);
    },

    getSPITstatus: function (cmp, taskID, pollId) {

        var hlp = this;
        var sdFile = cmp.get('v.sdFile');
        var _negotiation = cmp.get('v._negotiation');

        var action = cmp.get("c.GetSPITRecord");
        action.setParams({
            id: taskID
        });

        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var spitRecord = response.getReturnValue();
                if (spitRecord.Status__c == 'COMPLETE') {
                    window.clearInterval(pollId);
                    cmp.set('v.pollId', '');

                    var taskObject = cmp.get('v.taskObject');
                    taskObject.Status == 'Completed';
                    cmp.set('v.newTaskCreated', true);
                    cmp.set('v.showSpinner', false);

                    cmp.set('v.integrationTask', spitRecord);
                    cmp.set('v.showTaskAutomationMessage', true);


                    var appEvent = $A.get("e.c:evtNewTask");
                    appEvent.fire();

                    if (cmp.get('v.recordType').DeveloperName == "DocuSign") {
                        if (spitRecord.Task_Type__c == 'DOCUSIGN VOID') {
                            if (spitRecord.Disposition__c == 'FAIL') {
                                if (spitRecord.OUTPARM3__c.toUpperCase() == 'ENVELOPE_CANNOT_VOID_INVALID_STATE') {
                                    hlp.handleWarning('Failed to Void', 'The Envelope can no longer be voided.  Please contact the recipient.');
                                } else {
                                    hlp.handleErrors(spitRecord.OUTPARM1__c);
                                }
                            } else {
                                if (sdFile) {
                                    hlp.updateSDFileStatus(cmp, _negotiation.Case__c, _negotiation.Id, sdFile, 'Generated', 'Voided');
                                } else {
                                    cmp.find("overlayLib").notifyClose();
                                }
                            }
                        } else if (spitRecord.Task_Type__c == 'DOCUSIGN SEND') {
                            if (spitRecord.Disposition__c == 'FAIL') {
                                if (sdFile) {
                                    hlp.updateSDFileStatus(cmp, _negotiation.Case__c, _negotiation.Id, sdFile, 'Generated', 'Error');
                                }
                                hlp.handleWarning('Failed to Send', spitRecord.OUTPARM1__c);
                            } else {
                                if (sdFile) {
                                    hlp.updateSDFileStatus(cmp, _negotiation.Case__c, _negotiation.Id, sdFile, 'Sent', 'Sent');
                                } else {
                                    cmp.find("overlayLib").notifyClose();
                                }
                            }
                        }
                    } else {
                        cmp.find("overlayLib").notifyClose();
                    }
                } else {
                    var maxPollTime = parseInt(hlp.getExternalConfigValue(cmp, 'SPIT MAX Poll Time'), 10);
                    var accumPollTime = parseInt(cmp.get('v.accumulatedPollTime'), 10);
                    accumPollTime = accumPollTime + parseInt(hlp.getExternalConfigValue(cmp, 'SPIT Polling Interval'), 10);

                    if (accumPollTime >= maxPollTime) {
                        window.clearInterval(pollId);
                        cmp.set('v.pollId', '');
                        cmp.set('v.accumulatedPollTime', 0);

                        hlp.handleWarning("Long Running Process", "Requested Task is still running.  If the Task does not complete soon, please contact IT Support. This window will now close.");

                        cmp.set('v.newTaskCreated', true);
                        cmp.set('v.showSpinner', false);

                        var appEvent = $A.get("e.c:evtNewTask");
                        appEvent.fire();

                        cmp.find("overlayLib").notifyClose();

                    } else {
                        cmp.set('v.accumulatedPollTime', accumPollTime);
                    }

                }
            } else {
                window.clearInterval(pollId);
                cmp.set('v.pollId', '');

                cmp.set('v.showSpinner', false);
                hlp.handleErrors(response.getError());
            }


        });
        $A.enqueueAction(action);
    },

    getSPITMessage: function (cmp, taskID) {
        var hlp = this;

        var action = cmp.get("c.GetSPITRecord");
        action.setParams({
            id: taskID
        });

        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.integrationTask', response.getReturnValue());
                cmp.set('v.showTaskAutomationMessage', true);
            } else {
                cmp.set('v.showTaskAutomationMessage', false);
                cmp.set('v.showSpinner', false);
                hlp.handleErrors(response.getError());
            }
        });
        $A.enqueueAction(action);
    },

    updateFollowUpID: function (cmp, taskToUpdateID, followUpID) {
        var hlp = this;

        var action = cmp.get("c.UpdateTaskFollowUpId");
        action.setParams({
            taskIDToUpdate: taskToUpdateID,
            followUpTaskID: followUpID
        })

        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                cmp.set('v.newTaskCreated', true);
                cmp.set('v.showSpinner', false);
                cmp.find("overlayLib").notifyClose();
            } else {
                hlp.handleErrors(response.getError());
            }
        });
        $A.enqueueAction(action);
    },

    updateTask: function (cmp, taskToUpdate) {
        var hlp = this;
        var CDocuSign_Envelope__r;
        var docusignVoidRequested = cmp.get('v.docusignVoidRequested');

        if (taskToUpdate.CDocuSign_Envelope__r) {
            CDocuSign_Envelope__r = JSON.parse(JSON.stringify(taskToUpdate.CDocuSign_Envelope__r));
            if (taskToUpdate.CDocuSign_Envelope__r.Envelope_Status__c == 'Not Created') {
                taskToUpdate.CDocuSign_Envelope__r = null;
            }
        }

        var action = cmp.get("c.UpdateTask");
        action.setParams({
            task: taskToUpdate,
            docusignVoidRequested: docusignVoidRequested
        })

        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                taskToUpdate = response.getReturnValue();
                taskToUpdate.CDocuSign_Envelope__r = CDocuSign_Envelope__r;
                cmp.set('v.taskObject', taskToUpdate);
                hlp.setEditMode(cmp, false);

                cmp.set('v.newTaskCreated', true);

                var appEvent = $A.get("e.c:evtNewTask");
                appEvent.fire();

                if (cmp.get('v.recordType').DeveloperName == 'Attach_a_File') {
                    if (cmp.find('Task_Attachment__c').get('v.value') == 'Provider Bill' || cmp.find('Task_Attachment__c').get('v.value') == 'Revised Provider Bill') {
                        var appEvent = $A.get("e.c:evtTaskOverlay");

                        var changedFieldsA = {
                            Balance_Bills_Received__c: $A.localizationService.formatDate(cmp.find('Task_Occured_Due_Date__c').get('v.value'), "yyyy-MM-dd")
                        }

                        appEvent.setParams({
                            "updatedFields": changedFieldsA
                        });
                        appEvent.fire();
                    } else if (cmp.find('Task_Attachment__c').get('v.value') == 'HIPPA Authorization') {
                        var appEvent = $A.get("e.c:evtTaskOverlay");

                        var changedFieldsB = {
                            HIPPA_Consent__c: true
                        }

                        appEvent.setParams({
                            "updatedFields": changedFieldsB
                        });
                        appEvent.fire();
                    } else if (cmp.find('Task_Attachment__c').get('v.value') == 'Consent to Negotiate') {
                        var appEvent = $A.get("e.c:evtTaskOverlay");

                        var changedFieldsC = {
                            Authorization_for_Assistance__c: true
                        }

                        appEvent.setParams({
                            "updatedFields": changedFieldsC
                        });
                        appEvent.fire();
                    }


                }



                cmp.set('v.showSpinner', false);

                //if this was a Log a Call and the disposition was not successful, ask the user if they want to create a new task.//#endregion
                var taskObject = cmp.get('v.taskObject');

                if (cmp.get('v.recordType').DeveloperName == 'Log_a_Call' &&
                    taskObject.Task_Reason__c == 'Provider Outreach' &&
                    taskObject.Task_Disposition__c == 'Spoke with Provider Billing' &&
                    taskObject.Status == 'Completed') {
                    appEvent = $A.get("e.c:evtInitialProviderDateUpdated");
                    appEvent.fire();
                }
                if (cmp.get('v.recordType').DeveloperName == 'Log_a_Call' &&
                    taskObject.Task_Reason__c == 'Member Outreach' &&
                    taskObject.Task_Disposition__c == 'Spoke with Member' &&
                    taskObject.Status == 'Completed') {
                    appEvent = $A.get("e.c:evtInitialMemberDateUpdated");
                    appEvent.fire();
                }

                if (cmp.get('v.recordHomeMode') == false &&
                    cmp.get('v.recordType').DeveloperName == 'Log_a_Call' &&
                    taskObject.Status == 'Completed' &&
                    !taskObject.FollowUpTaskID__c) {
                    cmp.set('v.showPromptToCreateNewTask', true);
                } else if ((cmp.get('v.recordType').DeveloperName == 'Update_ORS' || cmp.get('v.recordType').DeveloperName == 'DocuSign') && taskObject.Status == 'Request Queued' && this.getExternalConfigValue(cmp, 'SPIT STATUS') == 'ON') {
                    cmp.set('v.showSpinner', true);
                    //lets call our iframe to execute the endpoint to process this SPIT, if the SPIT STATUS is OFF then we just go ahead and create this task which will be queued for processing once spit is turned back on
                    cmp.set('v.iframePageRef', hlp.getExternalConfigValue(cmp, 'SPIT Endpoint') + '?id=' + taskObject.Integration_Task__r.Id + '&token=' + taskObject.Integration_Task__r.GUID__c);
                    //now lets poll the SPIT table until our SPIT task is completed, OR we execeed the maximum allowed wait period
                    var pollId = window.setInterval(
                        $A.getCallback(function () {
                            hlp.getSPITstatus(cmp, taskObject.Integration_Task__r.Id, pollId);
                        }), hlp.getExternalConfigValue(cmp, 'SPIT Polling Interval')
                    );

                    cmp.set('v.pollId', pollId);
                }

            } else {
                cmp.set('v.showSpinner', false);
                cmp.set('v.newTaskCreated', false);
                hlp.handleErrors(response.getError());
            }
        });
        $A.enqueueAction(action);
    },


    loadPicklistsHardCoded: function (cmp, recordType) {
        var taskStatusOptions = [];
        var taskSourceOptions = [];
        var taskAttachmentOptions = [];
        var taskDispositionOptions = [];
        var taskReasonOptions = [];
        var mailingAddressOptions = [];
        var orsRouteToOptions = [];
        var orsStatusOptions = [];

        if (recordType == "Alert") {
            taskSourceOptions = ['Inbound', 'Outbound'];
            taskReasonOptions = ['--None--', 'Send Welcome Package', 'Member Info Confirmation', 'Request for Additional Info', 'Provider Outreach', 'Updating ORS Record', 'Providing Status or Clarification', 'Load Reference File', 'Strategy Development', 'Legal Clarification', 'Provider Negotiations', 'Secure Approval for Terms', 'Other Reason', 'Add Comments to ORS Record', 'Route ORS Record', 'Change status of ORS Record', 'DocuSign Sent', 'Blocked Email', 'Undeliverable Email', 'Digital General', 'Digital Invite Unsuccessful', 'Digital Bill Upload', 'Digital Bill Not Uploaded', 'Signatures Received', 'Forms Not Signed', 'Fax Send Unsuccessful', 'Case Re-Opened', 'Written Agreement Signatures Received', 'Request for Signatures Unsuccessful'];
            taskDispositionOptions = ['--None--', 'Completed', 'Unsuccessful', 'Other Disposition'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
        } else if (recordType == "Log_a_Call") {
            taskSourceOptions = ['Inbound', 'Outbound', 'From Voice Mail', 'Conf Call'];
            taskReasonOptions = ['--None--', 'Member Outreach', 'Request for Additional Info', 'Provider Outreach', 'Provider Negotiations', 'Other Reason'];
            taskDispositionOptions = ['--None--', 'Spoke with Member', 'Spoke with Other', 'Spoke with Provider Billing', 'Unable to Reach', 'Other Disposition'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];

        } else if (recordType == "Log_an_Email") {
            taskSourceOptions = ['Inbound', 'Outbound'];
            taskReasonOptions = ['--None--', 'Send Welcome Package', 'Request for Additional Info', 'Providing Status or Clarification', 'Other Reason'];
            taskDispositionOptions = ['--None--', 'Completed', 'Unsuccessful', 'Other Disposition'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
        } else if (recordType == "Log_a_Letter") {
            taskSourceOptions = ['Inbound', 'Outbound'];
            taskReasonOptions = ['--None--', 'Member Outreach', 'Send Welcome Package', 'Request for Additional Info', 'Providing Status or Clarification', 'Secure Approval for Terms', 'Other Reason'];
            taskDispositionOptions = ['--None--', 'Completed', 'Letter Returned', 'Unsuccessful', 'Other Disposition'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Primary Mailing Address', 'Alternative Mailing Address', 'Not Applicable'];
            taskStatusOptions = [{
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
        } else if (recordType == "Post_a_Comment") {
            taskSourceOptions = ['User Activity'];
            taskReasonOptions = ['Providing Status or Clarification'];
            taskDispositionOptions = ['Completed'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
        } else if (recordType == "Attach_a_File") {
            taskSourceOptions = ['User Activity'];
            taskReasonOptions = ['Load Reference File'];
            taskDispositionOptions = ['Completed'];

            //taskAttachmentOptions = ['Welcome Package', 'Consent to Negotiate', 'HIPPA Authorization', 'Explanation of Benefits (EOB)', 'Provider Bill', 'Negotiation Terms', 'Approval for Payment & Terms', 'Other Provider Correspondence', 'Other Member Correspondence', 'Letter from Collections Department'];
            if (cmp.get('v.viewModifyTask') == true) {
                taskAttachmentOptions = ['--None--', 'Welcome Package', 'Revised Provider Bill', 'Consent to Negotiate', 'HIPPA Authorization', 'EOB', 'Provider Bill', 'Negotiated Terms', 'Approval for Payment & Terms', 'Other Provider', 'Other Member', 'Collections Ltr', 'Unable to Reach Mbr', 'Negotiation Worksheet'];
            } else {
                taskAttachmentOptions = ['--None--', 'Provider Bill', 'Revised Provider Bill', 'Negotiated Terms', 'Other Provider', 'Other Member', 'Collections Ltr', 'Negotiated Outcome Mbr', 'Unable to Reach Mbr', 'Consent to Negotiate', 'HIPPA Authorization', 'Negotiation Worksheet'];
            }


            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
        } else if (recordType == "Update_ORS") {
            taskSourceOptions = ['User Activity'];
            taskReasonOptions = ['Add Comments to ORS Record', 'Route ORS Record', 'Change status of ORS Record'];
            taskDispositionOptions = ['Completed', 'Unsuccessful'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Request Queued',
                'value': 'Request Queued'
            }, {
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
            orsRouteToOptions = ['225 REW COM', '666 RES VOO CRI'];
            orsStatusOptions = ['Closed'];
        } else if (recordType == "Schedule_a_Meeting") {
            taskSourceOptions = ['User Activity'];
            taskReasonOptions = ['Request for Additional Info', 'Providing Status or Clarification', 'Strategy Development', 'Legal Clarification', 'Provider Negotiations', 'Secure Approval for Terms', 'Other Reason'];
            taskDispositionOptions = ['Completed', 'Rescheduled Meeting', 'Unsuccessful'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
        } else if (recordType == "Attend_a_Meeting") {
            taskSourceOptions = ['User Activity'];
            taskReasonOptions = ['Request for Additional Info', 'Providing Status or Clarification', 'Strategy Development', 'Legal Clarification', 'Provider Negotiations', 'Secure Approval for Terms', 'Other Reason'];
            taskDispositionOptions = ['Completed', 'Rescheduled Meeting'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
        } else if (recordType == "DocuSign") {
            taskSourceOptions = ['User Activity'];
            taskReasonOptions = ['DocuSign Sent'];
            taskDispositionOptions = ['Completed', 'Pending', 'Unsuccessful'];
            taskAttachmentOptions = ['Not Applicable'];
            mailingAddressOptions = ['Not Applicable'];
            taskStatusOptions = [{
                'label': 'Request Queued',
                'value': 'Request Queued'
            }, {
                'label': 'Completed',
                'value': 'Completed'
            }, {
                'label': 'Cancelled',
                'value': 'Cancelled'
            }, {
                'label': 'Pending',
                'value': 'Pending'
            }];
        }

        cmp.set("v.optionsTaskStatus", taskStatusOptions);
        cmp.set("v.optionsTaskSource", taskSourceOptions);
        cmp.set("v.optionsTaskAttachment", taskAttachmentOptions);
        cmp.set("v.optionsTaskDisposition", taskDispositionOptions);
        cmp.set("v.optionsTaskReason", taskReasonOptions);
        cmp.set("v.optionsMailingAddress", mailingAddressOptions);
        cmp.set("v.optionsRouteTo", orsRouteToOptions);
        cmp.set("v.optionsORSStatus", orsStatusOptions);
    },

    handleIncomingWCFileUploadMessage: function (component, event) {
        if (!component.isValid()) {
            return;
        }

        var cmp = component;
        var hlp = this;
        var newFileList = [];
        var taskObject;

        try {

            if (event.data && event.data.type) {
                if (event.data.type === 'GetFileListResponse') {
                    if (event.data.payload && Array.isArray(event.data.payload)) {
                        var fileList = event.data.payload;
                        if (fileList.length == 0) {
                            hlp.handleWarning("No Files Selected", "Please select at least 1 File to attach.");
                        } else {
                            taskObject = cmp.get('v.taskObject');
                            if (!taskObject.Task_Attachment__c || taskObject.Task_Attachment__c == '--None--') {
                                hlp.handleWarning("Missing Required Fields", "Please specify a Task Attachment Type.");
                            } else {
                                fileList.forEach(function (itm) {
                                    newFileList.push({
                                        File_Hash__c: itm.fileDataHash,
                                        Original_File_Name__c: itm.fileName,
                                        File_Extension__c: itm.fileName.slice((itm.fileName.lastIndexOf(".") - 1 >>> 0) + 2),
                                        File_Type__c: taskObject.Task_Attachment__c
                                    });
                                });

                                hlp.apex(cmp, 'createPendingCaseFiles', {
                                    caseID: cmp.get('v.CaseID'),
                                    newFileList: newFileList
                                }).then(function (result) {
                                    newFileList = result;
                                    newFileList.forEach(function (nfile) {
                                        fileList.forEach(function (file) {
                                            if (file.fileDataHash == nfile.File_Hash__c) {
                                                file.newFileName = nfile.File_Name__c;
                                                file.sfcaseFileID = nfile.Id;
                                            }
                                        });
                                    });
                                    cmp.set('v.newFileList', newFileList);
                                    cmp.set('v.wcFileList', fileList);
                                    hlp.handleSubmit(cmp, event);
                                }).catch(function (err) {
                                    cmp.set('v.showSpinner', false);
                                    hlp.handleErrors(err);
                                    console.error(err);
                                });
                            }

                        }
                    } else {
                        cmp.set('v.showSpinner', false);
                        hlp.handleWarning("No Files Selected", "Please select at least 1 File to attach.");
                    }
                } else if (event.data.type === 'UploadFilesResponse') {
                    if (event.data.payload && Array.isArray(event.data.payload)) {
                        taskObject = cmp.get('v.taskObject');
                        var uploadedFileList = event.data.payload;
                        newFileList = cmp.get('v.newFileList');
                        uploadedFileList.forEach(function (ufile) {
                            newFileList.forEach(function (nfile) {
                                if (nfile.File_Hash__c == ufile.fileDataHash) {
                                    if (ufile.uploadResult === 'SUCCESS') {
                                        nfile.File_Status__c = 'Uploaded';
                                        nfile.Task_ID__c = taskObject.Id;
                                    } else {
                                        nfile.File_Status__c = 'Error';
                                        nfile.Upload_Error_Message__c = ufile.errorMessage.toString();
                                        nfile.Task_ID__c = taskObject.Id;
                                        hlp.handleErrors('There was a problem uploading the select attachment(s).  You can try again by creating a new task.');
                                    }
                                }
                            });
                        });

                        var action = cmp.get("c.updateCaseFiles");
                        action.setParams({
                            caseFiles: newFileList
                        });
                        action.setCallback(hlp, function (response) {
                            var state = response.getState();
                            if (state === "SUCCESS") {
                                cmp.set('v.showSpinner', false);
                                var _files = [];
                                cmp.set('v._files', _files);
                            } else if (state === "ERROR") {
                                cmp.set('v.showSpinner', false);
                                hlp.handleErrors(response.getError());
                            }
                            cmp.set('v.showSpinner', false);
                            var appEvent = $A.get("e.c:evtNewTask");
                            appEvent.fire();
                            cmp.find("overlayLib").notifyClose();
                        });

                        $A.enqueueAction(action);
                    }
                }
            }

        } catch (err) {
            cmp.set('v.showSpinner', false);
            hlp.handleErrors(err.message);
            console.error(err);
        }
    },

    applyBusinessRules: function (cmp) {
        try {
            var taskObject = cmp.get('v.taskObject');
            var recordType = cmp.get('v.recordType');

            //set the visibility for those fields which are always shown (default is hidden so we don't need to hide anything as it will by default)
            if (recordType.DeveloperName == "Alert") {
                cmp.set('v.showContact', false);
                cmp.set('v.showNonContactEntityOption', false);
                cmp.set('v.showDispositionLine', true);
                cmp.set('v.showOtherDispositionComment', true);
                cmp.set('v.showOtherReasonComment', false);
            } else if (recordType.DeveloperName == "Log_a_Call") {
                cmp.set('v.showContact', true);
                cmp.set('v.showNonContactEntityOption', true);
                cmp.set('v.showDispositionLine', true);
                cmp.set('v.showOtherDispositionComment', true);
                cmp.set('v.showOtherReasonComment', true);
            } else if (recordType.DeveloperName == "Log_an_Email") {
                cmp.set('v.showNonContactEntityOption', true);
                cmp.set('v.showContact', true);
                cmp.set('v.showDispositionLine', true);
                cmp.set('v.showOtherDispositionComment', true);
                cmp.set('v.showOtherReasonComment', true);
            } else if (recordType.DeveloperName == "Log_a_Letter") {
                cmp.set('v.showNonContactEntityOption', true);
                cmp.set('v.showMailingAddress', true);
                cmp.set('v.showAttachment', false);
                cmp.set('v.showContact', true);
                cmp.set('v.showDispositionLine', true);
                cmp.set('v.showOtherDispositionComment', true);
                cmp.set('v.showOtherReasonComment', true);
            } else if (recordType.DeveloperName == "Post_a_Comment") {
                cmp.set('v.showDispositionLine', true);
            } else if (recordType.DeveloperName == "Attach_a_File") {
                cmp.set('v.showDispositionLine', true);
                cmp.set('v.showAttachment', true);

            } else if (recordType.DeveloperName == "Update_ORS") {
                cmp.set('v.showSubmitToORS', false);
                cmp.set('v.showDispositionLine', true);
            } else if (recordType.DeveloperName == "Schedule_a_Meeting") {
                cmp.set('v.showDispositionLine', true);
                cmp.set('v.showContact', true);
                cmp.set('v.showOtherReasonComment', true);
            } else if (recordType.DeveloperName == "Attend_a_Meeting") {
                cmp.set('v.showDispositionLine', true);
                cmp.set('v.showContact', true);
                cmp.set('v.showOtherReasonComment', true);

            } else if (recordType.DeveloperName == "DocuSign") {
                cmp.set('v.showContact', false);
                cmp.set('v.showMailingAddress', false);
                cmp.set('v.showDispositionLine', false);
                cmp.set('v.showOtherReasonComment', false);
                cmp.set('v.showDocuSign', true);
            }




            //set the disabled property for fields which are always disabled based on record type
            if (recordType.DeveloperName == "Alert") {
                this.setDisabledProperty(cmp, 'Task_Source__c', true, false);
                this.setDisabledProperty(cmp, 'Task_Reason__c', true, false);
            } else if (recordType.DeveloperName == "Post_a_Comment") {
                this.setDisabledProperty(cmp, 'Task_Source__c', true, false);
                this.setDisabledProperty(cmp, 'Task_Reason__c', true, false);
                this.setDisabledProperty(cmp, 'Task_Disposition__c', true, false);
                this.setDisabledProperty(cmp, 'ddStatus', true, false);
            } else if (recordType.DeveloperName == "Attach_a_File") {
                this.setDisabledProperty(cmp, 'Task_Source__c', true, false);
                this.setDisabledProperty(cmp, 'Task_Reason__c', true, false);

            } else if (recordType.DeveloperName == "Update_ORS") {
                this.setDisabledProperty(cmp, 'Task_Source__c', true, false);
                this.setDisabledProperty(cmp, 'ddStatus', true, false);
                if (taskObject.Status == 'Pending') {
                    cmp.set('v.showSubmitToORS', true);
                }
                //this.setDisabledProperty(cmp, 'Task_Reason__c', true, false);
                if (taskObject.Status == 'Request Queued') {
                    //this.setDisabledProperty(cmp, 'ddStatus', true, false);
                }
            } else if (recordType.DeveloperName == "Schedule_a_Meeting") {
                this.setDisabledProperty(cmp, 'Task_Source__c', true, false);
            } else if (recordType.DeveloperName == "Attend_a_Meeting") {
                this.setDisabledProperty(cmp, 'Task_Source__c', true, false);
            } else if (recordType.DeveloperName == "DocuSign") {
                this.setDisabledProperty(cmp, 'Task_Source__c', true, false);
                this.setDisabledProperty(cmp, 'Task_Reason__c', true, false);
                this.setDisabledProperty(cmp, 'ddStatus', true, false);
            }

            //set our enabled/disabled state based on rules
            if (cmp.get('v.followUpTaskMode') == true) {
                this.setDisabledProperty(cmp, 'ddStatus', true, false);
                this.setDisabledProperty(cmp, 'contactLookup', true, false);
                this.setDisabledProperty(cmp, 'Phone_Number__c', true, false);
                this.setDisabledProperty(cmp, 'Email_Address__c', true, false);
                this.setDisabledProperty(cmp, 'Non_Contact_Entity__c', true, false);
                this.setDisabledProperty(cmp, 'Non_Contact_Entity_Name__c', true, false);

            } else if (cmp.get('v.inEditMode') == true) {
                if (recordType.DeveloperName != "Update_ORS" &&
                    recordType.DeveloperName != "Post_a_Comment" &&
                    recordType.DeveloperName != "DocuSign") {
                    this.setDisabledProperty(cmp, 'ddStatus', false, false);
                }


                if (recordType.DeveloperName == 'DocuSign') {
                    if (taskObject.CDocuSign_Envelope__r.Envelope_Status__c == 'Not Created') {
                        this.setDisabledProperty(cmp, 'DocuSign_Template__c', false, false);
                        this.setDisabledProperty(cmp, 'btnCreateDraft', false, false);

                    } else {
                        this.setDisabledProperty(cmp, 'DocuSign_Template__c', true, false);
                        this.setDisabledProperty(cmp, 'btnCreateDraft', true, false);
                    }

                    if (taskObject.CDocuSign_Envelope__r.Envelope_Status__c == 'Created') {
                        this.setDisabledProperty(cmp, 'btnReviewModifyDocusign', false, false);
                    }

                }
            }


            //if this taks is already saved in a completed state, prevent changing certain fields when in edit mode
            if (taskObject.IsClosed == true) {
                this.setDisabledProperty(cmp, 'ddStatus', true, false);
                this.setDisabledProperty(cmp, 'contactLookup', true, false);
                this.setDisabledProperty(cmp, 'Phone_Number__c', true, false);
                this.setDisabledProperty(cmp, 'Email_Address__c', true, false);
                this.setDisabledProperty(cmp, 'Task_Source__c', true, false);
                this.setDisabledProperty(cmp, 'Task_Occured_Due_Date__c', true, false);
                this.setDisabledProperty(cmp, 'userLookup', true, false);
                this.setDisabledProperty(cmp, 'Follow_Up_Reminder_Date__c', true, false);
                this.setDisabledProperty(cmp, 'DocuSign_Template__c', true, false);
                this.setDisabledProperty(cmp, 'Non_Contact_Entity_Name__c', true, false);
                this.setDisabledProperty(cmp, 'Non_Contact_Entity__c', true, false);

            }

            if (taskObject.Status == 'Pending') {

                this.setDisabledProperty(cmp, 'Task_Disposition__c', true, false);
                this.setRequiredProperty(cmp, 'Task_Disposition__c', false);

                this.setDisabledProperty(cmp, 'Other_Disposition_Comments__c', true, true);
                this.setRequiredProperty(cmp, 'Other_Disposition_Comments__c', false);

                cmp.set('v.showFollowUp', true);

                this.setRequiredProperty(cmp, 'Follow_Up_Reminder_Date__c', true);
                //cmp.find('Follow_Up_Reminder_Date__c').set('v.value', taskObject.Task_Occured_Due_Date__c);
                if (cmp.get('v.inEditMode') == true) {
                    this.setDisabledProperty(cmp, 'Follow_Up_Comments__c', false);
                }

                this.resetValidity(cmp, ['Task_Disposition__c']);
                this.resetValidity(cmp, ['Other_Disposition_Comments__c']);

                // cmp.find('Task_Disposition__c').set('v.value', null);
                // cmp.find('Other_Disposition_Comments__c').set('v.value', null);

                cmp.set('v.showDispositionLine', false);

                this.setRequiredProperty(cmp, 'Task_Comments__c', false);
                if (cmp.get('v.inEditMode') == true) {

                    this.setDisabledProperty(cmp, 'userLookup', false, false);
                }

            } else if (taskObject.Status == 'Request Queued') {
                cmp.set('v.showDispositionLine', false);

                taskObject.Follow_Up_Reminder_Date__c = null;

                if (cmp.get('v.inEditMode') == true) {
                    this.setDisabledProperty(cmp, 'Task_Disposition__c', false, false);
                }
                this.setRequiredProperty(cmp, 'Task_Disposition__c', true);

                this.setDisabledProperty(cmp, 'Other_Disposition_Comments__c', true, false);
                this.setRequiredProperty(cmp, 'Other_Disposition_Comments__c', false);

                if (!taskObject.Task_Disposition__c) {
                    taskObject.Task_Disposition__c = cmp.get("v.optionsTaskDisposition")[0];
                }

                this.resetValidity(cmp, ['Task_Disposition__c']);
                this.resetValidity(cmp, ['Other_Disposition_Comments__c']);

                this.setRequiredProperty(cmp, 'Follow_Up_Reminder_Date__c', false, true);

                cmp.set('v.showFollowUp', false);
                if (recordType.DeveloperName != "DocuSign") {
                    this.setRequiredProperty(cmp, 'Task_Comments__c', true);
                }
                this.setDisabledProperty(cmp, 'userLookup', true, false);

            } else {
                cmp.set('v.showDispositionLine', true);

                taskObject.Follow_Up_Reminder_Date__c = null;

                if (cmp.get('v.inEditMode') == true) {
                    this.setDisabledProperty(cmp, 'Task_Disposition__c', false, false);
                }
                this.setRequiredProperty(cmp, 'Task_Disposition__c', true);

                this.setDisabledProperty(cmp, 'Other_Disposition_Comments__c', true, false);
                this.setRequiredProperty(cmp, 'Other_Disposition_Comments__c', false);

                if (!taskObject.Task_Disposition__c) {
                    taskObject.Task_Disposition__c = cmp.get("v.optionsTaskDisposition")[0];
                }

                this.resetValidity(cmp, ['Task_Disposition__c']);
                this.resetValidity(cmp, ['Other_Disposition_Comments__c']);

                this.setRequiredProperty(cmp, 'Follow_Up_Reminder_Date__c', false, true);

                cmp.set('v.showFollowUp', false);

                this.setRequiredProperty(cmp, 'Task_Comments__c', false);
                if (cmp.get('v.inEditMode') == true) {
                    this.setDisabledProperty(cmp, 'userLookup', false, false);
                }
            }

            if (taskObject.Task_Reason__c == 'Other Reason') {
                if (cmp.get('v.inEditMode') == true) {
                    this.setDisabledProperty(cmp, 'Other_Reason_Comment__c', false);
                }
                this.setRequiredProperty(cmp, 'Other_Reason_Comment__c', true);
            } else {
                this.setDisabledProperty(cmp, 'Other_Reason_Comment__c', true, true);
                this.setRequiredProperty(cmp, 'Other_Reason_Comment__c', false);

                if (taskObject.Task_Reason__c == 'Route ORS Record') {
                    cmp.set('v.showRouteDropDown', true);
                    if (cmp.get('v.inEditMode') == true) {
                        this.setDisabledProperty(cmp, 'ORS_Route_To__c', false, false);
                    } else {
                        this.setDisabledProperty(cmp, 'ORS_Route_To__c', true, false);
                    }
                    this.setRequiredProperty(cmp, 'ORS_Route_To__c', true);
                } else {
                    this.setDisabledProperty(cmp, 'ORS_Route_To__c', true, true);
                    this.setRequiredProperty(cmp, 'ORS_Route_To__c', false);
                    cmp.set('v.showRouteDropDown', false);
                }

                if (taskObject.Task_Reason__c == 'Change status of ORS Record') {
                    cmp.set('v.showChangeORSStatusDropDown', true);
                    if (cmp.get('v.inEditMode') == true) {
                        this.setDisabledProperty(cmp, 'ORS_Status__c', false, false);
                    } else {
                        this.setDisabledProperty(cmp, 'ORS_Status__c', true, false);
                    }
                    this.setRequiredProperty(cmp, 'ORS_Status__c', true);
                } else {
                    this.setDisabledProperty(cmp, 'ORS_Status__c', true, true);
                    this.setRequiredProperty(cmp, 'ORS_Status__c', false);
                    cmp.set('v.showChangeORSStatusDropDown', false);
                }
            }

            if (taskObject.Task_Disposition__c == 'Other Disposition') {
                if (cmp.get('v.inEditMode') == true) {
                    this.setDisabledProperty(cmp, 'Other_Disposition_Comments__c', false);
                }
                this.setRequiredProperty(cmp, 'Other_Disposition_Comments__c', true);
            } else {
                this.setDisabledProperty(cmp, 'Other_Disposition_Comments__c', true, true);
                this.setRequiredProperty(cmp, 'Other_Disposition_Comments__c', false);
            }

            //set the fields which are always required for the specified record type
            if (recordType.DeveloperName == "Log_a_Call") {
                this.setRequiredProperty(cmp, 'contactLookup', true);
                this.setRequiredProperty(cmp, 'Phone_Number__c', true);
            } else if (recordType.DeveloperName == "Log_an_Email") {
                this.setRequiredProperty(cmp, 'contactLookup', true);
                this.setRequiredProperty(cmp, 'Email_Address__c', true);
            } else if (recordType.DeveloperName == "Log_a_Letter") {
                this.setRequiredProperty(cmp, 'contactLookup', true);
                this.setRequiredProperty(cmp, 'Mailing_Address__c', true);
            } else if (recordType.DeveloperName == "Post_a_Comment") {
                this.setRequiredProperty(cmp, 'Task_Comments__c', true);
            } else if (recordType.DeveloperName == "Attach_a_File") {} else if (recordType.DeveloperName == "Update_ORS") {} else if (recordType.DeveloperName == "Schedule_a_Meeting") {
                this.setRequiredProperty(cmp, 'contactLookup', true);
            } else if (recordType.DeveloperName == "Attend_a_Meeting") {
                this.setRequiredProperty(cmp, 'contactLookup', true);
            } else if (recordType.DeveloperName != "DocuSign") {
                this.setRequiredProperty(cmp, 'DocuSign_Template__c', true);
            }

            //adding the below as a catch all to disable all controls when not in edit mode
            if (cmp.get('v.inEditMode') != true) {
                this.setEditMode(cmp, cmp.get('v.inEditMode'));
            }

        } catch (err) {
            console.error(err);
            this.handleErrors(err);

        }
    },

    initSetDefaults: function (cmp, taskObject, recordType) {
        //we don't need this method anymore as this is all being done in the controller now.
        if (recordType.DeveloperName == "Log_a_Call") {
            //set our defaults
            taskObject.Task_Disposition__c = 'Spoke with Member';
            taskObject.Task_Attachment__c = 'Not Applicable';
            taskObject.Task_Source__c = 'Outbound';
            taskObject.Mailing_Address__c = 'Not Applicable';
            if (cmp.get('v.followUpTaskMode') == true) {
                taskObject.Status = 'Pending';
                cmp.find('ddStatus').set('v.value', 'Pending');
            } else {
                taskObject.Status = 'Completed';
                cmp.find('ddStatus').set('v.value', 'Completed');
            }
        } else if (recordType.DeveloperName == "Log_an_Email") {
            //set our defaults
            taskObject.Task_Disposition__c = 'Completed';
            taskObject.Task_Attachment__c = 'Not Applicable';
            taskObject.Task_Source__c = 'Outbound';
            taskObject.Mailing_Address__c = 'Not Applicable';
            taskObject.Status = 'Completed';
        } else if (recordType.DeveloperName == "Log_a_Letter") {
            //set our defaults
            taskObject.Task_Disposition__c = 'Completed';
            taskObject.Task_Attachment__c = 'Not Applicable';
            taskObject.Task_Source__c = 'Outbound';
            taskObject.Mailing_Address__c = 'Primary Mailing Address';
            taskObject.Status = 'Completed';
        } else if (recordType.DeveloperName == "Post_a_Comment") {
            //set our defaults
            taskObject.Task_Reason__c = 'Providing Status or Clarification';
            taskObject.Task_Disposition__c = 'Completed';
            taskObject.Task_Attachment__c = 'Not Applicable';
            taskObject.Task_Source__c = 'User Activity';
            taskObject.Mailing_Address__c = 'Not Applicable';
            taskObject.Status = 'Completed';
        } else if (recordType.DeveloperName == "Attach_a_File") {
            //set our defaults
            taskObject.Task_Reason__c = 'Load Reference File';
            taskObject.Task_Disposition__c = 'Completed';
            taskObject.Task_Attachment__c = 'Provider Bill';
            taskObject.Task_Source__c = 'User Activity';
            taskObject.Mailing_Address__c = 'Not Applicable';
            taskObject.Status = 'Completed';
        } else if (recordType.DeveloperName == "Update_ORS") {
            //set our defaults
            taskObject.Task_Reason__c = 'Add Comments to ORS Record';
            taskObject.Task_Disposition__c = 'Completed';
            taskObject.Task_Attachment__c = 'Not Applicable';
            taskObject.Task_Source__c = 'User Activity';
            taskObject.Mailing_Address__c = 'Not Applicable';
            //we are only allowing for an option of Request Queued right now since we are hiding the other options.
            //if (this.getExternalConfigValue(cmp, 'SPIT STATUS') == 'ON') {
            taskObject.Status = 'Request Queued';
            //} else {
            //    taskObject.Status = 'Completed';
            //}
        } else if (recordType.DeveloperName == "Schedule_a_Meeting") {
            //set our defaults
            taskObject.Task_Reason__c = 'Request for Additional Info';
            taskObject.Task_Disposition__c = 'Completed';
            taskObject.Task_Attachment__c = 'Not Applicable';
            taskObject.Task_Source__c = 'User Activity';
            taskObject.Mailing_Address__c = 'Not Applicable';
            taskObject.Status = 'Completed';
        } else if (recordType.DeveloperName == "Attend_a_Meeting") {
            //set our defaults
            taskObject.Task_Reason__c = 'Request for Additional Info';
            taskObject.Task_Disposition__c = 'Completed';
            taskObject.Task_Attachment__c = 'Not Applicable';
            taskObject.Task_Source__c = 'User Activity';
            taskObject.Mailing_Address__c = 'Not Applicable';
            taskObject.Status = 'Completed';
        } else if (recordType.DeveloperName == "DocuSign") {
            //set our defaults
            taskObject.Task_Reason__c = 'DocuSign Sent';
            taskObject.Task_Disposition__c = 'Pending';
            taskObject.Task_Attachment__c = 'Not Applicable';
            taskObject.Task_Source__c = 'User Activity';
            taskObject.Mailing_Address__c = 'Not Applicable';
            taskObject.Status = 'Pending';
            taskObject.DocuSign_Template__c = 'ENRP Welcome Package';
        }
    },

    setRequiredProperty: function (cmp, fieldName, propertyValue) {
        try {
            var field = cmp.find(fieldName);
            if (!!field) {
                if (Array.isArray(field)) {
                    field.forEach(function (itm) {
                        itm.set('v.required', propertyValue);

                        if (propertyValue == false) {
                            this.resetValidity(cmp, [fieldName]);
                        }
                    });
                } else {
                    field.set('v.required', propertyValue);

                    if (propertyValue == false) {
                        this.resetValidity(cmp, [fieldName]);
                    }
                }
            }
        } catch (err) {
            console.err(err);
            this.handleErrors(err);

        }
    },

    setDisabledProperty: function (cmp, fieldName, propertyValue, clearOnDisable) {
        try {
            var field = cmp.find(fieldName);
            if (!!field) {
                if (Array.isArray(field)) {
                    field.forEach(function (itm) {
                        itm.set('v.disabled', propertyValue);

                        if (propertyValue == true && clearOnDisable == true) {
                            itm.set('v.value', null);
                        }
                    });
                } else {
                    field.set('v.disabled', propertyValue);

                    if (propertyValue == true && clearOnDisable == true) {
                        field.set('v.value', null);
                    }
                }
            }

        } catch (err) {
            console.err(err);
            this.handleErrors(err);

        }
    },

    resetValidity: function (cmp, cmpList) {
        cmpList.forEach(function (item) {
            var inputCmp = cmp.find(item);
            if (inputCmp) {
                if (Array.isArray(inputCmp)) {
                    inputCmp.forEach(function (itm) {
                        if (itm.setCustomValidity) {
                            itm.setCustomValidity('');
                        }
                        if (itm.reportValidity) {
                            itm.reportValidity();
                        }
                    });
                } else {
                    if (inputCmp.setCustomValidity) {
                        inputCmp.setCustomValidity('');
                    }
                    if (inputCmp.reportValidity) {
                        inputCmp.reportValidity();
                    }
                }
            }
        });
    },

    processContactNumber: function (contact) {
        var toReturn;
        try {
            if (!contact.Preferred_Phone_Type__c) {
                //toReturn = 'Preferred Phone Type not Set';
                toReturn = '';
            } else {
                if (contact.Preferred_Phone_Type__c == 'Home Phone') {
                    if (!contact.HomePhone) {
                        toReturn = '';
                        //toReturn = 'Preferred Phone Type of [Home Phone] not set';
                    } else {

                        toReturn = contact.HomePhone;
                    }
                } else if (contact.Preferred_Phone_Type__c == 'Mobile') {
                    if (!contact.MobilePhone) {
                        toReturn = '';
                        //toReturn = 'Preferred Phone Type of [Mobile] not set';
                    } else {
                        toReturn = contact.MobilePhone;
                    }
                } else if (contact.Preferred_Phone_Type__c == 'Work Phone') {
                    if (!contact.Work_Phone__c) {
                        toReturn = '';
                        //toReturn = 'Preferred Phone Type of [Work Phone] not set';
                    } else {
                        toReturn = contact.Work_Phone__c;
                    }
                } else if (contact.Preferred_Phone_Type__c == 'Other Phone') {
                    if (!contact.OtherPhone) {
                        toReturn = '';
                        //toReturn = 'Preferred Phone Type of [Other Phone] not set';
                    } else {
                        toReturn = contact.OtherPhone;
                    }
                }
            }
        } catch (err) {
            console.error(err);
            this.handleErrors(err);

        }

        return toReturn;
    },

    handleErrors: function (errors, cmp) {
        // Configure error toast
        let toastParams = {
            mode: 'sticky',
            title: "Error",
            message: "Unknown error", // Default error message
            type: "error",

        };

        if (errors) {
            if (Array.isArray(errors) && errors.length > 0) {
                if (errors[0].message) {
                    toastParams.message = errors[0].message;
                } else if (errors[0].fieldErrors) {
                    toastParams.message = this.objToString(errors[0].fieldErrors);
                } else {
                    toastParams.message = 'Could not execute requested action';
                }
            } else {
                toastParams.message = 'Could not execute requested action';
            }
        } else {
            toastParams.message = 'Could not execute requested action';
        }

        if (cmp) {
            cmp.set('v.showSpinner', false);
        }

        // Fire error toast
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams(toastParams);
        toastEvent.fire();
    },

    objToString: function (obj) {
        var str = '';
        for (var p in obj) {
            if (obj.hasOwnProperty(p)) {
                str += p + '::' + obj[p] + '\n';
            }
        }
        return str;
    },

    handleWarning: function (title, message) {
        let toastParams = {
            title: title,
            message: "Unknown error", // Default error message
            type: "warning",
            mode: 'sticky'
        };

        if (message) {
            toastParams.message = message;
        }

        // Fire error toast
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams(toastParams);
        toastEvent.fire();
    },

    apex: function (cmp, apexAction, params) {
        var p = new Promise($A.getCallback(function (resolve, reject) {
            var action = cmp.get("c." + apexAction + "");
            action.setParams(params);
            action.setCallback(this, function (callbackResult) {
                if (callbackResult.getState() == 'SUCCESS') {
                    resolve(callbackResult.getReturnValue());
                } else if (callbackResult.getState() == 'ERROR') {
                    console.log('ERROR', callbackResult.getError());
                    reject(callbackResult.getError());
                }
            });
            $A.enqueueAction(action);
        }));
        return p;
    },

    checkRequiredFields: function (cmp) {
        var hlp = this;
        try {
            var taskObject = cmp.get('v.taskObject');

            var toCheck = [];
            if (cmp.get('v.showAttachment') == true) {
                toCheck.push('Mailing_Address__c');
            }

            if (cmp.get('v.showAttachment') == true) {
                toCheck.push('Task_Attachment__c');
            }
            if (cmp.get('v.showFollowUp') == true) {
                toCheck.push('Follow_Up_Reminder_Date__c');
                toCheck.push('Follow_Up_Comments__c');
            }

            if (cmp.get('v.showOtherReasonComment') == true) {
                toCheck.push('Other_Reason_Comment__c');
            }

            if (cmp.get('v.showRouteDropDown') == true) {
                toCheck.push('ORS_Route_To__c');
            }

            if (cmp.get('v.showChangeORSStatusDropDown') == true) {
                toCheck.push('ORS_Status__c');
            }

            toCheck.push('Task_Reason__c');
            toCheck.push('Task_Source__c');
            toCheck.push('ddStatus');
            toCheck.push('contactLookup');
            toCheck.push('userLookup');
            toCheck.push('Task_Occured_Due_Date__c');
            toCheck.push('Phone_Number__c');
            toCheck.push('Email_Address__c');
            toCheck.push('Mailing_Address__c');
            toCheck.push('Task_Disposition__c');
            toCheck.push('Other_Disposition_Comments__c');
            toCheck.push('Task_Comments__c');


            var allValid = true;

            if (!taskObject.Task_Reason__c || taskObject.Task_Reason__c == '--None--') {
                if (allValid === false) {
                    hlp.handleWarning('Required Fields are Missing', 'Please choose a valid Task Reason and correct any other issues.');
                } else {
                    hlp.handleWarning('Required Fields are Missing', 'Please choose a valid Task Reason');
                }
                allValid = false;

            }

            if (cmp.get('v.showDispositionLine') === true) {
                if (!taskObject.Task_Disposition__c || taskObject.Task_Disposition__c == '--None--') {
                    if (allValid === false) {
                        hlp.handleWarning('Required Fields are Missing', 'Please choose a valid Task Outcome and correct any other issues.');
                    } else {
                        hlp.handleWarning('Required Fields are Missing', 'Please choose a valid Task Outcome');
                    }

                    allValid = false;

                }
            } else {
                taskObject.Task_Disposition__c = '';
            }




            toCheck.forEach(function (item) {
                var inputCmp = cmp.find(item);
                if (inputCmp) {
                    if (inputCmp.reportValidity) {
                        inputCmp.reportValidity();
                    }
                    if (inputCmp.showHelpMessageIfInvalid) {
                        inputCmp.showHelpMessageIfInvalid();
                    }
                    if (inputCmp.checkValidity) {
                        allValid = allValid && inputCmp.checkValidity();
                    }


                }
            });

            if (taskObject.Task_Reason__c == 'Add Comments to ORS Record' ||
                taskObject.Task_Reason__c == 'Route ORS Record') {
                if (!taskObject.Description) {
                    allValid = false;
                    hlp.handleWarning("Missing Comments.", "This action requires that Comments be entered.")
                }
            }



            if (taskObject.Status == 'Request Queued' &&
                cmp.get('v.recordType').DeveloperName != 'DocuSign') {
                var user = cmp.get("v.selectedUser");
                cmp.get("v.users").forEach(function (item) {
                    if (item.Id == user) {
                        if (!item.TOPS_User_ID__c || !item.TOPS_Password__c) {
                            allValid = false;
                            hlp.handleWarning("Missing Credentials.", "Please ensure your TOPS ID and Password are completed in your User Profile Settings before submitting this Task Type.")
                        }
                    }
                });
            }


            return allValid;

        } catch (err) {
            console.error(err);
            hlp.handleErrors(err);

        }
    },

    handleDocuSignSendRequest: function (cmp, event) {
        var taskObject = cmp.get('v.taskObject');
        var action = cmp.get("c.SetAndGetEnvelopeReadyToSend");
        action.setParams({
            "sfEnvelopeID": taskObject.CDocuSign_Envelope__c
        });

        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                try {
                    var isReadyForSend = response.getReturnValue();
                    if (isReadyForSend) {
                        var taskObject = cmp.get('v.taskObject');
                        taskObject.Status = 'Request Queued';
                        cmp.set('v.taskObject', taskObject);
                        cmp.set('v.docusignVoidRequested', false);
                        this.handleSubmit(cmp, event);
                    } else {
                        this.handleWarning("Missing Required Fields", "Please fill out all required fields in the DocuSign document before sending.");
                    }
                } catch (err) {
                    this.handleErrors(err.message);
                    console.error(err);
                }
            } else if (state === "ERROR") {
                this.handleErrors(response.getError());
            }
        });
        $A.enqueueAction(action);
    },

    handleSubmit: function (cmp, event) {
        var hlp = this;

        try {

            var allValid = hlp.checkRequiredFields(cmp);

            if (allValid) {
                var taskObject = cmp.get('v.taskObject');

                if (cmp.get('v.showContact') == true) {
                    var contact = cmp.get("v.selectedContact");
                    if (contact) {
                        taskObject.WhoId = contact;
                    } else {
                        taskObject.WhoId = undefined;
                    }
                }

                var user = cmp.get("v.selectedUser");
                taskObject.OwnerId = user;

                if (taskObject.Status == 'Pending') {
                    taskObject.IsReminderSet = true;
                    taskObject.ReminderDateTime = taskObject.Follow_Up_Reminder_Date__c;
                    //NOTE: we are now setting the subject in the APEX controller.
                    taskObject.ActivityDate = taskObject.Task_Occured_Due_Date__c;
                } else {
                    taskObject.IsReminderSet = false;
                    taskObject.ReminderDateTime = null;
                    taskObject.Subject = null;
                    taskObject.ActivityDate = null;
                }


                cmp.set('v.showSpinner', true);

                if (cmp.get('v.viewModifyTask') == true) {
                    hlp.updateTask(cmp, taskObject);
                } else {
                    taskObject.WhatId = cmp.get('v.CaseID');
                    if (taskObject.Status == 'Request Queued') {
                        taskObject.Task_Disposition__c = 'Pending';
                    }
                    taskObject.Milestone__c = cmp.get('v._milestone');
                    hlp.createTask(cmp, taskObject);

                    // if (cmp.get('v.recordType').DeveloperName == 'Attach_a_File') {
                    //     cmp.set('v.taskObjectHOLD', taskObject);
                    //     hlp.sendMessage(cmp, 'GetFileListRequest', null, false);
                    // } else {
                    //     hlp.createTask(cmp, taskObject);
                    // }


                }
            }

        } catch (err) {
            console.error(err);
            hlp.handleErrors(err);

        }
    },


    setEditMode: function (cmp, inEditMode) {
        var hlp = this;
        var toSet = [];

        var toSetOpposite = [];

        try {


            toSet.push('Task_Source__c');
            toSet.push('Task_Occured_Due_Date__c');
            toSet.push('Duration_minutes__c');
            toSet.push('contactLookup');
            toSet.push('Phone_Number__c');
            toSet.push('Email_Address__c');
            toSet.push('Mailing_Address__c');
            toSet.push('Task_Reason__c');
            toSet.push('Other_Reason_Comment__c');
            toSet.push('Other_Disposition_Comments__c');
            toSet.push('Task_Attachment__c');
            toSet.push('userLookup');
            toSet.push('ddStatus');
            toSet.push('Follow_Up_Reminder_Date__c');
            toSet.push('Follow_Up_Comments__c');
            toSet.push('Task_Comments__c');
            toSet.push('ORS_Route_To__c');
            toSet.push('ORS_Status__c');
            toSet.push('Task_Disposition__c');
            toSet.push('DocuSign_Template__c');
            toSet.push('Non_Contact_Entity__c');
            toSet.push('Non_Contact_Entity_Name__c');



            toSet.forEach(function (item) {
                hlp.setDisabledProperty(cmp, item, !inEditMode, false);
            });

            if (!inEditMode) {
                hlp.setDisabledProperty(cmp, 'btnCreateDraft', true, false);
                hlp.setDisabledProperty(cmp, 'btnReviewModifyDocusign', true, false);
            }
            toSetOpposite.push('btnSendDocusign');
            toSetOpposite.forEach(function (item) {
                hlp.setDisabledProperty(cmp, item, inEditMode, false);
            });

            cmp.set('v.inEditMode', inEditMode);
        } catch (err) {
            console.error(err);
            hlp.handleErrors(err);
        }
    },

    updateSDFileStatus: function (cmp, caseId, negotiationId, sdFileId, negotiationStatus, sdDistributionStatus) {
        var hlp = this;

        try {

            var action = cmp.get("c.updateOverallSmartDocStatusNegotiation");
            action.setParams({
                caseId: caseId,
                negotiationId: negotiationId,
                sdFileId: sdFileId,
                negotiationStatus: negotiationStatus,
                sdDistributionStatus: sdDistributionStatus,
                sdDistributionMethod: 'DocuSign',
                cFaxStatus: '',
                emailMessageId: '',
                cFaxObjId: ''
            });
            action.setCallback(this, function (response) {
                var state = response.getState();
                if (state === "ERROR") {
                    hlp.handleErrors(response.getError());
                } else {
                    //_negotiation.Current_SD_File__r.Distribution_Status__c = sdFileDistStatus;
                    //_negotiation.Smart_Doc_Status__c = negotiationSmartDocStatus;
                    cmp.set('v._negotiation', response.getReturnValue());
                    if (status != 'Error') {
                        cmp.find("overlayLib").notifyClose();
                    }
                }
            });
            $A.enqueueAction(action);
        } catch (err) {
            console.error(err);
            hlp.handleErrors(err);
        }
    },

    sendMessage: function (cmp, type, payload, withDelay) {
        try {
            var message = {
                type: type,
                payload: payload
            };

            if (withDelay === true) {
                setTimeout(function () {
                    var frame = document.getElementById('wcFileUploaderIframe');
                    frame.contentWindow.postMessage(message, '*');
                }, 500);
            } else {
                var frame = document.getElementById('wcFileUploaderIframe');
                frame.contentWindow.postMessage(message, '*');
            }
        } catch (err) {
            console.error(err);
            this.handleErrors(err);
        }
    },
    handleCloseAndRefresh: function (cmp, taskObject) {
        try {
            this.updateTask(cmp, taskObject);
            if (cmp.get('v.recordHomeMode') == true) {
                var url = window.location.href;
                var value = url.substr(0, url.lastIndexOf('/') + 1);
                window.history.back();
                return false;
            } else {
                cmp.find("overlayLib").notifyClose();
            }
        } catch (err) {
            console.error(err);
            this.handleErrors(err);
        }
    },
})