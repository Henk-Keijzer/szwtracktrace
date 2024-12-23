# szwtracktrace

Track & Trace app voor wedstrijden met historische zeilende bedrijfsvaartuigen

----------------------------------------------------------------------------------------------------

feature requests:

- veld bij shiptracks toevoegen, naast colorcode en shipname ook 'sleepwaarde' voor het berekenen
  van het wattage van roeisloepen, dit natuurlijk ook verwerken in de admin me pagina, get/index.php
  en de database (participans tabel), selectievakje om ipv de snelheid het wattage te tonen, maar
  dit wel in event.json optioneel te maken
- toegang tot testmodus dmv username password, met name voor toegang tot underscored events

optimalisaties:

- live en replay verder integreren en ook live door (replay)ticker aansturen

----------------------------------------------------------------------------------------------------
Version 3.3.1

- Feature: downarrow in appbar turned off when eventmenu is shown
- Feature: (eventInfo) Option to show full trails of selected participants

Version 3.3.0 released on October 15, 2024

- Bugfix: transition from pre-event to live gave some problems in case no positions were received yet

Version 3.2.9

- Optimization: optimize and correct participants ship/team names in pre-event

Version 3.2.8

- Feature: switch between team/shipname with default setting added
- Feature: added downarrow after eventtitle in appbar to indicate that there is a menu when clicking the eventtitle
- Bugfix & optimizations: displaydelay simplified, prevent jumping during live when changing settings

Version 3.2.7 released on July 9, 2024

- Fix: do not close menus when starting/stopping replay
- Optimization: minor cosmetic improvements and code optimizations
- Fix: move scalebar to the left if no centerwindmarker to show (not allowed or no wind data
  available)
- Fi: new version of flutter_map, causing no flickering on trails anymore

Version 3.2.6 released on June 24, 2024

- Feature: new field added for Teamname. Event option to enable teamnames and show teamname instead
  of shipname as default. Added a menu option to switch between team-shipname in case it is enabled
  for the event
- Optimization: removed some superfluous setStates

Version 3.2.5 released on June 10, 2024

- functional improvement: during live, introduced possibility of delayed display of ships, to enable
  smooth mevement towards the last posion received. This in combination with a (possibly) shorter
  prediction time.

Version 3.2.4 released on June 2, 2024

- improvement: turn off autofollow after manually zooming/moving the map, turn off autofollow when
  no ships are selected, and don't allow autofollow to be turned on when no ships are selected. Turn
  on autoFollow and autoZoom when user selects one or more ships.
- change: upgrade to flutter 3.22 with change in index.html for web
- bugfix: allow shipnames containing single quotes and ampersands

Version 3.2.3 released on April 30, 2024

- Internal optimizations (full screen button, widgets for mapTextLabels)
- Feature: link to windy.com in infoWindow van center wind arrow
- Enhancement: show start/finish polygons in route in testing mode
- Feature: added scalebar
- Bugfix: wind/route infowindow closed when windarrows/route turned off
- Bugfix: windmarkers were not updated immediately after mapchange
- Several cosmetic optimizations

Version 3.2.2 released on April 14, 2024
bugfix: mapchange fails when eventstatus is initial. solved.
bugfix: ui error causing problems when no shiptracks available at the start of an event. solved
feature/bugfix: shipInfoWindow remains on screen until explicitely cleared and it does not stop
replay or live. Image is not flickering anymore due to change in server php script (/get/index.php)
feature: double click on a ship-marker sets following that ship (only) and opens the shipmenu to
allow for additional ships to select (autofollow is set to true, autozoom is not changed)
feature: rightclick on the ship-marker opens the shipInfoWindow.
feature: click on the body of the ship's infowindow opens de shipInfoWindow
enhancement: fullscreen en fulllscreen_exit icons vervangen
enhancement: signalLossTime now eventinfo parameter

Version 3.2.1 - only released to web

Version 3.2.0 released on March 5, 2024
feature: Added a windarrow at the top-left of the screen, representing the weighted wind speed
and wind direction of the <nrStations> nearest Buienradar windstations at the center of the screen.
feature: Added the lostsignalindicator to the shipnames in the menu and added some explanation.
optimalization: Timing for replay now based on 16.666 ticker signal from the flutter framework (
replayTicker). Further optimizations in the moveTo routines, in particular wind and gpsBuoys.
buildXxxinfo routine also updated in line with moveTo routines. Labels no longer created using svg
strings, but using bordered text (required changing markercolors to flutter Color instead of svg hex
colors.
mod: moved loading the flutter_config file into a separate function (loadConfig()).
mod: included safeArea to stay away from stupid iPhone on-screen features (like microphones and
cameras)
mod: in line with start/timer for live and replay, now also start/live routines for pre-event
feature: (only for developers) added debugString

Version 3.1.9 released on February 14, 2024
feature: Added allowshowspeed option on a per event basis (event.json), default is true. If false,
it hides the checkbox in the mapmenu and does not show speeds next to the ships on the map (label,
tooltip and infowindow)
mod: Als kIsWeb server is '/' ipv volledige url. Heeft als mogelijkheid om de site vanuit
een andere URL door te linken, zonder CORS issues
feature: zoom+/- knoppen op de verticale buttonbar toegeoegd
mod: defaultconfig en defaulmaptileprovider opgenomen in aparte dart files (in lib)
mod: display update bij live hfupdte van 1 sec naar 200 ms

Version 3.1.8 released on January 13, 2024
bugfix: af en toe range error bij replay tijdens een live wedstrijd
feature: cancel buttons op alle menus
mod: stop replay van embedded bij overgang naar open in new tab
mod: variants for szw en sv
mod: Verticale buttonbar maakt meer ruimte voor de titel van het evenement
mod: ActionButtons voor autozoom en volgen vervangen door Switches
mod: autoZoom wordt uitgeschakels als de kiaart met de hand wordt bewogen
mod: maximale zoom level bij autoZoom op 17 ingesteld
mod: close knoppen in de menu's, menu's iets meer gecomprimeerd

Version 3.1.7 - released on December 25, 2023
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