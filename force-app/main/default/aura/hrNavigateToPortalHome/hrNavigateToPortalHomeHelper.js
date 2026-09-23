/* eslint-disable no-unused-expressions -- Aura helpers are a parenthesized object literal */
({
    getExperienceHomePath: function () {
        var pathname = window.location.pathname || "";
        var marker = "/s/";
        var markerIndex = pathname.indexOf(marker);
        if (markerIndex === -1) {
            return "/";
        }
        return pathname.substring(0, markerIndex + marker.length);
    }
});
