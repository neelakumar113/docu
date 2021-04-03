({
    doInit: function (cmp, event, helper) {
        try {


            window.addEventListener("keydown", function (event) {
                var kcode = event.code;
                if (kcode == 'Escape') {
                    console.log('esccape id pess - Outer Component');
                    event.preventDefault();
                    event.stopImmediatePropagation();
                }
            }, true);

            helper.setSDFileIfNeeded(cmp);

        } catch (err) {
            console.error(err);
            helper.handleErrors(err);

        }
    },

    handleError: function (cmp, event, helper) {
        cmp.set('v.showSpinner', false);
    },

    handleSubmit: function (cmp, event, helper) {
        try {

            cmp.set('v.docusignVoidRequested', false);

            if (cmp.get('v.viewModifyTask') == false &&
                cmp.get('v.recordType').DeveloperName == 'Attach_a_File') {
                helper.sendMessage(cmp, 'GetFileListRequest', null, false);
            } else {
                helper.handleSubmit(cmp, event);
            }

        } catch (err) {
            console.error(err);
            helper.handleErrors(err);

        }
    },


    onChangeContactLookup: function (cmp, event, helper) {
        try {

            var selectedContact = cmp.get("v.selectedContact");

            if (!selectedContact) {

                cmp.find("Email_Address__c").set("v.value", null);
                cmp.find("Phone_Number__c").set("v.value", null);
            } else {
                cmp.get("v.contacts").forEach(function (item) {
                    if (item.Id == selectedContact) {
                        cmp.find("Email_Address__c").set("v.value", item.Email);
                        var contactNumber = helper.processContactNumber(item);
                        cmp.find("Phone_Number__c").set("v.value", contactNumber);
                    }
                });
            }
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);
        }
    },

    handle_Task_Reason__c_onchange: function (cmp, event, helper) {
        try {
            helper.applyBusinessRules(cmp);
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);
        }
    },

    followUpDateChange: function (cmp, event, helper) {
        try {
            var taskObject = cmp.get('v.taskObject');
            taskObject.Task_Occured_Due_Date__c = taskObject.Follow_Up_Reminder_Date__c;
            cmp.set('v.taskObject', taskObject);
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);
        }
    },

    handle_Task_Disposition__c_onchange: function (cmp, event, helper) {
        try {
            helper.applyBusinessRules(cmp);
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);
        }
    },

    handle_Status_onchange: function (cmp, event, helper) {
        try {
            helper.applyBusinessRules(cmp);

            if (event.getParam('value') == 'Pending') {
                cmp.find('Follow_Up_Reminder_Date__c').set('v.value', cmp.get('v.taskObject').Task_Occured_Due_Date__c);
            } else if (event.getParam('value') == 'Request Queued') {
                cmp.set('v.selectedUser', $A.get("$SObjectType.CurrentUser.Id"));
            } else if (event.getParam('value') == 'Completed') {
                var today = new Date();
                var taskObject = cmp.get('v.taskObject');
                taskObject.Task_Occured_Due_Date__c = today.toISOString();
                cmp.set('v.taskObject', taskObject);
            }
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);
        }
    },

    handleBlur: function (cmp, event) {
        //var validity = cmp.find("myinput").get("v.validity");
        //console.log(validity.valid); //returns true
    },

    handleClose: function (cmp, event, helper) {
        try {

            if (cmp.get('v.recordHomeMode') == true) {
                var url = window.location.href;
                var value = url.substr(0, url.lastIndexOf('/') + 1);
                window.history.back();
                return false;
                //window.history.back();
            } else {
                cmp.find("overlayLib").notifyClose();
            }
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);


        }
    },

    handleCancel: function (cmp, event, helper) {
        try {
            window.removeEventListener("message", cmp.get('v.wcFileUploadMessageCallback'));
            if (cmp.get('v.viewModifyTask') == true) {
                //cmp.set('v.inEditMode', false);
                helper.setEditMode(cmp, false);
                //helper.setDisabledProperty(cmp, 'ddStatus', true, false);
                helper.doInit(cmp);

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

                helper.resetValidity(cmp, toCheck);
                helper.resetValidity(cmp, ['contactLookup']);

            } else {
                cmp.set("v.newTaskCreated", "false");
                cmp.find("overlayLib").notifyClose();
            }

        } catch (err) {
            console.error(err);
            helper.handleErrors(err);
        }
    },

    handleDocuSignAction: function (cmp, event, helper) {
        if (event.getParam("action") == "closeOverlay") {
            cmp.set('v.showDocuSignOverlay', false);

            var taskWrapper = cmp.find('TaskWrapper');
            if (taskWrapper) {
                var el = taskWrapper.getElement();

                if (el) {
                    el.style.display = 'block';
                }
            }

        } else if (event.getParam("action") == "closeOverlayAndTask") {
            cmp.set('v.showDocuSignOverlay', false);

            var taskWrapper = cmp.find('TaskWrapper');
            if (taskWrapper) {
                var el = taskWrapper.getElement();

                if (el) {
                    el.style.display = 'block';
                }
            }


            cmp.find("overlayLib").notifyClose();
        } else if (event.getParam("action") == "handleImmediateSend") {
            cmp.set('v.showDocuSignOverlay', false);

            var taskWrapper = cmp.find('TaskWrapper');
            if (taskWrapper) {
                var el = taskWrapper.getElement();

                if (el) {
                    el.style.display = 'block';
                }
            }


            helper.handleDocuSignSendRequest(cmp, event);
        }
    },

    handleDocuSignViewModifyDraft: function (cmp, event, helper) {
        try {
            if (helper.getExternalConfigValue(cmp, 'SPIT STATUS') !== 'ON') {
                helper.handleWarning("Not Available", "DocuSign Functionality is currently not available.  Please try again later or contact Support.");
            } else {
                cmp.set('v.showDocuSignOverlay', true);
                var taskWrapper = cmp.find('TaskWrapper');
                if (taskWrapper) {
                    var el = taskWrapper.getElement();

                    if (el) {
                        el.style.display = 'none';
                    }
                }

            }
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);

        }
    },

    handleDocuSignView: function (cmp, event, helper) {
        try {
            if (helper.getExternalConfigValue(cmp, 'SPIT STATUS') !== 'ON') {
                helper.handleWarning("Not Available", "DocuSign Functionality is currently not available.  Please try again later or contact Support.");
            } else {
                cmp.set('v.showDocuSignOverlay', true);
                var taskWrapper = cmp.find('TaskWrapper');
                if (taskWrapper) {
                    var el = taskWrapper.getElement();

                    if (el) {
                        el.style.display = 'none';
                    }
                }

            }
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);

        }
    },


    handleDocuSignCreateDraft: function (cmp, event, helper) {
        try {
            if (helper.getExternalConfigValue(cmp, 'SPIT STATUS') !== 'ON') {
                helper.handleWarning("Not Available", "DocuSign Functionality is currently not available.  Please try again later or contact Support.");
            } else {
                cmp.set('v.showDocuSignOverlay', true);
                var taskWrapper = cmp.find('TaskWrapper');
                if (taskWrapper) {
                    var el = taskWrapper.getElement();

                    if (el) {
                        el.style.display = 'none';
                    }
                }

            }
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);

        }
    },

    handleDocuSignSend: function (cmp, event, helper) {
        try {
            if (helper.getExternalConfigValue(cmp, 'SPIT STATUS') !== 'ON') {
                helper.handleWarning("Not Available", "DocuSign Functionality is currently not available.  Please try again later or contact Support.");
            } else {
                helper.handleDocuSignSendRequest(cmp, event);
            }
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);

        }
    },

    handleDocuSignVoid: function (cmp, event, helper) {
        try {
            if (helper.getExternalConfigValue(cmp, 'SPIT STATUS') !== 'ON') {
                helper.handleWarning("Not Available", "DocuSign Functionality is currently not available.  Please try again later or contact Support.");
            } else {
                var taskObject = cmp.get('v.taskObject');
                taskObject.Status = 'Request Queued';
                cmp.set('v.taskObject', taskObject);
                cmp.set('v.docusignVoidRequested', true);
                helper.handleSubmit(cmp, event);
            }
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);
        }
    },

    viewEmail: function (cmp, event, helper) {
        try {


            var emailMessage = cmp.get('v.emailMessage');


            var modalBody;
            $A.createComponent("c:EmailOverlay", {
                    caseID: cmp.get('v.CaseID'),
                    emailMessage: emailMessage,
                    recordHomeMode: cmp.get('v.recordHomeMode'),
                    viewMessageMode: true,
                    fromTask: true
                },
                function (content, status, errorMessage) {
                    if (status === "SUCCESS") {
                        modalBody = content;
                        cmp.find('overlayLib').showCustomModal({
                            //header: "Create new Task",
                            body: modalBody,
                            showCloseButton: false,
                            // cssClass: "mymodal slds-modal_small",
                            closeCallback: function (result) {}
                        })
                    } else if (status === "INCOMPLETE") {
                        console.log("No response from server or client is offline.")
                    } else if (status === "ERROR") {
                        helper.handleErrors(errorMessage);
                    }
                });

        } catch (err) {
            console.error(err);
            helper.handleErrors(err);

        }
    },


    handleEdit: function (cmp, event, helper) {

        helper.setEditMode(cmp, true);
        helper.applyBusinessRules(cmp);

        var taskObject = cmp.get('v.taskObject');

        if (taskObject.Status == 'Request Queued') {
            helper.setDisabledProperty(cmp, 'Task_Disposition__c', true, false);
            helper.setDisabledProperty(cmp, 'Task_Reason__c', true, false);
            helper.setDisabledProperty(cmp, 'ORS_Route_To__c', true, false);
            helper.setDisabledProperty(cmp, 'ORS_Status__c', true, false);
            helper.setDisabledProperty(cmp, 'Task_Comments__c', true, false);
            helper.setDisabledProperty(cmp, 'ddStatus', true, false);
        }

    },

    handleSubmitToORS: function (cmp, event, helper) {
        var taskObject = cmp.get('v.taskObject');
        taskObject.Status = 'Request Queued';
        cmp.set('v.taskObject', taskObject);
        helper.handleSubmit(cmp, event);
    },

    handleNewTaskYes: function (cmp, event, helper) {
        cmp.set('v.showPromptToCreateNewTask', false);
        cmp.set('v.taskIDToUpdateForFollowUp', cmp.get('v.taskObject').Id);
        cmp.set('v.followUpTaskMode', true);
        cmp.set('v.viewModifyTask', false);

        helper.doInit(cmp);
    },

    handleNewTaskNo: function (cmp, event, helper) {
        cmp.set('v.showPromptToCreateNewTask', false);
        cmp.set('v.followUpTaskMode', false);
        cmp.set('v.viewModifyTask', true);
    },

    spit: function (cmp, event, helper) {
        try {
            cmp.set("v.iframPageRef", "https://localhost.44316/api/ServicePortal/ProcessIntegrationTasks/v1?id=1");
        } catch (err) {
            console.error(err);
            helper.handleErrors(err);

        }
    },

    handleCancelTask: function (cmp, event, helper) {
        var taskObject = cmp.get('v.taskObject');
        taskObject.Status = "Cancelled";
        cmp.set('v.taskObject', taskObject);
        helper.updateTask(cmp, taskObject);

        //helper.handleCloseAndRefresh(cmp, taskObject);
    },

})