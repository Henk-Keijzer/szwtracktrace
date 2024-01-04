# szwtracktrace

Track & Trace app voor wedstrijden met historische zeilende bedrijfsvaartuigen

/*

Version 3.1.8
bugfix: af en toe range error bij replay tijdens een live wedstrijd
feature: cancel button op eventmenu
mod: stop replay van embedded bij overgang naar open in new tab
mod: variants for szw en sv
mod: Verticale buttonbar maakt meer ruimte voor de titel van het evenement
mod: ActionButtons voor autozoom en volgen vervangen door Switches
mod: autoZoom wordt uitgeschakels als de kiaart met de hand wordt bewogen
mod: maximale zoom level bij autoZoom op 17 ingesteld
mod: close knoppen in de menu's, menu's iets meer gecomprimeerd

Version 3.1.7 - released on December 26, 2023
Feature: ook speed toegevoegd aan web transfer info
Feature: appicon wordt nu van de server gehaald via een fetch (/get?req=appiconurl&event=<event>,
waarbij de event parameter optioneel mag zijn) in plaats van rechtstreeks (resulteerde in een 404
als het bestand voor een event niet bestond). Als de file onder het event niet bestaat wordt de url
de default uit de folder config gebruikt
Feature: de favicon voor de web app wordt uit de config folder gehaald (en niet uit root folder,
waar het bestand wordt overscheven bij een nieuwe release)
Feature: De dropdownmenu's in het evenementenmenu worden proactief geopend, zodat de gebruiker
alleen nog maar een selectie hoeft te klikken

Version 3.1.6 released op 12 december 2023
Feature: web transfer van maptypes en playtime info vanuit embedded page naar new tab page
(fullscreen knop)
Feature: flutter_config.json op server toegevoegd voor basic app info: text, colors en icons
Optimization: infowindow als marker toegevoegd aan de lijst met markers, waardoor flutter-map het
window verplaatst en we dat niet zelf hoeven te doen

Version 3.1.5 - released on November 23, 2023
Feature: upgraded to flutter_map V6.0.x
Feature: tiny quote added to shipname when in live position is older then 3 minutes.
Optimization: server definition based on web document.location.hostName
Maps: maptileproviders.json re-defined in service types WMS, WMTS (simple) and vector and tilelayers
defined accordingly
Note: vector tiles not yet working due to dependency issues with flutter_vector_map and Flutter_map

Version 3.1.4
Bugfix: add particpants later during the race at the right position based on colorcode, not at the
end
Feature: autoFollow false when starting a live event, true when starting an event in replay
Feature: position of autofollow and autozoom swapped
Bugfix: predicted position not during replay
Feature: don't close map menu when switching between overlays when overlay is off

Version 3.1.3
Feature: andere layout infowindow van de schepen, met coördinaten en tijd van ontvangst evt met
datum als de laatste ontvangst meer dan 24 uur geleden is (in plaats van xx minuten geleden)
Bugfix: scrollbar in menus shifted to the right to free the check and radio boxes
Feature: floatingbutton voor auto volgen toegevoegd
Feature: in live update predicted position since last received position

Version 3.1.2
bugfix: async exception in case the event in the URL query is not correct
corrected handling of URL query (?event=Event/Year/Day)
also if no eventDomain or a partial eventDomain is given, the eventmenu opens at startup, this
guides the new user
to select an event
bugfix: hide floating action button when menus are open

Version 3.1.1
bugfix: position of routepoint labels corrected
feature: in live, show position 1 minute back and update position every second one second forward
this makes the ships move continuously, provided that the trackers send positions frequently
eventinfo parameter hfupdate (bool)
feature: eventinfo parameter maxreplay in hours for continuous events (_TTTest and Olympia-Charters)
feature: eventinfo parameter boaticon for sailing, rowing or motorboat
feature: APP-const.dart const mobileAppAvailable boolean. If true, shows link to Apple/Google play
store
when web app is shown on mobile

Version 3.1.0
Bugfix: transition from live to replay at end of event

Version 3.0.9
new feature: replayLoop added

Version 3.0.5, 3.0.6, 3.0.7, 3.0.8
minor cosmetic changes and efficiency improvements
bugfix that links in map attributions can be clicked, even as attribution window was closed
minor cosmetic changes, code optimizations and error handling improved
bugfix: start at replay

Version 3.0.4
externe constanten voor varianten van de app voor Olympia en mogelijk andere gebruikers
maxReplay als externe constante toegevoegd. Hiermee wordt de replay beperkt tot maxReplay uren.
Dit ten behoeve van Olympia Charters, die slechts 1 heeel lang evenement hebben, waarbij de replay
de afgelopen 24 uur is
Verder wat bugfixes

Version 3.0.3
Cookie Consent toegevoegd
Voor web: url query ?event= toegevoegd (voor snelle link bijvoorbeeld via FB)

Version 3.0.2

- Added more maps and map overlays
- saved some more mapmenu stuff in shared preferences

Version 3.0.1

- minor cosmetic changes in the event menu

Version 3.0.0

- using the flutter_maps package instead of google maps
- new look and feel with semitransparent appbar
- working as web also
  */


