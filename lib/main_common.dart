//
// Track & Trace app, oorspronkelijk voor zeilwedstrijden met historische zeilende bedrijfsvaartuigen,
// maar ook geschikt voor het volgen van deelnemers aan sloeproeiwedstrijden en het volgen van huurboten.
//
// © 2010 - 2023 Stichting Zeilvaart Warmond / Henk Keijzer
//
// Version history in README.md
//

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_html/flutter_html.dart' show Html;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

//
// server and packageinfo
String server = 'https://tt.zeilvaartwarmond.nl/';
bool mobileAppAvailable = true;
late PackageInfo packageInfo;
//
// icons and default texts
String appIconUrl = ''; // appIcon is set in eventInfo, url is retreived by get?req=appiconurl
IconData boatIcon = Icons.sailing; // set default icon for "deelnemrs", overruled by config/flutter_config.json
String participants = 'schepen'; // set defaultvalues voor participants and shipname texts
String shipNames = 'Scheepsnamen'; // these values can be overruled in config/flutter_config.json
String skipper = 'Schipper:';
//
// devicetype / platformtype
final kIsMobile = (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
final kIsDesktop = (defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux);
final webOnMobile = kIsWeb && kIsMobile; // true if the user is running the web app on a mobile device
//
String phoneId = "";
//
// (default) Colors (are overruled by colors in config/flutter_config.json
Color? menuBackgroundColor = Colors.red[700];
Color menuForegroundColor = Colors.white70;
Color? infoPageColor = Colors.blueGrey[200];
//
const String hexBlack = '#000000';
const String hexWhite = '#ffffff';
//
// vars for getting physical device info and the phoneId
late MediaQueryData queryData; // needed for getting the screen width and height
double menuOffset = 0; // used to calculate the offset of the menutext from the top of the screen
int screenWidth = 0;
int screenHeight = 0;
//
// variables for the flutter_map
final mapController = MapController();
const initialMapPosition = LatLng(52.2, 4.8);
const double initialMapZoom = 8;
//
// vars for the selection of the event
late SharedPreferences prefs; // local parameter storage
Map<String, dynamic> dirList = {}; // see get-dirlist.php on the server
Map<String, dynamic> eventInfo = {}; // see get-eventinfo.php on the server
List<String> eventList = [];
List<String> eventYearList = [];
List<String> eventDayList = [];
String eventDomain = '';
String eventId = '';
String eventName = 'Kies een evenement';
String eventYear = '';
String eventDay = '';
//
// eventinfo (related) variables
int eventStart = 0; // evenInfo['eventstartstamp']
int eventEnd = 0; // eventInfo['eventendstamp']
int sliderEnd = 0;
int maxReplay = 0;
//    // eventInfo['maxreplay'] in hours = sets eventbegin xx hours before current time to limit the replay for continuous events (Olympia-charters)
bool hfUpdate = false; // eventInfo['hfupdate']. If 'true', positions are predicted every second during live
int trailsUpdateInterval = 60; // eventInfo['trailsupdateinterval'], in seconds between two subsequent get-trails requests from the db
int eventTrailLength = 30; // eventInfo['traillength']
int actualTrailLength = 30;
String socialMediaUrl = ''; // eventInfo['mediaframe']
String eventStatus = ''; // 'pre-event' || 'live' || 'replay'
//
// vars for the tracks and the markers
Map<String, dynamic> replayTracks = {}; // see get-replay.php on the server
Map<String, dynamic> liveTrails = {}; // see get-trails.php on the server
Map<String, dynamic> route = {}; // geoJSON structure with the route
//
// extract from the live/replaytracks above to make addressing the info a bit simplet
List<String> shipList = []; // list with ship names
List<int> shipColors = []; // corresponding list of ship colors
List<String> shipColorsSvg = []; //same list but as a svg string
//
// lists for markers and polylines, created in moveShipsTo and moveWindTo
List<Marker> shipMarkerList = [];
List<Marker> shipLabelList = [];
List<Polyline> shipTrailList = [];
List<Marker> windMarkerList = [];
List<Marker> routeMarkerList = [];
List<Polyline> routeLineList = [];
List<Marker> routeLabelList = [];
List<Marker> infoWindowMarkerList = [];
//
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
// variables used for following ships and zooming
Map<String, bool> following = {};
int followCounter = 0;
bool followAll = true;
bool autoZoom = true;
bool autoFollow = true;
bool hideFloatingActionButtons = false;
//
// vars for the movement of ships and wind markers in time
const speedIndexInitialValue = 4.0;
double speedIndex = speedIndexInitialValue; // index in the following table en position of the speed slider, default = 3 min/sec
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
List shipTimeIndex = []; // for each ship the time position in its list of stamps
List windTimeIndex = []; // for each weather station the time position in the list of stamps
//
// timers and replay related vars
late Timer replayTimer;
late Timer liveTimer;
late Timer preEventTimer;
int liveSecondsTimer = 60;
int currentReplayTime = 0;
bool replayRunning = false;
bool replayPause = false;
const int replayUpdatesPerSecond = 20;
const int replayRate = 1000 ~/ replayUpdatesPerSecond;
bool replayLoop = false;
//
// UI messages in the EventSelection menu
String selectionMessage = '';
String eventTitle = "Kies een evenement";
//
bool showEventMenu = false;
bool showMapMenu = false;
bool showShipMenu = false;
bool showInfoPage = false;
bool showShipInfo = false;
bool showAttribution = false;
bool showProgress = false;
bool cookieConsentGiven = false;
bool fullScreen = false;
String infoPageHTML = ''; // HTML text for the info page from {server}/config/app-info-page.html
//
bool testing = false; // double tap the title of the app to set to true.
//                    // Will cause the underscored events to be in the dirList
//
// map related vars
// set up an initial single default maptileprovider
Map<String, dynamic> mapTileProviderData = {
  'Standaard': {
    'service': 'WMTS',
    'URL': 'https://service.pdok.nl/brt/achtergrondkaart/wmts/v2_0/standaard/EPSG:3857/{z}/{x}/{y}.png',
    'subDomains': [],
    'labels': 'false',
    'maxZoom': 19.0,
    'bgColor': hexBlack,
    'attrib': 'Kadaster',
    'attribLink': 'https://www.kadaster.nl'
  },
};
String selectedMapType = mapTileProviderData.keys.toList()[0];
String markerBackgroundColor = mapTileProviderData[selectedMapType]['bgColor'];
String labelBackgroundColor = (markerBackgroundColor == hexBlack) ? hexWhite : hexBlack;
Map<String, dynamic> overlayTileProviderData = {};
String selectedOverlayType = '';
bool mapOverlay = false;
//
// Style for vector type maps
Style? baseMapStyle; // a vector base map
Style? overlayMapStyle; // a vector overlay map
Style? labelOverlayStyle; // a vector label overlay for satellite type base maps TODO
//
// default values for some booleans
bool windMarkersOn = true;
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
// the Id of the markerInfoWindow, rout/wind/ship+xxx, or blank
String infoWindowId = '';
//
// used to create/retrieve query parameterd when we press fullscreen on an <iframed>> web page
String queryPlayString = '';
//
// Global Keys for programmatically opening the dropdown lists
final GlobalKey dropEventKey = GlobalKey();
final GlobalKey dropYearKey = GlobalKey();
final GlobalKey dropDayKey = GlobalKey();

//------------------------------------------------------------------------------
//
// Here our app starts (more or less)
//
Future mainCommon(baseURL) async {
  WidgetsFlutterBinding.ensureInitialized();
  server = baseURL;
  packageInfo = await PackageInfo.fromPlatform(); // get some info of the platform we are running on
  prefs = await SharedPreferences.getInstance(); // get access to local storage

  // ----- APP VERSION
  // See if we are running a new version and if so, clear local storage and save the new version number
  var oldAppVersion = prefs.getString('appversion') ?? '';
  if (oldAppVersion != packageInfo.buildNumber) {
    await prefs.clear(); // clear all data (and wait for it...)
    prefs.setString('appversion', packageInfo.buildNumber); // and set the appversion
  }

  // ----- PHONE ID
  // See if we already have a phone id, if not, create one and save it in loval storage
  phoneId = prefs.getString('phoneid') ?? '';
  if (phoneId == '') {
    var uuid = const Uuid();
    phoneId = uuid.v1(); // generate a new phoneID
    prefs.setString('phoneid', phoneId); // and save it
  }
  // create a prefix for the phoneId consisting of a letter (F for Flutter Web, A, for Android, I for iOS and W for Windows),
  // followed by the 3 digit version of the app and a dash
  String prefix = "";
  if (kIsWeb) {
    prefix = "F";
  } else {
    prefix = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'A',
      TargetPlatform.iOS => 'I',
      TargetPlatform.windows => 'W',
      TargetPlatform.macOS => 'M',
      TargetPlatform.linux => 'L',
      TargetPlatform.fuchsia => 'U',
    };
  }
  phoneId = '$prefix${packageInfo.buildNumber}-$phoneId'; // use the saved phoneId with a platform/buildnumber prefix

  // ----- SERVER
//  server = kIsWeb ? "https://${window.location.hostname}/" : 'https://tt.zeilvaartwarmond.nl/';
  // if the server name is not tt.zeilvaartwarmond.nl, we do not have an Android or iOS app available
  mobileAppAvailable = (server == 'https://tt.zeilvaartwarmond.nl/');

  // ----- CONFIG
  // get the appconfig items from the flutter_config.json file on the server config folder
  // note that we get the config file through /get/index.php to record statistics on the number of times the app is started
  var response = await http.get(Uri.parse('${server}get/?req=config&dev=$phoneId'));
  Map<String, dynamic> config = (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : {};
  //
  // set some text, color and icon values based on the info in the config file
  participants = config['text']['participants'] ?? participants;
  shipNames = config['text']['shipNames'] ?? shipNames;
  skipper = config['text']['skipper'] ?? skipper;
  menuBackgroundColor = Color(int.parse(config['colors']['menuBackgroundColor'], radix: 16));
  menuForegroundColor = Color(int.parse(config['colors']['menuForegroundColor'], radix: 16));
  infoPageColor = Color(int.parse(config['colors']['infoPageColor'], radix: 16));
  boatIcon = switch (config['icons']['boatIcon']) {
    'sailing' => Icons.sailing,
    'rowing' => Icons.rowing,
    'motorboat' => Icons.directions_boat,
    _ => Icons.sailing
  };
  response = await http.get(Uri.parse('${server}get?req=appiconurl&dev=$phoneId'));
  appIconUrl = (response.statusCode == 200) ? response.body : '${server}assets/assets/images/defaultAppIcon.png';

  // ----- INFOPAGE
  // get the info page contents
  response = await http.get(Uri.parse('${server}config/app-info-page.html'));
  infoPageHTML = (response.statusCode == 200) ? response.body : '';
  infoPageHTML += (infoPageHTML != '') ? '<br><br>' : '<html><body>';
  infoPageHTML += '${packageInfo.appName}, Versie ${packageInfo.version}<br>'
      '${packageInfo.packageName}<br>$server</body></html>';

  // ----- BASE MAP
  // get the complete list of map tile providers from the server
  response = await http.get(Uri.parse('${server}get?req=maptileproviders&dev=$phoneId'));
  Map<String, dynamic> mapdata = (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : {};
  mapTileProviderData = mapdata['basemaps'] ?? {};
  overlayTileProviderData = mapdata['overlays'] ?? {};
  //
  // Get the selectedmaptype from local storage (from a previous session)
  // or set the default to the first maptype if null
  selectedMapType = prefs.getString('maptype') ?? mapTileProviderData.keys.toList()[0];
  // are we overruled by a query parameter?
  if (kIsWeb && Uri.base.queryParameters.containsKey('map')) {
    selectedMapType = Uri.base.queryParameters['map'].toString(); //get parameter with attribute "map"
  }
  // see if the map we want is in our list of maps, if not, set maptype to first maptype
  if (!mapTileProviderData.keys.toList().contains(selectedMapType)) {
    selectedMapType = mapTileProviderData.keys.toList()[0];
  }
  // save the base maptype for next time
  prefs.setString('maptype', selectedMapType);
  markerBackgroundColor = mapTileProviderData[selectedMapType]['bgColor'];
  labelBackgroundColor = (markerBackgroundColor == hexBlack) ? hexWhite : hexBlack;

// TODO: als vectormap beschikbaar voor alle platforms
//  if (mapTileProviderData[selectedMapType]['service'] == 'vector') {
//    baseMapStyle = await StyleReader(uri: mapTileProviderData[selectedMapType]['URL'], apiKey: '').read();
//  }

  // ----- MAP OVERLAY
  // now the same for the map overlay and the map overlaytype
  mapOverlay = prefs.getBool('mapoverlay') ?? false;
  selectedOverlayType = prefs.getString('overlaytype') ?? '';
  if (kIsWeb && Uri.base.queryParameters.containsKey('overlay')) {
    var a = Uri.base.queryParameters['overlay'].toString().split(':');
    mapOverlay = (a[0] == 'true') ? true : false;
    selectedOverlayType = a[1];
  }
  mapOverlay = overlayTileProviderData.isNotEmpty ? mapOverlay : false;
  if (overlayTileProviderData.isEmpty) {
    // are there any overlayTileProviders defined?
    selectedOverlayType = ''; // no
  } else {
    // does the list contain the overlaymaptype from the previous session
    selectedOverlayType = (overlayTileProviderData.keys.toList().contains(selectedOverlayType))
        ? selectedOverlayType
        : overlayTileProviderData.keys.toList()[0]; // if not, use entry 0
  }
  prefs.setBool('mapoverlay', mapOverlay);
  prefs.setString('overlaytype', selectedOverlayType);
  //
  // get the style of the maplabeloverlay TODO: als vector tiles beschikbaar is voor web
//  labelOverlayStyle = await StyleReader(uri: '${server}config/labeloverlaystyleroot.json', apiKey: '').read();

  // ----- EVENT DOMAIN
  // Get the event domain from a previous session or from the query string, if not, set default to an ampty string
  eventDomain = prefs.getString('domain') ?? "";
  if (kIsWeb && Uri.base.queryParameters.containsKey('event')) {
    eventDomain = Uri.base.queryParameters['event'].toString(); //get parameter with attribute "event"
  }
  //
  if (kIsWeb && Uri.base.queryParameters.containsKey('play')) {
    queryPlayString = Uri.base.queryParameters['play'].toString(); //get parameter with attribute "play"
    // consists of 3 values, separated by a ':' namely
    // a[0] true/false, is the event playin yes/no
    // a[1] the currentreplaytime, and
    // a[2] the replayspeed
  }

  // ----- WINDMARKERS, ROUTE, ROUTELABELS, SHIPLABELS, SHIPSPEEDS and COOKIECONSENT
  // get/set some other shared preference stuff (set default if value was not present in prefs)
  windMarkersOn = prefs.getBool('windmarkers') ?? windMarkersOn;
  prefs.setBool('windmarkers', windMarkersOn);
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
  prefs.setBool('shipspeeds', showShipSpeeds);
  //
  cookieConsentGiven = prefs.getBool('cookieconsent') ?? false;
  prefs.setBool('cookieconsent', cookieConsentGiven);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

//
// The main program
//
class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // needed to get the MediaQuery working
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (eventStatus == 'live') {
          liveSecondsTimer = 1;
          liveTimer = Timer.periodic(const Duration(seconds: 1), (liveTimer) {
            liveTimerRoutine();
          });
        }
        if (replayRunning) {
          replayTimer = Timer.periodic(const Duration(milliseconds: replayRate), (replayTimer) {
            replayTimerRoutine();
          });
        }
        break;
      case AppLifecycleState.inactive:
        if (eventStatus == 'live') {
          liveTimer.cancel();
        }
        if (replayRunning) {
          replayTimer.cancel();
        }
        break;
      case AppLifecycleState.paused:
        if (eventStatus == 'live') {
          liveTimer.cancel();
        }
        if (replayRunning) {
          replayTimer.cancel();
        }
        break;
      case AppLifecycleState.detached:
        if (eventStatus == 'live') {
          liveTimer.cancel();
        }
        if (replayRunning) {
          replayTimer.cancel();
        }
        break;
      default:
        break;
    }
  }

  //----------------------------------------------------------------------------
  //
  // Here starts the flutter UI
  // Still relatively simple, because our App has only one page, so no navigation to other pages
  // The UI is rebuilt each time the state of the info to be displayed needs to be updated to the screen.
  // this is not done automatically but only after calling setState. The info to be displayed is in
  // variables manipulated by the routines of the app
  //
  @override
  Widget build(BuildContext context) {
    // define the appbar here as a seperate widget, so that we can use it's height when positioning the menu's
    AppBar myAppBar = AppBar(
      backgroundColor: menuBackgroundColor?.withOpacity((showShipMenu || showInfoPage || showEventMenu || showMapMenu) ? 1 : 0.4),
      foregroundColor: menuForegroundColor,
      elevation: 0,
      titleSpacing: 5.0,
      leading: IconButton(
          // tappable appIcon of the T&T organization
          tooltip: showEventMenu ? 'sluit menu' : 'evenementmenu',
          padding: const EdgeInsets.all(0),
          icon: Image.network(appIconUrl),
          onPressed: () => setState(() {
                showShipMenu = showMapMenu = showInfoPage = showShipInfo = showAttribution = false;
                showEventMenu = replayPause = !showEventMenu;
              })),
      title: InkWell(
        onTap: () => setState(() {
          showShipMenu = showMapMenu = showInfoPage = showShipInfo = showAttribution = false;
          showEventMenu = replayPause = !showEventMenu;
        }),
        onDoubleTap: () async {
          // toggles testing mode and reloads the dirList, with or without underscored events
          testing = !testing;
          dirList = await getDirList();
          eventList = [];
          dirList.forEach((k, v) => eventList.add(k));
          eventYearList = [];
          eventDayList = [];
        },
        child: Tooltip(message: eventTitle, child: Text(eventTitle)),
      ),
      actions: [
        if (kIsWeb)
          IconButton(
            // button for fullscreen on web and desktop
            visualDensity: VisualDensity.compact,
            tooltip: fullScreen
                ? 'exit fullscreen'
                : document.referrer == ''
                    ? 'fullscreen'
                    : 'open in een nieuw tabblad',
            onPressed: () => setState(() {
              if (document.referrer == '') {
                fullScreen = !fullScreen;
                fullScreen ? document.documentElement?.requestFullscreen() : document.exitFullscreen();
              } else {
                launchUrl(Uri.parse('https://${window.location.hostname}?event=$eventDomain&map=$selectedMapType'
                    '&overlay=${mapOverlay ? 'true' : 'false'}:$selectedOverlayType'
                    '&play=${replayRunning ? 'true' : 'false'}:${currentReplayTime == sliderEnd ? '0' : currentReplayTime.toString()}:$speedIndex'));
                if (replayRunning) startStopRunning();
              }
            }),
            icon: fullScreen ? const Icon(Icons.fullscreen_exit) : const Icon(Icons.fullscreen),
          ),
        if (kIsDesktop && !kIsWeb)
          IconButton(
            // button for fullscreen on windows or macOS app
            visualDensity: VisualDensity.compact,
            tooltip: fullScreen ? 'exit fullscreen' : 'fullscreen',
            onPressed: () => setState(() {
              fullScreen = !fullScreen;
              fullScreen ? FullScreenWindow.setFullScreen(true) : FullScreenWindow.setFullScreen(false);
            }),
            icon: (fullScreen) ? const Icon(Icons.fullscreen_exit) : const Icon(Icons.fullscreen),
          ),
        IconButton(
          // button for the infoPage
          visualDensity: VisualDensity.compact,
          tooltip: showInfoPage ? 'sluit infopagina' : 'infopagina',
          onPressed: () => setState(() {
            showEventMenu = showShipMenu = showMapMenu = showShipInfo = showAttribution = false;
            showInfoPage = replayPause = !showInfoPage;
          }),
          icon: const Icon(Icons.info), //Image.asset('assets/images/ic_info_button.png'),
        ),
        IconButton(
          // button for the mapMenu
          visualDensity: VisualDensity.compact,
          tooltip: showMapMenu ? 'sluit menu' : 'kaartmenu',
          onPressed: () => setState(() {
            showEventMenu = showShipMenu = showInfoPage = showShipInfo = showAttribution = false;
            showMapMenu = replayPause = !showMapMenu;
          }),
          icon: const Icon(Icons.map),
        ),
        IconButton(
          // button for the shipList
          visualDensity: VisualDensity.compact,
          tooltip: showShipMenu ? 'sluit menu' : 'deelnemers',
          onPressed: () {
            if (eventStatus != 'pre-event' && shipList.isNotEmpty) {
              setState(() {
                showEventMenu = showMapMenu = showInfoPage = showShipInfo = showAttribution = false;
                showShipMenu = replayPause = !showShipMenu;
              });
            }
          },
          icon: Icon(boatIcon),
        ),
      ],
    );
    // Return the UI as a MaterialApp with title, theme and a home (with a Scaffold)
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: eventTitle,
      theme: ThemeData(
        canvasColor: menuBackgroundColor,
        unselectedWidgetColor: menuForegroundColor,
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: menuForegroundColor, fontSize: 15),
        ),
      ),
      home: Builder(builder: (BuildContext context) {
        screenWidth = MediaQuery.of(context).size.width.toInt();
        screenHeight = MediaQuery.of(context).size.height.toInt();
        // menuOffset is the heigth of the appBar + the notification area above the appbar on mobile
        // we need to calcualte this because we extend the map behind the appBar and the notification area
        // On Windows and web the height of the notification area = 0
        menuOffset = MediaQuery.of(context).viewPadding.top + myAppBar.preferredSize.height;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: myAppBar,
          body: Stack(
            children: [
              uiFlutterMap(),
              if (eventStatus != 'pre-event' && shipList.isNotEmpty) uiSliderArea(), // including speedSlider, ActionButtons, timeSlider
              uiAttribution(),
              if (showEventMenu) uiEventMenu().animate(effects: [const SlideEffect()]),
              if (showInfoPage) uiInfoPage().animate(effects: [const SlideEffect()]),
              if (showMapMenu) uiMapMenu().animate(effects: [const SlideEffect()]),
              if (showShipMenu) uiShipMenu().animate(effects: [const SlideEffect()]),
              if (showShipInfo) uiShipInfo().animate(effects: [const SlideEffect()]),
              if (!cookieConsentGiven) uiCookieConsent(),
              if (showProgress) uiProgressIndicator(),
            ],
          ),
        );
      }),
    );
  }

  //----------------------------------------------------------------------------
  //
  // the UI elements called above. The names speak for themselves
  //
  FlutterMap uiFlutterMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
          onMapReady: onMapCreated,
          initialCenter: initialMapPosition,
          initialZoom: initialMapZoom,
          maxZoom: mapTileProviderData[selectedMapType]['maxZoom'],
          backgroundColor: Colors.blueGrey,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onTap: (_, __) => setState(() {
                // on tapping the map: close all popups and menu's, and show the floatingaction buttons again
                infoWindowId = '';
                infoWindowMarkerList = [];
                showEventMenu = showMapMenu =
                    showShipMenu = showShipInfo = showInfoPage = replayPause = showAttribution = hideFloatingActionButtons = false;
              }),
          onLongPress: (kIsWeb) // TODO als flutter maps een betere gesture handling heeft voor web
              ? null
              : (_, latlng) {
                  if (eventStatus == 'live' || eventStatus == 'pre-event') {
                    launchUrl(Uri.parse('https://embed.windy.com/embed2.html?lat=${latlng.latitude}&lon=${latlng.longitude}'
                        '&detailLat=${latlng.latitude}&detailLon=${latlng.longitude}'
                        '&width=$screenWidth&height=$screenHeight&zoom=11&level=surface&overlay=wind&product=ecmwf&menu=&message=true&marker='
                        '&calendar=now&pressure=&type=map&location=coordinates&detail=true&metricWind=bft&metricTemp=%C2%B0C&radarRange=-1'));
                  }
                }),
      children: [
        // five children: the base map, the optional labeloverlay for satellite maps (disabled until vector_map_tiles is available for web),
        // the optional overlay map, the route polylines and all markers/textlabels
        //
        // the selected base map layer with three options, WMS, WMTS or vector todo
        switch (mapTileProviderData[selectedMapType]['service']) {
          "WMS" => TileLayer(
              wmsOptions: WMSTileLayerOptions(
                baseUrl: mapTileProviderData[selectedMapType]['wmsbaseURL'],
                layers: mapTileProviderData[selectedMapType]['wmslayers'].cast<String>(),
              ),
              tileProvider: CancellableNetworkTileProvider(),
              keepBuffer: 1000,
              panBuffer: 3,
              tileDisplay: const TileDisplay.instantaneous(),
              evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
              userAgentPackageName: packageInfo.packageName,
            ),
          "WMTS" => TileLayer(
              urlTemplate: mapTileProviderData[selectedMapType]['URL'],
              subdomains: List<String>.from(mapTileProviderData[selectedMapType]['subDomains']),
              tileProvider: CancellableNetworkTileProvider(),
              keepBuffer: 1000,
              panBuffer: 3,
              tileDisplay: const TileDisplay.instantaneous(),
              evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
              userAgentPackageName: packageInfo.packageName,
            ),
          'vector' => VectorTileLayer(
              tileProviders: baseMapStyle!.providers,
              theme: baseMapStyle!.theme,
              sprites: baseMapStyle?.sprites,
            ),
          _ => const SizedBox()
        },
        //
/*        // the (vector) label layer, mainly for satellite base maps
        if ((mapTileProviderData[selectedMapType]['labels'] ?? 'true') == 'true')
          VectorTileLayer(
            tileProviders: labelOverlayStyle!.providers,
            theme: labelOverlayStyle!.theme,
            sprites: labelOverlayStyle?.sprites,
          ),
*/ //
        // the tilelayer for the overlays, showing waterways, etc
        if (mapOverlay && overlayTileProviderData.isNotEmpty)
          switch (overlayTileProviderData[selectedOverlayType]['service']) {
            'WMS' => TileLayer(
                wmsOptions: WMSTileLayerOptions(
                  baseUrl: overlayTileProviderData[selectedOverlayType]['wmsbaseURL'],
                  layers: overlayTileProviderData[selectedOverlayType]['wmslayers'].cast<String>(),
                ),
                tileProvider: CancellableNetworkTileProvider(),
                keepBuffer: 1000,
                panBuffer: 3,
                tileDisplay: const TileDisplay.instantaneous(),
                evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
                userAgentPackageName: packageInfo.packageName,
              ),
            'WMTS' => TileLayer(
                urlTemplate: overlayTileProviderData[selectedOverlayType]['URL'],
                subdomains: List<String>.from(overlayTileProviderData[selectedOverlayType]['subDomains']),
                tileProvider: CancellableNetworkTileProvider(),
                keepBuffer: 1000,
                panBuffer: 3,
                tileDisplay: const TileDisplay.instantaneous(),
                evictErrorTileStrategy: EvictErrorTileStrategy.notVisible,
                userAgentPackageName: packageInfo.packageName,
              ),
            'vector' => VectorTileLayer(
                tileProviders: overlayMapStyle!.providers,
                theme: overlayMapStyle!.theme,
                sprites: overlayMapStyle?.sprites,
              ),
            _ => const SizedBox()
          },
        //
        // two more layers: the lines of the route and trails, and the markers
        PolylineLayer(polylines: routeLineList + shipTrailList),
        MarkerLayer(markers: routeLabelList + routeMarkerList + windMarkerList + shipLabelList + shipMarkerList + infoWindowMarkerList),
      ],
    );
  }

  Container uiSpeedSlider() {
    Color sliderColor = (markerBackgroundColor == hexBlack) ? Colors.black38 : Colors.white60;
    Color thumbColor = (markerBackgroundColor == hexBlack) ? Colors.black38 : Colors.white;
    return Container(
        color: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
          IconButton(
              tooltip: 'sneller',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => speedIndex = (speedIndex == speedTable.length - 1) ? speedTable.length - 1 : speedIndex + 1),
              icon: Icon(Icons.add, color: sliderColor)),
          RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: sliderColor,
                inactiveTrackColor: sliderColor,
                thumbColor: thumbColor,
              ),
              child: Slider(
                value: speedIndex,
                min: 0,
                max: speedTable.length - 1,
                divisions: speedTable.length - 1,
                onChanged: (speed) => setState(() => speedIndex = speed),
                onChangeEnd: (speed) => setState(() => speedIndex = speed),
              ),
            ),
          ),
          IconButton(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
              tooltip: 'langzamer',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => speedIndex = (speedIndex == 0) ? 0 : speedIndex - 1),
              icon: Icon(Icons.remove, color: sliderColor)),
        ]));
  }

  Column uiActionButtons() {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (autoFollow)
        FloatingActionButton(
          foregroundColor: menuForegroundColor,
          backgroundColor: menuBackgroundColor?.withOpacity(0.5),
          elevation: 5,
          onPressed: () => setState(() {
            autoZoom = !autoZoom;
            moveShipsAndWindTo(currentReplayTime);
          }),
          child: Text(autoZoom ? 'auto\nzoom\nuit' : 'auto\nzoom', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ),
      const SizedBox(width: 0, height: 10),
      FloatingActionButton(
        foregroundColor: menuForegroundColor,
        backgroundColor: menuBackgroundColor?.withOpacity(0.5),
        elevation: 5,
        onPressed: () => setState(() {
          autoFollow = !autoFollow;
          if (autoFollow) autoZoom = true;
          moveShipsAndWindTo(currentReplayTime);
        }),
        child: Text(autoFollow ? 'auto\nvolgen\nuit' : 'auto\nvolgen', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
      ),
    ]);
  }

  Container uiTimeSlider() {
    Color sliderColor = (markerBackgroundColor == hexBlack) ? Colors.black38 : Colors.white60;
    Color thumbColor = (markerBackgroundColor == hexBlack) ? Colors.black38 : Colors.white;
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 0, 15, 0),
      child: Row(children: [
        IconButton(
            padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
            tooltip: replayRunning ? 'stop replay' : 'start replay',
            onPressed: startStopRunning,
            icon: replayRunning
                ? const Icon(Icons.pause_presentation, color: Colors.red, size: 30)
                : const Icon(Icons.slideshow, color: Colors.green, size: 30)),
        //Image.asset('assets/images/pause.png') : Image.asset('assets/images/play.png')),
        Expanded(
            // and the time slider, expanding it to the rest of the row
            child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: sliderColor,
                  inactiveTrackColor: sliderColor,
                  thumbColor: thumbColor,
                ),
                child: Slider(
                  min: eventStart.toDouble(),
                  max: sliderEnd.toDouble(),
                  value: (currentReplayTime < eventStart || currentReplayTime > sliderEnd)
                      ? eventStart.toDouble()
                      : currentReplayTime.toDouble(),
                  onChangeStart: (x) => replayPause = true,
                  // pause the replay
                  onChanged: (time) => setState(() {
                    currentReplayTime = time.toInt();
                    if (time == sliderEnd) {
                      replayTimer.cancel();
                      replayRunning = false;
                    }
                    moveShipsAndWindTo(currentReplayTime);
                  }),
                  onChangeEnd: (time) => setState(() {
                    // resume play, but stop at end
                    currentReplayTime = time.toInt();
                    replayPause = false;
                    if (sliderEnd - time < 60 * 1000) {
                      // within one minute of sliderEnd
                      currentReplayTime = sliderEnd;
                      replayTimer.cancel();
                      replayRunning = false;
                    }
                    moveShipsAndWindTo(currentReplayTime);
                  }),
                ))),
      ]),
    );
  }

  Column uiSliderArea() {
    FontWeight textWeight = (markerBackgroundColor == hexBlack) ? FontWeight.bold : FontWeight.normal;
    Color textColor = (markerBackgroundColor == hexBlack) ? Colors.black38 : Colors.white;
    return Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
      // with 4 children: 1. Row with timeslider and actionbuttons, 2. Container with the start/stop button and the timeslider,
      // 3. a Row with texts and 4. a Sizedbox withsome space
      // first a row with the speedslider, a spacer, the actionbuttons and 15px wide sizedbox
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const SizedBox(width: 8),
        if (eventStatus == 'replay' || currentReplayTime != sliderEnd) uiSpeedSlider(),
        const Spacer(),
        if (!hideFloatingActionButtons && followCounter > 0 && !showShipMenu && !showInfoPage && !showMapMenu && cookieConsentGiven)
          uiActionButtons(),
        const SizedBox(width: 15),
      ]),
      // under this row the start/stop button and the timeslider
      uiTimeSlider(),
      // a container showing the selected speed, the currentreplaytime and the livetimer
      Container(
          color: Colors.transparent,
          child: Row(
            // row with some texts
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                  (eventStatus == 'live' && currentReplayTime == sliderEnd) ? '    1 sec/sec' : '    ${speedTextTable[speedIndex.toInt()]}',
                  style: TextStyle(fontWeight: textWeight, color: textColor)),
              Expanded(
                // live / replay time (filling up the leftover space either with a container or a column
                child: (eventStatus == 'pre-event')
                    ? const SizedBox()
                    : Container(
                        alignment: Alignment.center,
                        child: AutoSizeText(
                          ((currentReplayTime == sliderEnd) && (sliderEnd != eventEnd) ? 'Live   ' : 'Replay   ') +
                              DateTime.fromMillisecondsSinceEpoch(currentReplayTime).toString().substring(0, 16),
                          style: TextStyle(fontWeight: textWeight, color: textColor),
                          maxLines: 1,
                        ),
                      ),
              ),
              (eventStatus == 'live')
                  ? SizedBox(
                      width: 20,
                      child: InkWell(
                          onTap: () => setState(() {
                                liveSecondsTimer = 0;
                              }),
                          child: Text('$liveSecondsTimer',
                              textAlign: TextAlign.right, style: TextStyle(fontWeight: textWeight, color: textColor))))
                  : const SizedBox(),
              const SizedBox(width: 55),
            ],
          )),
      // and finally some space ate the bottom of the screen
      SizedBox(
        // give those poor iPhone owners some space for their microphone....
        height: (defaultTargetPlatform == TargetPlatform.iOS) ? 35 : 15,
      )
    ]);
  }

  Container uiEventMenu() {
    return Container(
        color: menuBackgroundColor,
        width: 275,
        padding: EdgeInsets.fromLTRB(10.0, menuOffset + 10.0, 0.0, 10.0),
        child: ListView(padding: const EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0), children: [
          Row(children: [
            const Text("Evenementmenu", style: TextStyle(fontSize: 20)),
            const Spacer(),
            IconButton(
                onPressed: () => setState(() => showEventMenu = replayPause = false),
                icon: Icon(Icons.cancel_outlined, color: menuForegroundColor)),
          ]),
          Container(height: 10),
          PopupMenuButton(
            key: dropEventKey,
            offset: const Offset(15, 35),
            itemBuilder: (BuildContext context) {
              return eventList.map((events) {
                return PopupMenuItem(height: 30.0, value: events, child: Text(events, style: const TextStyle(fontSize: 15)));
              }).toList();
            },
            onSelected: selectEventYear,
            tooltip: '',
            child: Row(
                children: [Text('   $eventName '), Icon(Icons.arrow_drop_down, size: 20, color: menuForegroundColor), const Text(' \n')]),
          ),
          PopupMenuButton(
            key: dropYearKey,
            offset: const Offset(15, 35),
            itemBuilder: (BuildContext context) {
              return eventYearList.map((years) {
                return PopupMenuItem(
                  height: 30.0,
                  value: years,
                  child: Text(years, style: const TextStyle(fontSize: 15)),
                );
              }).toList();
            },
            onSelected: selectEventDay,
            tooltip: '',
            child: (eventYear == '')
                ? const Text('')
                : Row(children: [
                    Text('   $eventYear '),
                    Icon(Icons.arrow_drop_down, size: 20, color: menuForegroundColor),
                    const Text(' \n')
                  ]),
          ),
          PopupMenuButton(
            key: dropDayKey,
            // dropdown day/race
            offset: const Offset(15, 35),
            itemBuilder: (BuildContext context) {
              return eventDayList.map((days) {
                return PopupMenuItem(
                  height: 30.0,
                  value: days,
                  child: Text(days, style: const TextStyle(fontSize: 15)),
                );
              }).toList();
            },
            onSelected: newEventSelected,
            tooltip: '',
            child: (eventDay == '')
                ? const Text('')
                : Row(
                    children: [Text('   $eventDay'), Icon(Icons.arrow_drop_down, size: 20, color: menuForegroundColor), const Text(' \n')]),
          ),
          if (selectionMessage != '')
            Wrap(children: [
              Divider(color: menuForegroundColor),
              Text('\n$selectionMessage\n'),
              Divider(color: menuForegroundColor),
              if (eventDomain != '')
                Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                    child: InkWell(
                      onTap: () => {if (socialMediaUrl != '') launchUrl(Uri.parse(socialMediaUrl), mode: LaunchMode.externalApplication)},
                      child: Image.network('${server}data/$eventDomain/logo.png'),
                    )),
              Text((socialMediaUrl == '') ? '' : '\nKlik op het logo voor de laatste info over deze wedstrijd.\n')
            ]),
          if ((webOnMobile && mobileAppAvailable))
            Wrap(
              children: [
                Divider(color: menuForegroundColor),
                InkWell(
                    child: const Text('\nMobiele Track & Trace App\n\nDe mobiele app werkt op uw '
                        'telefoon sneller dan de web-versie en verbruikt minder data. '
                        'Klik hier om de gratis app op uw telefoon installeren.'),
                    onTap: () {
                      if (defaultTargetPlatform == TargetPlatform.android) {
                        launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=nl.zeilvaartwarmond.szwtracktrace'),
                            mode: LaunchMode.externalApplication);
                      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                        launchUrl(Uri.parse('https://apps.apple.com/us/app/zeilvaart-warmond-track-trace/id1607502880'),
                            mode: LaunchMode.externalApplication);
                      }
                    })
              ],
            ),
        ]));
  }

  Row uiShipMenu() {
    return Row(children: [
      const Spacer(),
      Container(
        width: 275,
        color: menuBackgroundColor,
        padding: EdgeInsets.fromLTRB(10.0, menuOffset + 10.0, 0.0, 10.0),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text('Alle $participants volgen aan/uit'),
                    ),
                  ),
                  Checkbox(
                      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                      activeColor: menuForegroundColor,
                      checkColor: menuBackgroundColor,
                      side: BorderSide(color: menuForegroundColor),
                      value: followAll,
                      onChanged: (value) => setState(() {
                            following.forEach((k, v) {
                              following[k] = value!;
                            });
                            followAll = value!;
                            moveShipsAndWindTo(currentReplayTime);
                          })),
                ]),
                Divider(color: menuForegroundColor),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  itemCount: shipList.length,
                  itemBuilder: (BuildContext context, index) {
                    return Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                      Padding(
                        padding: const EdgeInsets.all(0),
                        child: Text('\u25A0', style: TextStyle(color: Color(shipColors[index]))),
                      ),
                      Expanded(
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                            child: InkWell(
                              child: Text(shipList[index]),
                              onTap: () => loadShipInfo(index),
                            )),
                      ),
                      Checkbox(
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                          activeColor: menuForegroundColor,
                          checkColor: menuBackgroundColor,
                          side: BorderSide(color: menuForegroundColor),
                          value: (following[shipList[index]] == null) ? false : following[shipList[index]],
                          onChanged: (value) => setState(() {
                                following[shipList[index]] = value!;
                                moveShipsAndWindTo(currentReplayTime);
                              })),
                    ]);
                  },
                ),
                Divider(color: menuForegroundColor),
                InkWell(
                    child: Text('Het spoor achter de $participants is $actualTrailLength minuten'),
                    onTap: () => setState(() {
                          if (actualTrailLength == eventTrailLength) {
                            if (maxReplay == 0) {
                              actualTrailLength = (eventEnd - eventStart) / 1000 ~/ 60;
                            } else {
                              actualTrailLength = maxReplay * 60; // minuten
                            }
                          } else {
                            actualTrailLength = eventTrailLength;
                          }
                          moveShipsAndWindTo(currentReplayTime);
                        })),
              ],
            )),
      )
    ]);
  }

  Row uiMapMenu() {
    return Row(children: [
      const Spacer(),
      Container(
          width: 275,
          color: menuBackgroundColor,
          padding: EdgeInsets.fromLTRB(10.0, menuOffset + 10.0, 0.0, 10.0),
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
              child: Column(children: [
                ListView.builder(
                    // radiobuttons for maptype
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: mapTileProviderData.keys.toList().length,
                    itemBuilder: (BuildContext context, index) {
                      return Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Text(mapTileProviderData.keys.toList()[index]),
                          ),
                        ),
                        Theme(
                            data: ThemeData.dark(),
                            child: Radio(
                                activeColor: menuForegroundColor,
                                visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                value: mapTileProviderData.keys.toList()[index],
                                groupValue: selectedMapType,
                                onChanged: (value) async {
                                  selectedMapType = value!;
                                  prefs.setString('maptype', selectedMapType);
                                  markerBackgroundColor = mapTileProviderData[selectedMapType]['bgColor'];
                                  labelBackgroundColor = markerBackgroundColor == hexBlack ? hexWhite : hexBlack;
                                  if (mapTileProviderData[selectedMapType]['service'] == 'vector') {
                                    baseMapStyle = await StyleReader(uri: mapTileProviderData[selectedMapType]['URL'], apiKey: '').read();
                                  }
                                  if (eventStatus != "" && eventStatus != 'pre-event') {
                                    // we need the eventStatus to be non-blank, otherwise the markers of the ships,
                                    // labels and wind will be moved when the markers are not initialized yet.
                                    // And we just want to change the colors, not move or zoom
                                    moveShipsAndWindTo(currentReplayTime, move: false);
                                  }
                                  showMapMenu = replayPause = false;
                                  if (eventStatus != "" && route['features'] != null) buildRoute();
                                  setState(() {});
                                }))
                      ]);
                    }),
                if (selectedOverlayType != "") // map overly on/off and radiobuttons
                  Wrap(children: [
                    Divider(color: menuForegroundColor),
                    Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: Text('Kaart overlay'),
                        ),
                      ),
                      Checkbox(
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                          activeColor: menuForegroundColor,
                          checkColor: menuBackgroundColor,
                          side: BorderSide(color: menuForegroundColor),
                          value: mapOverlay,
                          onChanged: (value) => setState(() {
                                mapOverlay = value!;
                                prefs.setBool('mapoverlay', mapOverlay);
                                showMapMenu = replayPause = false;
                              })),
                    ]),
                    ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: overlayTileProviderData.keys.toList().length,
                        itemBuilder: (BuildContext context, index) {
                          return Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                            Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 5, 5),
                                  child: Text(overlayTileProviderData.keys.toList()[index])),
                            ),
                            Theme(
                                data: ThemeData.dark(),
                                child: Radio(
                                    activeColor: menuForegroundColor,
                                    visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                    value: overlayTileProviderData.keys.toList()[index],
                                    groupValue: selectedOverlayType,
                                    onChanged: (value) => setState(() {
                                          selectedOverlayType = value!;
                                          prefs.setString('overlaytype', selectedOverlayType);
                                          if (mapOverlay) showMapMenu = replayPause = false;
                                        })))
                          ]);
                        })
                  ]),
                if (replayTracks['windtracks'] != null && replayTracks['windtracks'].length > 0)
                  Wrap(children: [
                    Divider(color: menuForegroundColor),
                    Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: Text('Windpijlen'),
                        ),
                      ),
                      Checkbox(
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                          activeColor: menuForegroundColor,
                          checkColor: menuBackgroundColor,
                          side: BorderSide(color: menuForegroundColor),
                          value: windMarkersOn,
                          onChanged: (value) => setState(() {
                                windMarkersOn = !windMarkersOn;
                                prefs.setBool('windmarkers', windMarkersOn);
                                showMapMenu = replayPause = false;
                                windMarkersOn ? rotateWindTo(currentReplayTime) : windMarkerList = [];
                              }))
                    ])
                  ]),
                if (route['features'] != null) // route and routelabels
                  Wrap(children: [
                    Divider(color: menuForegroundColor),
                    Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: Text('Route, havens, boeien'),
                        ),
                      ),
                      Checkbox(
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                          activeColor: menuForegroundColor,
                          checkColor: menuBackgroundColor,
                          side: BorderSide(color: menuForegroundColor),
                          value: showRoute,
                          onChanged: (value) => setState(() {
                                showRoute = !showRoute;
                                prefs.setBool('showroute', showRoute);
                                showMapMenu = replayPause = false;
                                buildRoute();
                              }))
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 5, 5),
                          child: Text('met namen'),
                        ),
                      ),
                      Checkbox(
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                          activeColor: menuForegroundColor,
                          checkColor: showRoute ? menuBackgroundColor : menuBackgroundColor?.withOpacity(0.5),
                          side: BorderSide(color: menuForegroundColor),
                          value: showRouteLabels,
                          onChanged: (value) => setState(() {
                                showRouteLabels = !showRouteLabels;
                                prefs.setBool('routelabels', showRouteLabels);
                                if (route['features'] != null) buildRoute();
                                if (showRoute) showMapMenu = replayPause = false;
                              }))
                    ])
                  ]),
                if (replayTracks['shiptracks'] != null) // shipnames and speeds
                  Wrap(children: [
                    Divider(color: menuForegroundColor),
                    Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Text(shipNames),
                        ),
                      ),
                      Checkbox(
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                          activeColor: menuForegroundColor,
                          checkColor: menuBackgroundColor,
                          side: BorderSide(color: menuForegroundColor),
                          value: showShipLabels,
                          onChanged: (value) => setState(() {
                                showShipLabels = !showShipLabels;
                                prefs.setBool('shiplabels', showShipLabels);
                                if (eventStatus != 'pre-event') moveShipsAndWindTo(currentReplayTime, move: false);
                                showMapMenu = replayPause = false;
                              }))
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 5, 5),
                          child: Text('met snelheden'),
                        ),
                      ),
                      Checkbox(
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                          activeColor: menuForegroundColor,
                          checkColor: showShipLabels ? menuBackgroundColor : menuBackgroundColor?.withOpacity(0.5),
                          side: BorderSide(color: menuForegroundColor),
                          value: showShipSpeeds,
                          onChanged: (value) => setState(() {
                                showShipSpeeds = !showShipSpeeds;
                                prefs.setBool('shipspeeds', showShipSpeeds);
                                if (eventStatus != 'pre-event') moveShipsAndWindTo(currentReplayTime, move: false);
                                if (showShipLabels) showMapMenu = replayPause = false;
                              }))
                    ])
                  ]),
                if (eventStatus == 'replay') // replay loop checkbox
                  Wrap(children: [
                    Divider(color: menuForegroundColor),
                    Row(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(5, 0, 5, 5),
                          child: Text('Replay loop'),
                        ),
                      ),
                      Checkbox(
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                          activeColor: menuForegroundColor,
                          checkColor: menuBackgroundColor,
                          side: BorderSide(color: menuForegroundColor),
                          value: replayLoop,
                          onChanged: (value) => setState(() {
                                replayLoop = !replayLoop;
                                showMapMenu = replayPause = false;
                              }))
                    ])
                  ]),
              ]))),
      const SizedBox(width: 35)
    ]);
  }

  Row uiInfoPage() {
    return Row(children: [
      const Spacer(),
      GestureDetector(
          onTap: () => setState(() => showInfoPage = replayPause = false),
          child: Container(
              width: (screenWidth > 750) ? 750 - 80 : screenWidth - 80,
              color: infoPageColor,
              padding: EdgeInsets.fromLTRB(20.0, menuOffset + 10.0, 10.0, 20.0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
                child: Html(
                  data: infoPageHTML,
                  onLinkTap: (link, _, __) async => await launchUrl(Uri.parse(link!), mode: LaunchMode.externalApplication),
                ),
              ))),
      Container(width: 80),
    ]);
  }

  Positioned uiShipInfo() {
    return Positioned(
        left: shipInfoPosition.dx,
        top: shipInfoPosition.dy,
        child: GestureDetector(
          onPanStart: (details) => shipInfoPositionAtDragStart = shipInfoPosition - details.localPosition,
          onPanUpdate: (details) => setState(() {
            shipInfoPosition = shipInfoPositionAtDragStart + details.localPosition;
          }),
          onTap: () => setState(() {
            if (!showShipMenu) replayPause = false; // continue the replay if the shipmenu is not open
            showShipInfo = false; // remove the info again from the screen on a tap
          }),
          child: Container(
              constraints: const BoxConstraints(minHeight: 100, maxHeight: 500, maxWidth: 350),
              decoration: BoxDecoration(color: menuBackgroundColor, border: Border.all(color: menuForegroundColor, width: 1)),
              padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
              child: Stack(children: [
                SingleChildScrollView(child: Html(data: shipInfoHTML)),
                Row(children: [
                  const Spacer(),
                  Icon(Icons.cancel_outlined, color: menuForegroundColor),
                ]),
              ])),
        ));
  }

  Row uiAttribution() {
    var attributeStyle = const TextStyle(color: Colors.black87, fontSize: 12);
    return Row(children: [
      const Spacer(),
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
                            child: Text('• Basiskaart: © ${mapTileProviderData[selectedMapType]['attrib']}', style: attributeStyle),
                            onTap: () => launchUrl(Uri.parse(mapTileProviderData[selectedMapType]['attribLink']))),
                        if (mapOverlay && overlayTileProviderData.isNotEmpty)
                          GestureDetector(
                              child: Text('• Overlaykaart: © ${overlayTileProviderData[selectedOverlayType]['attrib']}',
                                  style: attributeStyle),
                              onTap: () => launchUrl(Uri.parse(overlayTileProviderData[selectedOverlayType]['attribLink']))),
                        if (windMarkerList.isNotEmpty && windMarkersOn)
                          GestureDetector(
                              child: Text('• Windpijlen: © buienradar.nl', style: attributeStyle),
                              onTap: () => launchUrl(Uri.parse('https://www.buienradar.nl'))),
                        if (eventInfo.isNotEmpty && eventInfo['AISHub'] == 'true')
                          GestureDetector(
                            child: Text('• AIS tracking door www.AISHub.net', style: attributeStyle),
                            onTap: () => launchUrl(Uri.parse('https://www.aishub.net')),
                          ),
                        if (eventInfo.isNotEmpty && eventInfo['MarineTraffic'] == 'true')
                          GestureDetector(
                            child: Text('• AIS tracking door www.MarineTraffic.com', style: attributeStyle),
                            onTap: () => launchUrl(Uri.parse('https://www.marinetraffic.com')),
                          ),
                      ])))),
        IconButton(
          onPressed: () => setState(() {
            showAttribution = !showAttribution;
          }),
          icon: (showAttribution)
              ? Icon(
                  Icons.cancel_outlined,
                  color: (markerBackgroundColor == hexBlack) ? Colors.black38 : Colors.white60,
                )
              : Icon(
                  Icons.info_outline,
                  color: (markerBackgroundColor == hexBlack) ? Colors.black38 : Colors.white60,
                ),
        )
      ])
    ]);
  }

  Column uiCookieConsent() {
    return Column(children: [
      const Spacer(),
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
              child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                ElevatedButton(
                    onPressed: () => setState(() {
                          cookieConsentGiven = true;
                          prefs.setBool('cookieconsent', cookieConsentGiven);
                        }),
                    child: const Text('Akkoord')),
              ]))
        ]),
      )
    ]);
  }

  Center uiProgressIndicator() {
    return Center(
        child: CircularProgressIndicator(
      backgroundColor: menuBackgroundColor?.withOpacity(0.5),
      color: menuForegroundColor,
    ));
  }

  //----------------------------------- end of ui widgets --------------------------------------------
  //
  // This routine is called when UI is built and the map is ready.
  // Here we start up the rest of the initialization of our app
  //
  Future<void> onMapCreated() async {
    //
    // Get the list of events ready for selection
    dirList = await getDirList();
    dirList.forEach((k, v) => eventList.add(k));
    eventList.sort();
    eventYearList = [];
    eventDayList = [];
    //
    // open the event menu
    showEventMenu = true;
    if (eventDomain != "") {
      // we have info from a previous session or from the web url: use it as if the user had selected an event using the UI
      List subStrings = ('$eventDomain///').split('/');
      if (dirList.containsKey(subStrings[0])) {
        eventName = subStrings[0];
        dirList[eventName].forEach((k, v) => eventYearList.add(k));
        eventYearList = eventYearList.reversed.toList();
        if (eventYearList.contains(subStrings[1])) {
          eventYear = subStrings[1];
          if (dirList[eventName][eventYear].length == 0) {
            newEventSelected(''); // go with just eventName and eventYear
          } else {
            dirList[eventName][eventYear].forEach((k, v) => eventDayList.add(k));
            if (eventDayList.contains(subStrings[2])) {
              eventDay = subStrings[2];
              newEventSelected(eventDay); // go with eventName, eventYear and eventDay
            } else {
              Timer(const Duration(milliseconds: 600), () {
                // give the uiMapMenu animation time to settle, otherwise the drop down list show up at the wrong place
                selectEventDay(eventYear);
              });
            }
          }
        } else {
          Timer(const Duration(milliseconds: 600), () {
            // give the uiMapMenu animation time to settle, otherwise the drop down list show up at the wrong place
            selectEventYear(eventName);
          });
        }
      } else {
        eventName = 'Kies een evenement';
        eventYear = '';
        eventDay = '';
      }
    } else {
      // if we have no eventDomain from local storage or from the query string, the event selection menu will start things up
      Timer(const Duration(milliseconds: 600), () {
        // give the uiMapMenu animation time to settle, otherwise the drop down list show up at the wrong place
        dynamic state = dropEventKey.currentState;
        state.showButtonMenu();
        setState(() {}); // redraw the UI
      });
    }
    setState(() {}); // redraw the UI
  }

  //----------------------------------------------------------------------------
  //
  // Routines to handle the event selections from the UI event selection menu
  // First the routine to handle the selection of the event name and prepare for getting a year
  //
  void selectEventYear(event) {
    selectionMessage = '';
    eventName = event;
    eventYearList = [];
    // make a list of years for the event in reverse order. The list is automatically shown in the UI
    dirList[event].forEach((k, v) => eventYearList.add(k));
    eventYearList.sort();
    eventYearList = eventYearList.reversed.toList();
    eventYear = 'Kies een jaar';
    dynamic state = dropYearKey.currentState;
    state.showButtonMenu();
    eventDay = '';
    eventDayList = [];
    setState(() {});
  }

  //
  // (almost) identical routine to handle the selection of an event year and prepare for getting a day
  // unless this event does not have a day, in that case we go to newEventSelected immediately
  //
  void selectEventDay(year) {
    selectionMessage = '';
    eventYear = year;
    eventDayList = [];
    // make a list of days for the event/year, but only if this event year has any days. Otherwise we have a complete event selected
    if (dirList[eventName][eventYear].length != 0) {
      dirList[eventName][eventYear].forEach((k, v) => eventDayList.add(k));
      eventDayList.sort();
      eventDay = 'Kies een dag/race';
      dynamic state = dropDayKey.currentState;
      state.showButtonMenu();
      setState(() {});
    } else {
      newEventSelected('');
    }
  }

  //
  // Routine to start up a new event after the user selected the day (or year, in case there are no days in the event)
  // This routine is also called immediately after startup of the app, when we found an eventDomain
  // in local storage from a previous session or in the URL query
  //
  void newEventSelected(day) async {
    // set the new eventDomain and save it in local storage
    eventDay = day;
    eventDomain = '$eventName/$eventYear';
    if (eventDay != '') eventDomain = '$eventDomain/$eventDay';
    prefs.setString('domain', eventDomain); // save the selected event in local storage
    // put the direct link to this event in the addressbar
    if (kIsWeb) window.history.pushState({}, '', '?event=$eventDomain');

    // then "kill" whatever was running
    if (eventStatus == 'pre-event') {
      preEventTimer.cancel();
    } else if (eventStatus == 'live') {
      liveTimer.cancel();
    }
    if (replayRunning) {
      replayTimer.cancel();
      replayRunning = false;
    }

    // new event selected, show progressindicator and reset some variables to their initial/default values
    setState(() => showProgress = true);
    following = {};
    followCounter = 0;
    followAll = true;
    autoZoom = true;
    shipList = [];
    shipColors = [];
    shipColorsSvg = [];
    shipMarkerList = [];
    shipLabelList = [];
    shipTrailList = [];
    windMarkerList = [];
    replayTracks = {};
    replayLoop = false;
    infoWindowId = '';
    infoWindowMarkerList = [];
    //
    // get the event info from the server and unpack it into several vars
    // note that some values may be missing. If so, we set the vars to default values
    eventInfo = await getEventInfo(eventDomain);
    eventTitle = eventInfo['eventtitle'] ?? '--';
    eventId = eventInfo['eventid'] ?? '--';
    eventStart = int.parse(eventInfo['eventstartstamp'] ?? '0') * 1000;
    eventEnd = int.parse(eventInfo['eventendstamp'] ?? '0') * 1000;
    sliderEnd = eventEnd; //  otherwise the slider crashes with max <= min when we redraw the ui in setState
    eventTrailLength = actualTrailLength = int.parse(eventInfo['traillength'] ?? '30');
    maxReplay = int.parse(eventInfo['maxreplay'] ?? '0');
    hfUpdate = bool.parse(eventInfo['hfupdate'] ?? 'false');
    trailsUpdateInterval = int.parse(eventInfo['trailsupdateinterval'] ?? '60');
    trailsUpdateInterval = trailsUpdateInterval < 5 ? 60 : trailsUpdateInterval;
    eventInfo['mediaframe'] ?? '';
    socialMediaUrl = switch (eventInfo['mediaframe'].split(':')[0]) {
      'facebook' => 'https://www.facebook.com/${eventInfo['mediaframe'].split(':')[1]}',
      'twitter' || 'X' => 'https://www.x.com/${eventInfo['mediaframe'].split(':')[1]}',
      'http' || 'https' => eventInfo['mediaframe'],
      _ => ''
    };
    //
    // get the appicon.png either from the event or the default icon
    appIconUrl = await getAppIconUrl(event: eventDomain);
    //
    // get the route.geojson from the server
    route = await getRoute(eventDomain);
    //
    // set the event status based on the current time. Are we before, during or after the event
    final now = DateTime.now().millisecondsSinceEpoch;
    if (eventStart > now) {
      eventStatus = 'pre-event';
      // set the timeslider max equal to the eventstart, i.e. min and max are both eventStart
      sliderEnd = eventStart;
      selectionMessage = 'Het evenement is nog niet begonnen.\n\nKies een ander evenement of wacht rustig af. '
          'De Track & Trace begint op ${DateTime.fromMillisecondsSinceEpoch(eventStart).toString().substring(0, 19)}';
      if (route['features'] != null) {
        selectionMessage += '\n\nBekijk intussen de route / havens / boeien op de kaart';
        showRoute = true;
        showRouteLabels = true;
        buildRoute(move: true); // and move the map to the bounds of the route
      }
      // now just countdown seconds until the events starts, then go live
      showProgress = false;
      preEventTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (DateTime.now().millisecondsSinceEpoch > eventStart) {
          timer.cancel();
          eventStatus = 'live';
          startLive();
        }
      });
    } else if (eventEnd > now) {
      eventStatus = 'live';
      selectionMessage = 'Het evenement is "live". Wacht tot de tracks zijn geladen';
      startLive();
    } else {
      eventStatus = 'replay';
      selectionMessage = 'Het evenement is voorbij. Wacht tot de tracks zijn geladen';
      startReplay();
    }
    setState(() {}); // redraw the UI
  }

  //
  // Two routines for handling a live event
  // 1. startup the live event
  // 2. the live timer routine, runse every second, but acts every 60 seconds
  //
  void startLive() async {
    if (maxReplay == 0) {
      // maxReplay is set as an event parameter and is either 0 for normal events
      // or x hours when we have one long event where we want to limit the replay starting x hours back
      // first see if we already have live tracks of this event in local storage from a previous session
      String a = prefs.getString('live-$eventId') ?? ''; // get "old" live tracks from prefs (if not set to default '')
      if (a != '') {
        replayTracks = jsonDecode(a);
      } else {
        // no data yet, so get the replay (max 5 minutes old)
        replayTracks = await getReplayTracks(eventDomain);
      }
      liveTrails = await getTrails(eventDomain, fromTime: (replayTracks['endtime'] / 1000).toInt());
      addTrailsToTracks(); // merge the latest track info with the replay info and save it
    } else {
      // maxReplay > 0, fetch the trails of the last {maxReplay} hours
      eventStart = DateTime.now().millisecondsSinceEpoch - (maxReplay * 60 * 60 * 1000);
      replayTracks = await getTrails(eventDomain, fromTime: eventStart ~/ 1000);
      if (!kIsWeb) prefs.setString('live-$eventId', jsonEncode(replayTracks));
    }
    buildShipAndWindInfo(); // prepare menu and track info
    showRoute = true;
    if (shipList.isEmpty) showRouteLabels = true;
    if (route['features'] != null) buildRoute();
    selectionMessage = (shipList.isNotEmpty) ? 'De tracks zijn geladen en worden elke $trailsUpdateInterval seconden bijgewerkt' : '';
    replayPause = false; // allow replay to run
    sliderEnd = currentReplayTime = DateTime.now().millisecondsSinceEpoch; // put the timeslider to 'now'
    speedIndex = speedIndexInitialValue;
    if (queryPlayString != '') {
      var a = queryPlayString.split(':');
      queryPlayString = '';
      if (a[1] != '0') currentReplayTime = int.parse(a[1]);
      if (a[0] == 'true') startStopRunning();
      speedIndex = double.parse(a[2]);
    }
    moveShipsAndWindTo(currentReplayTime);
    autoFollow = false; // in 'live' we start with autofollow off
    liveSecondsTimer = trailsUpdateInterval;
    liveTimer = Timer.periodic(const Duration(seconds: 1), (_) => liveTimerRoutine());
    setState(() {}); // redraw the UI
    // hide the event menu after two seconds
    Timer(
        const Duration(seconds: 2),
        () => setState(() {
              showEventMenu ? showEventMenu = false : null;
              showProgress = false;
            }));
  }

  //
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
        liveSecondsTimer = trailsUpdateInterval;
        if ((now - replayTracks['endtime']) > (trailsUpdateInterval * 3 * 1000)) {
          // we must have been asleep for at least two trailsUpdatePeriods, get a complete uopdate since the last fetch
          liveTrails = await getTrails(eventDomain, fromTime: (replayTracks['endtime'] / 1000).toInt()); // fetch special
        } else {
          // we have relatively recent data, go get the latest. Note this fetch does not (always) access the database on the server
          // but gets data stored in the trails.json file, wich is not older then the trailsUpdateInterval
          liveTrails = await getTrails(eventDomain); // fetch the latest data
        }
        addTrailsToTracks(); // add it to what we already had and store it
        buildShipAndWindInfo(); // prepare menu and track info
      }
      if (currentReplayTime == sliderEnd) {
        // slider is at the end
        sliderEnd = currentReplayTime = now; // extend the slider and move the handle to the new end
        if (hfUpdate) {
          // update positions every second
          moveShipsAndWindTo(currentReplayTime);
        } else {
          // update positions only at trailsUpdatInterval
          if (liveSecondsTimer == trailsUpdateInterval) moveShipsAndWindTo(currentReplayTime);
        }
      } else {
        // slider is not at the end, the slider has been moved back in time by the user
        sliderEnd = now; // just make the slider a second longer
      }
      if (!showShipInfo) setState(() {}); // If shipInfo is shown, don't update. It makes the info flash, for whatever reason
    } else {
      // the live event is over
      liveTimer.cancel();
      eventStatus = 'replay';
      startReplay();
    }
  }

  //
  // routine to start replay after the event is really over
  void startReplay() async {
    // First get rid of the temporary live file if that existed...
    prefs.remove('live-$eventId');
    // Do we have already have data in local storage?
    String? a = prefs.getString('replay-$eventId');
    if (a == null) {
      // no data yet
      replayTracks = await getReplayTracks(eventDomain); // get the data from the server and
      if (!kIsWeb) prefs.setString('replay-$eventId', jsonEncode(replayTracks)); // store it locally
    } else {
      // send a get, just for statistics purposes, no need to wait for a response
      getReplayTracks(eventDomain, nodata: true);
      replayTracks = jsonDecode(a); // and just use the data from local storage
    }
    replayPause = false;
    replayRunning = false;
    buildShipAndWindInfo(); // prepare menu and track info
    selectionMessage =
        (shipList.isNotEmpty) ? 'De tracks zijn geladen. Sluit het menu en start de replay met de start/stop knop linksonder' : '';
    currentReplayTime = eventStart;
    speedIndex = speedIndexInitialValue;
    if (queryPlayString != '') {
      var a = queryPlayString.split(':');
      queryPlayString = ''; // only use these values when we get here for the first time
      if (a[1] != '0') currentReplayTime = int.parse(a[1]);
      if (a[0] == 'true') startStopRunning();
      speedIndex = double.parse(a[2]);
    }
    moveShipsAndWindTo(currentReplayTime, move: false);
    showRoute = true;
    if (shipList.isEmpty) showRouteLabels = true;
    if (route['features'] != null) buildRoute(move: true); // and move the map to the bounds of the route
    autoFollow = autoZoom = true;
    setState(() {}); // redraw the UI
    Timer(
        const Duration(seconds: 2),
        () => setState(() {
              showEventMenu ? showEventMenu = false : null;
              showProgress = false;
            }));
  }

  //----------------------------------------------------------------------------
  //
  // the replayTimerRoutine runs every replayRate ms, i.e 1000/replayRate times per second
  // default is 50ms, so 20 updates/second
  //
  void replayTimerRoutine() {
    if (!replayPause) {
      // paused if a menu is open. just wait another replayRate milliseconds
      currentReplayTime = (currentReplayTime + (speedTable[speedIndex.toInt()] * replayRate));
      //
      // Now we have different situations:
      //  - we moved beyond the end of the event and eventStatus is live: eventStatus becomes 'replay'
      //  - we moved beyond the last trails received from the server and the event is still live: just stop
      //  - we moved beyond the last trails in replay and replayLoop is true, move to the beginning of the track ang go on
      //    If we were live, the liveTimerRoutine will take over. If we were in replay, wait for the user to move the timeslider
      //  - we are still in replay: just move the ships and windmarkers
      //
      if (currentReplayTime > eventEnd) {
        if (eventStatus == 'live') liveTimer.cancel();
        eventStatus = 'replay';
        if (replayLoop) {
          currentReplayTime = eventStart;
          moveShipsAndWindTo(currentReplayTime);
        } else {
          replayRunning = false;
          replayTimer.cancel();
          currentReplayTime = eventEnd;
          moveShipsAndWindTo(eventEnd);
        }
        // Note that we continue to run using the 'live' tracks in memory
        // next session with this event we will start in the startReplay routine, where we delete the
        // locally stored live-xxxx.json file and replace is with the final replay-xxxx.json file
        // where xxxx is the eventId from the eventinfo.json file
      } else if (currentReplayTime > sliderEnd) {
        replayRunning = false;
        replayTimer.cancel();
        currentReplayTime = sliderEnd;
      } else {
        moveShipsAndWindTo(currentReplayTime);
      }
      setState(() {}); // redraw the UI
    }
  }

  //----------------------------------------------------------------------------
  //
  // Routine to handle start/stop button
  void startStopRunning() {
    if (eventStatus != "pre-event") {
      showEventMenu = showInfoPage = showMapMenu = showShipMenu = showShipInfo = replayPause = false;
      replayRunning = !replayRunning;
      if (replayRunning && currentReplayTime == sliderEnd) {
        // if he wants to run while at the end of the slider, move it to the beginning
        currentReplayTime = eventStart;
      }
      if (replayRunning) {
        replayTimer = Timer.periodic(const Duration(milliseconds: replayRate), (_) => replayTimerRoutine());
      } else {
        replayTimer.cancel();
      }
      setState(() {}); // redraw the UI
    }
  }

  //----------------------------------------------------------------------------
  //
  // Routines to move ships, shiplabels, redraw shiptrail polylines and rotate windmarkers
  // It is called in all eventStatus'es every time the markers need to be updated
  // During replay this routine is called 20 times per second, so in that situation the routine is time critical....
  //
  // 'move' is default to true.
  // Set it to false when you just want to change the backroundcolor of the markers or turn on/off labels
  //
  void moveShipsAndWindTo(time, {bool move = true}) {
    moveShipsTo(time, move);
    if (windMarkersOn) rotateWindTo(time);
  }

  //
  void moveShipsTo(time, move) {
    late LatLng calculatedPosition;
    late int calculatedRotation;
    LatLngBounds followBounds = LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
    followCounter = 0;
    int timeIndex = 0;
    shipMarkerList = [];
    shipLabelList = [];
    shipTrailList = [];
    // loop through the ships in replayTracks
    for (int ship = 0; ship < replayTracks['shiptracks'].length; ship++) {
      dynamic track = replayTracks['shiptracks'][ship]; // copy ship part of the track to a new var, to keep things a bit simpler
      //
      // see where we are in the time track of the ship
      if (time < track['stamp'][0]) {
        // before the first timestamp
        timeIndex = 0; // set the track index to the first entry
        calculatedPosition = LatLng(track['lat'].first, track['lon'].first);
        calculatedRotation = track['course'].first;
      } else if (time >= track['stamp'].last) {
        // we are beyond the last timestamp
        timeIndex = track['stamp'].length - 1; // set the track index to the last entry
        calculatedRotation = track['course'].last;
        if (time == sliderEnd && hfUpdate && (time - track['stamp'].last) < 180 * 1000) {
          // the last stamp is less then 3 minutes old and we are at the end of the slider (i.e. we are live and no replay running)
          // in this situation we make a prediction where the ship could be,
          // based on last known location, distance (speed, time),and heading
          calculatedPosition = predictPosition(
              LatLng(track['lat'].last, track['lon'].last), track['speed'].last / 10, time - track['stamp'].last, calculatedRotation);
        } else {
          // we are beyond the last timestamp and beyond the 3 minute lostSignal time
          calculatedPosition = LatLng(track['lat'].last, track['lon'].last);
        }
      } else {
        // we are somewhere between two stamps
        // travel along the track forth and back to find out where we are, using a local var to speed things up
        timeIndex = shipTimeIndex[ship]; // get the timeindex of this ship from a previous run
        if (time > track['stamp'][timeIndex]) {
          // move forward in the track
          while (track['stamp'][timeIndex] < time) {
            timeIndex++;
          }
          timeIndex--; // we went one entry too far
        } else {
          // else move backward in the track
          while (track['stamp'][timeIndex] > time) {
            timeIndex--;
          }
        }
        // calculate the ratio of time since previous stamp and next stamp
        double ratio = (time - track['stamp'][timeIndex]) / (track['stamp'][timeIndex + 1] - track['stamp'][timeIndex]);
        // and set the ship position and rotation at that ratio between previous and next position/rotation
        calculatedPosition = LatLng((track['lat'][timeIndex] + ratio * (track['lat'][timeIndex + 1] - track['lat'][timeIndex])),
            (track['lon'][timeIndex] + ratio * (track['lon'][timeIndex + 1] - track['lon'][timeIndex])));
        // calculate the rotation
        int diff = track['course'][timeIndex + 1] - track['course'][timeIndex];
        if (diff >= 180) {
          calculatedRotation = (track['course'][timeIndex] + (ratio * (diff - 360)).floor());
        } // anticlockwise through 360 dg
        else if (diff <= -180) {
          calculatedRotation = (track['course'][timeIndex] + (ratio * (diff + 360)).floor());
        } // clockwise through 360 dg
        else {
          calculatedRotation = (track['course'][timeIndex] + (ratio * diff).floor());
        } // clockwise or anti clockwise less then 180 dg
        calculatedRotation = (calculatedRotation + 720) % 360;
      }
      shipTimeIndex[ship] = timeIndex; // save the timeindex in the list of timeindices for the next run
      //
      // Update the bounds with the calculated position of this ship (but only if we are supposed to follow this ship)
      if (((following[track['name']] == null) ? false : following[track['name']])!) {
        if (followCounter == 0) {
          followBounds = LatLngBounds(calculatedPosition, calculatedPosition);
        } else {
          followBounds.extend(calculatedPosition);
        }
        followCounter++;
      }
      //
      // make a string with speed for the infowindow and the shiplabel
      var speedString = '${((track['speed'][timeIndex] / 10) / 1.852).toStringAsFixed(1)}kn ('
          '${track['speed'][timeIndex] / 10}km/h)';
      // make a new infowindow text with the name of the ship, the lostsignalindicator and the speed
      String lostSignalIndicator = ((time - track['stamp'][timeIndex]) > 180000) ? '\u0027' : '';
      String iwTitle = '${track['name']}$lostSignalIndicator';
      String iwText = 'Snelheid: $speedString';
      iwText += (lostSignalIndicator != '' && eventStatus == 'live')
          ? '\nPositie op ${DateTime.fromMillisecondsSinceEpoch(track['stamp'][timeIndex]).toString().substring(0, 16)}'
          : '';
      // create / replace the ship marker
      var svgString = '<svg width="22" height="22">'
          '<polygon points="10,1 11,1 14,4 14,18 13,19 8,19 7,18 7,4" '
          'style="fill:${shipColorsSvg[ship]};stroke:$markerBackgroundColor;stroke-width:1" '
          'transform="rotate($calculatedRotation 11,11)" />'
          '</svg>';
      shipMarkerList.add(
        Marker(
          point: calculatedPosition,
          width: 22,
          height: 22,
          child: Tooltip(
              message: showShipLabels ? '' : ('${track['name']}$lostSignalIndicator${showShipSpeeds ? '\n$speedString' : ''}'),
              child: InkWell(
                  child: SvgPicture.string(svgString),
                  onTap: () => setState(() {
                        infoWindowId = 'ship$ship';
                        infoWindowMarkerList = [createInfoWindowMarker(iwTitle, iwText, '', calculatedPosition)];
                        moveShipsTo(time, false);
                      }))),
        ),
      );
      // refresh the infowindow if it was open for this ship
      if (infoWindowId == 'ship$ship') {
        infoWindowMarkerList = [createInfoWindowMarker(iwTitle, iwText, '', calculatedPosition)];
      }
      //
      // build the shipLabel
      if (showShipLabels) {
        // note that the labelforgroundcolor is the markerbackgroundcolor
        var txt = '${track['name']}$lostSignalIndicator${((showShipSpeeds) ? ', $speedString' : '')}';
        var svgString = '<svg width="300" height="35">'
            '<text x="0" y="32" fill="$labelBackgroundColor">$txt</text>'
            '<text x="2" y="32" fill="$labelBackgroundColor">$txt</text>'
            '<text x="0" y="30" fill="$labelBackgroundColor">$txt</text>'
            '<text x="2" y="30" fill="$labelBackgroundColor">$txt</text>'
            '<text x="1" y="31" fill="$markerBackgroundColor">$txt</text>'
            '</svg>';
        shipLabelList.add(Marker(
            point: calculatedPosition,
            width: 300,
            height: 30,
            alignment: const Alignment(240 / 300, 20 / 30),
            child: SvgPicture.string(svgString)));
      }
      //
      // finally build the shipTrail (note we destroy the timeIndex here...)
      List<LatLng> trail = [calculatedPosition];
      while ((timeIndex >= 0) && (track['stamp'][timeIndex] > (time - actualTrailLength * 60 * 1000))) {
        trail.add(LatLng(track['lat'][timeIndex].toDouble(), track['lon'][timeIndex].toDouble()));
        timeIndex--;
      }
      shipTrailList.add(Polyline(
        points: trail,
        color: Color(shipColors[ship]),
        // thick line in case of short trails, thin line when we display full eventlong trails
        strokeWidth: (eventTrailLength == actualTrailLength) ? 2 : 1,
      ));
    } // for each ships in the replayTrack
    //
    // finally see if we need to move/zoom the camera to the ships
    if (followCounter == 0) autoZoom = false; // no ships to follow: turn autozoom off
    if (move && followCounter > 0 && autoFollow) {
      if (autoZoom) {
        mapController.fitCamera(CameraFit.bounds(
            bounds: followBounds,
            padding:
                EdgeInsets.fromLTRB(screenWidth * 0.15, menuOffset + screenHeight * 0.10, screenWidth * 0.15, screenHeight * 0.10 + 60)));
      } else {
        mapController.move(followBounds.center, mapController.camera.zoom);
      }
    }
  }

  //
  void rotateWindTo(time) {
    late int calculatedRotation;
    windMarkerList = [];
    // now rotate all weather station markers and set the correct colors
    for (int windStation = 0; windStation < replayTracks['windtracks'].length; windStation++) {
      dynamic track = replayTracks['windtracks'][windStation];
      int trackLength = track['stamp'].length;
      if (time < track['stamp'][0]) {
        // before the first time stamp
        windTimeIndex[windStation] = 0;
        calculatedRotation = track['course'][0];
      } else if (time >= track['stamp'][trackLength - 1]) {
        // after the last timestamp
        windTimeIndex[windStation] = trackLength - 1;
        calculatedRotation = track['course'][trackLength - 1];
      } else {
        // somewhere between two stamps
        // travel along the track back or forth to find out where we are
        if (time > track['stamp'][windTimeIndex[windStation]]) {
          while (track['stamp'][windTimeIndex[windStation]] < time) {
            windTimeIndex[windStation]++;
          }
          windTimeIndex[windStation]--;
        } else {
          while (track['stamp'][windTimeIndex[windStation]] > time) {
            windTimeIndex[windStation]--;
          }
        }
        calculatedRotation = track['course'][windTimeIndex[windStation] + 1];
      }
      // add the wind markers
      String iwTitle = track['name'];
      String iwText = '${track['speed'][windTimeIndex[windStation]]} knopen, ${knotsToBft(track['speed'][windTimeIndex[windStation]])} Bft';
      String fillColor = knotsToColor(track['speed'][windTimeIndex[windStation]]);
      String svgString = '''<svg width="22" height="22">
          <polygon points="7,1 11,20 15,1 11,6" 
          style="fill:$fillColor;stroke:$markerBackgroundColor;stroke-width:1" 
          transform="rotate($calculatedRotation 11,11)" />
          </svg>''';
      LatLng windStationPosition = LatLng(track['lat'].first.toDouble(), track['lon'].first.toDouble());
      windMarkerList.add(
        Marker(
            point: windStationPosition,
            width: 22,
            height: 22,
            child: Tooltip(
                message: iwText,
                child: InkWell(
                  child: SvgPicture.string(svgString),
                  onTap: () => setState(() {
                    infoWindowId = 'wind$windStation';
                    infoWindowMarkerList = [createInfoWindowMarker(iwTitle, iwText, '', windStationPosition)];
                  }),
                ))),
      );
      // refresh the infowindow if it was open for this windstation
      if (infoWindowId == 'wind$windStation') {
        infoWindowMarkerList = [createInfoWindowMarker(iwTitle, iwText, '', windStationPosition)];
      }
    }
  }

  //
  // build the route polyline and routemarkers (and move the map to its bounds)
  // if move = true, move the map to the bounds of the route after creating it
  // default = false, do not move
  //
  void buildRoute({bool move = false}) {
    routeLineList = [];
    routeMarkerList = [];
    routeLabelList = [];
    if (infoWindowId != '' && infoWindowId.substring(0, 4) == 'rout') {
      infoWindowId = '';
      infoWindowMarkerList = [];
    }
    if (showRoute) {
      LatLngBounds routeBounds = LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
      bool first = true;
      for (var k = 0; k < route['features'].length; k++) {
        if (route['features'][k]['geometry']['type'] == 'LineString') {
          List<LatLng> points = [];
          List<dynamic> pts = route['features'][k]['geometry']['coordinates'];
          for (var i = 0; i < route['features'][k]['geometry']['coordinates'].length; i++) {
            points.add(LatLng(pts[i][1], pts[i][0]));
            if (move) {
              if (first) {
                routeBounds = LatLngBounds(LatLng(pts[i][1], pts[i][0]), LatLng(pts[i][1], pts[i][0]));
                first = false;
              } else {
                routeBounds.extend(LatLng(pts[i][1], pts[i][0]));
              }
            }
          }
          routeLineList.add(Polyline(
              points: points,
              color: Color(int.parse('6F${route['features'][k]['properties']['stroke'].toString().substring(1)}', radix: 16)),
              strokeWidth: (eventStatus == 'pre-event') ? 4 : 2));
        } else if (route['features'][k]['geometry']['type'] == 'Point') {
          LatLng routePointPosition =
              LatLng(route['features'][k]['geometry']['coordinates'][1], route['features'][k]['geometry']['coordinates'][0]);
          var fillColor = route['features'][k]['properties']['fillcolor'] ?? 'red';
          String svgString = '<svg width="22" height="22">'
              '<polygon points="8,8 8,14 14,14 14,8" '
              'style="fill:$fillColor;stroke:$markerBackgroundColor;stroke-width:1" />'
              '</svg>';
          String iwTitle = '${route['features'][k]['properties']['name']}';
          String iwText = route['features'][k]['properties']['description'] ?? '';
          String iwLink = route['features'][k]['properties']['link'] ?? '';
          iwText += (iwLink == '') ? '' : ((kIsWeb) ? ' (klik)' : ' (tap)');
          routeMarkerList.add(Marker(
              point: routePointPosition,
              child: Tooltip(
                  message: showRouteLabels ? '' : route['features'][k]['properties']['name'],
                  child: InkWell(
                    child: SvgPicture.string(svgString),
                    onTap: () => setState(() {
                      infoWindowId = 'rout$k';
                      infoWindowMarkerList = [createInfoWindowMarker(iwTitle, iwText, iwLink, routePointPosition)];
                    }),
                  ))));
          if (showRouteLabels) {
            var svgString = '<svg width="300" height="35">'
                '<text x="0" y="32" fill="$labelBackgroundColor">${route['features'][k]['properties']['name']}</text>'
                '<text x="2" y="32" fill="$labelBackgroundColor">${route['features'][k]['properties']['name']}</text>'
                '<text x="0" y="30" fill="$labelBackgroundColor">${route['features'][k]['properties']['name']}</text>'
                '<text x="2" y="30" fill="$labelBackgroundColor">${route['features'][k]['properties']['name']}</text>'
                '<text x="1" y="31" fill="$markerBackgroundColor">${route['features'][k]['properties']['name']}</text>'
                '</svg>';
            routeLabelList.add(Marker(
                point: routePointPosition,
                width: 300,
                height: 30,
                alignment: const Alignment(240 / 300, 20 / 30),
                child: SvgPicture.string(svgString)));
          }
          if (move) {
            if (first) {
              routeBounds = LatLngBounds(routePointPosition, routePointPosition);
              first = false;
            } else {
              routeBounds.extend(routePointPosition);
            }
          }
        }
      }
      if (move) {
        //move the map to the route
        mapController.fitCamera(CameraFit.bounds(bounds: routeBounds, padding: EdgeInsets.fromLTRB(80.0, menuOffset + 40.0, 80.0, 120.0)));
      }
      setState(() {}); // redraw the UI
    }
  }

  //
  // routine to create an infowindow that can be added to the map as a marker
  Marker createInfoWindowMarker(String title, String body, String link, LatLng point) {
    return Marker(
        point: point,
        alignment: const Alignment(0.0, -1.1),
        width: 200,
        height: 200,
        child: Wrap(alignment: WrapAlignment.center, runAlignment: WrapAlignment.end, children: [
          Card(
              color: Colors.white,
              child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 12.0, color: Colors.black, fontWeight: FontWeight.bold)),
                    (body == '')
                        ? const SizedBox()
                        : MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                                onTap: (link == '')
                                    ? null
                                    : () async {
                                        showEventMenu = showShipMenu = showMapMenu = showShipInfo = false;
                                        await launchUrl(Uri.parse(link));
                                        setState(() {});
                                      },
                                child: Text(body, style: const TextStyle(fontSize: 12.0, color: Colors.black))))
                  ])))
        ]));
  }

  //
  // Routine to merge the latest live trails with saved replay trails into an updated replay trails
  // adding b (=liveTrails) to a (=replayTracks) both shiptracks and windtracks
  // Note that there may be more ships in liveTrails then in replayTracks, because a ship may have joined the race later
  // (tracker or AIS data only turned on after eventStart, or the admin added a ship)
  // at the end of the routine the merged data is saved in local storage (pref)
  void addTrailsToTracks() {
    for (int bship = 0; bship < liveTrails['shiptracks'].length; bship++) {
      // get the index (aship) in the replaytracks with the same name as the ship we try to add (bship)
      int aship = replayTracks['shiptracks'].indexWhere((item) => item['name'] == liveTrails['shiptracks'][bship]['name']);
      if (aship != -1) {
        // we found a ship with this name
        replayTracks['shiptracks'][aship]['colorcode'] = liveTrails['shiptracks'][bship]['colorcode']; // copy possible new colorcode
        int laststamp = replayTracks['shiptracks'][aship]['stamp'].last;
        for (int i = 0; i < liveTrails['shiptracks'][bship]['stamp'].length; i++) {
          // add stamps, lats, lons, speeds and courses
          if (liveTrails['shiptracks'][bship]['stamp'][i] > laststamp) {
            replayTracks['shiptracks'][aship]['stamp'].add(liveTrails['shiptracks'][bship]['stamp'][i]);
            replayTracks['shiptracks'][aship]['lat'].add(liveTrails['shiptracks'][bship]['lat'][i]);
            replayTracks['shiptracks'][aship]['lon'].add(liveTrails['shiptracks'][bship]['lon'][i]);
            replayTracks['shiptracks'][aship]['speed'].add(liveTrails['shiptracks'][bship]['speed'][i]);
            replayTracks['shiptracks'][aship]['course'].add(liveTrails['shiptracks'][bship]['course'][i]);
          }
        }
      } else {
        // we had no ship with this name yet, just add it
        replayTracks['shiptracks'].add(liveTrails['shiptracks'][bship]);
        following[liveTrails['shiptracks'][bship]['name']] = followAll; // set following for this ship same as followAll checkbox
      }
      // sort the tracks based on colorcode
      replayTracks['shiptracks'].sort((a, b) => int.parse(a['colorcode']).compareTo(int.parse(b['colorcode'])));
    }
    // and the same for the weather stations
    for (int bws = 0; bws < liveTrails['windtracks'].length; bws++) {
      int aws = 0;
      for (aws; aws < replayTracks['windtracks'].length; aws++) {
        if (replayTracks['windtracks'][aws]['name'] == liveTrails['windtracks'][bws]['name']) break;
      }
      if (aws < replayTracks['windtracks'].length) {
        // we already had a weather station with this name
        int laststamp = replayTracks['windtracks'][aws]['stamp'].last;
        for (int i = 0; i < liveTrails['windtracks'][bws]['stamp'].length; i++) {
          if (liveTrails['windtracks'][bws]['stamp'][i] > laststamp) {
            replayTracks['windtracks'][aws]['stamp'].add(liveTrails['windtracks'][bws]['stamp'][i]);
            replayTracks['windtracks'][aws]['lat'].add(liveTrails['windtracks'][bws]['lat'][i]);
            replayTracks['windtracks'][aws]['lon'].add(liveTrails['windtracks'][bws]['lon'][i]);
            replayTracks['windtracks'][aws]['speed'].add(liveTrails['windtracks'][bws]['speed'][i]);
            replayTracks['windtracks'][aws]['course'].add(liveTrails['windtracks'][bws]['course'][i]);
          }
        }
      } else {
        // we had no weather station with this name yet
        replayTracks['windtracks'].add(liveTrails['windtracks'][bws]); // add the complete weather station
      }
    }
    replayTracks['endtime'] = liveTrails['endtime']; // set the new endtime and store locally
    // browsers do not allow us to store more then 5 Mbyte. But for the rest: store the updated tracks using the
    // eventId as unique identifier
    if (!kIsWeb) prefs.setString('live-$eventId', jsonEncode(replayTracks));
  }

  //
  // Routine to prepare info for the shipmenu: a list of shipnames and shipcolors,
  // and the values for the 'following' checkboxes in the shipmenu.
  // In live we only add an entry to the 'following' list if no entry for that ship existed, because
  // we want to retain the contents during the rebuild in live
  // In replay it does not matter because we do this only once
  // Also set the shipTimeIndices and windTimeIndices to zero (beginning of the tracks), but only if replay is not running
  //
  void buildShipAndWindInfo() {
    // empty all lists except the 'following' list
    shipList = [];
    shipColors = [];
    shipColorsSvg = [];
    followCounter = 0;
    dynamic shipTracks = replayTracks['shiptracks']; // get the
    for (int k = 0; k < shipTracks.length; k++) {
      shipList.add(shipTracks[k]['name']); // add the name to the shipList for the menu in the righthand drawer
      shipColors.add(shipMarkerColorTable[int.parse(shipTracks[k]['colorcode']) % 32]);
      shipColorsSvg.add('#${(shipColors.last - 0xFF000000).toRadixString(16).padLeft(6, '0')}');
      following.putIfAbsent(shipTracks[k]['name'], () => true); // set 'following' for this ship to true (if it was not already in the list)
      if (following[shipTracks[k]['name']] == true) followCounter++;
    }
    if (!replayRunning) {
      shipTimeIndex = [];
      for (var k = 0; k < replayTracks['shiptracks'].length; k++) {
        shipTimeIndex.add(0);
      }
      windTimeIndex = [];
      for (var k = 0; k < replayTracks['windtracks'].length; k++) {
        windTimeIndex.add(0);
      }
    }
  }

  //
  // Routines to get info from the server
  //
  // first the routine to get the list of events, see get-dirlist.php on the server
  Future<Map<String, dynamic>> getDirList() async {
    final response = await http.get(Uri.parse('${server}get/?req=dirlist&dev=$phoneId${(testing) ? '&tst=true' : ''}'));
    return (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : {};
  }

  //
  // get the event info
  Future<Map<String, dynamic>> getEventInfo(domain) async {
    final response = await http.get(Uri.parse('${server}get/?req=eventinfo&dev=$phoneId&event=$domain'));
    return (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : {};
  }

  //
  // get the route geoJSON file
  Future<Map<String, dynamic>> getRoute(domain) async {
    final response = await http.get(Uri.parse('${server}get/?req=route&dev=$phoneId&event=$domain'));
    return (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : {};
  }

  //
  // get the app icon url
  Future<String> getAppIconUrl({event = ''}) async {
    final response = await http.get(Uri.parse('${server}get?req=appiconurl${(event == '') ? '' : '&event=$eventDomain'}&dev=$phoneId'));
    return (response.statusCode == 200) ? response.body : '${server}assets/assets/images/defaultAppIcon.png';
  }

  //
  // routine for getting a replay json file (during the event max 5 minutes old)
  // the optional noData parameter is just for statistics collected by the server
  Future<Map<String, dynamic>> getReplayTracks(domain, {nodata = false}) async {
    final response = await http.get(Uri.parse('${server}get/?req=replay&dev=$phoneId&event=$domain'
        '${nodata ? '&nodata' : ''}'));
    return (response.statusCode == 200 && response.body != '') ? convertTimes(jsonDecode(response.body)) : {};
  }

  //
  // Same for the trails (during the event max 1 minute old)
  // the fromTime parameter is for getting trails longer then the eventTrailLength, and is a timestamp (in seconds!)
  Future<Map<String, dynamic>> getTrails(domain, {fromTime = 0}) async {
    final response =
        await http.get(Uri.parse('${server}get/?req=trails&dev=$phoneId&event=$domain${(fromTime != 0) ? "&msg=$fromTime" : ""}'));
    return (response.statusCode == 200 && response.body != '') ? convertTimes(jsonDecode(response.body)) : {};
  }

  //
  // Note all stamps in the file are in seconds. In the app we work with milliseconds so
  // after getting the jsonfile into a map, we multiply all stamps with 1000
  Map<String, dynamic> convertTimes(track) {
    track['starttime'] *= 1000;
    track['endtime'] *= 1000;
    for (int i = 0; i < track['shiptracks'].length; i++) {
      track['shiptracks'][i]['stamp'] = track['shiptracks'][i]['stamp'].map((val) => val * 1000).toList();
    }
    for (int i = 0; i < track['windtracks'].length; i++) {
      track['windtracks'][i]['stamp'] = track['windtracks'][i]['stamp'].map((val) => val * 1000).toList();
    }
    return track;
  }

  //
  // and finally a routine to get shipInfo from the server
  void loadShipInfo(ship) async {
    final response = await http.get(Uri.parse('${server}get/?req=shipinfo&dev=$phoneId&event=$eventDomain&ship=${shipList[ship]}'));
    shipInfoHTML = (response.statusCode == 200 && response.body != '') ? response.body : 'Could not load ship info';
    shipInfoHTML = shipInfoHTML.replaceFirst('Schipper:', skipper);
    replayPause = true;
    if (!showShipInfo) shipInfoPosition = Offset((screenWidth - 350) / 2, menuOffset + 25);
    showShipInfo = true;
    setState(() {});
  }

  //
  // routines to convert wind knots into Beaufort and SVG colors
  int knotsToBft(speedInKnots) {
    const List<int> windKnots = [0, 1, 3, 6, 10, 16, 21, 27, 33, 40, 47, 55, 63];
    return windKnots.indexOf(windKnots.firstWhere((i) => i >= speedInKnots)).toInt();
  }

  //
  String knotsToColor(speedInKnots) {
    const List windColorTable = [
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

  //
  // predict new location based on initial location, speed in km/h, time in milliseconds and course in degrees
  LatLng predictPosition(LatLng initialPosition, double speed, int time, int course) {
    var rdist = (speed / 3600) * time / 1000 / 6371; // angular distance in radians
    var rcourse = course * pi / 180; // course in radians
    var rlat1 = initialPosition.latitudeInRad; // last known position in radians
    var rlon1 = initialPosition.longitudeInRad;
    var rlat2 = asin(sin(rlat1) * cos(rdist) + cos(rlat1) * sin(rdist) * cos(rcourse));
    var rlon2 = rlon1 + atan2(sin(rcourse) * sin(rdist) * cos(rlat1), cos(rdist) - sin(rlat1) * sin(rlat2));
    rlon2 = ((rlon2 + (3 * pi)) % (2 * pi)) - pi; // normalise to -180..+180º
    return LatLng(rlat2 * 180 / pi, rlon2 * 180 / pi);
  }
}
