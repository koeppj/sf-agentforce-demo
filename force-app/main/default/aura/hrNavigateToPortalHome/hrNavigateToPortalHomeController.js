/* eslint-disable no-unused-expressions -- Aura controllers are a parenthesized object literal */
({
    invoke: function (component, event, helper) {
        var homePath = helper.getExperienceHomePath();
        var navEvent = $A.get("e.force:navigateToURL");
        if (navEvent) {
            navEvent.setParams({ url: homePath });
            navEvent.fire();
            return;
        }
        window.location.replace(homePath);
    }
});
