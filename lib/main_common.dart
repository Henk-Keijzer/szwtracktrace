import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';

import 'package:bordered_text/bordered_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:media_kit/media_kit.dart';

import 'default_data.dart';
import 'services/api_service.dart';
import 'services/helpers.dart';
import 'services/localization_service.dart';
import 'widgets/animated_menu.dart';
import 'uicomponents/app_bar.dart';
import 'uicomponents/attribution_panel.dart';
import 'uicomponents/cookie_consent_panel.dart';
import 'uicomponents/event_menu.dart';
import 'uicomponents/floating_pip_video.dart';
import 'uicomponents/info_page.dart';
import 'uicomponents/language_menu.dart';
import 'uicomponents/main_map.dart';
import 'uicomponents/map_menu.dart';
import 'uicomponents/menu_button_bar.dart';
import 'uicomponents/participants_menu.dart';
import 'uicomponents/pre_event_participants_menu.dart';
import 'uicomponents/ship_info_panel.dart';
import 'uicomponents/slider_area.dart';
import 'uicomponents/testing_menu.dart';
import 'widgets/video_player_widget.dart';

//
//------------------------------------------------------------------------------------------------------------------------------------------
//
// top level definitions
enum EventStatus { initial, preEvent, live, replay }

enum OpenMenu { none, language, event, infoPage, map, ship, preEventParticipants, testing }

extension ResetTicker on Ticker {
  void reset() {
    stop();
    start();
  }
}

String debugString = '12345';
//
//------------------------------------------------------------------------------------------------------------------------------------------
//
// main routine (as called from main())
void mainCommon({required String serverUrl}) {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(MyApp(variantServerUrl: serverUrl)); // pass on the serverUrl as appVariantServerUrl to MyApp
}

//
//------------------------------------------------------------------------------------------------------------------------------------------
//
class MyApp extends StatefulWidget {
  final String variantServerUrl;
  const MyApp({super.key, required this.variantServerUrl});
  @override
  State<MyApp> createState() => MyAppState();
}

