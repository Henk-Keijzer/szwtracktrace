//------------------------------------------------------------------------------------------------------------------------------------------
//
// Track & Trace app, oorspronkelijk voor zeilwedstrijden met historische zeilende bedrijfsvaartuigen,
// maar ook geschikt voor het volgen van deelnemers aan sloeproeiwedstrijden en het volgen van huurboten.
//
// © 2010 - 2024 Stichting Zeilvaart Warmond / Henk Keijzer
//
// Version history in README.md
//
//------------------------------------------------------------------------------------------------------------------------------------------
// library imports
//
import 'dart:async';
import 'dart:core';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

//
import 'package:auto_size_text/auto_size_text.dart';
import 'package:bordered_text/bordered_text.dart';
import 'package:collection/collection.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart' show Html;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' show document, window;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

//
//------------------------------------------------------------------------------------------------------------------------------------------
// app imports
import 'default_config.dart';
import 'default_maptileproviders.dart';

//
//------------------------------------------------------------------------------------------------------------------------------------------
// app-wide variables
//
// default server and package info
String debugString = '';
String server = 'https://tt.zeilvaartwarmond.nl/';
late PackageInfo packageInfo; // info is picked up at the beginning of mainCommon
//
// devicetype / platformtype
final bool kIsDesktop = !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);
final bool kIsWebOnIOS =
    kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS); // true if the user is running the web app on a mobile device
final bool kIsWebOnAndroid = kIsWeb && (defaultTargetPlatform == TargetPlatform.android);
//
String phoneId = "";
//
// Colors (menu colors are overruled by colors in config/flutter_config.json, but we define them here in case we cannot reach the server)
// setting it as hex means we don't need a null check in the code
Color menuAccentColor = const Color(0xffffffff); // pure white
Color menuBackgroundColor = const Color(0xffd32f2f); // Colors.red[700]
Color menuForegroundColor = const Color(0xb3ffffff); // Colors.white70;
//
const String hexBlack = '#000000'; // marker and label outline colors depending on background black or white
const String hexWhite = '#ffffff';
//
// the next color table is created using an online program to create 32 distinct colors, for example https://mokole.com/palette.html
const List shipMarkerColorTable = [
  0xFF696969,
  0xFF556b2f,
  0xFF8b4513,
  0xFF483d8b,
  0xFF008000,
  0xFF3cb371,
  0xFFb8860b,
  0xFF008b8b,
  0xFF4682b4,
  0xFF00008b,
  0xFF32cd32,
  0xFF8b008b,
  0xFFff0000,
  0xFFff8c00,
  0xFFffd700,
  0xFF00ff00,
  0xFF00fa9a,
  0xFF8a2be2,
  0xFFdc143c,
  0xFF00ffff,
  0xFF0000ff,
  0xFFadff2f,
  0xFFda70d6,
  0xFFff00ff,
  0xFF1e90ff,
  0xFFdb7093,
  0xFFadd8e6,
  0xFFff1493,
  0xFF7b68ee,
  0xFFffa07a,
  0xFFffe4b5,
  0xFFffc0cb
];
//
// vars for getting physical device info and the phoneId
late MediaQueryData queryData; // needed for getting the screen width and height
double screenWidth = 0;
double screenHeight = 0;
double menuOffset = 0; // used to calculate the offset of the menutext from the top of the screen
//
// variable and constants for the flutter_map
final MapController mapController = MapController();
CacheStore cacheStore = FileCacheStore('');
const LatLng initialMapPosition = LatLng(52.5, 5.0);
const double initialMapZoom = 9;
//
// vars for the selection of the event
late SharedPreferences prefs; // local data storage
Map<String, dynamic> dirList = {}; // see get-dirlist.php on the server
List<String> eventNameList = [];
List<String> eventYearList = [];
List<String> eventDayList = [];
Map<String, dynamic> eventInfo = {}; // see get-eventinfo.php on the server
String eventDomain = '';
String eventId = '';
String eventName = 'Kies een evenement';
String eventYear = '';
String eventDay = '';
//
// eventinfo (related) variables
// appIcon is located in the event folder data/domain/appicon.png or in config/, url is retreived by get?req=appiconurl
String appIconUrl = '';
int eventStart = 0; // evenInfo['eventstartstamp']
int eventEnd = 0; // eventInfo['eventendstamp']
int sliderEnd = 0; // end of the time slider, during live it is the current time, during replay it is eventend
int maxReplay = 0; // eventInfo['maxreplay'] in hours
// sets eventbegin xx hours before current time to limit the replay for continuous events (Olympia-charters, _TTTEST)
bool allowShowSpeed = true; // eventInfo['allowshowspeed']
bool hfUpdate = true; // eventInfo['hfupdate']. If 'true', positions are predicted every hfUpdateInterval ms during live
bool showTeam = false; // show team instead of shipname
int displayDelay = 30; // eventInfo['dispaydelay'], seconds to wait for displaying the ships positions
int predictTime = 30; // eventInfo['predicttime'], seconds to predict postions after the the last position received
const int hfUpdateInterval = 100; // in ms, use these values: 100, 200, 250, 500 or 1000 (i.e. 1000/x preferably be an int)
// don't go beyond 1000 ms, otherwise the timer at the bottom skips values
bool allowShowWind = false; // eventInfo['buienradar'] If false, never show wind
int trailsUpdateInterval = 30; // eventInfo['trailsupdateinterval'], in seconds between two subsequent get-trails requests from the db
int signalLostTime = 180; // eventInfo['signallosttime'] in seconds
String signalLostTimeText = ' 1 minuut';
int eventTrailLength = 30; // eventInfo['traillength'] in minutes
int actualTrailLength = 30;
String socialMediaUrl = ''; // eventInfo['mediaframe']

//
enum EventStatus { initial, preEvent, live, replay }

EventStatus eventStatus = EventStatus.initial;
//
// vars for the tracks, route and participants
Map<String, dynamic> replayTracks = {}; // see get-replay.php on the server
Map<String, dynamic> liveTrails = {}; // see get-trails.php on the server
Map<String, dynamic> route = {}; // geoJSON structure with the route
//List<dynamic> participants = []; // list of colorcodes, shipnames and teamnames
//
// extract from the live/replaytracks above to make addressing the info a bit simpler
List<String> shipList = []; // list with ship names
List<String> teamList = []; // list with team names
List<String> shipLostSignalIndicators = []; // either "" or "'"
List<Color> shipColors = []; // corresponding list of ship colors used in the participantsmenu
List<String> shipColorsSvg = []; //same list but as an svg string used as markercolor
String shipSvgPath = '10,1 11,1 14,4 14,18 13,19 8,19 7,18 7,4'; // outline of the ship, overwritten by config['icons']['boatSVGPath']
//
// lists for markers and polylines, maintained in moveShipsTo, updateGpsBuoys and moveWindTo
List<Marker> shipMarkerList = [];
List<Marker> shipLabelList = [];
List<Polyline> shipTrailList = [];
List<Marker> gpsBuoyMarkerList = [];
List<Marker> gpsBuoyLabelList = [];
List<Marker> windMarkerList = [];
List<Marker> routeMarkerList = [];
List<Marker> routeLabelList = [];
List<Polyline> routeLineList = [];
List<Polygon> routePolygons = [];
List<Marker> infoWindowMarkerList = []; // although there is max 1 infowindow, we have a list to make it easy to add it to the other markers
String infoWindowId = '';
const nrWindStationsForCenterWindCalculation = 3; // should we make this a flutter_config or eventInfo constant???
//
// variables used for following ships and zooming
Map<String, bool> following = {}; // list of shipnames to be followed
bool followAll = true;
bool autoZoom = true;
bool autoFollow = true;
//
// vars and constants for the movement of ships and wind markers in time
const int speedIndexInitialValue = 4;
int speedIndex = speedIndexInitialValue; // index in the following table en position of the speed slider, default = 3 min/sec
const List<int> speedTable = [0, 1, 10, 30, 60, 180, 300, 900, 1800, 3600];
const List speedTextTable = [
  "gestopt",
  "1 sec/sec",
  "10 sec/sec",
  "30 sec/sec",
  "1 min/sec",
  "3 min/sec",
  "5 min/sec",
  "15 min/sec",
  "30 min/sec",
  "1 uur/sec"
];
List<int> shipTimeIndex = []; // for each ship the time position in its list of stamps
List<int> gpsBuoyTimeIndex = []; // for each gps buoy the time position in its list of stamps
List<int> windTimeIndex = []; // for each weather station the time position in the list of stamps
//
// timers, ticker and live/replay related vars
late Timer preEventTimer;
late Timer liveTimer;
late Ticker replayTicker;
int liveSecondsTimer = 60;
int currentReplayTime = 0;
bool replayRunning = false;
bool replayPause = false;
bool replayLoop = false;
//
// UI messages in the EventSelection menu
String selectionMessage = '';
String eventTitle = "Kies een evenement";
//
// what menus and other items are we to show on the screen?
bool showMenuButtonBar = true;
bool showEventMenu = false;
bool showMapMenu = false;
bool showShipMenu = false;
bool showPreEventParticipants = false;
bool showInfoPage = false;
bool showShipInfo = false;
bool showAttribution = false;
bool showProgress = false;
bool cookieConsentGiven = false;
bool fullScreen = false;
//
String infoPageHTML = ''; // HTML text for the info page from {server}/config/app-info-page.html
//
bool testing = false; // double tap the logo of the app (appicon) to set to true.
//                    // Will cause the underscored events to be in the dirList
//
// map related vars
// initial baseMapTileProviders and some vars are imported from default_maptileproviders.dart
Map<String, dynamic> baseMapTileProviders = {};
Map<String, dynamic> overlayTileProviders = {};
String selectedOverlayType = '';
bool mapOverlay = false;
Map<String, dynamic> labelTileProviders = {};
String labelOverlayType = '';
//
// default values for some booleans, selectable from the mapmenu
bool showWindMarkers = false;
bool showRoute = true;
bool showRouteLabels = false;
bool showShipLabels = true;
bool showShipSpeeds = false;
//
// vars for the shipinfo window and it's position on the screen
String shipInfoHTML = ''; // HTML from {server}/get?req=shipinfo&event=...&ship=...
Offset shipInfoPosition = const Offset(0, 0);
Offset shipInfoPositionAtDragStart = const Offset(0, 0);
//
// used to create/retrieve query parameterd when we press fullscreen on an <iframe>'d web page
String queryPlayString = '::';
//
// Global Keys for programmatically opening the dropdown lists in the eventMenu
final GlobalKey dropEventKey = GlobalKey();
final GlobalKey dropYearKey = GlobalKey();
final GlobalKey dropDayKey = GlobalKey();
//
DateFormat dtFormat = DateFormat("d MMM y, HH:mm", 'nl');
DateFormat dtsFormat = DateFormat("d MMM y, HH:mm:ss", 'nl');

