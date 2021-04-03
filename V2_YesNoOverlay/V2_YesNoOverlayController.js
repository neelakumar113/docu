({
    handleYes: function (cmp, event, helper) {
        try {
            cmp.set('v.yes', true);
            cmp.find("overlayLib").notifyClose();
        } catch (err) {
            helper.handleErrors(err.message);
            console.error(err);
        }
    },

    handleNo: function (cmp, event, helper) {
        try {
            cmp.set('v.yes', false);
            cmp.find("overlayLib").notifyClose();
        } catch (err) {
            helper.handleErrors(err.message);
            console.error(err);
        }
    },

})