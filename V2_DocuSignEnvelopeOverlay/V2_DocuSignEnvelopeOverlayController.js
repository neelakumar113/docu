({
    doInit: function (cmp, event, helper) {
        try {

            var envelope = cmp.get('v.taskObject').CDocuSign_Envelope__r;

            helper.refreshDataForContentViewer(cmp, true, false);

            if (envelope.Envelope_Status__c === 'Not Created') {
                helper.initialLoad(cmp);
            } else if (envelope.Envelope_Status__c === 'Created') {
                helper.initialLoadDraftCreated(cmp);
            } else {
                helper.postSentLoad(cmp);
            }
        } catch (err) {
            helper.handleErrors(err.message);
            console.error(err);
        }
    },

    onChangeContentViewer: function (cmp, event, helper) {
        try {

            var selectedContent = cmp.get("v.selectedContent");

            if (selectedContent) {

            }

        } catch (err) {
            helper.handleErrors(err.message);
            console.error(err);
        }
    },


    handleSectionToggle: function (cmp, event) {
        var openSections = event.getParam('openSections');

        var elements = document.getElementsByClassName("tabContainer");
        var totalHeight = 500;

        elements[0].style.height = '100%';
        openSections.forEach(function (item) {
            if (item == 'EnvelopeSummary') {
                totalHeight -= 50;
            } else if (item == 'EnvelopeRecipients') {
                totalHeight -= 185;
            }
        });
        elements[0].style.height = totalHeight + 'px';
        //elements[0].style.height = 'calc(100vh - 430px)';

    },

    handleReload: function (cmp, event, helper) {
        // var article = cmp.get('v.artifact');
        // if (article.URL__c) {
        cmp.set('v.showDocumentIframe', false);
        cmp.set('v.showDocumentIframe', true);

        // } else {
        // handleWarning(cmp, "Not Available", "Document is not currently avaialble.");
        // }
    },

    handleDocuSignCreateDraft: function (cmp, event, helper) {

        var body = cmp.get("v.bodyRecipients");
        var recipients = cmp.get('v.recipients');
        var readyForSave = true;

        if (body) {
            for (var i = (body.length - 1); i >= 0; i--) {
                var childRecipient = body[i].get("v.recipient");
                recipients.forEach(function (itm) {
                    if (itm.CDocuSign_Template_Recipient__r.Recipient_ID__c == childRecipient.CDocuSign_Template_Recipient__r.Recipient_ID__c) {
                        itm.Email_Address__c = childRecipient.Email_Address__c;
                        itm.First_Name__c = childRecipient.First_Name__c;
                        itm.Last_Name__c = childRecipient.Last_Name__c;
                        itm.Authentication_SMS_Number__c = childRecipient.Authentication_SMS_Number__c;
                        itm.Authentication_Access_Token__c = childRecipient.Authentication_Access_Token__c;
                        itm.Authentication_Phone_Number__c = childRecipient.Authentication_Phone_Number__c;
                        itm.Use_Phone__c = childRecipient.Use_Phone__c;
                        itm.Use_Digital__c = childRecipient.Use_Digital__c;
                        itm.Use_Access_Code_Auth__c = childRecipient.Use_Access_Code_Auth__c;
                        itm.Use_SMS_Auth__c = childRecipient.Use_SMS_Auth__c;
                        itm.Contact__c = childRecipient.Contact__c;
                    }

                    if (body[i].get("v.readyForSave") === false) {
                        readyForSave = false;
                    }
                });

            }
            cmp.set("v.recipients", recipients);
        }

        if (readyForSave === false) {
            helper.handleWarning('Cannot Proceed with Draft', 'Please complete all required fields for each Recipient.');
        } else {
            helper.setSpinner(cmp, true, 'Communicating with DocuSign......Please Wait');
            if (cmp.get('v.sdFile')) {
                helper.executeSPIT(cmp, 'DOCUSIGN CREATE SMART DOC DRAFT');
            } else {
                helper.executeSPIT(cmp, 'DOCUSIGN CREATE DRAFT');
            }
        }
    },

    handleFilter: function (cmp, event, helper) {
        var envelope = cmp.get('v.taskObject').CDocuSign_Envelope__r;
        var isDisabled = true;

        if (envelope.Envelope_Status__c === 'Created') {
            isDisabled = false;
        }

        helper.drawTabFields(cmp, cmp.find('filterByPreloaded').get('v.checked'), cmp.find('filterByRequired').get('v.checked'), isDisabled);
    },

    handleCloseDraftAndTaskWindows: function (cmp, event, helper) {
        var appEvent = $A.get("e.c:evtDocuSignAction");
        appEvent.setParams({
            "action": "closeOverlayAndTask"
        });
        appEvent.fire();
    },


    handleDocuSignDiscardDraft: function (cmp, event, helper) {
        if (cmp.get('v.taskObject').CDocuSign_Envelope__r.Envelope_Status__c == 'Not Created') {
            var appEvent = $A.get("e.c:evtDocuSignAction");
            appEvent.setParams({
                "action": "closeOverlayAndTask"
            });
            appEvent.fire();
        } else {
            helper.setSpinner(cmp, true, 'Cleaning up.....Please Wait');
            helper.executeSPIT(cmp, 'DOCUSIGN DISCARD DRAFT');
        }
    },

    handleDocuSignModifyDraft: function (cmp, event, helper) {

        var envelopeTabs = cmp.get('v.envelopeTabs');

        var body = cmp.get('v.bodyTabs');
        var readyForSave = true;

        envelopeTabs.forEach(function (tab) {
            for (var i = 0; i < body.length; i++) {

                var tabChild = body[i].get("v.envelopeTab");
                if (tab.Id == tabChild.Id) {
                    tab.Value__c = tabChild.Value__c;
                }

                if (body[i].get("v.isValid") === false) {
                    readyForSave = false;
                }
            }
        });

        if (readyForSave === false) {
            helper.handleWarning('Cannot Proceed with Update', 'Please correct any Envelope Tabs in error before continuing.');
        } else {
            helper.setSpinner(cmp, true, 'Communicating with DocuSign......Please Wait');
            cmp.set('v.envelopeTabs', envelopeTabs);
            helper.executeSPIT(cmp, 'DOCUSIGN UPDATE DRAFT TAB VALUES');
        }
    },

    handleReturnToDraft: function (cmp, event, helper) {
        var appEvent = $A.get("e.c:evtDocuSignAction");

        appEvent.setParams({
            "action": "closeOverlay"
        });
        appEvent.fire();
    },

    handleImmediateSend: function (cmp, event, helper) {
        var appEvent = $A.get("e.c:evtDocuSignAction");

        appEvent.setParams({
            "action": "handleImmediateSend"
        });
        appEvent.fire();
    },

    handleError: function (cmp, event, helper) {
        helper.setSpinner('cmp', false);
    },

    handleClose: function (cmp, event, helper) {
        try {} catch (err) {
            helper.handleErrors(err.message);
            console.error(err);
        }
    },

    handleCancel: function (cmp, event, helper) {
        try {} catch (err) {
            helper.handleErrors(err.message);
            console.error(err);
        }
    },
})