//
//------------------------------------------------------------------------------
//
// The mainCommon function is called from main.dart with the serverUrl as parameter
// Here we initialize the global app vars with data from the server
// After that we start the flutter framework by calling runApp with the MyApp StatefulWidget class as parameter
//
void mainCommon({required String serverUrl}) async {
  WidgetsFlutterBinding.ensureInitialized();
  packageInfo = await PackageInfo.fromPlatform(); // who and where are we
  prefs = await SharedPreferences.getInstance(); // get access to local storage
  await initializeDateFormatting('nl'); // initialize date formatting
  //
  // ----- SERVER
  server = (kIsWeb) ? '/' : serverUrl; // defined in main.dart
  // Using a simple '/' on web allows for redirection, for eaxample sv.zeilvaartwarmond.nl -> replay.sportvolgen.nl
  // for other platforms we need the full server url
  //
  // ----- APP VERSION and cookieConsent
  // See if we are running a new version and if so, clear local storage and save the new version number
  // We dont want the user to give consent each time we issue a new version, so keep the cookieConsent
  String oldAppVersion = prefs.getString('appversion') ?? '';
  cookieConsentGiven = prefs.getBool('cookieconsent') ?? false;
  if (oldAppVersion != packageInfo.buildNumber) {
    await prefs.clear(); // clear all data (and wait for it...)
    prefs.setString('appversion', packageInfo.buildNumber); // and set the new appversion
  }
  prefs.setBool('cookieconsent', cookieConsentGiven);
  // overrule cookieConsent in case we are running embedded in an iframe of another website
  if (kIsWeb && (document.referrer != '')) cookieConsentGiven = true;
  //
  // ----- PHONE (DEVICE) ID
  // See if we already have a phone id, if not, create one and save it in local storage
  phoneId = prefs.getString('phoneid') ?? const Uuid().v1();
  prefs.setString('phoneid', phoneId); // and save it (even if it did not change)
  // add a platform prefix and the appversion in front of the phoneid
  // this phoneId is used in all communication with the server for statistical purposes
  String prefix = kIsWeb
      ? "GD"
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'A',
          TargetPlatform.iOS => 'I',
          TargetPlatform.windows => 'W',
          TargetPlatform.macOS => 'M',
          TargetPlatform.linux => 'L',
          TargetPlatform.fuchsia => 'U',
        };
  if (kIsWebOnAndroid) prefix = 'GA';
  if (kIsWebOnIOS) prefix = 'GI';
  phoneId = '$prefix${packageInfo.buildNumber}-$phoneId'; // use the saved phoneId with a platform/buildnumber prefix
  //
  // ----- CONFIG
  // Get the flutter app config items from the flutter_config.json file on the server /config folder
  // The contents is merged with the default config in default_config.dart (but this only works for two levels!!! and only for String keys
  // and String values). The reason for merging is that the keys the app expects may not yet be in the file on the server
  http.Response response = await http.get(Uri.parse('${server}get/?req=config&dev=$phoneId'));
  Map<String, dynamic> newConfig = (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : config;
  for (final String mainEntry in newConfig.keys) {
    for (final subEntry in newConfig[mainEntry].entries) {
      config[mainEntry].addAll({subEntry.key.toString(): subEntry.value.toString()});
    }
  }
  // decode some color values based on the info in the config file as they are used very often
  menuAccentColor = Color(int.parse(config['colors']['menuAccentColor'], radix: 16));
  menuBackgroundColor = Color(int.parse(config['colors']['menuBackgroundColor'], radix: 16));
  menuForegroundColor = Color(int.parse(config['colors']['menuForegroundColor'], radix: 16));
  //
  shipSvgPath = config['icons']['boatSVGPath'];
  //
  // ----- APPICON URL
  response = await http.get(Uri.parse('${server}get/?req=appiconurl&dev=$phoneId'));
  // the response contains the full servername, but we only want the relative path, remove the server name using this trick
  // (replace the first slash after character position 8 with a vertical bar, split the string at the vertical bar and use the last part)
  // if we did not receive an app icon url, we point to the server location with the defaultAppIcon (assuming there is a webapp there)
  appIconUrl =
      (response.statusCode == 200) ? response.body.replaceFirst('/', '|', 8).split('|').last : 'assets/assets/images/defaultAppIcon.png';
  //
  // ----- INFOPAGE
  // get the info page contents, and add some package and version info at the bottom
  response = await http.get(Uri.parse('${server}get/?req=appinfopage&dev=$phoneId'));
  infoPageHTML = (response.statusCode == 200) ? response.body : '';
  infoPageHTML += '<br><br>appname: ${packageInfo.appName}, version ${packageInfo.version}<br>'
      'package: ${packageInfo.packageName}<br>server: $server</body></html>';
  //
  // ----- MAPS
  // set up the cacheStore for caching maptiles for everything except web
  if (!kIsWeb) {
    var dir = await getTemporaryDirectory();
    cacheStore = FileCacheStore('${dir.path}${Platform.pathSeparator}MapTiles');
  }
  // get the complete list of map tile providers from the server, overwriting the default mapdata in default_maptileproviders.dart
  response = await http.get(Uri.parse('${server}get/?req=maptileproviders&dev=$phoneId'));
  Map<String, dynamic> mapdata = (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : defaultMapTileProviders;
  baseMapTileProviders = mapdata['basemaps'] ?? {};
  overlayTileProviders = mapdata['overlays'] ?? {};
  labelTileProviders = mapdata['labels'] ?? {};
  // ----- BASEMAP
  // Get the selectedmaptype from local storage (from a previous session) or the querystring
  selectedMapType = prefs.getString('maptype') ?? baseMapTileProviders.keys.toList().first;
  // are we overruled by a query parameter?
  selectedMapType = (kIsWeb && Uri.base.queryParameters.containsKey('map'))
      ? Uri.base.queryParameters['map'].toString()
      : selectedMapType; //get parameter with attribute "map"
  // see if the map from the previous session or the query string is in our list of maps, if not, set maptype to first maptype
  selectedMapType =
      (!baseMapTileProviders.keys.toList().contains(selectedMapType)) ? baseMapTileProviders.keys.toList().first : selectedMapType;
  // save the base maptype for next time and set the marker and labelbackgroudcolors, based on the info in the map record
  prefs.setString('maptype', selectedMapType);
  bgColor = baseMapTileProviders[selectedMapType]['bgColor'];
  markerBackgroundColor = (bgColor == hexBlack) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  labelBackgroundColor = (bgColor == hexBlack) ? const Color(0xBfFFFFFF) : const Color(0xFF000000);
  // ----- MAP OVERLAY
  // now the same for the map overlays and the selected map overlaytype
  mapOverlay = prefs.getBool('mapoverlay') ?? false;
  selectedOverlayType = prefs.getString('overlaytype') ?? '';
  if (kIsWeb && Uri.base.queryParameters.containsKey('overlay')) {
    var a = Uri.base.queryParameters['overlay'].toString().split(':');
    mapOverlay = (a[0] == 'true') ? true : false;
    selectedOverlayType = a[1];
  }
  mapOverlay = overlayTileProviders.isNotEmpty ? mapOverlay : false;
  if (overlayTileProviders.isEmpty) {
    // are there any overlayTileProviders defined?
    selectedOverlayType = ''; // no
  } else {
    // does the list contain the overlaymaptype from the previous session
    selectedOverlayType = (overlayTileProviders.keys.toList().contains(selectedOverlayType))
        ? selectedOverlayType
        : overlayTileProviders.keys.toList().first; // if not, use first
  }
  prefs.setBool('mapoverlay', mapOverlay);
  prefs.setString('overlaytype', selectedOverlayType);
  //
  // ----- EVENT DOMAIN
  // Get the event domain from a previous session or from the query string, if no event domain found, set default to an empty string
  eventDomain = prefs.getString('domain') ?? "";
  if (kIsWeb && Uri.base.queryParameters.containsKey('event')) {
    eventDomain = Uri.base.queryParameters['event'].toString(); //get parameter with attribute "event"
  }
  // ----- AUTOSTART PLAY
  // this occurs after fullscreen on a web-embedded version of the app.
  if (kIsWeb && Uri.base.queryParameters.containsKey('play')) {
    queryPlayString = '${Uri.base.queryParameters['play']}::'; //get parameter with attribute "play (and add some separators)"
    // consists of (up to) 3 values, separated by a ':' namely
    // a[0] true/false, is the event playing yes/no
    // a[1] the currentreplaytime, and
    // a[2] the replayspeed
    // adding two colons ensures a[1|2] are never null
    // handling this info will be done in startLive or startReplay
  }
  //
  // ----- WINDMARKERS, ROUTE, ROUTELABELS, SHIPLABELS, and SHIPSPEEDS
  // get/set this info from shared preference (set default if value was not present in prefs)
  showWindMarkers = prefs.getBool('windmarkers') ?? showWindMarkers;
  prefs.setBool('windmarkers', showWindMarkers);
  //
  showRoute = prefs.getBool('showroute') ?? showRoute;
  prefs.setBool('showroute', showRoute);
  //
  showRouteLabels = prefs.getBool('routelabels') ?? showRouteLabels;
  prefs.setBool('routelabels', showRouteLabels);
  //
  showShipLabels = prefs.getBool('shiplabels') ?? showShipLabels;
  prefs.setBool('shiplabels', showShipLabels);
  //
  showShipSpeeds = prefs.getBool('shipspeeds') ?? showShipSpeeds;
  if (!allowShowSpeed) showShipSpeeds = false;
  prefs.setBool('shipspeeds', showShipSpeeds);

  //
  // start the flutter framework
  //
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // the StatefulWidget needs a State object (which is the actual program). Create it here.
  @override
  State<MyApp> createState() => MyAppState();
}

//------------------------------------------------------------------------------------------------------------------------------------------
// The main program (= the "state" belonging to MyApp)
//
// The methods dispose() and didChangeAppLifecycleState(..) are called by the flutter framework on exit or when we pause or resume
// The flutter framework calls initState() at the start of the app
// After initState() the build(..) method is called repetitatively each time the ui needs to be rebuild
//
class MyAppState extends State<MyApp> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  //
  // first the three routines that are called by the flutter framework when the app starts, changes its lifecycle or when it exits

  @override
  initState() {
    super.initState(); // call our ancestors initState routine, and than our own initState code
    WidgetsBinding.instance.addObserver(this); // needed to get the MediaQuery for screen size working
    replayTicker = createTicker((elapsed) => replayTickerRoutine(elapsed));
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        setState(() {
          if (eventStatus == EventStatus.preEvent) {
            preEventTimer = Timer.periodic(const Duration(seconds: 5), (_) => preEventTimerRoutine());
          }
          if (eventStatus == EventStatus.live) {
            liveSecondsTimer = 1;
            liveTimer = Timer.periodic(const Duration(milliseconds: hfUpdateInterval), (_) => liveTimerRoutine());
          }
          if (replayRunning && !replayTicker.isTicking) replayTicker.start();
        });
      case AppLifecycleState.inactive || AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached:
        setState(() {
          if (eventStatus == EventStatus.preEvent) preEventTimer.cancel();
          if (eventStatus == EventStatus.live) liveTimer.cancel();
          if (replayTicker.isTicking) replayTicker.stop();
        });
    }
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    replayTicker.dispose();
    super.dispose();
  }

  //----------------------------------------------------------------------------
  //
  // After initState, the flutter framework calls build(BuildContext context), which is the flutter UI
  // The value 'context' is a value the framework gives us, and is used to identify the environment in wich we are running
  // The method build is also called each time we call setState((){})
  //
  // The UI is relatively simple, because our App has only one page, so no navigation to other pages
  // The UI is rebuilt each time the state of the info to be displayed needs to be updated to the screen.
  // This is not done automatically but only after calling setState. The info to be displayed is in
  // variables manipulated by the routines of the app
  //
  // The main element of the UI is the flutterMap. The flutterMap has a callback onMapReady. We use that to continue the initialization by
  // asking the user what event he wants to see (or if we already have an event, continue to start-up that event)
  //
  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    // first define the appbar as a seperate widget, so that we can use it's height when positioning the menu's below the appbar
    AppBar myAppBar = uiAppBar();
    menuOffset = MediaQuery.of(context).viewPadding.top + myAppBar.preferredSize.height;
    // menuOffset is the heigth of the appBar + the notification area above the appbar on mobile devices
    // we need to calculate this because in the Scaffold below, we extend the map behind the appBar and the notification area (viewpadding
    // .top)
    // On Windows and web the height of the notification area = 0
    // Now return the UI as a MaterialApp with title, theme and a (single) homepage (with a SafeArea and a Scaffold)
    return MaterialApp(
        debugShowCheckedModeBanner: testing,
        title: eventTitle,
        theme: ThemeData(
          useMaterial3: true,
          canvasColor: menuBackgroundColor,
          dividerColor: menuForegroundColor,
          textTheme: TextTheme(bodyMedium: TextStyle(color: menuForegroundColor, fontSize: 15)),
        ),
        home: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: true,
            child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: myAppBar,
                body: Stack(
                  children: [
                    uiFlutterMap(),
                    if (eventStatus == EventStatus.live || eventStatus == EventStatus.replay) uiSliderArea(),
                    uiAttribution(),
                    if (showMenuButtonBar) uiMenuButtonBar().animate().slide(),
                    if (showEventMenu) uiEventMenu().animate().slide(),
                    if (showInfoPage) uiInfoPage().animate().slide(),
                    if (showMapMenu) uiMapMenu().animate().slide(),
                    if (showShipMenu) uiParticipantsMenu().animate().slide(),
                    if (showPreEventParticipants) uiPreEventParticipantsMenu().animate().slide(),
                    if (showShipInfo) uiShipInfo().animate().slide(),
                    if (!cookieConsentGiven) uiCookieConsent(),
                    if (showProgress) uiProgressIndicator(),
                  ],
                ))));
  }

  //----------------------------------------------------------------------------
  //
  // the UI elements listed above. The names speak for themselves (I hope)
  //
  AppBar uiAppBar() {
    return AppBar(
        backgroundColor: menuBackgroundColor
            .withOpacity((showShipMenu || showInfoPage || showEventMenu || showMapMenu || showPreEventParticipants) ? 1 : 0.5),
        foregroundColor: menuForegroundColor,
        elevation: 0,
        toolbarHeight: 40,
        leading: Container(
            padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
            child: InkWell(
                // appIcon of the T&T organization. single tap opens event menu, double tap enters testing mode (without redrawing the ui)
                onTap: () => setState(() {
                      showShipMenu = showMapMenu = showInfoPage = showAttribution = showPreEventParticipants = false;
                      showEventMenu = !showEventMenu;
                    }),
                onDoubleTap: () {
                  testing = !testing;
                  setUnsetTestingActions();
                },
                child: Tooltip(message: 'evenementmenu', child: Image.network('$server$appIconUrl')))),
        title: InkWell(
          onTap: () => setState(() {
            showShipMenu = showMapMenu = showInfoPage = showAttribution = showPreEventParticipants = false;
            showEventMenu = !showEventMenu;
          }),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Tooltip(message: 'evenementmenu', child: Text(eventTitle)),
            Icon(Icons.arrow_drop_down, size: 40, color: menuForegroundColor)
          ]),
        ),
        actions: [
          // button for fullscreen on web and desktop
          if (kIsWeb || kIsDesktop)
            IconButton(
              icon: fullScreen
                  ? Icon(Icons.close_fullscreen, color: menuForegroundColor, size: 18)
                  : Icon(Icons.open_in_full, color: menuForegroundColor, size: 18),
              tooltip: fullScreen ? 'exit fullscreen' : (kIsWeb && (document.referrer == '') ? 'fullscreen' : 'open in een nieuw tabblad'),
              onPressed: () => setState(() {
                fullScreen = !fullScreen;
                if (kIsWeb && (document.referrer != '')) {
                  // document.referrer != '' means we are runnig in an iframe
                  launchUrl(Uri.parse('https://${window.location.hostname}?event=$eventDomain&map=$selectedMapType'
                      '&overlay=${mapOverlay ? 'true' : 'false'}:$selectedOverlayType'
                      '&play=${replayRunning ? 'true' : 'false'}:${currentReplayTime == sliderEnd ? '0' : currentReplayTime.toString()}'
                      ':$speedIndex'));
                  if (replayRunning) startStopRunning();
                } else {
                  FullScreenWindow.setFullScreen(fullScreen);
                  if ((eventStatus == EventStatus.live || eventStatus == EventStatus.replay) && showWindMarkers && allowShowWind) {
                    // give the ui some time to settle and redraw the wind markers (especially the centerwind arrow and it's infowindow)
                    Timer(const Duration(milliseconds: 500), () => setState(() => rotateWindTo(currentReplayTime)));
                  }
                }
              }),
            ),
          // button to open/close the AppBar extension: uiMenuButtonBar
          IconButton(
            icon: showMenuButtonBar ? const Icon(Icons.expand_less) : const Icon(Icons.more_vert),
            onPressed: () => setState(() {
              showMenuButtonBar = !showMenuButtonBar;
              if (!showMenuButtonBar) showInfoPage = showMapMenu = showShipMenu = showPreEventParticipants = false;
            }),
          ),
        ]);
  }

  //
  // The vertical menu button bar (AppBar extention)
  //
  Row uiMenuButtonBar() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Column(children: [
        SizedBox(height: menuOffset),
        Container(
            width: 40,
            color: menuBackgroundColor
                .withOpacity((showShipMenu || showInfoPage || showEventMenu || showMapMenu || showPreEventParticipants) ? 1 : 0.5),
            child: Column(children: [
              IconButton(
                // button for the shipList
                icon: Icon(boatIcons[config['icons']['boatIcon']],
                    color: (showShipMenu || showPreEventParticipants) ? menuAccentColor : menuForegroundColor),
                onPressed: () => setState(() {
                  if (eventStatus != EventStatus.preEvent && shipList.isNotEmpty) {
                    showEventMenu = showMapMenu = showInfoPage = showAttribution = showPreEventParticipants = false;
                    showShipMenu = !showShipMenu;
                  } else {
                    showEventMenu = showMapMenu = showInfoPage = showAttribution = showShipMenu = false;
                    showPreEventParticipants = !showPreEventParticipants;
                  }
                }),
              ),
              IconButton(
                // button for the mapMenu
                icon: Icon(Icons.map, color: showMapMenu ? menuAccentColor : menuForegroundColor),
                onPressed: () => setState(() {
                  showEventMenu = showShipMenu = showInfoPage = showAttribution = showPreEventParticipants = false;
                  showMapMenu = !showMapMenu;
                }),
              ),
              IconButton(
                // button for the infoPage
                icon: Icon(Icons.info, color: showInfoPage ? menuAccentColor : menuForegroundColor),
                onPressed: () => setState(() {
                  showEventMenu = showShipMenu = showMapMenu = showAttribution = showPreEventParticipants = false;
                  showInfoPage = !showInfoPage;
                }),
              ),
              if ((config['options']['windy'] == "true") && (eventStatus == EventStatus.live || eventStatus == EventStatus.preEvent))
                IconButton(
                    //optional button for windy.com
                    icon: Tooltip(
                        message: 'open windy.com\nin een nieuw venster',
                        child: Image.asset('assets/images/windy-logo-full.png', width: 25, height: 25)),
                    onPressed: () {
                      var latlng = mapController.camera.center;
                      var zoom = mapController.camera.zoom;
                      launchUrl(Uri.parse('https://embed.windy.com/embed2.html?lat=${latlng.latitude}&lon=${latlng.longitude}'
                          '&detailLat=${latlng.latitude}&detailLon=${latlng.longitude}&width=$screenWidth&height=$screenHeight'
                          '&zoom=$zoom&level=surface&overlay=wind&product=ecmwf&menu=&message=true&marker=&calendar=now&pressure='
                          '&type=map&location=coordinates&detail=true&metricWind=bft&metricTemp=%C2%B0C&radarRange=-1'));
                    }),
              const Divider(),
              // and a + and - button for zoom-in and -out
              IconButton(
                  icon: Icon(Icons.add_box, color: menuForegroundColor),
                  onPressed: () => setState(() {
                        mapController.move(mapController.camera.center, mapController.camera.zoom + 0.5);
                        autoZoom = false;
                        if ((eventStatus == EventStatus.live || eventStatus == EventStatus.replay) && showWindMarkers && allowShowWind) {
                          rotateWindTo(currentReplayTime);
                        }
                      })),
              if (testing) Text(mapController.camera.zoom.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
              IconButton(
                  icon: Icon(Icons.indeterminate_check_box, color: menuForegroundColor),
                  onPressed: () => setState(() {
                        mapController.move(mapController.camera.center, mapController.camera.zoom - 0.5);
                        autoZoom = false;
                        if ((eventStatus == EventStatus.live || eventStatus == EventStatus.replay) && showWindMarkers && allowShowWind) {
                          rotateWindTo(currentReplayTime);
                        }
                      })),
            ]))
      ])
    ]);
  }

  //
  // the map
  //
  FlutterMap uiFlutterMap() {
    return FlutterMap(
        mapController: mapController,
        options: MapOptions(
            onMapReady: () => onMapCreated(),
            // when the map is ready, the onMapCreated routine starts the rest of the initialization
            initialCenter: initialMapPosition,
            initialZoom: initialMapZoom,
            maxZoom: baseMapTileProviders[selectedMapType]['maxZoom'],
            backgroundColor: Colors.blueGrey,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onPositionChanged: (_, gesture) {
              // only do this when the map position or zoom changed due to human interaction (gesture == true)
              if (gesture) {
                setState(() {
                  // stop autozoom and autofollow, close all menu's and update wind markers (in order to update the "center wind marker")
                  autoFollow = showEventMenu = showInfoPage = showMapMenu = showShipMenu = false;
                  if ((eventStatus == EventStatus.live || eventStatus == EventStatus.replay) && showWindMarkers && allowShowWind) {
                    rotateWindTo(currentReplayTime);
                  }
                });
              }
            },
            onTap: (_, __) => setState(() {
                  // on tapping the map: close all popups and menu's
                  infoWindowId = '';
                  infoWindowMarkerList = [];
                  showEventMenu = showMapMenu = showShipMenu = showInfoPage = showAttribution = false;
                })),
        children: [
          // seven children: the base map, the optional labeloverlay for base (satellite) maps,
          // the (optional) overlay map, the scale bar, the route polylines and polygons, and all markers/textlabels
          //
          // 1. the selected base map layer with three options, WMS, WMTS or vector (once available for web)
          switch (baseMapTileProviders[selectedMapType]['service']) {
            "WMS" => TileLayer(
                wmsOptions: WMSTileLayerOptions(
                  baseUrl: baseMapTileProviders[selectedMapType]['wmsbaseURL'],
                  layers: baseMapTileProviders[selectedMapType]['wmslayers'].cast<String>(),
                ),
                tileProvider: CachedTileProvider(store: cacheStore),
                retinaMode: RetinaMode.isHighDensity(context),
                tileDisplay: const TileDisplay.instantaneous(),
                userAgentPackageName: packageInfo.packageName,
              ),
            "WMTS" => TileLayer(
                urlTemplate: baseMapTileProviders[selectedMapType]['URL'],
                subdomains: List<String>.from(baseMapTileProviders[selectedMapType]['subDomains']),
                tileProvider: CachedTileProvider(store: cacheStore),
                retinaMode: baseMapTileProviders[selectedMapType]['URL'].contains('{r}') ? RetinaMode.isHighDensity(context) : false,
                tileDisplay: const TileDisplay.instantaneous(),
                userAgentPackageName: packageInfo.packageName,
              ),
            _ => const SizedBox.shrink()
          },
          // 2. the tile layer for the streetlabels (only when the selected basemap indicates a labels layer
          if (baseMapTileProviders[selectedMapType]['labels'] != '')
            switch (labelTileProviders[baseMapTileProviders[selectedMapType]['labels']]['service']) {
              'WMS' => TileLayer(
                  wmsOptions: WMSTileLayerOptions(
                    baseUrl: labelTileProviders[baseMapTileProviders[selectedMapType]['labels']]['wmsbaseURL'],
                    layers: labelTileProviders[baseMapTileProviders[selectedMapType]['labels']]['wmslayers'].cast<String>(),
                  ),
                  tileProvider: CachedTileProvider(store: cacheStore),
                  retinaMode: RetinaMode.isHighDensity(context),
                  tileDisplay: const TileDisplay.instantaneous(),
                  userAgentPackageName: packageInfo.packageName,
                ),
              'WMTS' => TileLayer(
                  urlTemplate: labelTileProviders[baseMapTileProviders[selectedMapType]['labels']]['URL'],
                  subdomains: List<String>.from(labelTileProviders[baseMapTileProviders[selectedMapType]['labels']]['subDomains']),
                  tileProvider: CachedTileProvider(store: cacheStore),
                  retinaMode: labelTileProviders[baseMapTileProviders[selectedMapType]['labels']]['URL'].contains('{r}')
                      ? RetinaMode.isHighDensity(context)
                      : false,
                  tileDisplay: const TileDisplay.instantaneous(),
                  userAgentPackageName: packageInfo.packageName,
                ),
              _ => const SizedBox.shrink()
            },
          // 3. the tilelayer for the selecatble overlays, showing waterways, etc
          if (mapOverlay && overlayTileProviders.isNotEmpty)
            switch (overlayTileProviders[selectedOverlayType]['service']) {
              'WMS' => TileLayer(
                  wmsOptions: WMSTileLayerOptions(
                    baseUrl: overlayTileProviders[selectedOverlayType]['wmsbaseURL'],
                    layers: overlayTileProviders[selectedOverlayType]['wmslayers'].cast<String>(),
                  ),
                  tileProvider: CachedTileProvider(store: cacheStore),
                  retinaMode: false,
                  //RetinaMode.isHighDensity(context),
                  tileDisplay: const TileDisplay.instantaneous(),
                  userAgentPackageName: packageInfo.packageName,
                ),
              'WMTS' => TileLayer(
                  urlTemplate: overlayTileProviders[selectedOverlayType]['URL'],
                  subdomains: List<String>.from(overlayTileProviders[selectedOverlayType]['subDomains']),
                  tileProvider: CachedTileProvider(store: cacheStore),
                  retinaMode: overlayTileProviders[selectedOverlayType]['URL'].contains('{r}') ? RetinaMode.isHighDensity(context) : false,
                  tileDisplay: const TileDisplay.instantaneous(),
                  userAgentPackageName: packageInfo.packageName,
                ),
              _ => const SizedBox.shrink()
            },
          Scalebar(
              alignment: Alignment.topLeft,
              padding: EdgeInsets.fromLTRB(
                  (showWindMarkers && replayTracks['windtracks'] != null && replayTracks['windtracks'].length > 0) ? 60 : 15,
                  menuOffset + 15,
                  0,
                  0),
              lineColor: markerBackgroundColor,
              textStyle: TextStyle(color: markerBackgroundColor),
              strokeWidth: 1),
          //
          // three more layers: the 5. lines of the route and trails, 6. the fences and 7. the markers
          PolylineLayer(polylines: routeLineList + shipTrailList),
          if (testing) PolygonLayer(polygons: routePolygons),
          MarkerLayer(
              markers: routeLabelList + // in this order from bottom to top
                  gpsBuoyLabelList +
                  routeMarkerList +
                  gpsBuoyMarkerList +
                  windMarkerList +
                  shipLabelList +
                  shipMarkerList +
                  infoWindowMarkerList),
        ]);
  }

  //
  // on top of the map the slider area with the two sliders, the actionbuttons and the speed, date/time and live update timers
  //
  Column uiSliderArea() {
    Color textColor = (bgColor == hexBlack) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
      // a column with 3 children:
      // 1. Row with timeslider and actionbuttons,
      // 2. Container with the start/stop button and the timeslider,
      // 3. a Row with texts
      //
      // first 1. a row with the speedslider, a spacer and the actionbuttons
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const SizedBox(width: 8),
        if (eventStatus == EventStatus.replay || currentReplayTime != sliderEnd) uiSpeedSlider(),
        const Spacer(),
        uiZoomFollowButtons(),
        const SizedBox(width: 4),
      ]),
      // under this row 2. the start/stop button and the timeslider
      uiTimeSlider(),
      // 3. a container showing the selected speed, the currentreplaytime and the livetimer
      Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 50, 15),
          color: Colors.transparent, // set a color so that the area does not allow click-through to the map
          child: Row(
              // row with some texts
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                    (eventStatus == EventStatus.live && currentReplayTime == sliderEnd)
                        ? '1 sec/sec${(testing) ? ' | $debugString' : ''}'
                        : '${speedTextTable[speedIndex]}${(testing) ? ' | $debugString' : ''}',
                    style: TextStyle(color: textColor)),
                const Spacer(),
                if (eventStatus != EventStatus.preEvent)
                  AutoSizeText(
                    ((currentReplayTime == sliderEnd) && (sliderEnd != eventEnd) ? 'Live ' : 'Replay ') +
                        dtsFormat.format(
                            DateTime.fromMillisecondsSinceEpoch(currentReplayTime - ((currentReplayTime == sliderEnd) ? displayDelay : 0))),
                    style: TextStyle(color: textColor),
                    minFontSize: 8,
                    maxLines: 1,
                  ),
                const Spacer(),
                if (eventStatus == EventStatus.live)
                  SizedBox(
                      width: 45,
                      child: InkWell(
                          onTap: () => setState(() => liveSecondsTimer = 0),
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text((liveSecondsTimer * hfUpdateInterval / 1000).ceil().toString(),
                                textAlign: TextAlign.right, style: TextStyle(color: textColor)),
                            const SizedBox(width: 2),
                            Icon(Icons.refresh, color: textColor, size: 15),
                          ]))),
              ]))
    ]);
  }

  Container uiSpeedSlider() {
    Color sliderColor = (bgColor == hexBlack) ? Colors.black54 : Colors.white60;
    Color thumbColor = (bgColor == hexBlack) ? Colors.black54 : Colors.white;
    return Container(
        color: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
          IconButton(
              icon: Icon(Icons.speed_outlined, color: thumbColor),
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              tooltip: "sneller",
              onPressed: () => setState(() => speedIndex = (speedIndex == speedTable.length - 1) ? speedTable.length - 1 : speedIndex + 1)),
          RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: sliderColor,
                inactiveTrackColor: sliderColor,
                trackShape: const RectangularSliderTrackShape(),
                thumbColor: thumbColor,
              ),
              child: Slider(
                value: speedIndex.toDouble(),
                min: 0,
                max: speedTable.length - 1,
                divisions: speedTable.length - 1,
                onChanged: (newValue) => setState(() => speedIndex = newValue.toInt()),
              ),
            ),
          ),
          IconButton(
              icon: Transform.flip(flipX: true, child: Icon(Icons.speed, color: thumbColor)),
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              tooltip: "langzamer",
              onPressed: () => setState(() => speedIndex = (speedIndex == 0) ? 0 : speedIndex - 1)),
          const SizedBox(height: 10),
        ]));
  }

  Column uiZoomFollowButtons() {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (autoFollow)
        Transform.scale(
            scale: 0.8,
            child: Switch(
                activeTrackColor: menuBackgroundColor.withOpacity(0.5),
                inactiveTrackColor: menuForegroundColor.withOpacity(0.5),
                trackOutlineWidth: const WidgetStatePropertyAll(0.0),
                thumbIcon: autoZoom ? const WidgetStatePropertyAll(Icon(Icons.check)) : null,
                value: autoZoom,
                onChanged: (value) => setState(() {
                      autoZoom = value;
                      if (sliderEnd != currentReplayTime) moveShipsBuoysAndWindTo(currentReplayTime);
                    }))),
      if (autoFollow)
        Text('zoom',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 0.01, color: bgColor == hexBlack ? Colors.black : Colors.white)),
      const SizedBox(width: 0, height: 10),
      Transform.scale(
          scale: 0.8,
          child: Switch(
              activeTrackColor: menuBackgroundColor.withOpacity(0.5),
              inactiveTrackColor: menuForegroundColor.withOpacity(0.5),
              trackOutlineWidth: const WidgetStatePropertyAll(0),
              thumbIcon: autoFollow ? const WidgetStatePropertyAll(Icon(Icons.check)) : null,
              value: autoFollow,
              onChanged: (value) => setState(() {
                    var temp = false;
                    following.forEach((_, val) {
                      if (val) temp = true;
                    }); // set temp to true if there are ships to follow
                    autoFollow = temp ? value : false; // dont allow autoFollow on when no ship to follow
                    showShipMenu = temp ? showShipMenu : true; // show shipmenu if no ships to follow
                    if (sliderEnd != currentReplayTime) moveShipsBuoysAndWindTo(currentReplayTime);
                  }))),
      Text('volgen',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 0.01, color: bgColor == hexBlack ? Colors.black : Colors.white)),
      const SizedBox(height: 10),
    ]);
  }

  Container uiTimeSlider() {
    Color sliderColor = (bgColor == hexBlack) ? Colors.black54 : Colors.white60;
    Color thumbColor = (bgColor == hexBlack) ? Colors.black54 : Colors.white;
    return Container(
        color: Colors.transparent,
        child: Row(children: [
          const SizedBox(width: 3),
          IconButton(
              icon: replayRunning
                  ? const Icon(Icons.pause, color: Colors.red, size: 35)
                  : const Icon(Icons.play_arrow, color: Colors.green, size: 35),
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              tooltip: replayRunning ? 'stop replay' : 'start replay',
              onPressed: startStopRunning),
          Expanded(
              // and the time slider, expanding it to the rest of the row
              child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: sliderColor,
                    inactiveTrackColor: sliderColor,
                    trackShape: const RectangularSliderTrackShape(),
                    thumbColor: thumbColor,
                  ),
                  child: Slider(
                    min: eventStart.toDouble(),
                    max: sliderEnd.toDouble(),
                    value: (currentReplayTime < eventStart || currentReplayTime > sliderEnd)
                        ? eventStart.toDouble()
                        : currentReplayTime.toDouble(),
                    onChangeStart: (_) => replayPause = true,
                    // pause the replay
                    onChanged: (time) => setState(() {
                      currentReplayTime = time.toInt();
                      if (time == sliderEnd) {
                        replayRunning = false;
                      }
                      moveShipsBuoysAndWindTo(currentReplayTime);
                    }),
                    onChangeEnd: (time) => setState(() {
                      // resume play, but stop at end
                      currentReplayTime = time.toInt();
                      replayPause = false;
                      if (sliderEnd - time < 60 * 1000) {
                        // within one minute of sliderEnd
                        currentReplayTime = sliderEnd;
                        replayRunning = false;
                      }
                      moveShipsBuoysAndWindTo(currentReplayTime);
                    }),
                  ))),
          const SizedBox(width: 17),
        ]));
  }

  //
  // the menus: uiEventMenu, uiShipMenu/uiPreEventParticipants, uiMapMenu and uiInfoPage
  //
  SingleChildScrollView uiEventMenu() {
    return SingleChildScrollView(
        child: Container(
            width: 275,
            color: menuBackgroundColor,
            padding: EdgeInsets.fromLTRB(10, menuOffset, 0, 10),
            child: Column(children: [
              Row(children: [
                const Text('Kies hieronder een evenement'),
                const Spacer(),
                IconButton(
                    icon: Icon(Icons.cancel_outlined, size: 20, color: menuForegroundColor),
                    onPressed: () => setState(() => showEventMenu = false)),
                const SizedBox(width: 3)
              ]),
              Container(
                  padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
                  child: Column(children: [
                    const Divider(),
                    PopupMenuButton(
                      key: dropEventKey,
                      offset: const Offset(15, 35),
                      itemBuilder: (_) {
                        return eventNameList
                            .map((event) =>
                                PopupMenuItem(height: 25, value: event, child: Text(event, style: const TextStyle(fontSize: 15))))
                            .toList(growable: false);
                      },
                      onSelected: (selectedEvent) => selectEventYear(event: selectedEvent),
                      tooltip: '',
                      child: Row(children: [
                        const SizedBox(width: 10),
                        Expanded(child: Container(padding: const EdgeInsets.fromLTRB(0, 5, 0, 5), child: Text(eventName))),
                        Icon(Icons.arrow_drop_down, size: 20, color: menuForegroundColor),
                      ]),
                    ),
                    if (eventYear != '')
                      PopupMenuButton(
                        key: dropYearKey,
                        offset: const Offset(15, 35),
                        itemBuilder: (_) {
                          return eventYearList
                              .map(
                                  (year) => PopupMenuItem(height: 25, value: year, child: Text(year, style: const TextStyle(fontSize: 15))))
                              .toList(growable: false);
                        },
                        onSelected: (selectedYear) => selectEventDay(year: selectedYear),
                        tooltip: '',
                        child: Row(children: [
                          const SizedBox(width: 10),
                          Expanded(child: Container(padding: const EdgeInsets.fromLTRB(0, 5, 0, 5), child: Text(eventYear))),
                          Icon(Icons.arrow_drop_down, size: 20, color: menuForegroundColor),
                        ]),
                      ),
                    if (eventDay != '')
                      PopupMenuButton(
                        key: dropDayKey,
                        offset: const Offset(15, 35),
                        itemBuilder: (_) {
                          return eventDayList
                              .map((dayRace) =>
                                  PopupMenuItem(height: 25, value: dayRace, child: Text(dayRace, style: const TextStyle(fontSize: 15))))
                              .toList(growable: false);
                        },
                        onSelected: (selectedDay) => newEventSelected(day: selectedDay),
                        tooltip: '',
                        child: Row(children: [
                          const SizedBox(width: 10),
                          Expanded(child: Container(padding: const EdgeInsets.fromLTRB(0, 5, 0, 5), child: Text(eventDay))),
                          Icon(Icons.arrow_drop_down, size: 20, color: menuForegroundColor),
                        ]),
                      ),
                    if (selectionMessage != '') Wrap(children: [const Divider(height: 20), Text(selectionMessage)]),
                    if (eventDomain != '')
                      Wrap(children: [
                        const Divider(height: 20),
                        Container(
                            alignment: const Alignment(0, 0),
                            padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                            child: InkWell(
                                child: Image.network('${server}data/$eventDomain/logo.png'),
                                onTap: () {
                                  if (socialMediaUrl != '') launchUrl(Uri.parse(socialMediaUrl), mode: LaunchMode.externalApplication);
                                })),
                        Text((socialMediaUrl == '') ? '' : 'Klik op het logo voor de laatste info over deze wedstrijd.')
                      ]),
                    if (kIsWebOnAndroid && ((config['options']['playstorelink'] ?? '') != ''))
                      Wrap(
                        children: [
                          const Divider(),
                          const Text('Mobiele Track & Trace App\nDe mobiele app werkt op uw '
                              'telefoon sneller dan de web-versie en verbruikt minder data. '
                              'Klik hier om de gratis Android app op uw telefoon installeren.'),
                          InkWell(
                            child: Image.asset('assets/images/googleplaystoreicon.png'),
                            onTap: () => launchUrl(Uri.parse(config['options']['playstorelink']), mode: LaunchMode.externalApplication),
                          ),
                        ],
                      ),
                    if (kIsWebOnIOS && ((config['options']['applestorelink'] ?? '') != ''))
                      Wrap(children: [
                        const Divider(),
                        const Text('Mobiele Track & Trace App\nDe mobiele app werkt op uw '
                            'telefoon sneller dan de web-versie en verbruikt minder data. '
                            'Klik hier om de gratis iOS app op uw telefoon installeren.'),
                        InkWell(
                          child: Image.asset('assets/images/appleappstoreicon.png'),
                          onTap: () => launchUrl(Uri.parse(config['options']['applestorelink']), mode: LaunchMode.externalApplication),
                        ),
                      ])
                  ]))
            ])));
  }

  Row uiParticipantsMenu() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      SingleChildScrollView(
          child: Container(
              width: 275,
              color: menuBackgroundColor,
              padding: EdgeInsets.fromLTRB(10, menuOffset, 0, 10),
              child: Column(children: [
                Row(children: [
                  const Text('Deelnemersmenu'),
                  const Spacer(),
                  IconButton(
                      icon: Icon(Icons.cancel_outlined, size: 20, color: menuForegroundColor),
                      onPressed: () => setState(() => showShipMenu = false)),
                  const SizedBox(width: 3)
                ]),
                Container(
                    padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
                    child: Column(children: [
                      const Divider(),
                      Row(children: [
                        const SizedBox(width: 5),
                        Text('Alle ${config['text']['participants']} volgen aan/uit'),
                        const Spacer(),
                        Checkbox(
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                            activeColor: menuForegroundColor,
                            checkColor: menuBackgroundColor,
                            side: BorderSide(color: menuForegroundColor),
                            value: followAll,
                            onChanged: (value) => setState(() {
                                  following.forEach((k, v) => following[k] = value!);
                                  followAll = autoZoom = autoFollow = value!;
                                  if (sliderEnd != currentReplayTime) moveShipsBuoysAndWindTo(currentReplayTime);
                                })),
                      ]),
                      const Divider(),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(0),
                        itemCount: shipList.length,
                        itemBuilder: (_, index) {
                          return Row(children: [
                            Icon(Icons.square, color: shipColors[index], size: 18),
                            const SizedBox(width: 5),
                            InkWell(
                              child: (showTeam)
                                  ? Text('${teamList[index]}${shipLostSignalIndicators[index]}')
                                  : Text('${shipList[index]}${shipLostSignalIndicators[index]}'),
                              onTap: () => loadAndShowShipDetails(shipList[index]),
                            ),
                            const Spacer(),
                            const SizedBox(width: 5),
                            Checkbox(
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                activeColor: menuForegroundColor,
                                checkColor: menuBackgroundColor,
                                side: BorderSide(color: menuForegroundColor),
                                value: (following[shipList[index]] == null) ? false : following[shipList[index]],
                                onChanged: (value) {
                                  following[shipList[index]] = value!;
                                  autoFollow = autoZoom = false;
                                  following.forEach((_, val) {
                                    if (val) autoFollow = autoZoom = true;
                                  });
                                  if (value && showShipInfo) loadAndShowShipDetails(shipList[index]);
                                  if (sliderEnd != currentReplayTime) moveShipsBuoysAndWindTo(currentReplayTime);
                                }),
                          ]);
                        },
                      ),
                      if (replayTracks['shiptracks'] != null)
                        Wrap(children: [
                          const Divider(),
                          Row(children: [
                            const SizedBox(width: 5),
                            Text('${config['text']['shipNames']} op de kaart'),
                            const Spacer(),
                            Checkbox(
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                activeColor: menuForegroundColor,
                                checkColor: menuBackgroundColor,
                                side: BorderSide(color: menuForegroundColor),
                                value: showShipLabels,
                                onChanged: (_) => setState(() {
                                      showShipLabels = !showShipLabels;
                                      if (eventStatus != EventStatus.preEvent && currentReplayTime != sliderEnd) {
                                        moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
                                      }
                                      prefs.setBool('shiplabels', showShipLabels);
                                    }))
                          ]),
                          if (allowShowSpeed)
                            Row(children: [
                              const SizedBox(width: 20),
                              const Text('met snelheden'),
                              const Spacer(),
                              Checkbox(
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  activeColor: menuForegroundColor,
                                  checkColor: showShipLabels ? menuBackgroundColor : menuBackgroundColor.withOpacity(0.5),
                                  side: BorderSide(color: menuForegroundColor),
                                  value: showShipSpeeds,
                                  onChanged: (_) => setState(() {
                                        showShipSpeeds = !showShipSpeeds;
                                        if (eventStatus != EventStatus.preEvent && currentReplayTime != sliderEnd) {
                                          moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
                                        }
                                        prefs.setBool('shipspeeds', showShipSpeeds);
                                      }))
                            ]),
                          if (eventInfo['showteam'] == 'true')
                            Row(children: [
                              const SizedBox(width: 20),
                              Text('Team- ipv ${config['text']['shipNames']}'),
                              const Spacer(),
                              Checkbox(
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  activeColor: menuForegroundColor,
                                  checkColor: showShipLabels ? menuBackgroundColor : menuBackgroundColor.withOpacity(0.5),
                                  side: BorderSide(color: menuForegroundColor),
                                  value: showTeam,
                                  onChanged: (_) => setState(() {
                                        showTeam = !showTeam;
                                        if (eventStatus != EventStatus.preEvent && currentReplayTime != sliderEnd) {
                                          moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
                                        }
                                      }))
                            ]),
                        ]),
                      const Divider(),
                      Row(children: [
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text("' achter de naam geeft aan dat de laatst doorgegeven positie ouder is dan $signalLostTimeText"))
                      ]),
                      const Divider(),
                      Row(children: [
                        const SizedBox(width: 5),
                        Expanded(
                            child: InkWell(
                                child: Text('Het spoor achter de ${config['text']['participants']} is $actualTrailLength '
                                    '${actualTrailLength == 1 ? 'minuut' : 'minuten'}'),
                                onTap: () {
                                  if (actualTrailLength == eventTrailLength) {
                                    if (maxReplay == 0) {
                                      actualTrailLength = (eventEnd - eventStart) / 1000 ~/ 60;
                                    } else {
                                      actualTrailLength = maxReplay * 60; // minuten
                                    }
                                  } else {
                                    actualTrailLength = eventTrailLength;
                                  }
                                  if (currentReplayTime != sliderEnd) moveShipsBuoysAndWindTo(currentReplayTime);
                                }))
                      ]),
                      if (testing)
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Divider(),
                          Text('displayDelay: ${displayDelay / 1000} seconden'),
                          Text('predictTime: ${predictTime / 1000} seconden')
                        ]),
                    ])),
              ]))),
      const SizedBox(width: 41),
    ]);
  }

  Row uiPreEventParticipantsMenu() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      SingleChildScrollView(
          child: Container(
              width: 275,
              color: menuBackgroundColor,
              padding: EdgeInsets.fromLTRB(10, menuOffset, 0, 10),
              child: shipList.isEmpty
                  ? Row(children: [
                      const Text('Deelnemers nog niet bekend'),
                      const Spacer(),
                      IconButton(
                          icon: Icon(Icons.cancel_outlined, size: 20, color: menuForegroundColor),
                          onPressed: () => setState(() => showPreEventParticipants = false)),
                      const SizedBox(width: 3)
                    ])
                  : Column(children: [
                      Row(children: [
                        const Text('Voorlopige lijst deelnemers'),
                        const Spacer(),
                        IconButton(
                            icon: Icon(Icons.cancel_outlined, size: 20, color: menuForegroundColor),
                            onPressed: () => setState(() => showPreEventParticipants = false)),
                        const SizedBox(width: 3)
                      ]),
                      Container(
                          padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
                          child: Column(children: [
                            const Divider(),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(0),
                              itemCount: shipList.length,
                              itemBuilder: (_, index) {
                                return Row(children: [
                                  Icon(Icons.square, color: shipColors[index], size: 18),
                                  const SizedBox(width: 5),
                                  InkWell(
                                    child: (showTeam) ? Text(teamList[index]) : Text(shipList[index]),
                                    onTap: () => loadAndShowShipDetails(shipList[index]),
                                  )
                                ]);
                              },
                            ),
                            if (eventInfo['showteam'] == 'true')
                              Wrap(children: [
                                const Divider(),
                                Row(children: [
                                  const SizedBox(width: 20),
                                  Text('Team- ipv ${config['text']['shipNames']}'),
                                  const Spacer(),
                                  Checkbox(
                                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                      activeColor: menuForegroundColor,
                                      checkColor: showShipLabels ? menuBackgroundColor : menuBackgroundColor.withOpacity(0.5),
                                      side: BorderSide(color: menuForegroundColor),
                                      value: showTeam,
                                      onChanged: (_) => setState(() {
                                            showTeam = !showTeam;
                                            if (eventStatus != EventStatus.preEvent && currentReplayTime != sliderEnd) {
                                              moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
                                            }
                                          }))
                                ])
                              ]),
                          ])),
                    ]))),
      const SizedBox(width: 41),
    ]);
  }

  Row uiMapMenu() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      SingleChildScrollView(
          child: Container(
              width: 275,
              color: menuBackgroundColor,
              padding: EdgeInsets.fromLTRB(10, menuOffset, 0, 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Text('Kaartmenu'),
                  const Spacer(),
                  IconButton(
                      icon: Icon(Icons.cancel_outlined, size: 20, color: menuForegroundColor),
                      onPressed: () => setState(() => showMapMenu = false)),
                  const SizedBox(width: 3)
                ]),
                SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
                    child: Column(children: [
                      const Divider(),
                      const Row(children: [SizedBox(width: 4), Text('Basiskaarten:')]),
                      ListView.builder(
                          // radiobuttons for maptype
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: baseMapTileProviders.keys.toList().length,
                          itemBuilder: (_, index) {
                            return Row(children: [
                              const SizedBox(width: 20),
                              Text(baseMapTileProviders.keys.toList()[index]),
                              const Spacer(),
                              Theme(
                                  data: ThemeData.dark(),
                                  child: Radio(
                                    activeColor: menuForegroundColor,
                                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                    value: baseMapTileProviders.keys.toList()[index],
                                    groupValue: selectedMapType,
                                    onChanged: (value) => setState(() {
                                      selectedMapType = value!;
                                      prefs.setString('maptype', selectedMapType);
                                      bgColor = baseMapTileProviders[selectedMapType]['bgColor'];
                                      markerBackgroundColor = bgColor == hexBlack ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
                                      labelBackgroundColor = bgColor == hexBlack ? const Color(0xBfFFFFFF) : const Color(0xFF000000);
                                      if (eventStatus == EventStatus.live || eventStatus == EventStatus.replay) {
                                        // force windTimeIndexes to beginning of the timestamp tables to ensure redrawing of the windmarkers
                                        windTimeIndex = List.filled(replayTracks['windtracks'].length, -1, growable: true);
                                        // and redraw all markers and labels
                                        if (currentReplayTime != sliderEnd) moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
                                      }
                                      if (route['features'] != null) buildRoute();
                                    }),
                                  ))
                            ]);
                          }),
                      if (selectedOverlayType != "") // map overlay on/off and radiobuttons
                        Wrap(children: [
                          const Divider(),
                          Row(children: [
                            const SizedBox(width: 5),
                            const Text('Kaart overlay'),
                            const Spacer(),
                            Checkbox(
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                activeColor: menuForegroundColor,
                                checkColor: menuBackgroundColor,
                                side: BorderSide(color: menuForegroundColor),
                                value: mapOverlay,
                                onChanged: (_) => setState(() {
                                      mapOverlay = !mapOverlay;
                                      prefs.setBool('mapoverlay', mapOverlay);
                                    }))
                          ]),
                          ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: overlayTileProviders.keys.toList().length,
                              itemBuilder: (_, index) {
                                return Row(children: [
                                  const SizedBox(width: 20),
                                  Text(overlayTileProviders.keys.toList()[index]),
                                  const Spacer(),
                                  Theme(
                                      data: ThemeData.dark(),
                                      child: Radio(
                                          activeColor: menuForegroundColor,
                                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                          value: overlayTileProviders.keys.toList()[index],
                                          groupValue: selectedOverlayType,
                                          onChanged: (value) => setState(() {
                                                selectedOverlayType = value!;
                                                prefs.setString('overlaytype', selectedOverlayType);
                                              })))
                                ]);
                              })
                        ]),
                      if (replayTracks['windtracks'] != null && replayTracks['windtracks'].length > 0 && allowShowWind)
                        Wrap(children: [
                          const Divider(),
                          Row(children: [
                            const SizedBox(width: 5),
                            const Text('Windpijlen'),
                            const Spacer(),
                            Checkbox(
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                activeColor: menuForegroundColor,
                                checkColor: menuBackgroundColor,
                                side: BorderSide(color: menuForegroundColor),
                                value: showWindMarkers,
                                onChanged: (value) => setState(() {
                                      showWindMarkers = !showWindMarkers;
                                      windTimeIndex = List.filled(windTimeIndex.length, -1, growable: true);
                                      rotateWindTo(currentReplayTime);
                                      if (infoWindowId != '' && infoWindowId.substring(0, 4) == 'wind') {
                                        infoWindowId = '';
                                        infoWindowMarkerList = [];
                                      }
                                      prefs.setBool('windmarkers', showWindMarkers);
                                    }))
                          ])
                        ]),
                      if (route['features'] != null ||
                          (replayTracks['gpsbuoy'] != null && replayTracks['gpsbuoy'].length != 0)) // route and routelabels
                        Wrap(children: [
                          const Divider(),
                          Row(children: [
                            const SizedBox(width: 5),
                            const Text('Route, havens, boeien'),
                            const Spacer(),
                            Checkbox(
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                activeColor: menuForegroundColor,
                                checkColor: menuBackgroundColor,
                                side: BorderSide(color: menuForegroundColor),
                                value: showRoute,
                                onChanged: (_) => setState(() {
                                      showRoute = !showRoute;
                                      if (infoWindowId != '' && infoWindowId.substring(0, 4) == 'rout') {
                                        infoWindowId = '';
                                        infoWindowMarkerList = [];
                                      }
                                      buildRoute();
                                      showGPSBuoys(currentReplayTime);
                                      prefs.setBool('showroute', showRoute);
                                    }))
                          ]),
                          Row(children: [
                            const SizedBox(width: 20),
                            const Text('met namen'),
                            const Spacer(),
                            Checkbox(
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                activeColor: menuForegroundColor,
                                checkColor: showRoute ? menuBackgroundColor : menuBackgroundColor.withOpacity(0.5),
                                side: BorderSide(color: menuForegroundColor),
                                value: showRouteLabels,
                                onChanged: (value) => setState(() {
                                      showRouteLabels = !showRouteLabels;
                                      buildRoute();
                                      gpsBuoyTimeIndex = List.filled(gpsBuoyTimeIndex.length, -1, growable: true);
                                      showGPSBuoys(currentReplayTime);
                                      prefs.setBool('routelabels', showRouteLabels);
                                    }))
                          ])
                        ]),
                      if (replayTracks['shiptracks'] != null) // shipnames and speeds
                        Wrap(children: [
                          const Divider(),
                          Row(children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                                child: Text(config['text']['shipNames']),
                              ),
                            ),
                            Checkbox(
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                activeColor: menuForegroundColor,
                                checkColor: menuBackgroundColor,
                                side: BorderSide(color: menuForegroundColor),
                                value: showShipLabels,
                                onChanged: (value) => setState(() {
                                      showShipLabels = !showShipLabels;
                                      if (eventStatus != EventStatus.preEvent && currentReplayTime != sliderEnd) {
                                        moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
                                      }
                                      prefs.setBool('shiplabels', showShipLabels);
                                    }))
                          ]),
                          if (allowShowSpeed)
                            Row(children: [
                              const SizedBox(width: 20),
                              const Text('met snelheden'),
                              const Spacer(),
                              Checkbox(
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  activeColor: menuForegroundColor,
                                  checkColor: showShipLabels ? menuBackgroundColor : menuBackgroundColor.withOpacity(0.5),
                                  side: BorderSide(color: menuForegroundColor),
                                  value: showShipSpeeds,
                                  onChanged: (_) => setState(() {
                                        showShipSpeeds = !showShipSpeeds;
                                        if (eventStatus != EventStatus.preEvent && currentReplayTime != sliderEnd) {
                                          moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
                                        }
                                        prefs.setBool('shipspeeds', showShipSpeeds);
                                      }))
                            ]),
                          if (eventInfo['showteam'] == 'true')
                            Row(children: [
                              const SizedBox(width: 20),
                              Text('Team- ipv ${config['text']['shipNames']}'),
                              const Spacer(),
                              Checkbox(
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                  activeColor: menuForegroundColor,
                                  checkColor: showShipLabels ? menuBackgroundColor : menuBackgroundColor.withOpacity(0.5),
                                  side: BorderSide(color: menuForegroundColor),
                                  value: showTeam,
                                  onChanged: (_) => setState(() {
                                        showTeam = !showTeam;
                                        if (eventStatus != EventStatus.preEvent && currentReplayTime != sliderEnd) {
                                          moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
                                        }
                                      }))
                            ]),
                        ]),
                      if (eventStatus == EventStatus.replay) // replay loop checkbox
                        Wrap(children: [
                          const Divider(),
                          Row(children: [
                            const SizedBox(width: 5),
                            const Text('Replay loop'),
                            const Spacer(),
                            Checkbox(
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                activeColor: menuForegroundColor,
                                checkColor: menuBackgroundColor,
                                side: BorderSide(color: menuForegroundColor),
                                value: replayLoop,
                                onChanged: (_) => setState(() => replayLoop = !replayLoop))
                          ])
                        ])
                    ]))
              ]))),
      const SizedBox(width: 41)
    ]);
  }

  Row uiInfoPage() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      SingleChildScrollView(
        child: GestureDetector(
            onTap: () => setState(() => showInfoPage = false),
            child: Container(
                width: (screenWidth > 750) ? 750 - 45 : screenWidth - 45,
                color: Color(int.parse(config['colors']['infoPageColor'], radix: 16)),
                padding: EdgeInsets.fromLTRB(20, menuOffset, 0, 20),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(icon: const Icon(Icons.cancel_outlined, size: 20), onPressed: () => setState(() => showInfoPage = false)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
                    child: Html(
                      data: infoPageHTML,
                      onLinkTap: (link, _, __) => launchUrl(Uri.parse(link!), mode: LaunchMode.externalApplication),
                    ),
                  )
                ]))),
      ),
      const SizedBox(width: 41),
    ]);
  }

  //
  // The ship info draggable container
  //
  Positioned uiShipInfo() {
    return Positioned(
        left: shipInfoPosition.dx,
        top: shipInfoPosition.dy,
        child: GestureDetector(
            onPanStart: (details) => shipInfoPositionAtDragStart = shipInfoPosition - details.localPosition,
            onPanUpdate: (details) => setState(() => shipInfoPosition = shipInfoPositionAtDragStart + details.localPosition),
            onTap: () => setState(() => showShipInfo = false),
            child: Container(
                constraints: BoxConstraints(minHeight: 100, maxHeight: 500, maxWidth: screenWidth - 55 < 350 ? screenWidth - 55 : 350),
                decoration: BoxDecoration(color: menuBackgroundColor, border: Border.all(color: menuForegroundColor, width: 1)),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Stack(children: [
                  SingleChildScrollView(
                      child: Html(
                          data: shipInfoHTML,
                          onLinkTap: (link, _, __) => launchUrl(Uri.parse(link!), mode: LaunchMode.externalApplication))),
                  Row(children: [
                    const Spacer(),
                    Icon(Icons.cancel_outlined, size: 20, color: menuForegroundColor),
                  ]),
                ]))));
  }

  //
  // the popup window with map contributor attributions
  //
  Row uiAttribution() {
    var attributeStyle = const TextStyle(color: Colors.black87, fontSize: 12);
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (showAttribution)
          Card(
              color: Colors.white,
              child: Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  padding: const EdgeInsets.all(10),
                  child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        GestureDetector(
                            child: Text('© 2010-${DateTime.now().year} Stichting Zeilvaart Warmond', style: attributeStyle),
                            onTap: () => launchUrl(Uri.parse('https://www.zeilvaartwarmond.nl'))),
                        GestureDetector(
                            child: Text('• Basiskaart: © ${baseMapTileProviders[selectedMapType]['attrib']}', style: attributeStyle),
                            onTap: () => launchUrl(Uri.parse(baseMapTileProviders[selectedMapType]['attribLink']))),
                        if (mapOverlay && overlayTileProviders.isNotEmpty)
                          GestureDetector(
                              child:
                                  Text('• Overlaykaart: © ${overlayTileProviders[selectedOverlayType]['attrib']}', style: attributeStyle),
                              onTap: () => launchUrl(Uri.parse(overlayTileProviders[selectedOverlayType]['attribLink']))),
                        if (windMarkerList.isNotEmpty && showWindMarkers)
                          GestureDetector(
                              child: Text('• Windpijlen: © buienradar.nl', style: attributeStyle),
                              onTap: () => launchUrl(Uri.parse('https://www.buienradar.nl'))),
                        if (eventInfo.isNotEmpty && eventInfo['MarineTraffic'] == 'true')
                          GestureDetector(
                            child: Text('• AIS tracking door www.MarineTraffic.com', style: attributeStyle),
                            onTap: () => launchUrl(Uri.parse('https://www.marinetraffic.com')),
                          ),
                        if (eventInfo.isNotEmpty && eventInfo['AISHub'] == 'true')
                          GestureDetector(
                            child: Text('• AIS tracking door www.AISHub.net', style: attributeStyle),
                            onTap: () => launchUrl(Uri.parse('https://www.aishub.net')),
                          ),
                      ])))),
        IconButton(
          icon: (showAttribution)
              ? Icon(Icons.cancel_outlined, color: (bgColor == hexBlack) ? Colors.black38 : Colors.white60)
              : Icon(Icons.info_outline, color: (bgColor == hexBlack) ? Colors.black38 : Colors.white60),
          onPressed: () => setState(() => showAttribution = !showAttribution),
        )
      ])
    ]);
  }

  Column uiCookieConsent() {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(
          color: menuBackgroundColor,
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            const Expanded(
              child: Text('Voor de goede werking van deze app wordt de nodige informatie opgeslagen op je '
                  'telefoon/PC. Ook wordt statistische informatie over het gebruik van de app verzameld. Er worden geen '
                  'persoonlijke gegevens verzameld. Ben je niet akkoord: wegwezen'),
            ),
            Container(
                padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                child: Center(
                  child: ElevatedButton(
                      onPressed: () => setState(() {
                            cookieConsentGiven = true;
                            prefs.setBool('cookieconsent', cookieConsentGiven);
                          }),
                      child: const Text('Akkoord')),
                ))
          ]))
    ]);
  }

  Center uiProgressIndicator() {
    return Center(child: Transform.scale(scale: 3, child: CircularProgressIndicator(color: menuForegroundColor)));
  }

  //----------------------------------- end of ui widgets --------------------------------------------
  //
  // This routine is called when UI is built and the map is ready.
  // Here we start up the rest of the initialization of our app
  //
  void onMapCreated() async {
    // Get the list of events ready for selection
    dirList = await getDirList();
    eventNameList = dirList.keys.toList()..sort();
    eventYearList = [];
    eventDayList = [];
    //
    // open the event menu
    showEventMenu = true;
    if (eventDomain != "") {
      // we have info from a previous session or from the web url: use it as if the user had selected an event using the UI
      List eventSubStrings = ('$eventDomain///').split('/');
      if (dirList.containsKey(eventSubStrings[0])) {
        eventName = eventSubStrings[0];
        eventYearList = dirList[eventName].keys.toList()..sort();
        eventYearList = eventYearList.reversed.toList();
        if (eventYearList.contains(eventSubStrings[1])) {
          eventYear = eventSubStrings[1];
          if (dirList[eventName][eventYear].isEmpty) {
            newEventSelected(day: ''); // no day/races in this year, just go with eventName and eventYear
          } else {
            eventDayList = dirList[eventName][eventYear].keys.toList()..sort();
            if (eventDayList.contains(eventSubStrings[2])) {
              eventDay = eventSubStrings[2];
              newEventSelected(day: eventDay); // go with eventName, eventYear and eventDay
            } else {
              Timer(const Duration(milliseconds: 600), () {
                // give the uiEventMenu animation time to settle, otherwise the drop down list shows up at the wrong place
                selectEventDay(year: eventYear);
              });
            }
          }
        } else {
          Timer(const Duration(milliseconds: 600), () {
            // give the uiEventMenu animation time to settle, otherwise the drop down list shows up at the wrong place
            selectEventYear(event: eventName);
          });
        }
      } else {
        eventDomain = '';
      }
    }
    if (eventDomain == '') {
      eventName = 'Kies een evenement';
      eventYear = '';
      eventDay = '';
      // if we have no eventDomain from local storage or from the query string, the event selection menu will start things up
      Timer(const Duration(milliseconds: 600), () {
        // give the uiEventMenu animation time to settle, otherwise the drop down list shows up at the wrong place
        dynamic state = dropEventKey.currentState;
        state.showButtonMenu();
        setState(() {}); // redraw the UI
      });
    }
    setState(() {}); // redraw the UI
  }

  //----------------------------------------------------------------------------
  // Routines to handle the event selections from the UI event selection menu
  // First the routine to handle the selection of the event name and prepare for getting a year
  //
  selectEventYear({event}) {
    selectionMessage = '';
    eventName = event;
    eventYearList = [];
    // make a list of years for the event in reverse order. The list is automatically shown in the UI
    eventYearList = dirList[event].keys.toList()..sort();
    eventYearList = eventYearList.reversed.toList();
    eventYear = 'Kies een jaar';
    Timer(const Duration(milliseconds: 600), () {
      // give the uiEventMenu animation time to settle, otherwise the drop down list shows up at the wrong place
      dynamic state = dropYearKey.currentState;
      state.showButtonMenu();
      setState(() {}); // redraw the UI
    });
    eventDay = '';
    eventDayList = [];
    setState(() {});
  }

  //----------------------------------------------------------------------------
  // (almost) identical routine to handle the selection of an event year and prepare for getting a day
  // unless this event does not have a day, in that case we go to newEventSelected immediately
  //
  void selectEventDay({year}) {
    selectionMessage = '';
    eventYear = year;
    eventDayList = [];
    // make a list of days for the event/year, but only if this event year has any days. Otherwise we have a complete event selected
    if (dirList[eventName][eventYear].length != 0) {
      eventDayList = dirList[eventName][eventYear].keys.toList()..sort();
      eventDay = 'Kies een dag/race';
      Timer(const Duration(milliseconds: 600), () {
        // give the uiMapMenu animation time to settle, otherwise the drop down list show up at the wrong place
        dynamic state = dropDayKey.currentState;
        state.showButtonMenu();
        setState(() {}); // redraw the UI
      });
      setState(() {});
    } else {
      newEventSelected(day: '');
    }
  }

  //----------------------------------------------------------------------------
  // Routine to start up a new event after the user selected the day (or year, in case there are no days in the event)
  // This routine is also called immediately after startup of the app, when we found an eventDomain
  // in local storage from a previous session or in the URL query
  //
  void newEventSelected({day}) async {
    // set the new eventDomain and save it in local storage
    eventDay = day;
    eventDomain = '$eventName/$eventYear';
    if (eventDay != '') eventDomain = '$eventDomain/$eventDay';
    prefs.setString('domain', eventDomain); // save the selected event in local storage
    // put the direct link to this event in the addressbar
    if (kIsWeb) window.history.pushState({}, '', '?event=$eventDomain');
    // then "kill" whatever was running
    if (replayTicker.isTicking) replayTicker.stop();
    replayRunning = false;
    if (eventStatus == EventStatus.preEvent) {
      preEventTimer.cancel();
    } else if (eventStatus == EventStatus.live) {
      liveTimer.cancel();
    }
    //
    // new event selected, show progressindicator and reset some variables to their initial/default values
    setState(() => showProgress = true);
    following = {}; // status of the checkboxes in the ship menu
    followAll = true; // the follow all ships checkbox
    autoZoom = true; // the status of the autozoom switch
    replayLoop = false;
    showShipInfo = false;
    replayTracks = {};
    shipList = []; // list of patricipting shipnames
    teamList = []; // list of corresponding teamnames
    shipColors = []; // and their corresponding colors
    shipColorsSvg = []; // same but in svg format
    shipMarkerList = [];
    shipLabelList = [];
    shipTrailList = [];
    gpsBuoyMarkerList = [];
    gpsBuoyLabelList = [];
    windMarkerList = [];
    infoWindowId = '';
    infoWindowMarkerList = [];
    //
    // get the eventInfo for the selected event from the server and unpack it into several vars
    // note that some values may be missing. If so, we set the vars to default values
    eventInfo = await getEventInfo(eventDomain);
    eventTitle = eventInfo['eventtitle'] ?? '--';
    eventId = eventInfo['eventid'] ?? '--'; // normally the eventdomain with dashes instead of slashes
    eventStart = int.parse(eventInfo['eventstartstamp'] ?? '0') * 1000;
    eventEnd = int.parse(eventInfo['eventendstamp'] ?? '0') * 1000;
    sliderEnd = eventEnd;
    eventTrailLength = actualTrailLength = int.parse(eventInfo['traillength'] ?? '30');
    maxReplay = int.parse(eventInfo['maxreplay'] ?? '0');
    trailsUpdateInterval = int.parse(eventInfo['trailsupdateinterval'] ?? '15');
    trailsUpdateInterval = trailsUpdateInterval < 5 ? 5 : trailsUpdateInterval;
    hfUpdate = bool.parse(eventInfo['hfupdate'] ?? 'false');
    displayDelay = hfUpdate ? (int.parse(eventInfo['displaydelay'] ?? '25')) * 1000 : 0;
    predictTime = (int.parse(eventInfo['predicttime'] ?? '15')) * 1000;
    signalLostTime = int.parse(eventInfo['signallosttime'] ?? '60');
    signalLostTimeText = signalLostTime ~/ 60 == 0 ? '' : '${signalLostTime ~/ 60} ${signalLostTime ~/ 60 == 1 ? ' minuut' : ' minuten'}';
    signalLostTimeText += signalLostTime % 60 == 0 ? '' : '${signalLostTime ~/ 60 == 0 ? '' : ' en '}${signalLostTime % 60} seconden';
    signalLostTime *= 1000;
    showTeam = bool.parse(eventInfo['showteamdefault'] ?? 'false');
    eventInfo['mediaframe'] ??= '';
    socialMediaUrl = switch (eventInfo['mediaframe'].split(':').first) {
      'facebook' => 'https://www.facebook.com/${eventInfo['mediaframe'].split(':').last}',
      'twitter' || 'X' => 'https://www.x.com/${eventInfo['mediaframe'].split(':').last}',
      'http' || 'https' => eventInfo['mediaframe'],
      _ => ''
    };
    allowShowSpeed = bool.parse(eventInfo['allowspeed'] ?? 'true');
    allowShowWind = showWindMarkers = bool.parse(eventInfo['buienradar'] ?? 'true');
    // get the appicon.png either from the event or the default icon
    appIconUrl = await getAppIconUrl(event: eventDomain);
    // get the route.geojson from the server
    route = await getRoute(eventDomain);
    //
    // set the event status based on the current time. Are we before, during or after the event
    final now = DateTime.now().millisecondsSinceEpoch;
    if (eventStart > now) {
      startPreEvent();
    } else if (eventEnd > now) {
      startLive();
    } else {
      startReplay();
    }
    setState(() {}); // redraw the UI
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // Two routines for an event that has not started yet
  //
  void startPreEvent() async {
    eventStatus = EventStatus.preEvent;
    selectionMessage = 'Het evenement is nog niet begonnen.\n\nKies een ander evenement of wacht rustig af. '
        'De Track & Trace begint op ${dtFormat.format(DateTime.fromMillisecondsSinceEpoch(eventStart))}';
    await getParticipants(eventDomain);
    if (route['features'] != null) {
      selectionMessage += '\n\nBekijk intussen de route / havens / boeien op de kaart';
      showRoute = true;
      showRouteLabels = true;
      buildRoute(move: true); // and move the map to the bounds of the route
    }
    showProgress = false;
    // hide the menu when we are running in a web iframe
    if (kIsWeb && (document.referrer != '')) Timer(const Duration(milliseconds: 1500), () => setState(() => showEventMenu = false));
    preEventTimer = Timer.periodic(const Duration(seconds: 5), (_) => preEventTimerRoutine());
  }

  // wait for the event to begin
  void preEventTimerRoutine() {
    if (DateTime.now().millisecondsSinceEpoch > eventStart) {
      preEventTimer.cancel();
      eventStatus = EventStatus.live;
      startLive();
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // Two routines for handling a live event
  // 1. startup the live event
  // 2. the live timer routine, runs every 100 milliseconds
  //
  void startLive() async {
    eventStatus = EventStatus.live;
    selectionMessage = 'Het evenement is "live". Wacht tot de tracks zijn geladen';
    if (maxReplay == 0) {
      // maxReplay is set as an event parameter and is either 0 for normal events, or x hours when we have one long event where
      // we want to limit the replay starting x hours back. 0 is the "normal" operation mode
      //
      // first see if we already have live tracks of this event in local storage from a previous session
      String savedTrails = prefs.getString('live-$eventId') ?? ''; // get "old" live tracks from prefs (if not set to default '')
      if (savedTrails != '') {
        replayTracks = jsonDecode(savedTrails);
      } else {
        // no data yet, so get the replay (max 5 minutes old)
        replayTracks = await getReplayTracks(eventDomain, noStats: true);
      }
      // now get the latest bunch of live tracks
      liveTrails = await getTrails(eventDomain, fromTime: (replayTracks['endtime'] / 1000).toInt());
      addLiveTrailsToTracks(); // merge the latest track info with the replay info and save it
    } else {
      //
      // maxReplay > 0, fetch the trails of the last {maxReplay} hours
      eventStart = DateTime.now().millisecondsSinceEpoch - (maxReplay * 60 * 60 * 1000);
      replayTracks = await getTrails(eventDomain, fromTime: eventStart ~/ 1000);
    }
    if (!kIsWeb) prefs.setString('live-$eventId', jsonEncode(replayTracks));
    setupShipGpsBuoyAndWindInfo(); // prepare menu and track info
    for (var name in shipList) {
      following[name] = true;
    }
    showRoute = true;
    if (shipList.isEmpty) showRouteLabels = true;
    if (route['features'] != null) buildRoute();
    selectionMessage = shipList.isNotEmpty ? 'De tracks zijn geladen en worden elke $trailsUpdateInterval seconden bijgewerkt' : '';
    sliderEnd = currentReplayTime = DateTime.now().millisecondsSinceEpoch; // put the timeslider to 'now'
    speedIndex = speedIndexInitialValue;
    if (queryPlayString != '::') {
      var a = queryPlayString.split(':');
      queryPlayString = '::'; // set the string to 'empty' in case the user lateron selects an other event manually
      if (a[1] != '' && a[1] != '0') currentReplayTime = int.parse(a[1]);
      if (a[2] != '' && a[2] != '0') speedIndex = int.parse(a[2]);
      if (a[0] == 'true') startStopRunning();
    }
    autoFollow = true;
    autoZoom = true; // zoom to all ships at the start
    moveShipsBuoysAndWindTo(currentReplayTime - displayDelay);
    //autoZoom = false; // but turn of autozoom when running
    liveSecondsTimer = trailsUpdateInterval * 1000 ~/ hfUpdateInterval;
    liveTimer = Timer.periodic(const Duration(milliseconds: hfUpdateInterval), (_) => liveTimerRoutine());
    setState(() {}); // redraw the UI
    // hide the event menu and the progress indicator after 1.5 seconds
    Timer(const Duration(milliseconds: 1500), () => setState(() => showEventMenu = showProgress = false));
  }

  //----------------------------------------------------------------------------
  // The live timer routine, runs every second,
  // the routine continues to be called, also when the time slider was moved backward in time
  // (currentReplayTime != endReplay). In that case, we continue to get data but don't update the
  // ship and wind markers, as this is done by the timeSliderUpdate and replayTimerRoutine
  //
  void liveTimerRoutine() async {
    int now = DateTime.now().millisecondsSinceEpoch; // have a look at the clock
    if (now < eventEnd) {
      // event is not over yet
      liveSecondsTimer--;
      if (liveSecondsTimer <= 0) {
        // we've waited 'trailsUpdateInterval' seconds, so, reset it and get new trails and add them to what we have
        liveSecondsTimer = trailsUpdateInterval * 1000 ~/ hfUpdateInterval; // we run 10 times per second
        if ((now - replayTracks['endtime']) > (trailsUpdateInterval * 3 * 1000)) {
          // we must have been asleep for at least two trailsUpdatePeriods, get a complete uopdate since the last fetch
          liveTrails = await getTrails(eventDomain, fromTime: (replayTracks['endtime'] / 1000).toInt()); // fetch special
        } else {
          // we have relatively recent data, go get the latest. Note this fetch does not (always) access the database on the server
          // but gets data stored in the trails.json file, which is not older then the trailsUpdateInterval and contains the positions of
          // the last four trails update periods (see get/index/php)
          liveTrails = await getTrails(eventDomain); // fetch the latest data
        }
        addLiveTrailsToTracks(); // add it to what we already had and store it
        setupShipGpsBuoyAndWindInfo(); // prepare menu and track info
      }
      if (currentReplayTime == sliderEnd) {
        // slider is at the end
        sliderEnd = currentReplayTime = now; // extend the slider and move the handle to the new end
        moveShipsBuoysAndWindTo(currentReplayTime - displayDelay);
      } else {
        // slider is not at the end, the slider has been moved back in time by the user
        sliderEnd = now; // just make the slider a second longer
        if (!replayRunning || replayPause) {
          moveShipsBuoysAndWindTo(currentReplayTime); // and redraw the ships at the current replaytime,
          // only whenreplay is not running or replay is pausing (user moves slider during replayrunning)
        }
      }
    } else {
      // the live event is over
      liveTimer.cancel();
      eventStatus = EventStatus.replay;
      startReplay();
    }
  }

  //----------------------------------------------------------------------------
  // routine to start replay after the event is really over
  void startReplay() async {
    eventStatus = EventStatus.replay;
    selectionMessage = 'Het evenement is voorbij. Wacht tot de tracks zijn geladen';
    // First get rid of the temporary live file if that existed...
    prefs.remove('live-$eventId');
    // Do we have already have data in local storage?
    String? savedTracks = prefs.getString('replay-$eventId');
    if (savedTracks == null) {
      // no data yet
      replayTracks = await getReplayTracks(eventDomain); // get the data from the server and
      if (!kIsWeb && replayTracks.isNotEmpty) prefs.setString('replay-$eventId', jsonEncode(replayTracks)); // store it locally
    } else {
      // send a get, just for statistical purposes, no need to wait for a response
      getReplayTracks(eventDomain, noData: true);
      replayTracks = jsonDecode(savedTracks); // and just use the data from local storage
    }
    replayRunning = false;
    setupShipGpsBuoyAndWindInfo(); // prepare menu and track info
    for (var name in shipList) {
      following[name] = true;
    }
    autoFollow = autoZoom = true;
    selectionMessage =
        shipList.isNotEmpty ? 'De tracks zijn geladen. Sluit het menu en start de replay met de start/stop knop linksonder' : '';
    currentReplayTime = eventStart;
    speedIndex = speedIndexInitialValue;
    if (queryPlayString != '::') {
      var a = queryPlayString.split(':');
      queryPlayString = '::'; // only use these values when we get here for the first time
      if (a[1] != '' && a[1] != '0') currentReplayTime = int.parse(a[1]);
      if (a[2] != '' && a[2] != '0') speedIndex = int.parse(a[2]);
      if (a[0] == 'true') startStopRunning();
    }
    showRoute = true;
    if (shipList.isEmpty) showRouteLabels = true; // no ships (yet), always show routelabels
    if (route['features'] != null) buildRoute(move: true); // and move the map to the bounds of the route
    moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
    setState(() {}); // redraw the UI
    Timer(const Duration(seconds: 2), () => setState(() => showEventMenu = showProgress = false));
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // the replayTickerRoutine runs every fluttertick i.e. 60 times per second
  // this ticker routine ensures that ships are moving forward and wind is rotating in a timely manner during replay
  void replayTickerRoutine(Duration elapsedTime) {
    // reset elapsed time to zero (for next tick)
    replayTicker.stop();
    replayTicker.start();
    if (replayPause) return; // don't move forward
    // use the elapsed since the previous run to calculate the new currentReplayTime
    currentReplayTime = (currentReplayTime + (elapsedTime.inMilliseconds * speedTable[speedIndex]));
    //
    // Now we have different situations:
    //  1 We moved beyond the end of the event and eventStatus is live: eventStatus becomes 'replay' and we possibly have case 3
    //  2 We moved beyond the last trails received from the server and the event is still live: just stop
    //    If we were live, the liveTimerRoutine will take over. If we were in replay, wait for the user to move the timeslider
    //  3 W moved beyond the last trails in replay and replayLoop is true, move to the beginning of the track and go on
    //  4 We are still in replay: just move the ships and windmarkers
    //
    if (currentReplayTime > eventEnd) {
      //case 1
      if (eventStatus == EventStatus.live) liveTimer.cancel(); // case 1
      eventStatus = EventStatus.replay; // case 1, 3
      if (replayLoop) {
        currentReplayTime = eventStart; // case 3
      } else {
        startStopRunning();
        currentReplayTime = eventEnd;
      }
    } else if (currentReplayTime > sliderEnd) {
      // case 2
      startStopRunning();
      currentReplayTime = sliderEnd;
    }
    moveShipsBuoysAndWindTo(currentReplayTime); // case 4
  }

  //----------------------------------------------------------------------------
  //
  // Routine to handle start/stop button
  void startStopRunning() {
    if (eventStatus != EventStatus.preEvent) {
      setState(() {
        replayRunning = !replayRunning;
        if (currentReplayTime == sliderEnd && replayRunning) {
          // if he wants to run while at the end of the slider, move it to the beginning
          currentReplayTime = eventStart;
        }
        (replayRunning) ? replayTicker.start() : replayTicker.stop();
      }); // redraw the UI
    }
  }

  //----------------------------------------------------------------------------
  //
  // Routines to move ships, shiplabels, redraw shiptrail polylines, rotate windmarkers and plot the GPS buoys
  // It is called in all eventStatus'es every time the markers need to be updated
  // During replay this routine is called 20 times per second, so in that situation the routine is time critical....
  //
  // 'move' is default to true.
  // Set it to false when you only want to change the backgroundcolor of the markers or turn on/off the route and or labels
  //
  void moveShipsBuoysAndWindTo(time, {bool moveMap = true}) {
    setState(() {
      moveShipsTo(time, moveMap: moveMap);
      if (showRoute) showGPSBuoys(time);
      if (showWindMarkers && allowShowWind) rotateWindTo(time);
    });
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  void moveShipsTo(time, {moveMap}) {
    late int timeIndex;
    LatLng calculatedPosition = const LatLng(0, 0);
    int calculatedRotation = 0;
    List<LatLng> followBounds = [];
    // loop through the ships in replayTracks
    for (int i = 0; i < replayTracks['shiptracks'].length; i++) {
      var shipTrack = replayTracks['shiptracks'][i];
      if (shipTrack['stamp'].length > 0) {
        // see where we are in the time track of the ship
        if (time <= shipTrack['stamp'].first) {
          // before the first timestamp
          timeIndex = 0; // set the track's timeIndex to the first entry
          calculatedPosition = LatLng(shipTrack['lat'].first.toDouble(), shipTrack['lon'].first.toDouble());
          calculatedRotation = shipTrack['course'].first;
        } else if (time >= shipTrack['stamp'].last) {
          // we are at or beyond the last timestamp
          timeIndex = shipTrack['stamp'].length - 1; // set the track timeIndex to point to the last entry
          calculatedRotation = shipTrack['course'].last;
          if (hfUpdate &&
              (eventStatus == EventStatus.live) &&
              (currentReplayTime == sliderEnd) &&
              (time - shipTrack['stamp'].last) < predictTime) {
            // we are allowed to predict AND we are live AND at the end of the slider AND the last stamp is less then predictTime old:
            // in this situation we make a prediction where the ship could be, based on the last known location, speed, time since the last
            // location and the heading
            calculatedPosition = predictPosition(LatLng(shipTrack['lat'].last.toDouble(), shipTrack['lon'].last.toDouble()),
                shipTrack['speed'].last / 10, time - shipTrack['stamp'].last, calculatedRotation);
          } else {
            calculatedPosition = LatLng(shipTrack['lat'].last.toDouble(), shipTrack['lon'].last.toDouble());
          }
        } else {
          // we are somewhere between two stamps:
          // travel along the track from the previous index forth (or back) to find out where we are
          timeIndex = shipTimeIndex[i]; // get the timeindex of this ship from a previous run
          var stamps = shipTrack['stamp']; // make a ref to the list of stamps, in an effort to speedup the search
          if (time > stamps[timeIndex]) {
            while (stamps[timeIndex] < time) {
              timeIndex++; // move forward in the track
            }
            timeIndex--; // we went one entry too far
          } else {
            while (stamps[timeIndex] > time) {
              timeIndex--; // else move backward in the track
            }
          }
          // we are in between stamps, calculate the ratio of time since last stamp and next stamp
          double ratio = (time - stamps[timeIndex]) / (stamps[timeIndex + 1] - stamps[timeIndex]);
          // and set the ship position and rotation at that ratio between last and next positions/rotations
          calculatedPosition = LatLngTween(
                  begin: LatLng(shipTrack['lat'][timeIndex].toDouble(), shipTrack['lon'][timeIndex].toDouble()),
                  end: LatLng(shipTrack['lat'][timeIndex + 1].toDouble(), shipTrack['lon'][timeIndex + 1].toDouble()))
              .transform(ratio);
          // calculate the rotation
          // tried this with a conversion to vectors, but the sin, cos and atan2 functions require too much time
          int diff = shipTrack['course'][timeIndex + 1] - shipTrack['course'][timeIndex];
          if (diff >= 180) {
            calculatedRotation = (shipTrack['course'][timeIndex] + (ratio * (diff - 360)).floor()); // anticlockwise through north (360 dg)
          } else if (diff <= -180) {
            calculatedRotation = (shipTrack['course'][timeIndex] + (ratio * (diff + 360)).floor()); // clockwise through north (360 dg)
          } else {
            calculatedRotation = (shipTrack['course'][timeIndex] + (ratio * diff).floor()); // clockwise or anti clockwise less then 180 dg
          }
          calculatedRotation = (calculatedRotation + 720) % 360; // ensures a value between 0 and 359
        }
        shipTimeIndex[i] = timeIndex; // save the timeindex in the list of timeindices for the next run
        //
        // Update the bounds with the calculated position of this ship (but only if we are supposed to follow this ship)
        if (following[shipTrack['name']] ?? false) {
          followBounds.add(calculatedPosition);
        }
        //
        // make a string with the ship's speed for the infowindow and the shiplabel
        var speedString = '${(shipTrack['speed'][timeIndex] / 18.52).toStringAsFixed(1)}kn ('
            '${(shipTrack['speed'][timeIndex] / 10).toStringAsFixed(1)}km/h)';
        //
        // make a new infowindow text with the name of the ship, the lostsignalindicator and the speed
        shipLostSignalIndicators[i] =
            ((time - (replayRunning ? shipTrack['stamp'][timeIndex] : shipTrack['stamp'].last)) > signalLostTime) ? "'" : '';
        //
        String infoWindowTitle = '${shipTrack['name']}${shipLostSignalIndicators[i]}';
        String infoWindowText = (allowShowSpeed) ? 'Snelheid: $speedString' : '';
        // only during live AND lost signal we add a line with info when this 'more-then-3-minutes-old' position was received
        infoWindowText += (shipLostSignalIndicators[i] != '' && eventStatus == EventStatus.live && !replayRunning)
            ? '\nPositie op ${dtsFormat.format(DateTime.fromMillisecondsSinceEpoch(shipTrack['stamp'][timeIndex]))}'
            : '';
        // create the shipmarker's icon with the correct color and rotation
        var svgString = '<svg width="22" height="22"><polygon points="$shipSvgPath" '
            'style="fill:${shipColorsSvg[i]};stroke:$bgColor;stroke-width:1" '
            'transform="rotate($calculatedRotation,11,11)" /></svg>';
        // create / replace the ship marker
        shipMarkerList[i] = Marker(
          point: calculatedPosition,
          width: 22,
          height: 22,
          child: Tooltip(
              message: showShipLabels
                  ? (showShipSpeeds ? '' : speedString)
                  : ('${shipTrack['name']}${shipLostSignalIndicators[i]}${showShipSpeeds ? ', $speedString' : ''}'),
              child: InkWell(
                  child: SvgPicture.string(svgString),
                  onSecondaryTap: () => loadAndShowShipDetails(shipTrack['name']),
                  onDoubleTap: () => setState(() {
                        // zoom in on the ship double tapped
                        followAll = false;
                        following.forEach((k, v) => following[k] = false);
                        autoFollow = following[shipTrack['name']] = true;
                        var saveZoom = autoZoom;
                        autoZoom = true;
                        moveShipsBuoysAndWindTo(currentReplayTime);
                        autoZoom = saveZoom;
                        // show the ship menu and hide any info window and ship info
                        showShipMenu = true;
                        infoWindowId = '';
                        infoWindowMarkerList = [];
                        showShipInfo = false;
                      }),
                  onTap: () => setState(() {
                        infoWindowId = 'ship${shipTrack['name']}';
                        infoWindowMarkerList = [
                          infoWindowMarker(title: infoWindowTitle, body: infoWindowText, link: '', point: calculatedPosition)
                        ];
                        moveShipsTo(time, moveMap: false);
                      }))),
        );
        //
        // refresh the infowindow if it was open for this ship
        if (infoWindowId == 'ship${shipTrack['name']}') {
          infoWindowMarkerList = [infoWindowMarker(title: infoWindowTitle, body: infoWindowText, link: '', point: calculatedPosition)];
        }
        //
        // build the shipLabel
        shipLabelList[i] = showShipLabels
            ? mapTextLabel(
                calculatedPosition,
                '${showTeam ? teamList[i] : shipList[i]}${shipLostSignalIndicators[i]}${(showShipSpeeds ? ', '
                    '$speedString' : '')}')
            : const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
        //
        // build the shipTrail (note we reuse/destroy the timeIndex here...)
        List<LatLng> trail = [calculatedPosition];
        while ((timeIndex >= 0) && (shipTrack['stamp'][timeIndex] > (time - actualTrailLength * 60 * 1000))) {
          trail.add(LatLng(shipTrack['lat'][timeIndex].toDouble(), shipTrack['lon'][timeIndex].toDouble()));
          timeIndex--;
        }
        shipTrailList[i] = Polyline(
          points: trail,
          color: shipColors[i],
          // thick line in case of short trails, thin line when we display full eventlong trails
          strokeWidth: eventTrailLength == actualTrailLength ? 2 : 1,
        );
      }
    }
    //
    // finally after all ships were moved, see if we need to move/zoom the camera to the ships
    if (moveMap && followBounds.isNotEmpty && autoFollow) {
      LatLngBounds bounds = LatLngBounds.fromPoints(followBounds);
      if (autoZoom) {
        mapController.fitCamera(CameraFit.bounds(
            maxZoom: 16,
            bounds: bounds,
            padding: EdgeInsets.fromLTRB(
                screenWidth * 0.15, menuOffset + (screenHeight * 0.10), screenWidth * 0.15, (screenHeight * 0.10) + menuOffset)));
      } else {
        mapController.move(bounds.center, mapController.camera.zoom);
      }
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // now position all gps buoy markers
  void showGPSBuoys(time) {
    int timeIndex = 0;
    for (int i = 0; i < replayTracks['buoytracks'].length; i++) {
      if (!showRoute) {
        gpsBuoyMarkerList[i] = const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
        gpsBuoyLabelList[i] = const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
      } else {
        var gpsBuoy = replayTracks['buoytracks'][i];
        if (gpsBuoy['stamp'].length > 0) {
          if (time <= gpsBuoy['stamp'].first) {
            timeIndex = 0;
          } else if (time >= gpsBuoy['stamp'].last) {
            timeIndex = gpsBuoy['stamp'].length - 1;
          } else {
            // travel along the track from the previous index back or forth to find out where we are
            timeIndex = gpsBuoyTimeIndex[i] == -1 ? 0 : gpsBuoyTimeIndex[i];
            var stamps = gpsBuoy['stamp'];
            if (time > stamps[timeIndex]) {
              while (stamps[timeIndex] < time) {
                timeIndex++;
              }
              timeIndex--;
            } else {
              while (stamps[timeIndex] > time) {
                timeIndex--;
              }
            }
          }
          if (gpsBuoyTimeIndex[i] != timeIndex) {
            // only update when we moved into a different timeframe
            gpsBuoyTimeIndex[i] = timeIndex;
            // no interpolation to the next position, as the position of a GPS buoy should be relatively constant
            // add the buoy marker
            String svgString = '<svg width="22" height="22"><circle cx="11" cy="11" r="4" '
                'fill="${gpsBuoy['color']}" stroke="$bgColor" stroke-width="1"/></svg>';
            LatLng gpsBuoyPosition = LatLng(gpsBuoy['lat'][timeIndex].toDouble(), gpsBuoy['lon'][timeIndex].toDouble());
            gpsBuoyMarkerList[i] = Marker(
                point: gpsBuoyPosition,
                width: 22,
                height: 22,
                child: Tooltip(
                    message: showRouteLabels ? '' : gpsBuoy['name'],
                    child: InkWell(
                      child: SvgPicture.string(svgString),
                      onTap: () => setState(() {
                        infoWindowId = 'buoy${gpsBuoy['name']}';
                        infoWindowMarkerList = [
                          infoWindowMarker(title: gpsBuoy['name'], body: gpsBuoy['description'], link: '', point: gpsBuoyPosition)
                        ];
                      }),
                    )));
            // refresh the infowindow if it was open for this buoy
            if (infoWindowId == 'buoy${gpsBuoy['name']}') {
              infoWindowMarkerList = [
                infoWindowMarker(title: gpsBuoy['name'], body: gpsBuoy['description'], link: '', point: gpsBuoyPosition)
              ];
            }
            gpsBuoyLabelList[i] = showRouteLabels
                ? mapTextLabel(gpsBuoyPosition, gpsBuoy['name'])
                : const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
          }
        }
      }
      // no need to refresh the infowindow that may be open for this floating buoy, because for gps buoys it does not contain
      // info that changes over time
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // as the title says: rotate (and recolor) the windmarkers
  void rotateWindTo(time) {
    int rotation = 0;
    int timeIndex = 0;
    // now rotate all weather station markers and set the correct colors
    for (int i = 0; i < replayTracks['windtracks'].length; i++) {
      if (!showWindMarkers) {
        windMarkerList[i] = const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
      } else {
        var windStation = replayTracks['windtracks'][i];
        if (windStation['stamp'].length > 0) {
          if (time <= windStation['stamp'].first) {
            // before the first time stamp
            timeIndex = 0;
            rotation = windStation['course'].first;
          } else if (time >= windStation['stamp'].last) {
            // after the last timestamp
            timeIndex = windStation['stamp'].length - 1;
            rotation = windStation['course'].last;
          } else {
            // somewhere between two stamps
            // travel along the track back or forth to find out where we are, starting from the previously saved timeIndex
            timeIndex = windTimeIndex[i] == -1 ? 0 : windTimeIndex[i];
            var stamps = windStation['stamp'];
            if (time > stamps[timeIndex]) {
              while (stamps[timeIndex] < time) {
                timeIndex++;
              }
              timeIndex--;
            } else {
              while (stamps[timeIndex] > time) {
                timeIndex--;
              }
            }
            rotation = windStation['course'][timeIndex];
          }
          if (windTimeIndex[i] != timeIndex) {
            // only update when we moved into a different timeframe or when we are here at the start of the race
            windTimeIndex[i] = timeIndex;
            // add the wind markers
            String iwText = '${windStation['speed'][timeIndex]} knopen, ${knotsToBft(windStation['speed'][timeIndex])} Bft';
            String fillColor = knotsToColor(windStation['speed'][timeIndex]);
            String svgString = '<svg width="22" height="22"><polygon points="7,1 11,20 15,1 11,6" '
                'style="fill:$fillColor;stroke:$bgColor;stroke-width:1" transform="rotate($rotation,11,11)" /></svg>';
            // windstation positions do not change over time, so use the first position of the track
            LatLng windStationPosition = LatLng(windStation['lat'].first.toDouble(), windStation['lon'].first.toDouble());
            windMarkerList[i] = Marker(
                point: windStationPosition,
                width: 22,
                height: 22,
                child: Tooltip(
                    message: iwText,
                    child: InkWell(
                      child: SvgPicture.string(svgString),
                      onTap: () => setState(() {
                        infoWindowId = 'wind${windStation['name']}';
                        infoWindowMarkerList = [
                          infoWindowMarker(title: windStation['name'], body: iwText, link: '', point: windStationPosition)
                        ];
                      }),
                    )));
            //
            // refresh the infowindow if it was open for this windstation
            if (infoWindowId == 'wind-${windStation['name']}') {
              infoWindowMarkerList = [infoWindowMarker(title: windStation['name'], body: iwText, link: '', point: windStationPosition)];
            }
          }
        }
      }
    }
    // update the windmarker at the upperleft corner
    // this windmarker represents the average wind speed and direction of
    // nrWindStationsForCenterWindCalculation in the middle of the screen
    if (!showWindMarkers) {
      windMarkerList.last = const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
    } else {
      if (replayTracks['windtracks'].length > nrWindStationsForCenterWindCalculation - 1) {
        // calculate average windspeed and direction at the middle of the screen
        ({int heading, double speed}) center = centerWind(nrWindStationsForCenterWindCalculation);
        String infoWindowTitle = 'Wind midden van de kaart\nobv nabije weerstations';
        String infoWindowText = '${center.speed.toStringAsFixed(1)} knopen, ${knotsToBft(center.speed)} Bft';
        String toolTipText = infoWindowText;
        bool showWindy = ((config['options']['windy'] == 'true') && eventStatus == EventStatus.live);
        infoWindowText += showWindy ? '\n(www.windy.com)' : '';
        String fillColor = knotsToColor(center.speed);
        String svgString = '<svg width="22" height="22"><circle cx="11" cy="11" r="10" '
            'fill="none" stroke="$bgColor" stroke-width="1.2"/><polygon points="7,1 11,20 15,1 11,6" '
            'style="fill:$fillColor;stroke:$bgColor;stroke-width:1" transform="rotate(${center.heading} 11,11)" /></svg>';
        LatLng arrowPosition = mapController.camera.pointToLatLng(Point(30, menuOffset + 30));
        // position the infowindow beneath the marker
        LatLng infoWindowPosition = mapController.camera.pointToLatLng(Point(110, menuOffset + (showWindy ? 145 : 130)));
        LatLng midMap = mapController.camera.center;
        String iwLink = 'https://embed.windy.com/embed2.html?lat=${midMap.latitude}&lon=${midMap.longitude}'
            '&detailLat=${midMap.latitude}&detailLon=${midMap.longitude}&width=$screenWidth&height=$screenHeight'
            '&zoom=${mapController.camera.zoom}&level=surface&overlay=wind&product=ecmwf&menu=&message=true&marker=&calendar=now&pressure='
            '&type=map&location=coordinates&detail=true&metricWind=bft&metricTemp=%C2%B0C&radarRange=-1';
        windMarkerList.last = Marker(
            point: arrowPosition,
            width: 22,
            height: 22,
            child: Tooltip(
                message: toolTipText,
                child: InkWell(
                  child: SvgPicture.string(svgString),
                  onTap: () => setState(() {
                    infoWindowId = 'windCenter';
                    infoWindowMarkerList = [
                      infoWindowMarker(
                          title: infoWindowTitle, body: infoWindowText, link: showWindy ? iwLink : '', point: infoWindowPosition)
                    ];
                  }),
                )));
        // refresh the infowindow if it was open for this windstation
        if (infoWindowId == 'windCenter') {
          infoWindowMarkerList = [
            infoWindowMarker(title: infoWindowTitle, body: infoWindowText, link: showWindy ? iwLink : '', point: infoWindowPosition)
          ];
        }
      }
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // Build the route polyline, routemarkers and the labels.
  // If move = true, move the map to the bounds of the route after creating it, default = false, do not move.
  // The route itself is contained in a .geojson file. We only look at Points and LineStrings (i.e. no Polygons or other features)
  //
  void buildRoute({bool move = false}) {
    routeLineList = [];
    routePolygons = [];
    routeMarkerList = [];
    routeLabelList = [];
    List<LatLng> routeBounds = [];
    List<LatLng> points = [];
    List<dynamic> pts = [];
    // if there is an active infowindow for a route element: get rid of it
    if (infoWindowId != '' && infoWindowId.substring(0, 4) == 'rout') {
      infoWindowId = '';
      infoWindowMarkerList = [];
    }
    if (showRoute && route.isNotEmpty) {
      route['features'].forEach((feature) {
        if (feature['geometry']['type'] == 'LineString') {
          points = [];
          pts = feature['geometry']['coordinates'];
          for (int i = 0; i < pts.length; i++) {
            points.add(LatLng(pts[i][1], pts[i][0]));
          }
          routeBounds += move ? points : [];
          routeLineList.add(Polyline(
              points: points,
              color: Color(int.parse('8F${feature['properties']['stroke'].toString().substring(1)}', radix: 16)),
              strokeWidth: eventStatus == EventStatus.preEvent ? 4 : 2));
        } else if (feature['geometry']['type'] == 'Point') {
          var routePoint = LatLng(feature['geometry']['coordinates'][1], feature['geometry']['coordinates'][0]);
          var fillColor = feature['properties']['fillcolor'] ?? 'red';
          String svgString = '<svg width="22" height="22"><circle cx="11" cy="11" r="4" '
              'fill="$fillColor" stroke="$bgColor" stroke-width="1"/></svg>';
          String infoWindowTitle = '${feature['properties']['name']}';
          String infoWindowText = feature['properties']['description'] ?? '';
          String infoWindowLink = feature['properties']['link'] ?? '';
          infoWindowText += (infoWindowLink == '') ? '' : ' (klik of tap)';
          routeMarkerList.add(Marker(
              point: routePoint,
              width: 22,
              height: 22,
              child: Tooltip(
                  message: showRouteLabels ? '' : feature['properties']['name'],
                  child: InkWell(
                    child: SvgPicture.string(svgString),
                    onTap: () => setState(() {
                      infoWindowId = 'rout-${feature['properties']['name']}';
                      infoWindowMarkerList = [
                        infoWindowMarker(title: infoWindowTitle, body: infoWindowText, link: infoWindowLink, point: routePoint)
                      ];
                    }),
                  ))));
          if (showRouteLabels) routeLabelList.add(mapTextLabel(routePoint, feature['properties']['name']));
          routeBounds += move ? [routePoint] : [];
        } else if ((feature['geometry']['type'] == 'Polygon') && testing) {
          points = [];
          pts = feature['geometry']['coordinates'];
          for (int i = 0; i < pts[0].length; i++) {
            points.add(LatLng(pts[0][i][1], pts[0][i][0]));
          }
          routePolygons.add(Polygon(
              points: points,
              color: Colors.black12,
              borderStrokeWidth: 1,
              borderColor: Colors.black,
              label: feature['properties']['name'],
              labelStyle: const TextStyle(color: Colors.black)));
        }
      });
    }
    if (move && routeBounds.isNotEmpty) {
      //move the map to show the whole route
      mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(routeBounds),
          maxZoom: 17,
          padding:
              EdgeInsets.fromLTRB(screenWidth * 0.15, menuOffset + screenHeight * 0.10, screenWidth * 0.15, screenHeight * 0.10 + 60)));
    }
    setState(() {}); // redraw the UI
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // Routine to merge the latest live ship, gps buoy and wind trails with saved replay trails into an updated replay trails object
  // Note that there may be more/new ships/buoys/windstations in liveTrails then in replayTracks, because a ship may have joined the race later
  // (tracker or AIS data only turned on after eventStart, or the admin added a ship).
  // At the end of the routine the merged data is saved in local storage (pref)
  //
  void addLiveTrailsToTracks() async {
    liveTrails['shiptracks'].forEach((liveShip) {
      // get the index (index) in the replaytracks with the same name as the ship we try to add (liveShip)
      int index = replayTracks['shiptracks'].indexWhere((item) => item['name'] == liveShip['name']);
      if (index != -1) {
        // we found a ship with this name, now add the 'live' info to the 'replay' track info
        var replayShip = replayTracks['shiptracks'][index];
        replayShip['colorcode'] = liveShip['colorcode']; // copy possible new colorcode
        int laststamp = (replayShip['stamp'].length > 0) ? replayShip['stamp'].last : 0; // there may be overlapping data, so make sure we
        // start with data newer then our last stamp
        for (int k = 0; k < liveShip['stamp'].length; k++) {
          // add stamps, lats, lons, speeds and courses
          if (liveShip['stamp'][k] > laststamp) {
            replayShip['stamp'].add(liveShip['stamp'][k]);
            replayShip['lat'].add(liveShip['lat'][k]);
            replayShip['lon'].add(liveShip['lon'][k]);
            replayShip['speed'].add(liveShip['speed'][k]);
            replayShip['course'].add(liveShip['course'][k]);
          }
        }
      } else {
        // we had no ship with this name yet, just add it at at the end
        replayTracks['shiptracks'].add(liveShip);
        following[liveShip['name']] = followAll; // set following for this ship same as followAll checkbox
      }
      // sort tracks based on colorcode (new tracks and tracks with changed colorcodes)
      replayTracks['shiptracks'].sort((a, b) => int.parse(a['colorcode']).compareTo(int.parse(b['colorcode'])));
    });
    //
    // now for the gps buoys
    liveTrails['buoytracks'].forEach((liveBuoy) {
      // get the index (index) in the replaytracks with the same name as the buoy we try to add (liveBuoy)
      int index = replayTracks['buoytracks'].indexWhere((item) => item['name'] == liveBuoy['name']);
      if (index != -1) {
        // we found a buoy with this name
        var replayBuoy = replayTracks['buoytracks'][index];
        replayBuoy['color'] = liveBuoy['color']; // copy possible new colorcode
        int laststamp = replayBuoy['stamp'].last;
        for (int k = 0; k < liveBuoy['stamp'].length; k++) {
          // add stamps, lats and lons. There are no relevant speeds and courses.
          if (liveBuoy['stamp'][k] > laststamp) {
            replayBuoy['stamp'].add(liveBuoy['stamp'][k]);
            replayBuoy['lat'].add(liveBuoy['lat'][k]);
            replayBuoy['lon'].add(liveBuoy['lon'][k]);
          }
        }
      } else {
        // we had no buoy with this name yet, just add it
        replayTracks['buoytracks'].add(liveBuoy);
      }
    });
    //
    // and finally the same for the weather stations
    liveTrails['windtracks'].forEach((liveWindStation) {
      int index = replayTracks['windtracks'].indexWhere((item) => item['name'] == liveWindStation['name']);
      if (index != -1) {
        // we already had a weather station with this name
        var replayWindStation = replayTracks['windtracks'][index];
        int laststamp = replayWindStation['stamp'].last;
        for (int k = 0; k < liveWindStation['stamp'].length; k++) {
          if (liveWindStation['stamp'][k] > laststamp) {
            replayWindStation['stamp'].add(liveWindStation['stamp'][k]);
            replayWindStation['lat'].add(liveWindStation['lat'][k]);
            replayWindStation['lon'].add(liveWindStation['lon'][k]);
            replayWindStation['speed'].add(liveWindStation['speed'][k]);
            replayWindStation['course'].add(liveWindStation['course'][k]);
          }
        }
      } else {
        // we had no weather station with this name yet
        replayTracks['windtracks'].add(liveWindStation); // add the complete weather station
      }
    });
    //
    replayTracks['endtime'] = liveTrails['endtime']; // set the new endtime and store locally
    // browsers do not allow us to store more then 5 Mbyte. But for the rest: store/overwrite the updated tracks
    // using the eventId as unique identifier
    if (!kIsWeb) prefs.setString('live-$eventId', jsonEncode(replayTracks));
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // Routine to prepare info for ships, gps buoys and windstations after we received new tracks
  //
  void setupShipGpsBuoyAndWindInfo() {
    shipTimeIndex = List.filled(replayTracks['shiptracks'].length, 0, growable: true);
    shipList = [];
    teamList = [];
    shipLostSignalIndicators = [];
    shipColors = [];
    shipColorsSvg = [];
    shipMarkerList = [];
    shipLabelList = [];
    shipTrailList = [];
    for (int i = 0; i < replayTracks['shiptracks'].length; i++) {
      var ship = replayTracks['shiptracks'][i];
      shipList.add(ship['name']); // add the name to the shipList for the shipmenu
      ship['team'] = ship['team'] ?? "";
      teamList.add((ship['team'] != "") ? ship['team'] : "team ${ship['name']}");
      shipLostSignalIndicators.add('');
      shipColors.add(Color(shipMarkerColorTable[int.parse(ship['colorcode']) % 32])); // and the color code
      shipColorsSvg.add('#${((shipColors[i].value) - 0xFF000000).toRadixString(16).padLeft(6, '0')}');
      shipMarkerList.add(const Marker(point: LatLng(0, 0), child: SizedBox.shrink()));
      shipLabelList.add(const Marker(point: LatLng(0, 0), child: SizedBox.shrink()));
      shipTrailList.add(Polyline(points: [const LatLng(0, 0)]));
    }
    gpsBuoyTimeIndex = List.filled(replayTracks['buoytracks'].length, -1, growable: true);
    gpsBuoyMarkerList =
        List.filled(replayTracks['buoytracks'].length, const Marker(point: LatLng(0, 0), child: SizedBox.shrink()), growable: true);
    gpsBuoyLabelList =
        List.filled(replayTracks['buoytracks'].length, const Marker(point: LatLng(0, 0), child: SizedBox.shrink()), growable: true);
    windTimeIndex = List.filled(replayTracks['windtracks'].length, -1, growable: true);
    // note: one extra for the centerscreenwindmarker
    windMarkerList =
        List.filled(replayTracks['windtracks'].length + 1, const Marker(point: LatLng(0, 0), child: SizedBox.shrink()), growable: true);
  }

  //
  // a few widget creating routines
  //
  //----------------------------------------------------------------------------------------------------------------------------------------
  // one to create an infowindow that can be added to the map as a marker
  //
  Marker infoWindowMarker({required String title, required String body, required String link, required LatLng point}) {
    return Marker(
        point: point,
        alignment: const Alignment(0, -1.1),
        width: 200,
        height: 200,
        child: Wrap(alignment: WrapAlignment.center, runAlignment: WrapAlignment.end, children: [
          Card(
              color: Colors.white,
              child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
                    if (body != '')
                      MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                              onTap: (link == '')
                                  ? null
                                  : () => setState(() {
                                        showEventMenu = showShipMenu = showMapMenu = showShipInfo = false;
                                        launchUrl(Uri.parse(link));
                                      }),
                              child: Text(body, style: const TextStyle(fontSize: 12, color: Colors.black))))
                  ])))
        ]));
  }

  //
  // and a routine to create labels next to ships, buoys and route points
  //
  Marker mapTextLabel(LatLng point, String txt) {
    return Marker(
        point: point,
        width: 300,
        height: 30,
        alignment: const Alignment(0.95, 1.4),
        child: Wrap(alignment: WrapAlignment.start, children: [
          BorderedText(
              strokeWidth: 1.5,
              strokeColor: labelBackgroundColor,
              child: Text(txt, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: markerBackgroundColor)))
        ]));
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // Routines to get info from the server
  //
  //----------------------------------------------------------------------------------------------------------------------------------------
  // first the routine to get the tree of events
  //
  Future<Map<String, dynamic>> getDirList() async {
    final response = await http.get(Uri.parse('${server}get/?req=dirlist&dev=$phoneId${(testing) ? '&tst=true' : ''}'));
    Map<String, dynamic> dir = (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : {};
    dir.remove('_Shipinfo');
    return dir;
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // get the event info
  //
  Future<Map<String, dynamic>> getEventInfo(domain) async {
    final response = await http.get(Uri.parse('${server}get/?req=eventinfo&dev=$phoneId&event=$domain'));
    return (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : {};
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // get the list of colorcodes, shipnames and teamnames, for use in the participants menu during pre-event
  //
  getParticipants(domain) async {
    shipList = [];
    teamList = [];
    shipColors = [];
    final response = await http.get(Uri.parse('${server}get/?req=participants&dev=$phoneId&event=$domain'));
    final participants = (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : [];
    for (int i = 0; i < participants.length; i++) {
      shipColors.add(Color(shipMarkerColorTable[int.parse(participants[i]['colorcode']) % 32]));
      shipList.add(participants[i]['shipname']);
      teamList.add(participants[i]['teamname'] != '' ? participants[i]['teamname'] : 'Team ${participants[i]['shipname']}');
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // get the route geoJSON file
  //
  Future<Map<String, dynamic>> getRoute(domain) async {
    final response = await http.get(Uri.parse('${server}get/?req=route&dev=$phoneId&event=$domain'));
    return (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : {};
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // get the app icon url
  //
  Future<String> getAppIconUrl({event = ''}) async {
    final response = await http.get(Uri.parse('${server}get?req=appiconurl${(event == '') ? '' : '&event=$eventDomain'}&dev=$phoneId'));
    return (response.statusCode == 200)
        ? response.body.replaceFirst('/', '|', 8).split('|').last // remove servername from response
        : 'assets/assets/images/defaultAppIcon.png';
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // routine for getting a replay json file (during the event max 5 minutes old)
  // the optional noData and noStats parameters is just for statistics collected by the server
  // with noData = true, we will not receive any data back. This is used when we are running as a mobile app or a windows app and we
  // alreadu have replay data in shared preference data.
  // with noStats, the server will not log statistical data. This is done when we retreive replay data during live.
  //
  Future<Map<String, dynamic>> getReplayTracks(domain, {noData = false, noStats = false}) async {
    final response = await http.get(
        Uri.parse('${server}get/?req=replay&dev=$phoneId&event=$domain${noData ? '&nodata=true' : ''}${noStats ? '&nostats=true' : ''}'));
    return (response.statusCode == 200 && response.body != '') ? convertTimes(jsonDecode(response.body)) : {};
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // Same for the trails during the event, max eventInfo['trailsupdateinterval'] old (plus some margin, see server/get/index.php)
  // or from the time given in the fromTime parameter, in seconds ago. Note when you call this, the info is obtained from the database,
  // whereas in the case whithout the fromTime parameter, the info comes from a file that is updated only at the trailsupdateinterval
  //
  Future<Map<String, dynamic>> getTrails(domain, {fromTime = 0}) async {
    final response =
        await http.get(Uri.parse('${server}get/?req=trails&dev=$phoneId&event=$domain${(fromTime != 0) ? "&msg=$fromTime" : ""}'));
    return (response.statusCode == 200 && response.body != '') ? convertTimes(jsonDecode(response.body)) : {};
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // All timestamps in the file we receive from the server are in seconds. In the app we work with milliseconds so after getting the
  // jsonfile into a map, we need to multiply all stamps with 1000. To save us some null-checking lateron, we also add empty ship-, buoy-
  // and windtracks just in case they were not in the file
  //
  Map<String, dynamic> convertTimes(track) {
    track['starttime'] *= 1000;
    track['endtime'] *= 1000;
    track['shiptracks'] ??= [];
    track['shiptracks'].forEach((ship) => ship['stamp'] = ship['stamp'].map((timeStamp) => timeStamp * 1000).toList());
    track['buoytracks'] ??= [];
    track['buoytracks'].forEach((buoy) => buoy['stamp'] = buoy['stamp'].map((timeStamp) => timeStamp * 1000).toList());
    track['windtracks'] ??= [];
    track['windtracks'].forEach((station) => station['stamp'] = station['stamp'].map((timeStamp) => timeStamp * 1000).toList());
    return track;
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // routine to get shipInfo from the server and show it in a draggable window (see uiShipInfo widget)
  //
  void loadAndShowShipDetails(shipname) async {
    bool team = bool.parse(eventInfo['showteam'] ?? 'false');
    final response = await http.get(Uri.parse('${server}get/?req=shipinfo&dev=$phoneId&event=$eventDomain'
        '&ship=${Uri.encodeQueryComponent(shipname)}&team=${team ? 'true' : 'false'}'));
    shipInfoHTML = (response.statusCode == 200 && response.body != '') ? response.body : 'Could not load ship info';
    shipInfoHTML = shipInfoHTML.replaceFirst('Schipper:', '${config['text']['skipper'] ?? 'Schipper'}:');
    if (!showShipInfo) shipInfoPosition = Offset(55, menuOffset + 50);
    showShipInfo = true;
    setState(() {});
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // routines to convert wind knots into Beaufort and SVG colors
  //
  int knotsToBft(speedInKnots) {
    const List<int> windKnots = [0, 1, 3, 6, 10, 16, 21, 27, 33, 40, 47, 55, 63, 999];
    return windKnots.indexOf(windKnots.firstWhere((i) => i >= speedInKnots)).toInt();
  }

  String knotsToColor(speedInKnots) {
    List windColorTable = [
      '#ffffff',
      '#ffffff',
      '#c1fcf9',
      '#7ef8f3',
      '#24fc54',
      '#b2f500',
      '#ff5225',
      '#ff08d1',
      '#e50cff',
      '#b026ff',
      '#8334ff',
      '#7f0000',
      '#000000'
    ];
    return windColorTable[knotsToBft(speedInKnots)];
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // routine to predict new location, based on initial location, speed in km/h, time in milliseconds and course in degrees
  //
  LatLng predictPosition(LatLng initialPosition, double speed, int time, int course) {
    var rdist = (speed / 3600) * time / earthRadius; // angular distance in radians
    var rcourse = course * pi / 180; // course in radians
    var rlat1 = initialPosition.latitudeInRad; // last known position in radians
    var rlon1 = initialPosition.longitudeInRad;
    var rlat2 = asin(sin(rlat1) * cos(rdist) + cos(rlat1) * sin(rdist) * cos(rcourse));
    var rlon2 = rlon1 + atan2(sin(rcourse) * sin(rdist) * cos(rlat1), cos(rdist) - sin(rlat1) * sin(rlat2));
    rlon2 = ((rlon2 + (3 * pi)) % (2 * pi)) - pi; // normalise to -180..+180º
    return LatLng(rlat2 * 180 / pi, rlon2 * 180 / pi);
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  // routine to calculate the weighted average wind speed and direction based on nrStations nearest to the center of the screen
  //
  ({int heading, double speed}) centerWind(nrStations) {
    var windTracks = replayTracks['windtracks'];
    Map<int, double> unsortedDistanceTable = {}; // map with station index in the windTracks as key and the distance as value
    var distance = const Distance();
    List<double> eastWestVectors = [];
    List<double> northSouthVectors = [];
    List<double> distanceFactors = [];
    double eastWestSum = 0;
    double northSouthSum = 0;
    // get the distances from the center of the screen to all Buienradar stations
    for (int i = 0; i < windTracks.length; i++) {
      unsortedDistanceTable.addAll({
        i: distance.as(
            LengthUnit.Meter, mapController.camera.center, LatLng(windTracks[i]['lat'][0].toDouble(), windTracks[i]['lon'][0].toDouble()))
      });
    }
    // sort the map from near to far (values)
    var distanceTable = unsortedDistanceTable.entries.toList()
      ..sort((e1, e2) {
        var diff = e1.value.compareTo(e2.value);
        if (diff == 0) diff = e1.key.compareTo(e2.key);
        return diff;
      });
    // get relevant info of the nearest stations in a number of lists
    // first the sum of the distances to the nearest stations
    double sumDistances = distanceTable.take(nrStations).fold(0, (sum, element) => sum + element.value);
    // now create a list with 'reverse' distancefactors (nearest has highest value, but sum is higher then 1.0)
    // and in the same loop lists for East-West and NorthSouth vectors using the speed and direction values in windTracks
    for (int i = 0; i < nrStations; i++) {
      distanceFactors.add(1 - (distanceTable[i].value / sumDistances));
      var windDirection = (windTracks[distanceTable[i].key]['course'][windTimeIndex[distanceTable[i].key]] * pi / 180).toDouble();
      var windSpeed = windTracks[distanceTable[i].key]['speed'][windTimeIndex[distanceTable[i].key]].toDouble();
      eastWestVectors.add(windSpeed * cos(windDirection));
      northSouthVectors.add(windSpeed * sin(windDirection));
    }
    // normalize the 'reversed' distancefactors to 1.0 (again) and use the elements to
    // calculate the weighted vector at the center of the screen
    sumDistances = distanceFactors.sum;
    distanceFactors = distanceFactors.map((factor) => factor / sumDistances).toList();
    for (int i = 0; i < nrStations; i++) {
      eastWestSum += eastWestVectors[i] * distanceFactors[i];
      northSouthSum += northSouthVectors[i] * distanceFactors[i];
    }
    // and return the result
    return (heading: atan2(northSouthSum, eastWestSum) * 180 ~/ pi, speed: sqrt(pow(eastWestSum, 2) + pow(northSouthSum, 2)));
  }

  void setUnsetTestingActions() async {
    // clear the test string under the time slider (currently set in replayTickerRoutine if testing is true)
    if (!testing) debugString = '';
    // get a new dirlist WITH (or without, depending on the value of testing) domain name items starting with an underscore
    dirList = await getDirList();
    eventNameList = dirList.keys.toList()..sort;
    eventYearList = [];
    eventDayList = [];
    // redraw the route with or without the geofence polygons in line with the testing boolean
    buildRoute();
  }
}
