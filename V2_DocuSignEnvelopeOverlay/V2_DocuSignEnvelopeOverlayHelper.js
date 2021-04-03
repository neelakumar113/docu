({
    doInit: function (cmp) {},

    refreshDataForContentViewer: function (cmp, refreshData, refreshDocuSignURLOnly) {
        var artifacts;

        if (refreshData === true) {
            cmp.set("v.contentViewerData", "");

            var action = cmp.get("c.GetContentViewerData");
            action.setParams({
                caseID: cmp.get("v.CaseID")
            });
            action.setCallback(this, function (response) {
                var state = response.getState();
                if (state === "SUCCESS") {

                    try {
                        artifacts = response.getReturnValue();
                        if (artifacts != null) {
                            artifacts.forEach(function (item) {
                                item.label = item.Display_Name__c;
                                item.value = item.URL__c;
                            });
                        }
                        cmp.set("v.contentViewerData", artifacts);

                        if (cmp.get('v.sdFile')) {
                            cmp.set('v.documentPageRef', artifacts[0].URL__c);
                        } else {
                            cmp.find('contentViewerSelection').set('v.value', artifacts[0].URL__c);
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
        }

        // if (refreshData === true || refreshDocuSignURLOnly === true) {
        //     var documentURL = cmp.get('v.documentUrl');

        //     if (!documentURL) {
        //         documentURL = 'about:blank';
        //     }

        //     artifacts = cmp.get("v.contentViewerData");
        //     if (artifacts != null) {
        //         artifacts.forEach(function (item) {
        //             if (itm.label == 'DocuSign') {
        //                 item.value = documentURL;
        //             }
        //         });
        //     }
        //     cmp.set("v.contentViewerData", artifacts);
        // }

        // var selectedContent = cmp.get('v.selectedContent');

        // if (!selectedContent) {
        //     artifacts = cmp.get("v.contentViewerData");
        //     if (artifacts != null) {
        //         artifacts.forEach(function (item) {
        //             if (itm.label == 'DocuSign') {
        //                 cmp.set('v.selectedContent', itm.value);
        //             }
        //         });
        //     }
        // }
    },

    refreshDocuSignURL: function (cmp, updatedDocuSignURL) {
        try {
            var artifacts = cmp.get("v.contentViewerData");
            if (artifacts != null) {
                artifacts.forEach(function (item) {
                    if (item.label == 'DocuSign') {
                        item.value = updatedDocuSignURL;
                    }
                });
            }
            cmp.set("v.contentViewerData", artifacts);
            cmp.set('v.documentPageRef', updatedDocuSignURL);

            cmp.set('v.showDocumentIframe', false);
            cmp.set('v.showDocumentIframe', true);

        } catch (err) {
            this.handleErrors(err.message);
            console.error(err);
        }
    },


    loadPostDraftCreate: function (cmp) {
        try {
            this.setSpinner(cmp, true);
        } catch (err) {
            this.handleErrors(err);
            console.error(err);
            this.setSpinner(cmp, true);
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

    executeSPIT: function (cmp, taskType) {
        try {
            var hlpr = this;
            var action;
            var envelope;

            if (taskType == 'DOCUSIGN CREATE DRAFT') {
                action = cmp.get("c.CreateSPITRecordForDocusignCreateDraft");
                action.setParams({
                    taskObjectId: cmp.get('v.taskObject').Id,
                    caseID: cmp.get('v.CaseID'),
                    templateName: cmp.get('v.templateName'),
                    recipients: cmp.get('v.recipients')

                });
            } else if (taskType == "DOCUSIGN CREATE SMART DOC DRAFT") {
                action = cmp.get("c.CreateSPITRecordForDocusignCreateSmartDocumentDraft");
                action.setParams({
                    taskObjectId: cmp.get('v.taskObject').Id,
                    caseID: cmp.get('v.CaseID'),
                    templateName: cmp.get('v.templateName'),
                    recipients: cmp.get('v.recipients'),
                    sdFileId: cmp.get('v.sdFile'),
                    isTest: false
                });
            } else if (taskType == 'DOCUSIGN UPDATE DRAFT TAB VALUES') {
                action = cmp.get("c.CreateSPITRecordForDocusignUpdate");
                //cmp.set('v.documentUrl', 'about:blank');
                hlpr.refreshDocuSignURL(cmp, 'about:blank');

                envelope = cmp.get('v.taskObject').CDocuSign_Envelope__r;

                action.setParams({
                    envelopeID: envelope.Envelope_ID__c,
                    envelopeSFID: envelope.Id,
                    tabValues: cmp.get('v.envelopeTabs'),
                    artifactID: cmp.get('v.artifact').Id
                });
            } else if (taskType == 'DOCUSIGN DISCARD DRAFT') {
                action = cmp.get("c.CreateSPITRecordForDocusignDiscardDraft");
                envelope = cmp.get('v.taskObject').CDocuSign_Envelope__r;

                action.setParams({
                    envelopeID: envelope.Envelope_ID__c,
                    fileName: cmp.get('v.artifact').File_Name__c
                });
            }

            action.setCallback(this, function (response) {
                var state = response.getState();
                if (state === "SUCCESS") {
                    try {
                        var intTask = response.getReturnValue();
                        cmp.set('v.iframePageRef', this.getExternalConfigValue(cmp, 'SPIT Endpoint') + '?id=' + intTask.Id + '&token=' + intTask.GUID__c);

                        //now lets poll the SPIT table until our SPIT task is completed, OR we execeed the maximum allowed wait period
                        var pollId = window.setInterval(
                            $A.getCallback(function () {
                                hlpr.getSPITstatusForDocusign(cmp, intTask.Id, pollId);
                            }), hlpr.getExternalConfigValue(cmp, 'SPIT Polling Interval')
                        );

                        cmp.set('v.pollId', pollId);
                    } catch (err) {
                        var catchPolId = cmp.get('v.pollId');
                        if (catchPolId) {
                            cmp.set('v.pollId', '');
                            window.clearInterval(catchPolId);
                            this.setSpinner(cmp, false);
                        }
                        this.handleErrors(err);
                        console.error(err);
                    }
                } else {
                    this.setSpinner(cmp, false);
                    this.handleErrors(response.getError());
                }
            });
            $A.enqueueAction(action);
        } catch (err) {
            this.setSpinner(cmp, false);
            this.handleErrors(err);

        }
    },

    getSPITstatusForDocusign: function (cmp, integrationId, pollId) {
        var hlp = this;
        var cancelled = false;
        var recipients = cmp.get('v.recipients');
        var envelopeTabs = cmp.get('v.envelopeTabs');
        var spitRecord;
        var taskObject = cmp.get('v.taskObject');
        var appEvent = $A.get("e.c:evtDocuSignAction");

        try {

            this.apex(cmp, 'GetSPITRecord', {
                    id: integrationId
                })
                .then(function (result) {
                    spitRecord = result;

                    if (spitRecord.Status__c == 'COMPLETE') {
                        //SPITTER IS DONE
                        //CLEAR OUR COUNTERS SO WE NO LONGER POLL
                        cmp.set('v.accumulatedPollTime', 0);
                        window.clearInterval(pollId);
                        cmp.set('v.pollId', '');
                        cmp.set('v.integrationTaskDocuSign', spitRecord);

                        if (spitRecord.Disposition__c == 'SUCCESS') {
                            if (spitRecord.Task_Type__c == 'DOCUSIGN CREATE DRAFT' ||
                                spitRecord.Task_Type__c == 'DOCUSIGN CREATE SMART DOC DRAFT' ||
                                spitRecord.Task_Type__c == 'DOCUSIGN UPDATE DRAFT TAB VALUES') {
                                return hlp.apex(cmp, 'GetEnvelopeByID', {
                                    envelopeId: spitRecord.OUTPARM1__c
                                });
                            } else if (spitRecord.Task_Type__c == 'DOCUSIGN DISCARD DRAFT') {
                                return hlp.apex(cmp, 'DiscardDraftPostCleanUp', {
                                    taskObject: taskObject
                                });
                            }
                        } else {
                            cancelled = true;
                            throw spitRecord.Message__c;
                        }
                    } else {
                        cancelled = true;
                        //NO RESULT FROM SPITTER YET SO LETS GET READY TO RUN AGAIN
                        var maxPollTime = parseInt(hlp.getExternalConfigValue(cmp, 'SPIT MAX Poll Time'), 10);
                        var accumPollTime = parseInt(cmp.get('v.accumulatedPollTime'), 10);
                        accumPollTime = accumPollTime + parseInt(hlp.getExternalConfigValue(cmp, 'SPIT Polling Interval'), 10);

                        if (accumPollTime >= maxPollTime) {
                            window.clearInterval(pollId);
                            cmp.set('v.pollId', '');
                            cmp.set('v.accumulatedPollTime', 0);
                            hlp.setSpinner(cmp, false);
                            hlp.handleWarning("Transaction did not complete", "This function took to long to finish.  Please try again.");

                        } else {
                            cmp.set('v.accumulatedPollTime', accumPollTime);
                        }
                    }
                })
                .then(function (result) {
                    if (cancelled == false) {
                        if (spitRecord.Task_Type__c == 'DOCUSIGN CREATE DRAFT' ||
                            spitRecord.Task_Type__c == 'DOCUSIGN CREATE SMART DOC DRAFT' ||
                            spitRecord.Task_Type__c == 'DOCUSIGN UPDATE DRAFT TAB VALUES') {
                            taskObject.CDocuSign_Envelope__r = result;
                            taskObject.CDocuSign_Envelope__c = taskObject.CDocuSign_Envelope__r.Id;
                            cmp.set('v.taskObject', taskObject);

                            return hlp.apex(cmp, 'GetEnvelopeArtifactByArtifactID', {

                                artifactID: spitRecord.OUTPARM2__c
                            });


                        } else if (spitRecord.Task_Type__c == 'DOCUSIGN DISCARD DRAFT') {
                            taskObject = result;
                            cmp.set('v.taskObject', taskObject);
                            cmp.set('v.artifact', null);
                            cancelled = true;
                            //cmp.set('v.documentUrl', 'about:blank');
                            if (cmp.get('v.sdFile')) {
                                appEvent.setParams({
                                    "action": "closeOverlayAndTask"
                                });
                                appEvent.fire();

                            } else {
                                hlp.refreshDocuSignURL(cmp, 'about:blank');
                                hlp.initialLoad(cmp);

                            }

                        }
                    }
                })
                .then(function (result) {
                    if (cancelled == false) {
                        cmp.set('v.artifact', result);
                        //cmp.set('v.documentUrl', result.URL__c);
                        hlp.refreshDocuSignURL(cmp, result.URL__c);

                        return hlp.apex(cmp, 'WriteAndReturnRecipients', {
                            sfEnvelopeID: taskObject.CDocuSign_Envelope__c,
                            recipients: recipients
                        });
                    }
                })
                .then(function (result) {
                    if (cancelled == false) {
                        cmp.set('v.recipients', result);
                        hlp.drawRecipients(cmp, true);

                        return hlp.apex(cmp, 'WriteAndReturnEnvTabs', {
                            sfEnvelopeID: taskObject.CDocuSign_Envelope__c,
                            eTabs: envelopeTabs
                        });
                    }
                })
                .then(function (result) {
                    if (cancelled == false) {
                        envelopeTabs = result;

                        envelopeTabs.forEach(function (itm) {
                            if (!itm.Value__c) {
                                itm.Value__c = '';
                            }
                        });
                        cmp.set('v.envelopeTabs', envelopeTabs);

                        hlp.drawTabFields(cmp, cmp.find('filterByPreloaded').get('v.checked'), cmp.find('filterByRequired').get('v.checked'), false);
                        if (!cmp.get('v.sdFile')) {
                            hlp.toggleAccordionSection(cmp, "EnvelopeTabs", true);
                        }
                    }

                    if (spitRecord.Status__c == 'COMPLETE') {
                        hlp.setSpinner(cmp, false);
                    }
                })
                .catch(function (err) {
                    cmp.set('v.spitError', true);
                    cancelled = true;
                    hlp.setSpinner(cmp, false);
                    hlp.handleErrors(err);
                    console.error(err);
                });

        } catch (err) {
            window.clearInterval(pollId);
            if (cmp) {
                cmp.set('v.pollId', '');
                cmp.set('v.accumulatedPollTime', 0);
                hlp.setSpinner(cmp, false);
                hlp.handleErrors(err.message);
            }
            console.error(err);
        }
    },

    setDisabledModeForRecipients: function (isDisabled) {
        var appEvent = $A.get("e.c:evtDocuSignParentToRecipientChild");
        var fields = {
            isDisabled: isDisabled
        };

        appEvent.setParams({
            "fields": fields
        });
        appEvent.fire();
    },

    drawRecipients: function (cmp, isDisabled) {
        var hlpr = this;

        try {
            hlpr.removeAllRecipientChildren(cmp);

            var recipients = cmp.get('v.recipients');
            var contacts = cmp.get('v.contacts');

            if (recipients) {
                recipients.forEach(function (item) {
                    var filteredContacts = [];
                    //filter the contact list if necessary
                    if (item.CDocuSign_Template_Recipient__r.Filter_By_Advisor_Contact__c === true ||
                        item.CDocuSign_Template_Recipient__r.Filter_By_Employer_Group_Contact__c === true ||
                        item.CDocuSign_Template_Recipient__r.Filter_By_Family_Contact__c === true ||
                        item.CDocuSign_Template_Recipient__r.Filter_By_Negotiator_Contact__c === true ||
                        item.CDocuSign_Template_Recipient__r.Filter_By_OPS_Manager_Contact__c === true ||
                        item.CDocuSign_Template_Recipient__r.Filter_By_Provider_Contact__c === true ||
                        item.CDocuSign_Template_Recipient__r.Filter_By_Naviguard_Signee__c === true) {
                        var advisorRID;
                        var employerRID;
                        var familyRID;
                        var negotiatorRID;
                        var providerRID;
                        var billingProviderGroupID;
                        var billingAgencyID;
                        var opsManagerID;
                        var naviguardSigneeID;

                        cmp.get("v.contactRecordTypes").forEach(function (itm) {
                            if (itm.DeveloperName == 'Advisor') {
                                advisorRID = itm.Id;
                            }
                            if (itm.DeveloperName == 'Employer_Group') {
                                employerRID = itm.Id;
                            }
                            if (itm.DeveloperName == 'Enrolee_Contact') {
                                familyRID = itm.Id;
                            }
                            if (itm.DeveloperName == 'Negotiator') {
                                negotiatorRID = itm.Id;
                            }
                            if (itm.DeveloperName == 'OPS_Manager') {
                                opsManagerID = itm.Id;
                            }
                            if (itm.DeveloperName == 'Provider_Group') {
                                providerRID = itm.Id;
                            }
                            if (itm.DeveloperName == 'Billing_Provider_Group') {
                                billingProviderGroupID = itm.Id;
                            }
                            if (itm.DeveloperName == 'Billing_Agency') {
                                billingAgencyID = itm.Id;
                            }
                            if (itm.DeveloperName == 'Naviguard_DocuSigner') {
                                naviguardSigneeID = itm.Id;
                            }

                        });

                        contacts.forEach(function (cont) {
                            if (item.CDocuSign_Template_Recipient__r.Filter_By_Advisor_Contact__c == true) {
                                if (cont.RecordTypeId == advisorRID) {
                                    filteredContacts.push(cont);
                                }
                            } else if (item.CDocuSign_Template_Recipient__r.Filter_By_Employer_Group_Contact__c == true) {
                                if (cont.RecordTypeId == employerRID) {
                                    filteredContacts.push(cont);
                                }
                            } else if (item.CDocuSign_Template_Recipient__r.Filter_By_Family_Contact__c == true) {
                                if (cont.RecordTypeId == familyRID) {
                                    filteredContacts.push(cont);
                                }
                            } else if (item.CDocuSign_Template_Recipient__r.Filter_By_Negotiator_Contact__c == true) {
                                if (cont.RecordTypeId == negotiatorRID) {
                                    filteredContacts.push(cont);
                                }
                            } else if (item.CDocuSign_Template_Recipient__r.Filter_By_OPS_Manager_Contact__c == true) {
                                if (cont.RecordTypeId == opsManagerID) {
                                    filteredContacts.push(cont);
                                }
                            } else if (item.CDocuSign_Template_Recipient__r.Filter_By_Naviguard_Signee__c == true) {
                                if (cont.RecordTypeId == naviguardSigneeID) {
                                    filteredContacts.push(cont);
                                }
                            } else if (item.CDocuSign_Template_Recipient__r.Filter_By_Provider_Contact__c == true) {
                                if (cont.RecordTypeId == providerRID ||
                                    cont.RecordTypeId == billingProviderGroupID ||
                                    cont.RecordTypeId == billingAgencyID) {
                                    filteredContacts.push(cont);
                                }
                            }

                        });
                    } else {
                        filteredContacts = contacts;
                    }

                    filteredContacts.sort(function (a, b) {
                        var nameA = a.label.toUpperCase(); // ignore upper and lowercase
                        var nameB = b.label.toUpperCase(); // ignore upper and lowercase
                        if (nameA < nameB) {
                            return -1;
                        }
                        if (nameA > nameB) {
                            return 1;
                        }

                        // names must be equal
                        return 0;
                    });

                    var allowDigital = false;

                    if (cmp.get('v._caseDetail')) {
                        if (cmp.get('v._caseDetail').Digital__c == 'Yes') {
                            var templateName = cmp.get('v.templateName');
                            if (templateName.toUpperCase().includes('WELCOME')) {
                                allowDigital = true;
                            }
                        }
                    }

                    $A.createComponent(
                        "c:V2_DocuSignRecipientChild", {
                            "aura:id": "tabRecipient-" + item.Id,
                            "recipient": item,
                            "contacts": filteredContacts,
                            "selectedContact": item.Contact__c,
                            "envelopeStatus": cmp.get('v.taskObject').CDocuSign_Envelope__r.Envelope_Status__c,
                            "isDisabled": isDisabled,
                            "allowDigital": allowDigital
                            //"allowDigital": cmp.get('v.taskObject').DocuSign_Template__c.toUpperCase().includes('WELCOME')
                        },
                        function (newChild, status, errorMessage) {
                            if (status === "SUCCESS") {
                                var body = cmp.get("v.bodyRecipients");
                                body.push(newChild);
                                cmp.set("v.bodyRecipients", body);
                            } else if (status === "INCOMPLETE") {
                                console.log("No response from server or client is offline.")
                            } else if (status === "ERROR") {
                                hlpr.handleErrors(errorMessage);
                            }
                        }
                    )

                })
            }
        } catch (err) {
            hlpr.setSpinner(cmp, false);
            hlpr.handleErrors(err.message);
            console.error(err);
        }
    },

    removeAllRecipientChildren: function (cmp) {

        var body = cmp.get("v.bodyRecipients");
        if (body) {
            for (var i = (body.length - 1); i >= 0; i--) {
                body.pop();
            }
            cmp.set("v.bodyRecipients", body);
        }
    },


    drawTabFields: function (cmp, filterByPreload, filterByRequiredForSend, isDisabled) {
        var hlpr = this;


        try {

            if (!cmp.get('v.sdFile')) {

                hlpr.removeAllTabChildren(cmp);

                var tabFields = cmp.get('v.envelopeTabs');
                tabFields.sort(function (a, b) {
                    return a.CDocuSign_Template_Tab__r.Order_Number__c - b.CDocuSign_Template_Tab__r.Order_Number__c;
                });

                tabFields.forEach(function (item) {
                    if (item.CDocuSign_Template_Tab__r.Display_In_Overlay__c == true) {
                        var filtered = false;

                        if (filterByPreload === true) {
                            if (item.CDocuSign_Template_Tab__r.Preloaded__c == false) {
                                filtered = true;
                            }
                        }

                        if (filterByRequiredForSend === true) {
                            if (item.CDocuSign_Template_Tab__r.Required_For_Send__c == false) {
                                filtered = true;
                            }
                        }

                        if (filtered === false) {
                            $A.createComponent(
                                "c:V2_DocuSignTabChild", {
                                    "aura:id": "tabChild-" + item.Id,
                                    "envelopeTab": item,
                                    "isDisabled": isDisabled
                                },
                                function (newTabChild, status, errorMessage) {
                                    if (status === "SUCCESS") {
                                        var body = cmp.get("v.bodyTabs");
                                        body.push(newTabChild);
                                        cmp.set("v.bodyTabs", body);
                                    } else if (status === "INCOMPLETE") {
                                        console.log("No response from server or client is offline.")
                                    } else if (status === "ERROR") {
                                        hlpr.handleErrors(errorMessage);
                                    }
                                }
                            );
                        }
                    }


                });
            }
        } catch (err) {
            hlpr.setSpinner(cmp, false);
            hlpr.handleErrors(err.message);
            console.error(err);
        }
    },

    removeAllTabChildren: function (cmp) {

        var body = cmp.get("v.bodyTabs");

        for (var i = (body.length - 1); i >= 0; i--) {
            body.pop();
        }
        cmp.set("v.bodyTabs", body);
    },

    handleErrors: function (errors) {
        // Configure error toast
        let toastParams = {
            mode: 'sticky',
            title: "Error",
            message: "Unknown error", // Default error message
            type: "error",

        };

        if (errors && Array.isArray(errors) && errors.length > 0) {
            toastParams.message = errors[0].message;
        }

        if (errors) {
            if (Array.isArray(errors) && errors.length > 0) {
                toastParams.message = errors[0].message;
            } else {
                toastParams.message = errors;
            }
        }

        // Fire error toast
        let toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams(toastParams);
        toastEvent.fire();
    },

    initialLoad: function (cmp) {
        var hlp = this;
        hlp.setSpinner(cmp, true, '');
        var caseID = cmp.get('v.CaseID');
        var templateName = cmp.get('v.templateName');
        //var envelope = cmp.get('v.envelope');
        var envelope = cmp.get('v.taskObject').CDocuSign_Envelope__r;
        hlp.toggleAccordionSection(cmp, "EnvelopeSummary", true);

        this.apex(cmp, 'InitRecipientsForSFTemplateName', {
                caseId: caseID,
                templateName: templateName
            })
            .then(function (result) {
                cmp.set('v.recipients', result);
                hlp.drawRecipients(cmp, false);
                hlp.toggleAccordionSection(cmp, "EnvelopeRecipients", true);

                return hlp.apex(cmp, 'InitTabsForTemplateName', {
                    caseID: caseID,
                    templateName: templateName
                });
            })
            .then(function (result) {
                var envelopeTabs = result;
                envelopeTabs.forEach(function (itm) {
                    if (!itm.Value__c) {
                        itm.Value__c = '';
                    }
                });
                cmp.set('v.envelopeTabs', envelopeTabs);
                hlp.drawTabFields(cmp, cmp.find('filterByPreloaded').get('v.checked'), cmp.find('filterByRequired').get('v.checked'), true);
                if (!cmp.get('v.sdFile')) {
                    hlp.toggleAccordionSection(cmp, "EnvelopeTabs", false);
                }
                hlp.setSpinner(cmp, false);
            })
            .catch(function (err) {
                hlp.setSpinner(cmp, false);
                hlp.handleErrors(err.message);
                console.error(err);
            });
    },

    initialLoadDraftCreated: function (cmp) {
        var hlp = this;

        try {
            hlp.setSpinner(cmp, true, 'Loading DocuSign Draft - Please Wait');
            var envelope = cmp.get('v.taskObject').CDocuSign_Envelope__r;
            hlp.toggleAccordionSection(cmp, "EnvelopeSummary", true);

            hlp.apex(cmp, 'GetRecipientsForSFEnvelopeID', {
                    sfEnvelopeID: envelope.Id
                })
                .then(function (result) {
                    cmp.set('v.recipients', result);
                    hlp.drawRecipients(cmp, true);
                    hlp.toggleAccordionSection(cmp, "EnvelopeRecipients", true);

                    return hlp.apex(cmp, 'GetEnvelopeTabsByEnvelopeID', {
                        envelopeID: envelope.Id
                    });
                })
                .then(function (result) {
                    var envelopeTabs = result;
                    envelopeTabs.forEach(function (itm) {
                        if (!itm.Value__c) {
                            itm.Value__c = '';
                        }
                    });
                    cmp.set('v.envelopeTabs', envelopeTabs);
                    hlp.drawTabFields(cmp, cmp.find('filterByPreloaded').get('v.checked'), cmp.find('filterByRequired').get('v.checked'), false);
                    if (!cmp.get('v.sdFile')) {
                        hlp.toggleAccordionSection(cmp, "EnvelopeTabs", true);
                    }

                    return hlp.apex(cmp, 'GetEnvelopeArtifactByEnvelopeIDAndArtifactType', {
                        envelopeID: envelope.Id,
                        artifactType: 'Envelope Draft'
                    });
                })
                .then(function (result) {
                    cmp.set('v.artifact', result);
                    //cmp.set('v.documentUrl', result.URL__c);
                    hlp.refreshDocuSignURL(cmp, result.URL__c);
                    hlp.setSpinner(cmp, false);
                }).catch(function (err) {
                    hlp.setSpinner(cmp, false);
                    hlp.handleErrors(err.message);
                    console.error(err);
                });
        } catch (err) {
            hlp.setSpinner(cmp, false);
            hlp.handleErrors(err.message);
            console.error(err);
        }
    },

    postSentLoad: function (cmp) {
        var hlp = this;

        try {
            hlp.setSpinner(cmp, true, 'Loading - Please Wait');
            var envelope = cmp.get('v.taskObject').CDocuSign_Envelope__r;
            hlp.toggleAccordionSection(cmp, "EnvelopeSummary", true);

            hlp.apex(cmp, 'GetRecipientsForSFEnvelopeID', {
                    sfEnvelopeID: envelope.Id
                })
                .then(function (result) {
                    cmp.set('v.recipients', result);
                    hlp.drawRecipients(cmp, true);
                    hlp.toggleAccordionSection(cmp, "EnvelopeRecipients", true);

                    return hlp.apex(cmp, 'GetEnvelopeTabsByEnvelopeID', {
                        envelopeID: envelope.Id
                    });
                })
                .then(function (result) {
                    var envelopeTabs = result;
                    envelopeTabs.forEach(function (itm) {
                        if (!itm.Value__c) {
                            itm.Value__c = '';
                        }
                    });
                    cmp.set('v.envelopeTabs', envelopeTabs);
                    hlp.drawTabFields(cmp, cmp.find('filterByPreloaded').get('v.checked'), cmp.find('filterByRequired').get('v.checked'), true);
                    if (!cmp.get('v.sdFile')) {
                        hlp.toggleAccordionSection(cmp, "EnvelopeTabs", true);
                    }

                    return hlp.apex(cmp, 'GetEnvelopeArtifactsByCaseID', {
                        caseID: cmp.get('v.CaseID')
                    });

                }).then(function (result) {
                    var statusToSearchFor;
                    if (envelope.Envelope_Status__c == 'Voided') {
                        statusToSearchFor = 'Envelope Voided';
                    } else {
                        statusToSearchFor = 'Envelope Sent';
                    }
                    result.forEach(function (itm) {
                        if (itm.Artifact_Type__c == statusToSearchFor) {
                            //cmp.set('v.documentUrl', itm.URL__c);
                            hlp.refreshDocuSignURL(cmp, itm.URL__c);
                        }
                    });
                    hlp.setSpinner(cmp, false);
                })
                .catch(function (err) {
                    hlp.setSpinner(cmp, false);
                    hlp.handleErrors(err.message);
                    console.error(err);
                });
        } catch (err) {
            hlp.setSpinner('cmp', false);
            hlp.handleErrors(err.message);
            console.error(err);
        }
    },

    setSpinner: function (cmp, spinnerSwitch, spinnerText) {
        if (spinnerSwitch === true) {
            cmp.set('v.pleaseWaitText', spinnerText);
        } else {
            cmp.set('v.pleaseWaitText', '');
        }

        cmp.set('v.showSpinner', spinnerSwitch);
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

    setRequiredProperty: function (cmp, fieldName, propertyValue) {
        try {
            var field = cmp.find(fieldName);
            if (!!field) {
                field.set('v.required', propertyValue);

                if (propertyValue == false) {
                    this.resetValidity(cmp, [fieldName]);
                }
            }
        } catch (err) {
            this.handleErrors(err);
            console.err(err);
        }
    },

    setDisabledProperty: function (cmp, fieldName, propertyValue, clearOnDisable) {
        try {
            var field = cmp.find(fieldName);
            if (!!field) {
                field.set('v.disabled', propertyValue);

                if (propertyValue == true && clearOnDisable == true) {
                    field.set('v.value', null);
                }
            }

        } catch (err) {
            this.handleErrors(err);
            console.err(err);
        }
    },

    resetValidity: function (cmp, cmpList) {
        cmpList.forEach(function (item) {
            var inputCmp = cmp.find(item);
            if (inputCmp) {
                if (inputCmp.setCustomValidity) {
                    inputCmp.setCustomValidity('');
                }
                if (inputCmp.reportValidity) {
                    inputCmp.reportValidity();
                }
            }
        });
    },

    toggleAccordionSection: function (cmp, sectionName, isOpen) {
        try {

            var activeSections = cmp.get('v.activeSections');

            var foundIt = false;

            if (isOpen === true) {
                if (activeSections) {
                    activeSections.forEach(function (item) {
                        if (item == sectionName) {
                            foundIt = true;
                        }
                    });

                    if (foundIt == false) {
                        activeSections.push(sectionName);
                    }
                } else {
                    activeSections.push(sectionName);
                }

                cmp.set('v.activeSections', activeSections);
            } else if (isOpen === false) {
                var updatedActiveSections = [];
                if (activeSections) {
                    activeSections.forEach(function (item) {
                        if (item != sectionName) {
                            updatedActiveSections.push(item);
                        }
                    });
                }

                setTimeout($A.getCallback(
                    () => cmp.set("v.activeSections", updatedActiveSections)
                ));
            }
        } catch (err) {
            this.handleErrors(err);
            console.err(err);
        }

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
    }
})