//
//------------------------------------------------------------------------------------------------------------------------------------------
//
class MyAppState extends State<MyApp> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  //
  // global appState variables
  //
  String serverUrl = ''; // stores the full server url, as received from main()
  String server = ''; // modified server url depending on whether we run as web ('/') or as an app (full server url)

  late PackageInfo packageInfo;
  late ApiService apiService;
  late SharedPreferencesWithCache prefs;
  late LocalizationService txt;

  final bool kIsDesktop = !kIsWeb && {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);
  final bool kIsWebOnIOS = kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS);
  final bool kIsWebOnAndroid = kIsWeb && (defaultTargetPlatform == TargetPlatform.android);
  String phoneId = '';
  String platformLanguage = 'nl';

  String queryPlayString = '::'; // stores the querystring (?event=eventDomain&play=true/false:currentReplayTime:replaySpeed)

  late Map<dynamic, dynamic> config; // stores the contents of the flutter-config file, merged with the default config file)

  double screenWidth = 0;
  double screenHeight = 0;
  double menuOffset = 0; // is actually the height of the appbar

  // map related vars
  final MapController mapController = MapController();
  LatLng initialMapPosition = LatLng(52.5, 5.0);
  double initialMapZoom = 9;
  bool mapReady = false;

  Map<String, dynamic> baseMapTileProviders = {};
  String selectedMapType = 'Standaard';
  String bgColor = '';
  Map<String, dynamic> overlayTileProviders = {};
  String selectedOverlayType = '';
  bool mapOverlay = false;
  Map<String, dynamic> labelTileProviders = {};
  String labelOverlayType = '';

  // vars related to event selection
  Map<String, dynamic> dirList = {};
  List<String> eventNameList = [];
  List<String> eventYearList = [];
  List<String> eventDayList = [];
  String eventDomain = '';
  String eventName = 'seLectAnEvent';
  String eventYear = '';
  String eventDay = '';
  final GlobalKey dropEventKey = GlobalKey();
  final GlobalKey dropYearKey = GlobalKey();
  final GlobalKey dropDayKey = GlobalKey();

  // vars related to a specific event, as defined in event.json on the server
  Map<String, dynamic> eventInfo = {};
  String eventTitle = 'SZW Track&Trace';
  String eventId = '';
  String appIconUrl = '';
  int eventStart = 0;
  int eventEnd = 0;
  int sliderEnd = 0;
  int maxReplay = 0;
  bool allowShowSpeed = true;
  bool hfUpdate = true;
  bool showTeam = false;
  bool allowTeams = false;
  int displayDelay = 30;
  int predictTime = 30;
  int hfUpdateInterval = 100;
  bool allowShowWind = false;
  int trailsUpdateInterval = 30;
  int signalLostTime = 180;
  int trailLength = 30;
  int eventTrailLength = 30;
  bool allowMaxTrailLengths = false;
  String socialMediaUrl = '';
  List<String> videoIdList = [];
  int videoIndex = 0;

  EventStatus eventStatus = EventStatus.initial;

  // vars related to the participants and their presentation on the menu and map
  Map<String, dynamic> replayTracks = {};
  Map<String, dynamic> liveTrails = {};
  List<String> shipList = [];
  List<String> teamList = [];
  List<String> shipLostSignalIndicators = [];
  List<Color> shipColors = [];
  List<String> shipColorsSvg = [];
  String shipSvgPath = '';
  Color markerBackgroundColor = Colors.black;
  Color labelBackgroundColor = Colors.white;

  List<Marker> shipMarkerList = [];
  List<Marker> shipLabelList = [];
  List<Polyline> shipTrailList = [];
  List<Marker> gpsBuoyMarkerList = [];
  List<Marker> gpsBuoyLabelList = [];
  List<Polyline> gpsBuoyLineList = [];
  List<Marker> gpsBuoyLineArrowList = [];
  List<Marker> windMarkerList = [];
  List<Marker> routeMarkerList = [];
  List<Marker> routeLabelList = [];
  List<Polyline> routeLineList = [];
  List<Polygon> routePolygons = [];
  List<Marker> infoWindowMarkerList = [];
  Map<String, LatLng> routeBuoyPositionList = {};
  String infoWindowId = '';

  Map<String, bool> following = {};
  bool followAll = true;
  bool autoZoom = true;
  bool autoFollow = true;
  bool moveWhileNotInFocus = false;

  // timers and replay related stuff
  List<int> shipTimeIndices = [];
  List<int> gpsBuoyTimeIndices = [];
  List<int> windTimeIndex = [];
  late Timer preEventTimer;
  int preEventSecondsTimer = 60;
  late Timer liveTimer;
  int liveSecondsCounter = 60;
  late Ticker replayTicker;
  int currentReplayTime = 0;
  bool replayRunning = false;
  bool manualSliderMove = false;
  bool replayLoop = false;
  int speedIndex = speedIndexInitialValue;

  // menu related stuff
  OpenMenu activeMenu = OpenMenu.none;
  Map<OpenMenu, Widget> get _menuWidgets => {
        OpenMenu.language: LanguageMenu(appState: this),
        OpenMenu.event: EventMenu(appState: this),
        OpenMenu.infoPage: InfoPage(appState: this),
        OpenMenu.map: MapMenu(appState: this),
        OpenMenu.ship: ParticipantsMenu(appState: this),
        OpenMenu.preEventParticipants: PreEventParticipantsMenu(appState: this),
        OpenMenu.testing: TestingMenu(appState: this),
      };
  bool showMenuButtonBar = true;
  bool enableMapRotation = false;
  bool showRouteFences = false;
  bool showShipInfo = false;
  bool showAttribution = false;
  bool showProgress = false;
  bool cookieConsentGiven = false;
  bool fullScreen = false;
  bool showVideo = false;
  bool mapOnly = false;

  static const double appBarHeight = 40;
  Color menuAccentColor = const Color(0xFFFFFFFF);
  Color menuBackgroundColor = const Color(0xFF455A64);
  Color menuForegroundColor = const Color(0xFFC8CED1);
  String infoPageHTML = '';
  bool testing = false;
  double gpsBuoyTotalLineLength = 0.0;

  bool showWindMarkers = false;
  bool showWindParticles = false;
  int windParticlesSpeed = 0;
  int windParticlesDirection = 0;
  bool windPaused = false;

  // route related vars
  Map<String, dynamic> route = {};
  bool showRoute = true;
  bool showRouteLabels = false;
  bool showShipLabels = true;
  bool showShipSpeeds = false;

  // ship info panel
  String shipInfoHTML = '';
  Offset shipInfoPosition = Offset(60, 60);
  Offset shipInfoPositionAtDragStart = Offset(0, 0);

  // language related vars
  List<String> supportedLanguages = [];
  String currentLanguage = 'en';
  late DateFormat dtFormat;
  late DateFormat dtsFormat;

  bool initializationComplete = false;
  //
  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // flutter routines for initialization, lifecyclechange and dispose
  //
  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeApp();
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!moveWhileNotInFocus && !showVideo) {
      switch (state) {
        case AppLifecycleState.inactive || AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached:
          setState(() {
            if (eventStatus == EventStatus.preEvent) preEventTimer.cancel();
            if (eventStatus == EventStatus.live) liveTimer.cancel();
            if (replayTicker.isActive) replayTicker.stop();
            windPaused = true;
          });
        case AppLifecycleState.resumed:
          setState(() {
            if (eventStatus == EventStatus.preEvent) {
              preEventTimer = Timer.periodic(const Duration(seconds: 1), (_) => preEventTimerRoutine());
            }
            if (eventStatus == EventStatus.live) {
              liveSecondsCounter = 1;
              liveTimer = Timer.periodic(Duration(milliseconds: hfUpdateInterval), (_) => liveTimerRoutine());
            }
            if (replayRunning && !replayTicker.isActive) replayTicker.start();
            windPaused = false;
          });
      }
    }
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    replayTicker.dispose();
    if (preEventTimer.isActive) preEventTimer.cancel();
    if (liveTimer.isActive) liveTimer.cancel();
    super.dispose();
  }

  //
  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // our own app initialization routine (called from initState)
  //
  void initializeApp() async {
    packageInfo = await PackageInfo.fromPlatform();
    prefs = await SharedPreferencesWithCache.create(cacheOptions: SharedPreferencesWithCacheOptions());
    await initializeDateFormatting('nl');
    replayTicker = createTicker((elapsed) => replayTickerRoutine(elapsed));

    serverUrl = widget.variantServerUrl; // get the serverUrl from the main routine
//    server = kIsWeb ? '/' : serverUrl;
    server = serverUrl;

    //
    // in case of a new app version, keep the cookieConsent, but delete the rest of the saved data
    String oldAppVersion = prefs.getString('appversion') ?? '';
    cookieConsentGiven = prefs.getBool('cookieconsent') ?? false;
    if (oldAppVersion != packageInfo.buildNumber) {
      await prefs.clear();
      prefs.setString('appversion', packageInfo.buildNumber);
    }
    await prefs.setBool('cookieconsent', cookieConsentGiven);
    // in case we run as an embedded web-page (iframe), we don't ask for consent
    if (isEmbeddedInIframe()) cookieConsentGiven = true;
    //
    // get or create a device / phone id for this device
    phoneId = prefs.getString('phoneid') ?? const Uuid().v1();
    await prefs.setString('phoneid', phoneId);
    String prefix = switch (defaultTargetPlatform) {
      TargetPlatform.android => kIsWeb ? 'GA' : 'A',
      TargetPlatform.iOS => kIsWeb ? 'GI' : 'I',
      TargetPlatform.windows => kIsWeb ? 'GD' : 'W',
      TargetPlatform.macOS => kIsWeb ? 'GD' : 'M',
      TargetPlatform.linux => kIsWeb ? 'GD' : 'L',
      TargetPlatform.fuchsia => kIsWeb ? 'GD' : 'U',
    };
    phoneId = '$prefix${packageInfo.buildNumber}-$phoneId';
    //
    // now that we know the server and have a phoneId, create the api service for communication with the server
    final sslCert = await rootBundle.load('assets/cert/zeilvaart.pem');
    apiService = ApiService(server: server, phoneId: phoneId, sslCert: sslCert.buffer.asUint8List());
    //
    // get the (flutter) config file from the server and merge it with the default config, just to make sure that 'old' config files
    // can also be handled. Store the data in easy to handle vars
    config = await apiService.getConfig();
    mergeMaps(config, defaultConfig);
    //
    // set the basic app colors
    menuAccentColor = Color(int.parse(config['colors']['menuAccentColor'], radix: 16));
    menuBackgroundColor = Color(int.parse(config['colors']['menuBackgroundColor'], radix: 16));
    menuForegroundColor = Color(int.parse(config['colors']['menuForegroundColor'], radix: 16));
    // and the boat icon as svg
    shipSvgPath = config['icons']['boatSVGPath'];
    //
    // get the initial language from the server config file and set the language parameters
    supportedLanguages = config['options']['localizations'].split(",").map((s) => s.trim()).toList().cast<String>();
    currentLanguage = prefs.getString('language') ?? PlatformDispatcher.instance.locale.languageCode;
    currentLanguage = supportedLanguages.contains(currentLanguage) ? currentLanguage : supportedLanguages[0];
    await prefs.setString('language', currentLanguage);
    dtFormat = DateFormat("d MMM y, HH:mm", currentLanguage);
    dtsFormat = DateFormat("d MMM y, HH:mm:ss", currentLanguage);
    // initialize the localization service and load the translations
    txt = LocalizationService(server: server);
    await txt.load(currentLanguage);
    //
    // get the URL of the initial AppIcon, it can be overwritten by the event appicon.png
    appIconUrl = await apiService.getAppIconUrl();
    //
    // get the infopage from the server and add some data to it
    infoPageHTML = await apiService.getInfoPage(currentLanguage);
    infoPageHTML += '<br><br>appname: ${packageInfo.appName}, version ${packageInfo.version}<br>'
        'package: ${packageInfo.packageName}<br>server: $server</body></html>';
    //
    // get the map tile providers from the server and set up the three lists of map tile providers
    // then initialize the map vars with the selection from a previous run
    Map<String, dynamic> mapData = await apiService.getMapTileProviders();
    if (mapData.isEmpty) mapData = defaultMapTileProviders; // Fallback to defaults on API failure
    baseMapTileProviders = mapData['basemaps'] ?? {};
    overlayTileProviders = mapData['overlays'] ?? {};
    labelTileProviders = mapData['labels'] ?? {};
    // basemap (get the selection from a previous run, or take the first of the providers list)
    selectedMapType = prefs.getString('maptype') ?? baseMapTileProviders.keys.toList().first;
    // ignore saved maptype if we receive the maptype on web via a query string
    selectedMapType =
        (kIsWeb && Uri.base.queryParameters.containsKey('map')) ? Uri.base.queryParameters['map'].toString() : selectedMapType;
    // select the first maptype if we don't have one that is in the providers list
    selectedMapType =
        (!baseMapTileProviders.keys.toList().contains(selectedMapType)) ? baseMapTileProviders.keys.toList().first : selectedMapType;
    await prefs.setString('maptype', selectedMapType);
    bgColor = baseMapTileProviders[selectedMapType]['bgColor'];
    markerBackgroundColor = (bgColor == '#000000') ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    labelBackgroundColor = (bgColor == '#000000') ? const Color(0x7FFFFFFF) : const Color(0x7F000000);
    // map overlay
    mapOverlay = prefs.getBool('mapoverlay') ?? false;
    selectedOverlayType = prefs.getString('overlaytype') ?? '';
    // get the overlay type from the query string, if we have a query string: &overlay=true/false:overlaytype
    if (kIsWeb && Uri.base.queryParameters.containsKey('overlay')) {
      var a = Uri.base.queryParameters['overlay'].toString().split(':');
      mapOverlay = (a[0] == 'true') ? true : false;
      selectedOverlayType = a[1];
    }
    // set mapOverly (checkbox) to false if there are no overlay providers defined
    mapOverlay = overlayTileProviders.isNotEmpty ? mapOverlay : false;
    // set the overlay type to '' if the provider list is empty or does not contain the selected type from shared mem or query string
    if (overlayTileProviders.isEmpty) {
      selectedOverlayType = '';
    } else {
      selectedOverlayType = (overlayTileProviders.keys.toList().contains(selectedOverlayType))
          ? selectedOverlayType
          : overlayTileProviders.keys.toList().first;
    }
    await prefs.setBool('mapoverlay', mapOverlay);
    await prefs.setString('overlaytype', selectedOverlayType);
    //
    // get the eventDomain from a previous run (if available)
    eventDomain = prefs.getString('domain') ?? "";
    // or get it from the query string &event=eventDomain
    if (kIsWeb) eventDomain = Uri.base.queryParameters['event'] ?? eventDomain;
    // get the play params from the query string: '&play=true/false:[currentReplayTime]:[replaySpeed]'
    queryPlayString = (kIsWeb && Uri.base.queryParameters.containsKey('play'))
        ? queryPlayString = '${Uri.base.queryParameters['play']}::'
        : queryPlayString;
    //
    // get some other params from a previous run (or leave them as originally initialized)
    showWindMarkers = prefs.getBool('windmarkers') ?? showWindMarkers;
    await prefs.setBool('windmarkers', showWindMarkers);
    showWindParticles = prefs.getBool('windparticles') ?? showWindParticles;
    await prefs.setBool('windmarkers', showWindParticles);
    showRoute = prefs.getBool('showroute') ?? showRoute;
    await prefs.setBool('showroute', showRoute);
    showRouteLabels = prefs.getBool('routelabels') ?? showRouteLabels;
    await prefs.setBool('routelabels', showRouteLabels);
    showShipLabels = prefs.getBool('shiplabels') ?? showShipLabels;
    await prefs.setBool('shiplabels', showShipLabels);
    showShipSpeeds = prefs.getBool('shipspeeds') ?? showShipSpeeds;
    if (!allowShowSpeed) showShipSpeeds = false;
    await prefs.setBool('shipspeeds', showShipSpeeds);
    //
    // app initialization ready, now build the real ui with all ui elements and start our app logic after the map is ready
    initializationComplete = true;
    setState(() {});
  }

  //
  // define a simple routine that can be called from uicomponents and other routines to refresh the ui
  void refreshUI() => setState(() {});
  //
  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // here we build our 'simple' one page ui
  // the different components (widgets) are in separate files under uicomponents
  //
  @override
  Widget build(BuildContext context) {
    // Just show a blank page with a progress bar until the initialization is complete and we can show the map
    if (!initializationComplete) {
      return Container(
          color: Colors.blueGrey.shade200,
          child: Center(child: Transform.scale(scale: 3, child: CircularProgressIndicator(color: Colors.white))));
    }
    // Else we return a MaterialApp with the ui
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    menuOffset = MediaQuery.of(context).viewPadding.top + appBarHeight;
    return MaterialApp(
        debugShowCheckedModeBanner: testing,
        title: eventTitle,
        theme: ThemeData(
          useMaterial3: true,
          canvasColor: menuBackgroundColor,
          dividerColor: menuForegroundColor,
          textTheme: TextTheme(bodyMedium: TextStyle(color: menuForegroundColor, fontSize: 15)),
        ),
        locale: Locale(currentLanguage),
        home: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: true,
            child: Scaffold(
                appBar: CustomAppBar(appState: this),
                extendBodyBehindAppBar: true,
                body: Column(children: [
                  Expanded(
                      child: Stack(children: [
                    MapView(appState: this),
                    if (showVideo && (screenWidth > screenHeight / 1.6)) FloatingPipVideo(appState: this),
                    if ((eventStatus == EventStatus.live || eventStatus == EventStatus.replay) && (eventStart != eventEnd))
                      SliderArea(appState: this),
                    AttributionPanel(appState: this),
                    AnimatedMenu(isVisible: showMenuButtonBar, child: MenuButtonBar(appState: this)),
                    ..._menuWidgets.entries.map((e) => AnimatedMenu(isVisible: activeMenu == e.key, child: e.value)),
                    if (showShipInfo) ShipInfoPanel(appState: this),
                    if (!cookieConsentGiven) CookieConsentBanner(appState: this),
                    if (showProgress)
                      Center(child: Transform.scale(scale: 3, child: CircularProgressIndicator(color: menuForegroundColor))),
                  ])),
                  if (showVideo && (screenWidth <= screenHeight / 1.6))
                    VideoPlayerWidget(videoIdList: videoIdList, index: videoIndex, onClose: (index) => videoIndex = index),
                ]))));
  }

  //
  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // This onMapCreated routine is called when UI is built and the map is ready.
  // Here we start up the rest of the initialization of our app and all of the state routines
  //
  void onMapCreated() async {
    mapReady = true;
    dirList = await apiService.getDirList(testing: false);
    selectEvent();
  }

  //
  // three routines for selection of an event/year/day as part of the eventmenu
  // 1. prepare the directory tree the user can select from, starting with the eventdomain
  //
  void selectEvent() {
    eventNameList = dirList.keys.toList();
    eventNameList.sort();
    eventYearList = [];
    eventDayList = [];
    // open the eventMenu
    toggleMenu(OpenMenu.event);
    if (eventDomain != "") {
      // we have an eventDomain from a previous run
      List eventSubStrings = ('$eventDomain///').split('/');
      if (dirList.containsKey(eventSubStrings[0])) {
        // we have a valid event name
        eventName = eventSubStrings[0];
        eventYearList = dirList[eventName].keys.toList();
        eventYearList.sort();
        if (config['options']['sortyearreverse'] == 'true') eventYearList = eventYearList.reversed.toList();
        if (eventYearList.contains(eventSubStrings[1])) {
          // we also have a valid year
          eventYear = eventSubStrings[1];
          if (dirList[eventName][eventYear].isEmpty) {
            // we have a valid event and a valid year, but the event does nor have days, so we can load the race
            newEventSelected('');
          } else {
            // we have a valid event and year, and this race has days
            eventDayList = dirList[eventName][eventYear].keys.toList();
            eventDayList.sort();
            if (eventDayList.contains(eventSubStrings[2])) {
              // have a valid even, year and day, so we can load the race
              eventDay = eventSubStrings[2];
              newEventSelected(eventDay);
            } else {
              // we have a valid event and year, but no day yet. Wait a bit and ask the user to select a day
              Timer(const Duration(milliseconds: 600), () {
                selectEventDay(eventYear);
              });
            }
          }
        } else {
          // we have a valid event, but no year yet. Wait a bit and ask the user to select a year
          Timer(const Duration(milliseconds: 600), () {
            selectEventYear(eventName);
          });
        }
      } else {
        // we had an eventname, but is was not valid. Fall through
        eventDomain = '';
      }
    }
    if (eventDomain == '') {
      eventName = txt.str('selectAnEvent');
      eventYear = '';
      eventDay = '';
      // now dropdown the list of events for the user to select from. from there we jump to the next routine: selectEventYear
      Timer(const Duration(milliseconds: 600), () {
        setState(() {
          dynamic state = dropEventKey.currentState;
          state?.showButtonMenu();
        });
      });
    }
    setState(() {});
  }

  //
  // 2. handle the selected event and ask for the year
  void selectEventYear(String event) {
    eventName = event;
    eventYearList = [];
    eventYearList = dirList[event].keys.toList();
    eventYearList.sort();
    if (config['options']['sortyearreverse'] == 'true') eventYearList = eventYearList.reversed.toList();
    eventYear = txt.str('selectAYear');
    // same here, we have a valid event, now drop the list of years for the user to select from,
    // and from there we jump to the next routine: selectEventDay
    Timer(const Duration(milliseconds: 600), () {
      setState(() {
        dynamic state = dropYearKey.currentState;
        state?.showButtonMenu();
      });
    });
    eventDay = '';
    eventDayList = [];
    setState(() {});
  }

  //
  // 3 handle the selected year and ask for the day
  void selectEventDay(String year) {
    eventYear = year;
    eventDayList = [];
    if (dirList[eventName][eventYear].length != 0) {
      eventDayList = dirList[eventName][eventYear].keys.toList();
      eventDayList.sort();
      eventDay = txt.str('selectADayRace');
      // and finally we drop the list of days for the user to select from, and from there we jump to the next routine: newEventSelected
      Timer(const Duration(milliseconds: 600), () {
        setState(() {
          dynamic state = dropDayKey.currentState;
          state?.showButtonMenu();
        });
      });
      setState(() {});
    } else {
      // no races under the year the user selected, so go to the next routine: newEventSelected
      newEventSelected('');
    }
  }

  //
  // finally handle the selected event/year/(day) and start the event
  void newEventSelected(String day) async {
    // construct the eventDomain and store it in shared preferences
    eventDay = day;
    eventDomain = '$eventName/$eventYear${eventDay == '' ? '' : '/$eventDay'}';
    await prefs.setString('domain', eventDomain);
    // show the selected event as a complete url in the web addressbar
    setBrowserUrl(eventDomain);
    // kill anything that was running
    if (eventStatus == EventStatus.preEvent) preEventTimer.cancel();
    if (eventStatus == EventStatus.live) liveTimer.cancel();
    if (replayTicker.isTicking) replayTicker.stop();
    replayRunning = false;
    setState(() => showProgress = true);
    // start initializing our variables for the new event
    following = {};
    followAll = true;
    autoZoom = true;
    replayLoop = false;
    showShipInfo = false;
    replayTracks = {};
    shipList = [];
    teamList = [];
    shipColors = [];
    shipColorsSvg = [];
    shipMarkerList = [];
    shipLabelList = [];
    shipTrailList = [];
    gpsBuoyMarkerList = [];
    gpsBuoyLabelList = [];
    gpsBuoyLineList = [];
    gpsBuoyLineArrowList = [];
    windMarkerList = [];
    infoWindowMarkerList = [];
    infoWindowId = '';
    routeMarkerList = [];
    routeLabelList = [];
    routeLineList = [];
    routePolygons = [];
    // get all necessary data from the server
    eventInfo = await apiService.getEventInfo(event: eventDomain);
    appIconUrl = await apiService.getAppIconUrl(event: eventDomain);
    route = await apiService.getRoute(event: eventDomain);
    //
    // unravel the info from the event file (and set defaults if data is missing)
    // basic event data
    eventTitle = eventInfo['eventtitle'] ?? '--';
    eventId = eventInfo['eventid'] ?? '--';
    eventStart = int.parse(eventInfo['eventstartstamp'] ?? '0') * 1000;
    eventEnd = int.parse(eventInfo['eventendstamp'] ?? '0') * 1000;
    showMenuButtonBar = (eventStart != eventEnd);
    sliderEnd = eventEnd; // make sure that slider max >= slider min (the beginning of the slider is always eventStart)
    // trail related data
    eventTrailLength = int.parse(eventInfo['traillength'] ?? '30');
    trailLength = eventTrailLength;
    allowMaxTrailLengths = bool.parse(eventInfo['allowmaxtraillengths'] ?? 'false');
    // endless event with max replay?
    maxReplay = int.parse(eventInfo['maxreplay'] ?? '0');
    // live update parameters, including prediction and signal loss times
    trailsUpdateInterval = max(5, int.parse(eventInfo['trailsupdateinterval'] ?? '5')) * 1000;
    hfUpdate = bool.parse(eventInfo['hfupdate'] ?? 'false');
    displayDelay = hfUpdate ? (int.parse(eventInfo['displaydelay'] ?? '30')) * 1000 : 0;
    predictTime = hfUpdate ? (int.parse(eventInfo['predicttime'] ?? '15')) * 1000 : 0;
    signalLostTime = int.parse(eventInfo['signallosttime'] ?? '60') * 1000;
    // team related data (sorry for the inconsistency, but it is too late to change things now)
    allowTeams = bool.parse(eventInfo['showteam'] ?? 'false');
    showTeam = bool.parse(eventInfo['showteamdefault'] ?? 'false');
    // link when logo in event menu is clicked
    eventInfo['mediaframe'] ??= ''; // we used to have the twitter/facebook timeline in a small iframe in the past, hence 'mediaframe'
    socialMediaUrl = switch (eventInfo['mediaframe'].split(':').first) {
      'facebook' => 'https://www.facebook.com/${eventInfo['mediaframe'].split(':').last}',
      'twitter' || 'X' => 'https://www.x.com/${eventInfo['mediaframe'].split(':').last}',
      'http' || 'https' => eventInfo['mediaframe'],
      _ => ''
    };
    // video stuff
    eventInfo['pipvideo'] ??= '';
    videoIdList = (eventInfo['pipvideo'].isEmpty) ? [] : eventInfo['pipvideo'].split(",").map((s) => s.trim()).toList().cast<String>();
    videoIndex = 0;
    showVideo = false;
    //
    // other parameters
    allowShowSpeed = bool.parse(eventInfo['allowspeed'] ?? 'true');
    allowShowWind = bool.parse(eventInfo['buienradar'] ?? 'true');
    //
    // ok, we have all info we need, now what state are we in...
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (true) {
      case _ when eventStart > now:
        startPreEvent();
      case _ when eventEnd > now:
        startLive();
      default:
        startReplay();
    }
    setState(() {});
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // three routines for handling the pre-event status
  void startPreEvent() async {
    eventStatus = EventStatus.preEvent;
    List<dynamic> participants = await apiService.getParticipants(event: eventDomain);
    for (var participant in participants) {
      shipColors.add(Color(shipMarkerColorTable[int.parse(participant['colorcode']) % 32]));
      shipList.add(participant['shipname']);
      teamList.add(participant['teamname'] != '' ? participant['teamname'] : 'Team ${participant['shipname']}');
    }
    if ((route['features'] ?? []).isNotEmpty) {
      showRoute = true;
      showRouteLabels = true;
      buildRoute(move: true);
    }
    setState(() => showProgress = false);
    // if we are running in an iframe on web, hide all menu's, else keep the event menu open to allow selection of a different event
    if (isEmbeddedInIframe()) Timer(const Duration(milliseconds: 1500), () => setState(() => toggleMenu(OpenMenu.none)));
    preEventSecondsTimer = 0;
    preEventTimer = Timer.periodic(const Duration(seconds: 1), (_) => preEventTimerRoutine());
  }

  // the updatePreEvent routine is async and cannot be cancelled, that why we have this 'dummy' timerroutine
  void preEventTimerRoutine() => updatePreEvent();

  void updatePreEvent() async {
    if (preEventSecondsTimer-- <= 0) {
      preEventSecondsTimer = 60;
      // get an updated version of the eventinfo, in case the start of the event has changed
      var temp = await apiService.getEventInfo(event: eventDomain, noStats: true);
      eventStart = int.parse(temp['eventstartstamp']) * 1000;
    }
    setState(() {});
    if (DateTime.now().millisecondsSinceEpoch > eventStart) {
      preEventTimer.cancel();
      setState(() => showProgress = true);
      startLive();
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // also three routines for handling the live status
  void startLive() async {
    eventStatus = EventStatus.live;
    if (maxReplay == 0) {
      // 'normal' event. See if the user watched before and have saved tracks already
      String savedTrails = prefs.getString('live-$eventId') ?? '';
      if (savedTrails != '') {
        replayTracks = apiService.safeJsonDecode(savedTrails);
      } else {
        replayTracks = await apiService.getReplayTracks(event: eventDomain, noStats: true);
      }
      // now get additional tracks from the time the time we already data
      var fromTime = replayTracks['filestamp'] ?? eventStart;
      liveTrails = await apiService.getTrails(event: eventDomain, fromTime: fromTime ~/ 1000);
      replayTracks = mergeTracks(replayTracks, liveTrails);
    } else {
      // it is an 'ongoing' event, set the eventstart maxReplay hours ago
      eventStart = DateTime.now().millisecondsSinceEpoch - (maxReplay * 60 * 60 * 1000);
      replayTracks = await apiService.getTrails(event: eventDomain, fromTime: eventStart ~/ 1000);
    }
    if (!kIsWeb) await prefs.setString('live-$eventId', jsonEncode(replayTracks));
    // setup the lists for menu's and for the moveShipsBuoysAndWindTo routine
    setupShipGpsBuoyAndWindLists(replayTracks);
    following = {for (var name in shipList) name: true};
    if ((route['features'] ?? []).isNotEmpty) buildRoute();
    sliderEnd = currentReplayTime = DateTime.now().millisecondsSinceEpoch;
    speedIndex = speedIndexInitialValue;
    if (queryPlayString != '::') {
      var a = queryPlayString.split(':');
      queryPlayString = '::';
      if (a[1] != '' && a[1] != '0') currentReplayTime = int.parse(a[1]);
      if (a[2] != '' && a[2] != '0') speedIndex = int.parse(a[2]);
      if (a[0] == 'true') startStopRunning();
    }
    autoFollow = true;
    autoZoom = true;
    moveShipsBuoysAndWindTo(currentReplayTime, moveMap: true);
    liveSecondsCounter = trailsUpdateInterval ~/ hfUpdateInterval;
    liveTimer = Timer.periodic(Duration(milliseconds: hfUpdateInterval), (_) => liveTimerRoutine());
    showProgress = false;
    Timer(const Duration(milliseconds: 1500), () => toggleMenu(OpenMenu.none));
  }

  // again a cancellable timerroutine, because updateLive is async
  void liveTimerRoutine() => updateLive();

  void updateLive() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now > eventEnd) {
      // event is over, stop the live timer
      liveTimer.cancel();
      setState(() => showProgress = true);
      startReplay();
      return;
    }
    // else update the live data
    if (liveSecondsCounter-- <= 0) {
      // reset the counter
      liveSecondsCounter = trailsUpdateInterval ~/ hfUpdateInterval;
      //
      // see how old our replay data is, and if older then two times the update interval, get an update with a from time
      if ((now - replayTracks['filestamp']) > (trailsUpdateInterval * 2)) {
        liveTrails = await apiService.getTrails(event: eventDomain, fromTime: replayTracks['filestamp'] ~/ 1000);
      } else {
        liveTrails = await apiService.getTrails(event: eventDomain);
      }
      //
      // set the endtime to the possibly updated endtime in the trails we received
      eventEnd = liveTrails['endtime'];
      // add the received trails to the tracks we already had
      replayTracks = mergeTracks(replayTracks, liveTrails);
      // and save the updated tracks to the prefs
      if (!kIsWeb) prefs.setString('live-$eventId', jsonEncode(replayTracks));
      // and update the lists of ships, gpsbuoys and wind for the menu's and for the moveShipsBuoysAndWindTo routine
      setupShipGpsBuoyAndWindLists(replayTracks);
    }
    if (currentReplayTime == sliderEnd) {
      // we are at the end of the slider, i.e. we are really live and not replaying during live
      sliderEnd = now;
      currentReplayTime = now;
      moveShipsBuoysAndWindTo(currentReplayTime, moveMap: true);
    } else {
      // the user moved the slider backwards, just update the sliderEnd but not the currentReplayTime
      sliderEnd = now;
      if (!replayRunning || manualSliderMove) {
        // if replayrunning, the replayTicker will handle the currentReplayTime. If not we move the ships based on the manual move
        moveShipsBuoysAndWindTo(currentReplayTime, moveMap: true);
      }
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // and three routines for handling the replay status
  void startReplay() async {
    eventStatus = EventStatus.replay;
    // get rid of any saved tracks during live
    prefs.remove('live-$eventId');
    // See if we have saved tracks already, and if so, just inform the server for statistics
    if (prefs.getString('replay-$eventId') case final String savedTracks) {
      apiService.getReplayTracks(event: eventDomain, noData: true);
      replayTracks = jsonDecode(savedTracks);
    } else {
      // get the event's tracks from the server
      replayTracks = await apiService.getReplayTracks(event: eventDomain);
      if (!kIsWeb && replayTracks.isNotEmpty) await prefs.setString('replay-$eventId', jsonEncode(replayTracks));
    }
    sliderEnd = replayTracks['endtime'];
    replayRunning = false;
    setupShipGpsBuoyAndWindLists(replayTracks);
    following = {for (var name in shipList) name: true};
    autoFollow = autoZoom = true;
    currentReplayTime = eventStart;
    speedIndex = speedIndexInitialValue;
    if (queryPlayString != '::') {
      var a = queryPlayString.split(':');
      queryPlayString = '::';
      if (a[1] != '' && a[1] != '0') currentReplayTime = int.parse(a[1]);
      if (a[2] != '' && a[2] != '0') speedIndex = int.parse(a[2]);
      if (a[0] == 'true') startStopRunning();
    }
    showRoute = true;
    if (shipList.isEmpty) showRouteLabels = true;
    if ((route['features'] ?? []).isNotEmpty) buildRoute(move: true);
    showProgress = false;
    moveShipsBuoysAndWindTo(currentReplayTime, moveMap: false);
    Timer(const Duration(milliseconds: 1500), () => setState(() => toggleMenu(OpenMenu.none)));
  }

  void replayTickerRoutine(Duration elapsedTime) {
    replayTicker.reset();
    if (manualSliderMove) return;
    currentReplayTime = (currentReplayTime + (elapsedTime.inMilliseconds * speedTable[speedIndex]));
    if (currentReplayTime > eventEnd) {
      if (eventStatus == EventStatus.live) liveTimer.cancel();
      eventStatus = EventStatus.replay;
      currentReplayTime = replayLoop ? eventStart : eventEnd;
      if (!replayLoop) startStopRunning();
    } else if (currentReplayTime > sliderEnd) {
      startStopRunning();
      currentReplayTime = sliderEnd;
    }
    moveShipsBuoysAndWindTo(currentReplayTime, moveMap: true);
  }

  void startStopRunning() {
    setState(() {
      replayRunning = !replayRunning;
      if (replayRunning && currentReplayTime == sliderEnd) currentReplayTime = eventStart;
      replayRunning ? replayTicker.start() : replayTicker.stop();
    });
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // four routines for handling the map markers for ships buoys and wind
  // NOTE: the routines here are very time critical
  // first a simple routine that conditionally calls the other three routines
  //
  void moveShipsBuoysAndWindTo(int time, {required bool moveMap}) {
    setState(() {
      if (replayTracks.isEmpty) return;
      if ((replayTracks['shiptracks'] ?? []).isNotEmpty) moveShipsTo(time, moveMap: moveMap);
      if (showRoute && (replayTracks['buoytracks'] ?? []).isNotEmpty) updateGPSBuoys(time);
      if (allowShowWind && (replayTracks['windtracks'] ?? []).isNotEmpty) rotateWindTo(time);
    });
  }

  //
  // first time critical routine: move ships and textlabels next to the ship, and the infowindow (if open)
  // and optionally meve the map in order to follow and optionally zoom to the selected ships
  //
  void moveShipsTo(int replayTime, {required bool moveMap}) {
    // set the time a bit back if we are live and at the end of the slider
    int time = (eventStatus == EventStatus.live && replayTime == sliderEnd) ? replayTime - displayDelay : replayTime;
    int timeIndex = 0;
    LatLng calculatedPosition = const LatLng(0, 0);
    int calculatedRotation = 0;
    List<LatLng> followBounds = [];
    for (int i = 0; i < replayTracks['shiptracks'].length; i++) {
      var shipTrack = replayTracks['shiptracks'][i];
      if (shipTrack['stamp'].isEmpty) continue;
      final stamps = shipTrack['stamp'];
      if (time <= stamps.first) {
        timeIndex = 0;
        calculatedPosition = LatLng(shipTrack['lat'].first.toDouble(), shipTrack['lon'].first.toDouble());
        calculatedRotation = shipTrack['course'].first;
      } else if (time >= stamps.last) {
        timeIndex = stamps.length - 1;
        calculatedRotation = shipTrack['course'].last;
        if (hfUpdate && (eventStatus == EventStatus.live) && (currentReplayTime == sliderEnd) && (time - stamps.last) < predictTime) {
          calculatedPosition = predictPosition(LatLng(shipTrack['lat'].last.toDouble(), shipTrack['lon'].last.toDouble()),
              shipTrack['speed'].last / 10, time - stamps.last as int, calculatedRotation);
        } else {
          calculatedPosition = LatLng(shipTrack['lat'].last.toDouble(), shipTrack['lon'].last.toDouble());
        }
      } else {
        timeIndex = shipTimeIndices[i];
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
        double ratio = (time - stamps[timeIndex]) / (stamps[timeIndex + 1] - stamps[timeIndex]);
        final double startLat = shipTrack['lat'][timeIndex].toDouble();
        final double startLon = shipTrack['lon'][timeIndex].toDouble();
        final double endLat = shipTrack['lat'][timeIndex + 1].toDouble();
        final double endLon = shipTrack['lon'][timeIndex + 1].toDouble();
        final double interpolatedLat = startLat + (endLat - startLat) * ratio;
        final double interpolatedLon = startLon + (endLon - startLon) * ratio;
        calculatedPosition = LatLng(interpolatedLat, interpolatedLon);
        int diff = shipTrack['course'][timeIndex + 1] - shipTrack['course'][timeIndex];
        diff = (diff + 540) % 360 - 180;
        calculatedRotation = (shipTrack['course'][timeIndex] + (ratio * diff).floor() + 360) % 360;
      }
      shipTimeIndices[i] = timeIndex;
      followBounds += (following[shipTrack['name']] ?? false) ? [calculatedPosition] : [];
      var speedString =
          '${(shipTrack['speed'][timeIndex] / 18.52).toStringAsFixed(1)}kn (${(shipTrack['speed'][timeIndex] / 10).toStringAsFixed(1)}km/h)';
      shipLostSignalIndicators[i] =
          ((time - (replayRunning ? shipTrack['stamp'][timeIndex] : shipTrack['stamp'].last)) > signalLostTime) ? "*" : '';
      String infoWindowTitle = '${shipTrack['name']}${shipLostSignalIndicators[i]}';
      String infoWindowText = (allowShowSpeed) ? txt.param('speed', {'speedString': speedString}) : '';
      infoWindowText += (testing || (shipLostSignalIndicators[i] != '' && eventStatus == EventStatus.live && !replayRunning))
          ? '\n${txt.param("positionOn", {
                  "dateTimeString": dtsFormat.format(DateTime.fromMillisecondsSinceEpoch(shipTrack['stamp'][timeIndex]))
                })}'
          : '';
      var svgString = '<svg width="22" height="22"><polygon points="$shipSvgPath" '
          'style="fill:${shipColorsSvg[i]};stroke:$bgColor;stroke-opacity:0.7;stroke-width:1" '
          'transform="rotate($calculatedRotation,11,11)" /></svg>';
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
                  onDoubleTap: () => setState(() {
                        followAll = false;
                        following.forEach((k, v) => following[k] = false);
                        autoFollow = following[shipTrack['name']] = true;
                        var saveZoom = autoZoom;
                        autoZoom = true;
                        moveShipsTo(currentReplayTime, moveMap: true);
                        autoZoom = saveZoom;
                        toggleMenu(OpenMenu.ship);
                        infoWindowId = '';
                        infoWindowMarkerList = [];
                        showShipInfo = false;
                      }),
                  onTap: () => setState(() {
                        infoWindowId = 'ship${shipTrack['name']}';
                        infoWindowMarkerList = [
                          infoWindow(
                              title: infoWindowTitle,
                              body: infoWindowText,
                              link: 'shipInfo:${shipTrack['name']}',
                              point: calculatedPosition)
                        ];
                        moveShipsTo(time, moveMap: false);
                      }))));
      if (infoWindowId == 'ship${shipTrack['name']}') {
        infoWindowMarkerList = [
          infoWindow(title: infoWindowTitle, body: infoWindowText, link: 'shipInfo:${shipTrack['name']}', point: calculatedPosition)
        ];
      }
      shipLabelList[i] = showShipLabels
          ? mapTextLabel(
              calculatedPosition,
              '${showTeam ? teamList[i] : shipList[i]}'
              '${shipLostSignalIndicators[i]}'
              '${(showShipSpeeds ? ', $speedString' : '')}')
          : const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
      //
      // create the trail for this ship
      var displayTrailLength = (following[shipTrack['name']] == true) ? trailLength : eventTrailLength;
      final int trailStartTime = time - displayTrailLength * 60 * 1000;
      final List<LatLng> trail = [calculatedPosition];
      final List<dynamic> lats = shipTrack['lat'];
      final List<dynamic> lons = shipTrack['lon'];
      for (int i = timeIndex; i >= 0 && stamps[i] > trailStartTime; i--) {
        trail.add(LatLng(lats[i].toDouble(), lons[i].toDouble()));
      }
      shipTrailList[i] = Polyline(
        points: trail,
        color: shipColors[i],
        strokeWidth: 2,
      );
    }
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

  //
  // a similar (but slightly simpeler) routine for moving the GPS buoys
  //
  void updateGPSBuoys(int time) {
    Map<String, LatLng> gpsBuoyPositionList = {};
    int timeIndex = 0;
    for (int i = 0; i < replayTracks['buoytracks'].length; i++) {
      if (!showRoute) {
        gpsBuoyMarkerList[i] = const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
        gpsBuoyLabelList[i] = const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
        gpsBuoyPositionList.addAll({replayTracks['buoytracks'][i]['name']: const LatLng(0, 0)});
        continue; // to next buoy
      }
      var gpsBuoy = replayTracks['buoytracks'][i];
      if (gpsBuoy['stamp'].length > 0) {
        if (time <= gpsBuoy['stamp'].first) {
          timeIndex = 0;
        } else if (time >= gpsBuoy['stamp'].last) {
          timeIndex = gpsBuoy['stamp'].length - 1;
        } else {
          timeIndex = gpsBuoyTimeIndices[i] == -1 ? 0 : gpsBuoyTimeIndices[i];
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
        gpsBuoyTimeIndices[i] = timeIndex;
        LatLng gpsBuoyPosition = LatLng(gpsBuoy['lat'][timeIndex].toDouble(), gpsBuoy['lon'][timeIndex].toDouble());
        gpsBuoyPositionList.addAll({gpsBuoy['name']: gpsBuoyPosition});
        String svgString = '<svg width="22" height="22"><circle cx="11" cy="11" r="4.0" '
            'style="fill:${gpsBuoy['color']};stroke:$bgColor;stroke-opacity:0.7;stroke-width:1" /></svg>';
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
                      infoWindow(title: gpsBuoy['name'], body: gpsBuoy['description'], link: '', point: gpsBuoyPosition)
                    ];
                  }),
                )));
        if (infoWindowId == 'buoy${gpsBuoy['name']}') {
          infoWindowMarkerList = [infoWindow(title: gpsBuoy['name'], body: gpsBuoy['description'], link: '', point: gpsBuoyPosition)];
        }
        gpsBuoyLabelList[i] =
            showRouteLabels ? mapTextLabel(gpsBuoyPosition, gpsBuoy['name']) : const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
      }
    }
    gpsBuoyTotalLineLength = 0.0;
    List<Marker> arrowList = [];
    List<Polyline> lineList = [];
    for (int i = 0; i < replayTracks['buoytracks'].length; i++) {
      var gpsBuoy = replayTracks['buoytracks'][i];
      if (showRoute &&
          (gpsBuoyPositionList.containsKey(gpsBuoy['lineto']) || routeBuoyPositionList.containsKey(gpsBuoy['lineto'])) &&
          gpsBuoyPositionList.containsKey(gpsBuoy['name'])) {
        var lineTo = gpsBuoyPositionList.containsKey(gpsBuoy['lineto'])
            ? gpsBuoyPositionList[gpsBuoy['lineto']]
            : routeBuoyPositionList[gpsBuoy['lineto']];
        lineList.add(Polyline(
            points: [gpsBuoyPositionList[gpsBuoy['name']]!, lineTo!], color: markerBackgroundColor.withAlpha(177), strokeWidth: 0.5));
        if (gpsBuoy['witharrow'] != "0") {
          gpsBuoyTotalLineLength = gpsBuoyTotalLineLength + Distance().as(LengthUnit.Meter, gpsBuoyPositionList[gpsBuoy['name']]!, lineTo);
          var heading1 = calculateHeading(gpsBuoyPositionList[gpsBuoy['name']]!, lineTo);
          var heading2 = calculateHeading(lineTo, gpsBuoyPositionList[gpsBuoy['name']]!);
          var position1 = LatLngTween(begin: gpsBuoyPositionList[gpsBuoy['name']]!, end: lineTo).transform(0.6);
          var position2 = LatLngTween(begin: lineTo, end: gpsBuoyPositionList[gpsBuoy['name']]!).transform(0.6);
          if (gpsBuoy['witharrow'] == "1" || gpsBuoy['witharrow'] == "3") {
            String svgString = '<svg width="22" height="22"><polygon points="7,1 11,20 15,1 11,6" '
                'style="fill:$bgColor;fill-opacity:0.7;stroke:$bgColor;stroke-opacity:0.7;stroke-width:0.5" transform="rotate($heading1,11,'
                '11)" /></svg>';
            arrowList.add(Marker(point: position1, width: 22, height: 22, child: SvgPicture.string(svgString)));
          }
          if (gpsBuoy['witharrow'] == "2" || gpsBuoy['witharrow'] == "3") {
            String svgString = '<svg width="22" height="22"><polygon points="7,1 11,20 15,1 11,6" '
                'style="fill:$bgColor;fill-opacity:0.7;stroke:$bgColor;stroke-opacity:0.7;stroke-width:0.5" transform="rotate($heading2,11,'
                '11)" /></svg>';
            arrowList.add(Marker(point: position2, width: 22, height: 22, child: SvgPicture.string(svgString)));
          }
        }
      }
    }
    gpsBuoyLineArrowList = arrowList;
    gpsBuoyLineList = lineList;
  }

  //
  // and finally a routine to rotate the wind markers, including the averahge wind speed in the middle of the screen
  //
  void rotateWindTo(int time) {
    for (int i = 0; i < replayTracks['windtracks'].length; i++) {
      // first update the timeIndex for this station
      final windStation = replayTracks['windtracks'][i];
      final stamps = windStation['stamp'];
      if (stamps.isEmpty) continue;
      int timeIndex;
      if (time <= stamps.first) {
        timeIndex = 0;
      } else if (time >= stamps.last) {
        timeIndex = stamps.length - 1;
      } else {
        timeIndex = windTimeIndex[i] == -1 ? 0 : windTimeIndex[i];
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
      if (windTimeIndex[i] == timeIndex) continue;
      windTimeIndex[i] = timeIndex;

      if (!showWindMarkers) {
        // no windmarkers on the screen, just make an 'empty' marker
        windMarkerList[i] = const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
      } else {
        int rotation = windStation['course'][timeIndex];
        String iwText = '${windStation['speed'][timeIndex]} kn, ${knotsToBft(windStation['speed'][timeIndex].toDouble())} Bft';
        String fillColor = knotsToColor(windStation['speed'][timeIndex].toDouble());
        String svgString = '<svg width="22" height="22"><polygon points="7,1 11,20 15,1 11,6" '
            'style="fill:$fillColor;stroke:$bgColor;stroke-opacity:0.7;stroke-width:1" transform="rotate($rotation,11,11)" /></svg>';
        LatLng windStationPosition = LatLng(windStation['lat'].last.toDouble(), windStation['lon'].last.toDouble());
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
                            infoWindow(title: windStation['name'], body: iwText, link: '', point: windStationPosition)
                          ];
                        }))));
        if (infoWindowId == 'wind-${windStation['name']}') {
          infoWindowMarkerList = [infoWindow(title: windStation['name'], body: iwText, link: '', point: windStationPosition)];
        }
      }
    }
    //
    // now the center windmarker. Note the windmarkerlist is always one longer then the number of windstations received
    // we first make an 'empty' marker
    windMarkerList.last = const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
    if (replayTracks['windtracks'].length >= nrWindStationsForCenterWindCalculation) {
      //do we have enough windstations?
      final centerData = centerWind(replayTracks['windtracks'], nrWindStationsForCenterWindCalculation);
      // leave some data behind for the particles
      windParticlesSpeed = knotsToBft(centerData.speed.toDouble());
      windParticlesDirection = centerData.heading;
      // now prepare the windmarker in the upper left corner of the screen
      String infoWindowTitle = txt.str('windMiddleMap');
      String infoWindowText = '${centerData.speed.toStringAsFixed(1)} ${txt.str('knots')}, $windParticlesSpeed Bft';
      String fillColor = knotsToColor(centerData.speed);
      String svgString = '<svg width="22" height="22"><circle cx="11" cy="11" r="10" '
          'fill="none" stroke="$bgColor" stroke-width="1.2"/><polygon points="7,1 11,20 15,1 11,6" '
          'style="fill:$fillColor;stroke:$bgColor;stroke-opacity:0.7;stroke-width:1" transform="rotate(${centerData.heading} 11,11)" '
          '/></svg>';
      LatLng arrowPosition = mapController.camera.screenOffsetToLatLng(Offset(30, menuOffset + 30));
      LatLng infoWindowPosition = mapController.camera.screenOffsetToLatLng(Offset(110, menuOffset + 130));
      windMarkerList.last = Marker(
          point: arrowPosition,
          width: 22,
          height: 22,
          child: Tooltip(
              message: infoWindowText,
              child: InkWell(
                  child: SvgPicture.string(svgString),
                  onTap: () => setState(() {
                        infoWindowId = 'windCenter';
                        infoWindowMarkerList = [
                          infoWindow(title: infoWindowTitle, body: infoWindowText, link: '', point: infoWindowPosition, alignTop: true)
                        ];
                      }))));
      if (infoWindowId == 'windCenter') {
        infoWindowMarkerList = [
          infoWindow(title: infoWindowTitle, body: infoWindowText, link: '', point: infoWindowPosition, alignTop: true)
        ];
      }
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // routine to create markers and lines for the route
  void buildRoute({bool move = false}) {
    routeLineList = [];
    routePolygons = [];
    routeMarkerList = [];
    routeLabelList = [];
    List<LatLng> routeBounds = [];
    routeBuoyPositionList = {};
    if (infoWindowId != '' && infoWindowId.substring(0, 4) == 'rout') {
      infoWindowId = '';
      infoWindowMarkerList = [];
    }
    if (showRoute && route.isNotEmpty) {
      route['features'].forEach((feature) {
        if (feature['geometry']['type'] == 'LineString') {
          List<LatLng> points = feature['geometry']['coordinates'].map<LatLng>((pt) => LatLng(pt[1], pt[0])).toList();
          if (move) routeBounds.addAll(points);
          var lineColor = feature['properties']['stroke'] ?? "#E91E63";
          routeLineList.add(Polyline(
              points: points,
              color: Color(int.parse('8F${lineColor.toString().substring(1)}', radix: 16)),
              strokeWidth: eventStatus == EventStatus.preEvent ? 2 : 1));
        } else if (feature['geometry']['type'] == 'Point') {
          var routePoint = LatLng(feature['geometry']['coordinates'][1], feature['geometry']['coordinates'][0]);
          if (feature['properties']['name'] != '') {
            var fillColor = feature['properties']['fillcolor'] ?? 'red';
            String svgString = '<svg width="22" height="22"><circle cx="11" cy="11" r="3.5" '
                'style="fill:$fillColor;stroke:$bgColor;stroke-opacity:0.7;stroke-width:1"/></svg>';
            String infoWindowTitle = '${feature['properties']['name']}';
            String infoWindowText = feature['properties']['description'] ?? '';
            String infoWindowLink = feature['properties']['link'] ?? '';
            infoWindowText += (infoWindowLink == '') ? '' : ' (${txt.str('clickOrTap')})';
            routeMarkerList.add(Marker(
                point: routePoint,
                width: 22,
                height: 22,
                child: Tooltip(
                    message: showRouteLabels ? '' : feature['properties']['name'],
                    child: InkWell(
                      onTap: feature['properties']['name'] == ''
                          ? null
                          : () => setState(() {
                                infoWindowId = 'rout-${feature['properties']['name']}';
                                infoWindowMarkerList = [
                                  infoWindow(title: infoWindowTitle, body: infoWindowText, link: infoWindowLink, point: routePoint)
                                ];
                              }),
                      child: SvgPicture.string(svgString),
                    ))));
            if (showRouteLabels) routeLabelList.add(mapTextLabel(routePoint, feature['properties']['name']));
            routeBuoyPositionList.addAll({feature['properties']['name']: routePoint});
          }
          routeBounds += move ? [routePoint] : [];
        } else if ((feature['geometry']['type'] == 'Polygon') && testing && showRouteFences) {
          List<LatLng> points = (feature['geometry']['coordinates'][0] as List).map<LatLng>((pt) => LatLng(pt[1], pt[0])).toList();
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
      mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(routeBounds),
          maxZoom: 17,
          padding:
              EdgeInsets.fromLTRB(screenWidth * 0.15, menuOffset + screenHeight * 0.10, screenWidth * 0.15, screenHeight * 0.10 + 60)));
    }
  }

  //----------------------------------------------------------------------------------------------------------------------------------------
  //
  // some helper routines
  //
  // first a routine that is called from the live timer routine to add the latest positions to the replay tracks
  // note that the newTracks may overlap with what we already have. The List.generate instruction selects only items that are newer then
  // the latest items in the existing track
  //
  Map<String, dynamic> mergeTracks(Map<String, dynamic> tracks, Map<String, dynamic> newTracks) {
    tracks['filestamp'] = newTracks['filestamp'];
    // Create a map of existing ships for fast lookups.
    final existingShipsMap = {for (var ship in tracks['shiptracks']) ship['name']: ship};
    final newShipNames = {for (var ship in newTracks['shiptracks']) ship['name']};
    // Remove ships from 'tracks' that are not in 'newTracks'
    tracks['shiptracks'].removeWhere((ship) => !newShipNames.contains(ship['name']));
    existingShipsMap.removeWhere((name, ship) => !newShipNames.contains(name));
    for (final newShip in newTracks['shiptracks']) {
      final existingShip = existingShipsMap[newShip['name']];
      if (existingShip != null) {
        // --- SHIP EXISTS: Merge new data into the existing track ---
        existingShip['colorcode'] = newShip['colorcode'];
        final int lastStamp = existingShip['stamp'].isNotEmpty ? existingShip['stamp'].last : 0;
        for (int k = 0; k < newShip['stamp'].length; k++) {
          if (newShip['stamp'][k] > lastStamp) {
            existingShip['stamp'].add(newShip['stamp'][k]);
            existingShip['lat'].add(newShip['lat'][k]);
            existingShip['lon'].add(newShip['lon'][k]);
            existingShip['speed'].add(newShip['speed'][k]);
            existingShip['course'].add(newShip['course'][k]);
          }
        }
      } else {
        // --- NEW SHIP: Add the entire track and set its follow status ---
        tracks['shiptracks'].add(newShip);
        following[newShip['name']] = followAll;
      }
    }
    // A single sort at the end is necessary to maintain order.
    tracks['shiptracks'].sort((a, b) => int.parse(a['colorcode']).compareTo(int.parse(b['colorcode'])));
    //
    // similar for the buoy tracks
    // Create a map of existing buoys for fast lookups.
    final existingBuoysMap = {for (var buoy in tracks['buoytracks']) buoy['name']: buoy};
    for (final newBuoy in newTracks['buoytracks']) {
      final existingBuoy = existingBuoysMap[newBuoy['name']];
      if (existingBuoy != null) {
        // --- BUOY EXISTS: Update properties and merge new data points ---
        existingBuoy['color'] = newBuoy['color'];
        existingBuoy['description'] = newBuoy['description'];
        existingBuoy['lineto'] = newBuoy['lineto'];
        existingBuoy['witharrow'] = newBuoy['witharrow'];
        final int lastStamp = existingBuoy['stamp'].last;
        for (int k = 0; k < newBuoy['stamp'].length; k++) {
          if (newBuoy['stamp'][k] > lastStamp) {
            existingBuoy['stamp'].add(newBuoy['stamp'][k]);
            existingBuoy['lat'].add(newBuoy['lat'][k]);
            existingBuoy['lon'].add(newBuoy['lon'][k]);
          }
        }
      } else {
        // --- NEW BUOY: Add the entire track to the list ---
        tracks['buoytracks'].add(newBuoy);
      }
    }
    // and the wind stations
    // Create a map of existing wind stations for fast lookups.
    final existingWindStationsMap = {for (var station in tracks['windtracks']) station['name']: station};
    // Loop through the new wind station tracks
    for (final newWindStation in newTracks['windtracks']) {
      final existingStation = existingWindStationsMap[newWindStation['name']];
      if (existingStation != null) {
        // --- STATION EXISTS: Merge new data points into the existing track ---
        final int lastStamp = existingStation['stamp'].last;
        for (int k = 0; k < newWindStation['stamp'].length; k++) {
          if (newWindStation['stamp'][k] > lastStamp && newWindStation['speed'][k] != 0) {
            existingStation['stamp'].add(newWindStation['stamp'][k]);
            existingStation['lat'].add(newWindStation['lat'][k]);
            existingStation['lon'].add(newWindStation['lon'][k]);
            existingStation['speed'].add(newWindStation['speed'][k]);
            existingStation['course'].add(newWindStation['course'][k]);
          }
        }
      } else {
        // --- NEW STATION: Add the entire track to the list, if it has valid data ---
        if (newWindStation['speed'][0] != 0) {
          tracks['windtracks'].add(newWindStation);
        }
      }
    }
    tracks['endtime'] = newTracks['endtime'];
    return tracks;
  }

  //
  // next a helper routine to set up the ship, buoy and wind lists needed for the menus and the markers
  // it is called in live each time there is an update, or at the start of the replay
  //
  void setupShipGpsBuoyAndWindLists(Map<String, dynamic> tracks) {
    final nrShips = tracks['shiptracks'].length;
    shipTimeIndices = List.filled(nrShips, 0, growable: true);
    shipMarkerList = List.filled(nrShips, const Marker(point: LatLng(0, 0), child: SizedBox.shrink()), growable: true);
    shipLabelList = List.filled(nrShips, const Marker(point: LatLng(0, 0), child: SizedBox.shrink()), growable: true);
    shipTrailList = List.filled(nrShips, Polyline(points: [const LatLng(0, 0)]), growable: true);
    shipLostSignalIndicators = List.filled(nrShips, '', growable: true);
    shipList = [];
    teamList = [];
    shipColors = [];
    shipColorsSvg = [];
    for (var ship in tracks['shiptracks']) {
      shipList.add(ship['name']);
      ship['team'] == null || ship['team'] == '' ? teamList.add("team ${ship['name']}") : teamList.add(ship['team']);
      final color = Color(shipMarkerColorTable[int.parse(ship['colorcode']) % 32]);
      shipColors.add(color);
      shipColorsSvg.add('#${shipMarkerColorTable[int.parse(ship['colorcode']) % 32].toRadixString(16).substring(2)}');
    }
    gpsBuoyTimeIndices = List.filled(tracks['buoytracks'].length, -1, growable: true);
    gpsBuoyMarkerList =
        List.filled(tracks['buoytracks'].length, const Marker(point: LatLng(0, 0), child: SizedBox.shrink()), growable: true);
    gpsBuoyLabelList =
        List.filled(tracks['buoytracks'].length, const Marker(point: LatLng(0, 0), child: SizedBox.shrink()), growable: true);
    gpsBuoyLineList = List.filled(tracks['buoytracks'].length, Polyline(points: []), growable: true);
    gpsBuoyLineArrowList =
        List.filled(tracks['buoytracks'].length, Marker(child: const SizedBox.shrink(), point: LatLng(0, 0)), growable: true);
    windTimeIndex = List.filled(tracks['windtracks'].length, -1, growable: true);
    // the windmarker list is one longer then the number of windstations received to accomodate the center wind marker
    windMarkerList =
        List.filled(tracks['windtracks'].length + 1, const Marker(point: LatLng(0, 0), child: SizedBox.shrink()), growable: true);
  }

  //
  // a helper routine to create an infowindow for ships, buoys and routepoints
  // the link can be blank, contain a shipname ('shipInfo:shipname'), or a url
  Marker infoWindow({required String title, required String body, required String link, required LatLng point, bool alignTop = false}) {
    return Marker(
        point: point,
        alignment: alignTop ? Alignment(0.05, 0.15) : Alignment(0, -1.1),
        width: 220,
        height: 200,
        rotate: true,
        child: Wrap(
            alignment: alignTop ? WrapAlignment.start : WrapAlignment.center,
            runAlignment: alignTop ? WrapAlignment.start : WrapAlignment.end,
            children: [
              Card(
                  color: Colors.white,
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                      child: MouseRegion(
                          cursor: (link != '') ? SystemMouseCursors.click : MouseCursor.uncontrolled,
                          child: GestureDetector(
                              onTap: (link == '')
                                  ? () {}
                                  : link.split(":")[0] == 'shipInfo'
                                      ? () => loadAndShowShipDetails(link.split(":")[1], eventDomain)
                                      : () => launchUrl(Uri.parse(link)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(title, style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
                                if (body != '') Text(body, style: const TextStyle(fontSize: 12, color: Colors.black))
                              ])))))
            ]));
  }

  //
  // a helper routine to create a text label for ships, buoys and routepoints
  Marker mapTextLabel(LatLng point, String txt) {
    return Marker(
        point: point,
        width: 300,
        height: 30,
        alignment: const Alignment(0.95, 1.4),
        rotate: true,
        child: Wrap(alignment: WrapAlignment.start, children: [
          BorderedText(
              strokeWidth: 1.5,
              strokeColor: labelBackgroundColor,
              child: Text(txt, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: markerBackgroundColor.withAlpha(0xBF))))
        ]));
  }

  //
  // a helper function to load a new html shipinfo text and show the shipinfo panel
  void loadAndShowShipDetails(String shipname, String event) async {
    shipInfoHTML = await apiService.getShipInfo(ship: shipname, event: event, team: allowTeams);
    if (!showShipInfo) shipInfoPosition = Offset(55, menuOffset + 50);
    showShipInfo = true;
    setState(() {});
  }

  //
  // a (time critical) helper routine to calculate the center wind
  // it selects the 'nrStartions' nearest to the center of the screen and returns the weighted windspeed in knots and weighted
  // winddirection of these stations
  ({int heading, double speed}) centerWind(List<dynamic> windTracks, int nrStations) {
    if (windTracks.length < nrStations) return (heading: 0, speed: 0);
    final distance = const Distance();
    final center = mapController.camera.center;
    final distances = List.generate(windTracks.length, (i) {
      final lat = windTracks[i]['lat'][0].toDouble();
      final lon = windTracks[i]['lon'][0].toDouble();
      final dist = distance.as(LengthUnit.Meter, center, LatLng(lat, lon));
      return MapEntry(i, dist);
    });
    final nearest = distances..sort((a, b) => a.value.compareTo(b.value));
    final selected = nearest.take(nrStations).toList();
    final totalDist = selected.fold(0.0, (sum, e) => sum + e.value);
    double ewSum = 0, nsSum = 0;
    double weightSum = 0;
    for (final entry in selected) {
      final index = entry.key;
      final distFactor = 1 - (entry.value / totalDist);
      weightSum += distFactor;
      final directionRad = windTracks[index]['course'][windTimeIndex[index]] * pi / 180;
      final speed = windTracks[index]['speed'][windTimeIndex[index]].toDouble();
      ewSum += speed * cos(directionRad) * distFactor;
      nsSum += speed * sin(directionRad) * distFactor;
    }
    ewSum /= weightSum;
    nsSum /= weightSum;
    final heading = ((atan2(nsSum, ewSum) * 180 ~/ pi) + 360) % 360;
    final speed = sqrt(ewSum * ewSum + nsSum * nsSum);
    return (heading: heading, speed: speed);
  }

  //
  // helper routine to open one menu and close all others or close all menu's
  void toggleMenu(OpenMenu menuToToggle) => setState(() => activeMenu = (activeMenu == menuToToggle) ? OpenMenu.none : menuToToggle);

  //
  // helper function to enter/exit testing modus (double clicking the appbar leading icon)
  void toggleTesting() async {
    testing = !testing;
    dirList = await apiService.getDirList(testing: testing, noStats: true);
    eventNameList = dirList.keys.toList();
    eventNameList.sort();
    eventYearList = [];
    eventDayList = [];
    activeMenu = OpenMenu.none;
    buildRoute(); // just in case we had the black polygons in view
    refreshUI();
  }
}
