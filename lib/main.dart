//
// ©2021-2023 Stichting Zeilvaart Warmond
// Flutter/Dart Track & Trace app for Android, iOS and web
//
// Version 3.0.1
// - minor cosmetic changes in the event menu
//
// Version 3.0.0
// - using the flutter_maps package instead of google maps
// - new look and feel with semitransparent appbar
// - working as web also
//

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' show Html;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
//
final isDeviceMobile = kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
//
// constant with the URL of the our server
//
const server = 'https://tt.zeilvaartwarmond.nl/';
//
// vars for getting physical device info and the phoneId
late MediaQueryData queryData;    // needed for getting the screen width and height
int screenWidth = 0;
int screenHeight = 0;

String? phoneId = "";
//
// some variables for the flutter_map
final mapController = MapController();
const initialMapPosition = LatLng(52.2, 4.535);
//
// vars for the selection of the event and the eventinfo
late SharedPreferences prefs;           // local parameter storage
late Map<String, dynamic> dirList;      // see get-dirlist.php on the server
late Map<String, dynamic> eventInfo;    // see get-eventinfo.php on the server
List <String>eventList = [];
List eventYearList = [];
List eventDayList = [];
String eventDomain = '';
String eventId = '';
String eventName = 'Kies een evenement';
String eventYear = '';
String eventDay = '';
int eventStart = 0;
int eventEnd = 0;
int replayEnd = 0;
int eventTrailLength = 30;
int actualTrailLength = 30;
String socialMediaUrl = '';
String eventStatus = '';  // pre-event, live or replay
//
// vars for the tracks and the markers
Map<String, dynamic> replayTracks = jsonDecode('{}'); // see get-replay.php on the server
Map<String, dynamic> liveTrails = jsonDecode('{}');   // see get-trails.php on the server
Map<String, dynamic> route = jsonDecode('{}');        // geoJSON structure with the route
List shipList = [];
List shipColors = [];
List<Marker> shipMarkerList = [];
List<Marker> shipLabelList = [];
List<Polyline> shipTrailList = [];
List<Marker> windMarkerList = [];
List<Marker> routeMarkerList = [];
List<Polyline> routeLineList = [];
List<Marker> routeLabelList = [];
String infoWindowId = '';
String infoWindowText = '';
String infoWindowLink = '';
TextStyle infoWindowTextStyle = const TextStyle();
LatLng infoWindowLatLng = const LatLng(0,0);
double infoWindowAnchorRight = 0;
double infoWindowAnchorBottom = 0;
//
List shipMarkerColorTable = [
  '#696969', '#556b2f', '#8b4513', '#483d8b', '#008000', '#3cb371', '#b8860b', '#008b8b',
  '#4682b4', '#00008b', '#32cd32', '#8b008b', '#ff0000', '#ff8c00', '#ffd700', '#00ff00',
  '#00fa9a', '#8a2be2', '#dc143c', '#00ffff', '#0000ff', '#adff2f', '#da70d6', '#ff00ff',
  '#1e90ff', '#db7093', '#add8e6', '#ff1493', '#7b68ee', '#ffa07a', '#ffe4b5', '#ffc0cb' ];
//
List<int> windKnots = [0, 1, 3, 6, 10, 16, 21, 27, 33, 40, 47, 55, 63];
List windColorTable = [
  '#ffffff', '#ffffff', '#c1fcf9', '#7ef8f3', '#24fc54', '#b2f500',
  '#ff5225', '#ff08d1', '#e50cff', '#b026ff', '#8334ff', '#7f0000', '#000000' ];
//
// variables used for following ships and zooming
Map<String, bool> following = {};
int followCounter = 0;
bool followAll = true;
bool autoZoom = true;
//
// vars for the movement of ships and wind markers in time
const speedIndexInitialValue = 4;
int speedIndex = speedIndexInitialValue;     // index in the following table en position of the speed slider, default = 3 min/sec
List<int> speedTable = [0,         10,           30,           60,          180,         300,         900,          1800,         3600];
List speedTextTable =  ["gestopt", "10 sec/sec", "30 sec/sec", "1 min/sec", "3 min/sec", "5 min/sec", "15 min/sec", "30 min/sec", "1 uur/sec"];
List shipTimeIndex = [];  // for each ship the time position in the list of stamps
List windTimeIndex = [];  // for each weather station the time position in the list of stamps
late Timer replayTimer;
late Timer liveTimer;
late Timer preEventTimer;
int liveSecondsTimer = 60;
int currentReplayTime = 0;
bool replayRunning = false;
bool replayPause = false;
const replayRate = 50;      // milliseconds = 20 frames/second
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
String infoTextHTML = '';       // HTML text for the info page from {server}/html/app-info-page.html
String windyURL = '';           // URL for the windy page after a long press on the map
String shipInfoHTML = '';       // HTML from get-shipinfo.php
//
bool testing = false;           // double tap the title of the app to set to true.
//                              // Will cause the underscored events to be in the dirList
//
const String bgColorBlack = '#000000';
const String bgColorWhite = '#ffffff';
const Map<String, dynamic> mapTileProviderData = {
  'Standaard': {
    'URL': 'https://service.pdok.nl/brt/achtergrondkaart/wmts/v2_0/standaard/EPSG:3857/{z}/{x}/{y}.png',
    'bgColor': bgColorBlack,
    'subDomains': [],
    'maxZoom' : 19.0,
    'attrib': 'Kadaster.nl',
    'attribLink': 'https://www.kadaster.nl'},
  'Grijs': {
    'URL': 'https://service.pdok.nl/brt/achtergrondkaart/wmts/v2_0/grijs/EPSG:3857/{z}/{x}/{y}.png',
    'bgColor': bgColorBlack,
    'subDomains': [],
    'maxZoom' : 19.0,
    'attrib': 'Kadaster.nl',
    'attribLink': 'https://www.kadaster.nl'},
  'Satelliet': {
    'URL': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        '?token=AAPK98f1d23951d54ec6af3162442bf68e054QnQLuJueZ8pkCU6hV6vAcwoykak2mZeyCj8Y3-MIMAOSPZtZm4jHvwxGw_kcMJv',
    'bgColor': bgColorWhite,
    'subDomains': [],
    'maxZoom' : 19.0,
    'attrib': 'Esri, Maxar, others...',
    'attribLink': 'https://www.esri.com'},
  'Open Street Map': {
    'URL': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'bgColor': bgColorBlack,
    'subDomains': [],
    'maxZoom' : 19.0,
    'attrib': 'Open Street Map Contributors',
    'attribLink': 'https://www.openstreetmap.org/'},
};
String selectedMapType = mapTileProviderData.keys.toList()[0];
String markerBackgroundColor = mapTileProviderData[selectedMapType]['bgColor'];
//
bool openSeaMapOverlay = false;
bool windMarkersOn = true;
bool showRoute = true;
bool showRouteLabels = false;
bool showShipLabels = true;
bool showShipSpeeds = false;
late Icon locationMarkerIconBlack;
late Icon locationMarkerIconWhite;
//------------------------------------------------------------------------------
//
// Here our app starts (more or less)
//
//------------------------------------------------------------------------------
//
// Here our app starts (more or less)
//
Future main() async {
  // first wait for something flutter want us to wait for...
  WidgetsFlutterBinding.ensureInitialized();
  // get any saved preferences from local storage
  prefs = await SharedPreferences.getInstance();
  // and run the app as a stateful widget
  runApp(const MyApp());
}

//
// a standard flutter intermediate class to start the actual app as a StatefulWidget class
//
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => MyAppState();
}
//
//------------------------------------------------------------------------------
//
// Finally the main program
//
class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  var key = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);   // needed to get the MediaQuery working
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  //
  // This routine is called when there was an AppLifeCycleChange
  //
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (eventStatus == 'live') {
          liveSecondsTimer = 1;
          liveTimer = Timer.periodic(const Duration(seconds:1), (liveTimer) {liveTimerRoutine();});
        }
        if (replayRunning) {
          replayTimer = Timer.periodic(const Duration(milliseconds:100), (replayTimer) {replayTimerRoutine();});
        }
        break;
      case AppLifecycleState.inactive:
        if (eventStatus == 'live') {liveTimer.cancel();}
        if (replayRunning) {replayTimer.cancel();}
        break;
      case AppLifecycleState.paused:
        if (eventStatus == 'live') {liveTimer.cancel();}
        if (replayRunning) {replayTimer.cancel();}
        break;
      case AppLifecycleState.detached:
        if (eventStatus == 'live') {liveTimer.cancel();}
        if (replayRunning) {replayTimer.cancel();}
        break;
    }
  }
  //
  // called when the map is ready. Start up the rest of the initialization of our app
  //
  Future<void> onMapCreated() async {
    //
    // See if we already have a phone id, if not, create one
    //
    phoneId = prefs.getString('phoneid');
    if (phoneId?.substring(0,3) == "WEB" || phoneId?.substring(0,3) == "AND" || phoneId?.substring(0,3) == "IOS") phoneId = "";
    if (phoneId == "" || phoneId == null) {
      var uuid = const Uuid();
      phoneId = uuid.v1(); // generate a new phoneID
      prefs.setString('phoneid', phoneId!);
    }
    String prefix = "";
    String version = '300';
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    version = packageInfo.buildNumber;
    if (kIsWeb) { // Flutterweb
      prefix = "F$version-";
    } else {
      if (defaultTargetPlatform == TargetPlatform.android) {
        prefix = "A$version-";
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        prefix = "I$version-";
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        prefix = "W$version-";
      }
    }
    phoneId = prefix + phoneId!; // use the saved phoneId with a platform/buildnumber prefix
    //
    // Get the list of events ready for selection
    //
    dirList = await fetchDirList();
    dirList.forEach((k, v) => eventList.add(k));
    eventList.sort();
    eventYearList = [];
    eventDayList = [];
    //
    // get the info page contents
    //
    final response = await http.get(Uri.parse(
        '${server}html/app-info-page.html'));
    if (response.statusCode == 200) {
      infoTextHTML = '${response.body}<br><br>Versie $version</body></html>';
    } else {
      infoTextHTML = '';
    }
    //
    // Get the maptype from local storage (from a previous session)
    //
    String? type = prefs.getString('maptype');
    type ??= mapTileProviderData.keys.toList()[0];     // set maptype to default if nothing in local storage
    selectedMapType = type;       // and set it correctly for the RadioButton on the Map Menu
    if (!mapTileProviderData.keys.toList().contains(selectedMapType)) {
      //set maptype to first maptype if the stored maptype is no longer in the mapTileProviderData list
      selectedMapType = mapTileProviderData.keys.toList()[0];
    }
    markerBackgroundColor = mapTileProviderData[selectedMapType]['bgColor'];
    //
    // see if we had the Open Sea Layer on during the previous session
    //
    bool? a = prefs.getBool('openseamapoverlay');
    openSeaMapOverlay = (a == null) ? false : a;
    //
    // Get the event domain from a previous session
    //
    eventDomain = (prefs.getString('domain') == null) ? "" : prefs.getString('domain')!;
    if (eventDomain != "") {
      // we have info from a previous session: use it as if the user had selected an event using the UI
      List substrings = eventDomain.split('/');
      eventName = substrings[0];
      dirList[eventName].forEach((k, v) => eventYearList.add(k));
      eventYearList = eventYearList.reversed.toList();
      eventYear = substrings[1];
      if (substrings.length == 3) {
        dirList[eventName][eventYear].forEach((k, v) => eventDayList.add(k));
        eventDay = substrings[2];
      } else {
        eventDay = "";
      }
      newEventSelected(eventDay);     // go and re-start the event from the previous session.
    }
    // if we have no eventDomain from local storage, the event selection menu will start things up
  }
  //
  //----------------------------------------------------------------------------
  //
  // Routines to get info from the server
  //
  // first the routine to get the list of events, see get-dirlist.php on the server
  //
  Future<Map<String, dynamic>> fetchDirList() async {
    final tst = (testing) ? '&tst=true' : '';
    final response = await http.get(Uri.parse(
        '${server}get?req=dirlist&dev=$phoneId$tst'));
    if (response.statusCode == 200) {
      return (jsonDecode(response.body));
    } else {
      return {};
    }
  }
  //
  // get the event info
  //
  Future<Map<String, dynamic>> fetchEventInfo() async {
    final response = await http.get(Uri.parse(
        '${server}get?req=eventinfo&dev=$phoneId&event=$eventDomain'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {};
    }
  }
  //
  // get the route geoJSON file
  //
  Future<Map<String, dynamic>> fetchRoute() async {
    final response = await http.get(Uri.parse(
        '${server}get?req=route&dev=$phoneId&event=$eventDomain'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {};
    }
  }
  //
  // routine for getting a replay json file (during the event max 5 minutes old)
  // Note all stamps in the file are in seconds. In the app we work with milliseconds so
  // after getting the jsonfile into a map, we multiply all stamps with 1000
  //
  Future<Map<String, dynamic>> fetchReplayTracks() async {
    final response = await http.get(Uri.parse(
        '${server}get?req=replay&dev=$phoneId&event=$eventDomain'));
    if (response.statusCode == 200) {
      return convertTimes(jsonDecode(response.body));
    } else {
      return {};
    }
  }
  //
  // Same for the trails (during the event max 1 minute old)
  // the parameter is for getting trails longer then the eventTrailLength, and is a timestamp (in seconds!)
  //
  Future<Map<String, dynamic>> fetchTrails([fromTime = 0]) async {
    String msg = (fromTime != 0) ? '&msg=$fromTime' : "";
    final response = await http.get(Uri.parse(
        '${server}get?req=trails&dev=$phoneId&event=$eventDomain$msg'));
    if (response.statusCode == 200) {
      return convertTimes(jsonDecode (response.body));
    } else {
      return {};
    }
  }
  Map<String, dynamic> convertTimes(a)  {
    a['starttime'] = a['starttime'] * 1000;
    a['endtime'] = a['endtime'] * 1000;
    for (int i=0; i < a['shiptracks'].length; i++) {
      for (int j=0; j < a['shiptracks'][i]['stamp'].length; j++) {
        a['shiptracks'][i]['stamp'][j] = a['shiptracks'][i]['stamp'][j] * 1000;
      }
    }
    for (int i=0; i < a['windtracks'].length; i++) {
      for (int j=0; j < a['windtracks'][i]['stamp'].length; j++) {
        a['windtracks'][i]['stamp'][j] = a['windtracks'][i]['stamp'][j] * 1000;
      }
    }
    return a;
  }
  //
  // and finally a routine to get shipInfo from the server
  //
  void loadShipInfo(ship) async {
    final response = await http.get(Uri.parse(
        '${server}get?req=shipinfo&dev=$phoneId&event=$eventDomain&ship=${shipList[ship]}'));
    if (response.statusCode == 200) {
      shipInfoHTML = response.body;
    } else {
      shipInfoHTML = 'Could not load ship info';
    }
    replayPause = true;
    showShipInfo = true;
    setState(() { });
  }
  //----------------------------------------------------------------------------
  //
  // Here starts the flutter UI
  // Still relatively simple, because our App has only one page, so no navigation to
  // other pages
  // The UI is rebuilt each time the state of the info to be displayed needs to be updated to the screen.
  // this is not done automatically but only after calling setState. The info to be displayed is in
  // variables manipulated by the routines of the app
  //
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: eventTitle,
      theme: ThemeData (      // some basic colours
        canvasColor: Colors.blueGrey[700],
        unselectedWidgetColor: Colors.white70,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white70, fontSize: 15),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: Builder(builder: (BuildContext context) {
        screenWidth = MediaQuery.of(context).size.width.toInt();
        screenHeight = MediaQuery.of(context).size.height.toInt();
        return Scaffold(
          extendBodyBehindAppBar: true,
          //
          // The UI consists of: (in the order below)
          // - a floatingactionbutton (autozoom on/off),
          // - an appBar at the top, with from left to right:
          //   - SZW icon + eventTitle (tap will open the eventMenu)
          //   - infoButton for the infoPage
          //   - mapbutton for the map selection menu
          //   - shiplist button for the list of participating ships
          // - a body with two stacks of widgets
          //   - inner stack at the bottom, with
          //     - the google map at the bottom
          //     - two 'containers' on top of the map, aligned from the bottom-left, with
          //       - a SizedBox with the vertical speed slider, surrounded by + and -
          //       - a Column with three rows:
          //         - the start/stop button and the time slider
          //         - the replay speed, the live/replay time and the live seconds timer
          //         - a filler to move up the text a bit for the poor iPhone users
          //       Note that all the stuff we put in these two transparent containers (or SizedBox'es)
          //       has two color setting, depending on the mapType selected, where the two satellite mapTypes
          //       cause the text and sliders to be white and for all other mapTypes black
          //   - outer stack on top of the inner stack, with 6 'containers', all aligned from the top left:
          //     - the inner stack at the bottom and on top of that
          //     - the eventselection menu
          //     - the app-info page
          //     - the map menu
          //     - the shiplist menu
          //     - the ship info container
          //
          // To make the whole thing a bit more easy to handle, the main elements of the UI are refactored into
          // separate methods, defined under this thingy
          //
          floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
          floatingActionButton: (followCounter > 0 && !showShipMenu && !showInfoPage && !showMapMenu) ?
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),   // move the button up from the bottom of the screen
              // to make place for the time slider
              child: FloatingActionButton(
                elevation: 5,
                onPressed: () {
                  autoZoom = !autoZoom;
                  moveShipsAndWindTo(currentReplayTime, (autoZoom)?false:true);
                  setState(() { });
                },
                foregroundColor: Colors.white70,
                backgroundColor: Colors.blueGrey[700]?.withOpacity(0.5),
                child: Text((autoZoom) ? ' auto\nzoom\n  off' : ' auto\nzoom', style: const TextStyle(fontSize: 11)),
              )
          ) : null,
          appBar: AppBar(
            backgroundColor: Colors.blueGrey[700]?.withOpacity((showShipMenu || showInfoPage || showEventMenu || showMapMenu) ? 1 : 0.3) ,
            elevation: 0,
            titleSpacing: 0.0,
            leading: IconButton(        // tappable SZW logo
                padding: const EdgeInsets.all(0),
                icon: Image.asset('assets/images/whiteSZWicon.png'),
                onPressed: () {
                  showShipMenu = showMapMenu = showInfoPage = showShipInfo = false;
                  showEventMenu = replayPause= !showEventMenu;
                  setState(() { });
                }
            ),
            title: InkWell(     // the InkWell makes the title "tappable"
              onTap: () {       // show the eventMenu and allow the user to make a selection
                showShipMenu = showMapMenu = showInfoPage = showShipInfo = false;
                showEventMenu = replayPause = !showEventMenu;
                setState(() { });
              },
              onDoubleTap: () async {   // toggles testing mode and reloads the dirList, with or without underscored events
                testing = !testing;
                dirList = await fetchDirList();
                eventList = [];
                dirList.forEach((k, v) => eventList.add(k));
                eventYearList = [];
                eventDayList = [];
              },
              child: Text(eventTitle),
            ),
            actions: [
              IconButton(           // button for the infoPage
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  showEventMenu = showShipMenu = showMapMenu = showShipInfo = false;
                  showInfoPage = replayPause = !showInfoPage;
                  setState(() {  });
                },
                icon: const Icon(Icons.info), //Image.asset('assets/images/ic_info_button.png'),
              ),
              IconButton(           // button for the mapMenu
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  showEventMenu = showShipMenu = showInfoPage = showShipInfo = false;
                  showMapMenu = replayPause = !showMapMenu;
                  setState(() {  });
                },
                icon: const Icon(Icons.map),  //Image.asset('assets/images/mapicon.png'),
              ),
              IconButton(           // button for the shipList
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  showEventMenu = showMapMenu = showInfoPage = showShipInfo = false;
                  showShipMenu = replayPause = !showShipMenu;
                  setState(() {  });
                },
                icon: const Icon(Icons.sailing),
              ),
            ],
          ),
          body: Stack(                            // this is the outer stack
            alignment: Alignment.topLeft,
            children: [
              Stack(                              // this is the inner stack
                alignment: Alignment.bottomLeft,
                children: [
                  uiFlutterMap(),
                  uiMarkerInfoWindow(context),
                  uiSpeedSliderSizedBox(context),
                  uiTimeSliderAreaColumn(context)
                ],
              ),      // inner stack with the map & sliders
              // these are the other elements of the outer stack:
              uiEventMenuSizedBox(),
              uiShipMenuSizedBox(),
              uiMapMenuSizedBox(),
              uiInfoPageSizedBox(),
              uiShipInfoSizedBox(),
            ],
          ),
        );
      }),
    );
  }
  //
  //----------------------------------------------------------------------------
  //
  // the UI elements jnot defined above. Hopefully the names speak for themselves
  //
  FlutterMap uiFlutterMap() {
    return FlutterMap(                     // fills the complete body as bottom layer in the UI
      mapController: mapController,
      options: MapOptions(
          onMapReady: onMapCreated,
          center: initialMapPosition,
          zoom: 12.0,
          maxZoom: mapTileProviderData[selectedMapType]['maxZoom'],
          interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          onTap: (_, __) {             // on tapping the map: close all popups and menu's
            infoWindowId = '';
            showEventMenu = showMapMenu = showShipMenu = replayPause = showShipInfo = false;
            setState(() {});
          },
          onLongPress: (_, latlng) {
            if (eventStatus == 'live' || eventStatus == 'pre-event') {
              windyURL = 'https://embed.windy.com/embed2.html?lat=${latlng.latitude}&lon=${latlng.longitude}'
                  '&detailLat=${latlng.latitude}&detailLon=${latlng.longitude}'
                  '&width=$screenWidth&height=$screenHeight&zoom=11&level=surface&overlay=wind&product=ecmwf&menu=&message=true&marker='
                  '&calendar=now&pressure=&type=map&location=coordinates&detail=true&metricWind=bft&metricTemp=%C2%B0C&radarRange=-1';
              final Uri url = Uri.parse(windyURL);
              launchUrl(url, mode: LaunchMode.platformDefault);
            }
          },
          onPositionChanged: (_, __) {  // have te infowindow repainted at the correct spot on the screen
            if (infoWindowId != '') showInfoWindow(infoWindowId, infoWindowText, infoWindowLatLng, infoWindowLink);
          }
      ),
      nonRotatedChildren: [
        SimpleAttributionWidget(
          source: Text(mapTileProviderData[selectedMapType]['attrib'], overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.black12,
          onTap: () async {
            showEventMenu = showShipMenu = showMapMenu = showShipInfo = false;
            final Uri url = Uri.parse(mapTileProviderData[selectedMapType]['attribLink']);
            await launchUrl(url, mode: LaunchMode.platformDefault);
            setState(() {  });
          },
        )
      ],
      children: [
        TileLayer(
            urlTemplate: mapTileProviderData[selectedMapType]['URL'],
            subdomains: List<String>.from(mapTileProviderData[selectedMapType]['subDomains']),
            maxZoom: mapTileProviderData[selectedMapType]['maxZoom'],
            userAgentPackageName: 'nl.zeilvaartwarmond.szwtracktrace'
        ),
        TileLayer(
          urlTemplate: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
          tileBounds: (openSeaMapOverlay) ? LatLngBounds(const LatLng(-90,0), const LatLng(90,180)) : LatLngBounds(const LatLng(0,0), const LatLng(0,0)),
          backgroundColor: Colors.transparent,
          userAgentPackageName: 'nl.zeilvaartwarmond.szwtracktrace',
        ),
        PolylineLayer(polylines: routeLineList + shipTrailList),
        MarkerLayer(markers: routeLabelList + routeMarkerList + windMarkerList + shipLabelList + shipMarkerList),
      ],
    );
  }

  Positioned uiMarkerInfoWindow(BuildContext context) {
    return Positioned(
        bottom: infoWindowAnchorBottom,
        right: infoWindowAnchorRight,
        child: (infoWindowId == '') ? Container() : SizedBox(
            width: 300,
            height: 300,
            child: Align(
                alignment: Alignment.bottomCenter,
                child: Card(
                  child: Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      margin: const EdgeInsets.all(5),
                      child: InkWell(
                          onTap: (infoWindowLink == '') ? null : () async {
                            showEventMenu = showShipMenu = showMapMenu = showShipInfo = false;
                            final Uri url = Uri.parse(infoWindowLink);
                            await launchUrl(url, mode: LaunchMode.platformDefault);
                            setState(() {  });
                          },
                          child: Text(infoWindowText, style: infoWindowTextStyle)
                      )
                  ),
                )
            ))
    );
  }

  SizedBox uiSpeedSliderSizedBox(BuildContext context) {
    return SizedBox(                       // the speedslider with a rotated box inside
      width: 45,                    // only visible when actually replaying
      height: (MediaQuery.of(context).size.width > MediaQuery.of(context).size.height) ? 265 : 285,
      child: (eventStatus == 'live' && currentReplayTime == replayEnd) ? null : RotatedBox(
        quarterTurns: 3,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
                onTap: decreaseReplaySpeed,
                child: Text('|',             // - rotated, so we use a vertical bar in a smaller font
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (markerBackgroundColor == bgColorBlack) ? Colors.black87 : Colors.white
                    )
                )),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: (markerBackgroundColor == bgColorBlack) ? Colors.black38 : Colors.white60,
                inactiveTrackColor: (markerBackgroundColor == bgColorBlack) ? Colors.black38 : Colors.white60,
                thumbColor: (markerBackgroundColor == bgColorBlack) ? Colors.black87 : Colors.white,
              ),
              child: Slider(
                value: speedIndex.toDouble(),
                min: 0,
                max: (speedTable.length-1).toDouble(),
                divisions: speedTable.length-1,
                onChanged: changeReplaySpeed,
                onChangeEnd: changeReplaySpeed,
              ),
            ),
            InkWell(
                onTap: increaseReplaySpeed,
                child: Text('+',
                    style: TextStyle(
                        fontSize: 20,
                        color: (markerBackgroundColor == bgColorBlack) ? Colors.black87 : Colors.white
                    )
                )),
          ],
        ),
      ),
    );
  }

  Column uiTimeSliderAreaColumn(BuildContext context) {
    return Column(                               // bottom area of the screen with...
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
            child: Row(
                children: [
                  IconButton(                 // the start/stop button
                      onPressed: startStopRunning,
                      icon: (replayRunning) ? Image.asset('assets/images/pause.png') : Image.asset('assets/images/play.png')
                  ),
                  Expanded(                 // and the time slider, expanding it to the rest of the row
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          overlayShape: SliderComponentShape.noOverlay,
                          activeTrackColor: (markerBackgroundColor == bgColorBlack) ? Colors.black38 : Colors.white60,
                          inactiveTrackColor: (markerBackgroundColor == bgColorBlack) ? Colors.black38 : Colors.white60,
                          thumbColor: (markerBackgroundColor == bgColorBlack) ? Colors.black87 : Colors.white,
                        ),
                        child: Slider(
                          min: eventStart.toDouble(),
                          max: replayEnd.toDouble(),
                          value: (currentReplayTime < eventStart || currentReplayTime > replayEnd) ? eventStart.toDouble() : currentReplayTime.toDouble(),
                          onChangeStart: (x) => replayPause = true,         // pause the replay
                          onChanged: (time) {                               // move the ships
                            currentReplayTime = time.toInt();
                            moveShipsAndWindTo (currentReplayTime, (autoZoom)?false:true);
                            setState(() { });
                          },
                          onChangeEnd: timeSliderUpdate,                    // resume play, but stop at end
                        ),
                      )
                  ),
                ]
            ),
          ),
          Row(                                         // row with some texts
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(                                // the speed we are running at
                  width: 110,
                  child: Text(
                      (eventStatus == 'live' && currentReplayTime == replayEnd) ? '      1 sec/sec' : '      ${speedTextTable[speedIndex]}',
                      style: TextStyle(
                          color: (markerBackgroundColor == bgColorBlack) ? Colors.black87 : Colors.white
                      )
                  )
              ),
              Expanded(                                // live / replay time (filling up the leftover space
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children : [
                    Text(
                        ((currentReplayTime == replayEnd) && (replayEnd != eventEnd) ? 'Live   ' : 'Replay   ') +
                            DateTime.fromMillisecondsSinceEpoch(currentReplayTime).toString().substring(0,16),
                        style: TextStyle(color: (markerBackgroundColor == bgColorBlack) ? Colors.black87 : Colors.white
                        )
                    ),
                  ],
                ),
              ),
              InkWell(                                  // tappable live seconds refresh timer
                onTap: () {
                  liveSecondsTimer = 0;
                  setState(() {});
                },
                child: SizedBox(
                    width: 70,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          (currentReplayTime == replayEnd && eventStatus == 'live') ? Text('$liveSecondsTimer    ',
                              style: TextStyle(
                                  color: (markerBackgroundColor == bgColorBlack) ? Colors.black87 : Colors.white
                              )
                          ) : const Text(''),
                        ]
                    )
                ),
              ),
            ],
          ),
          SizedBox(               // give those poor iPhone owners some space for their microphone....
            height: (MediaQuery.of(context).size.width > MediaQuery.of(context).size.height) ? 15 : 35,
          )
        ]
    );
  }

  SizedBox uiEventMenuSizedBox() {
    return SizedBox(                                         // eventMenu
      child: (showEventMenu) ? Container(
          color: Colors.blueGrey[700],
          width: 275,
          padding: const EdgeInsets.fromLTRB(20, 20, 10, 0),
          child: ListView(
              children: [
                const Text("Evenement menu\n", style: TextStyle(fontSize: 20)),
                PopupMenuButton(
                  offset: const Offset(15, 20),
                  tooltip: '',
                  onSelected: selectEventYear,
                  itemBuilder: (BuildContext context) {
                    return eventList.map((events) {
                      return PopupMenuItem(
                        height: 30.0,
                        value: events,
                        child: Text(events),
                      );
                    }).toList();
                  },
                  child:
                  Row(children:[Text('   $eventName '), const Icon(Icons.arrow_drop_down, size:20, color: Colors.white70), const Text(' \n')]),
                ),
                PopupMenuButton(
                  offset: const Offset(15, 20),
                  tooltip: '',
                  onSelected: selectEventDay,
                  itemBuilder: (BuildContext context) {
                    return eventYearList.map((years) {
                      return PopupMenuItem(
                        height: 30.0,
                        value: years,
                        child: Text(years),
                      );
                    }).toList();
                  },
                  child: (eventYear == '') ? const Text('') :
                  Row(children:[Text('   $eventYear '), const Icon(Icons.arrow_drop_down, size:20, color: Colors.white70), const Text(' \n')]),
                ),
                PopupMenuButton(
                  offset: const Offset(15, 20),
                  tooltip: '',
                  onSelected: newEventSelected,
                  itemBuilder: (BuildContext context) {
                    return eventDayList.map((days) {
                      return PopupMenuItem(
                        height: 30.0,
                        value: days,
                        child: Text(days),
                      );
                    }).toList();
                  },
                  child: (eventDay == '') ? const Text('') :
                  Row(children:[Text('   $eventDay'), const Icon(Icons.arrow_drop_down, size:20, color: Colors.white70), const Text(' \n')]),
                ),
                const Divider(color: Colors.white60),
                Text('\n$selectionMessage\n'),
                const Divider(color: Colors.white60),
                Text('\nDe $eventName wordt georganiseerd door:'),
                Container(
                    margin: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                    child: (eventDomain == '') ? null :
                    InkWell(
                      onTap: () => {
                        if (socialMediaUrl != '') launchUrl(Uri.parse(socialMediaUrl), mode: LaunchMode.externalApplication)
                      },
                      child: Image.network('${server}data/$eventDomain/logo.png'),
                    )
                ),
                Text((socialMediaUrl == '') ? '' : '\nKlik op het logo voor de laatste info over deze wedstrijd.\n'),
                Container(
                    child: (!isDeviceMobile) ? null : Column( children: [
                      const Divider(color: Colors.white60),
                      InkWell (
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
                          }
                      )
                    ]
                    )
                ),
              ]
          )
      ) : null,
    );
  }

  SizedBox uiShipMenuSizedBox() {
    return SizedBox( // ShipMenu
        child: (!showShipMenu) ? null : Row(
            children: [
              const Expanded(
                child: SizedBox(),
              ),
              Container(
                width: 275,
                color: Colors.blueGrey[700],
                padding: const EdgeInsets.fromLTRB(10.0, 105.0, 10.0, 10.0),
                child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Text('Alle schepen volgen aan/uit'),
                                ),
                              ),
                              Checkbox(
                                  visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                  activeColor: Colors.white70,
                                  checkColor: Colors.black87,
                                  side: const BorderSide(color: Colors.white70),
                                  value: followAll,
                                  onChanged: (value) {
                                    following.forEach((k, v) { following[k] = value!; });
                                    followAll = value!;
                                    moveShipsAndWindTo(currentReplayTime, false);
                                    setState(() {});
                                  }
                              ),
                            ]
                        ),
                        const Divider(color: Colors.black38),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                          itemCount: shipList.length,
                          itemBuilder: (BuildContext context, index) {
                            return Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: Text(
                                        (kIsWeb) ? '\u2588' : '\u2588\u258C',
                                        style: TextStyle(
                                            color: Color(int.parse('FF${shipColors[index].toUpperCase().replaceAll("#", "")}', radix:16))
                                        )
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: InkWell(
                                          child: Text(shipList[index]),
                                          onTap: () => loadShipInfo(index),
                                        )
                                    ),
                                  ),
                                  Checkbox(
                                      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                      activeColor: Colors.white70,
                                      checkColor: Colors.black87,
                                      side: const BorderSide(color: Colors.white70),
                                      value: (following[shipList[index]] == null) ? false : following[shipList[index]],
                                      onChanged: (value) {
                                        following[shipList[index]] = value!;
                                        moveShipsAndWindTo(currentReplayTime, false);
                                        setState(() {});
                                      }
                                  ),
                                ]
                            );
                          },
                        ),
                        const Divider(color: Colors.black38),
                        InkWell(
                            child: Text('Het spoor achter de schepen is $actualTrailLength minuten'),
                            onTap: () {
                              if (actualTrailLength == eventTrailLength) {
                                actualTrailLength = (eventEnd - eventStart) / 1000 ~/ 60;
                              } else {
                                actualTrailLength = eventTrailLength;
                              }
                              moveShipsAndWindTo (currentReplayTime, true);
                              setState(() {});
                            }
                        ),
                      ],
                    )
                ),
              )
            ]
        )
    );
  }

  SizedBox uiMapMenuSizedBox()  {
    return SizedBox(                                 // Mapmenu
        child: (!showMapMenu) ? null : Row(
            children: [
              const Expanded(
                  child: SizedBox()
              ),
              Container(
                  width: 275,
                  color: Colors.blueGrey[700],
                  padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
                  child: SingleChildScrollView(
                      child: Column(
                          children: [
                            ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: mapTileProviderData.keys.toList().length,
                                itemBuilder: (BuildContext context, index) {
                                  return Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      mainAxisSize:MainAxisSize.max,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(5),
                                            child: Text(mapTileProviderData.keys.toList()[index]),
                                          ),
                                        ),
                                        Radio(
                                            activeColor: Colors.white70,
                                            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                            value: mapTileProviderData.keys.toList()[index],
                                            groupValue: selectedMapType,
                                            onChanged: (x) {
                                              selectedMapType = x as String;
                                              prefs.setString('maptype', selectedMapType);
                                              markerBackgroundColor = mapTileProviderData[selectedMapType]['bgColor'];
                                              showMapMenu = replayPause= false;
                                              if (!replayRunning && eventStatus != "" && eventStatus != 'pre-event') {
                                                // we need the eventStatus to be non-blank, otherwise the markers of the ships, labels and wind will be
                                                // moved when the markers are not initialized yet.
                                                // And if replay is running, we will update every xx milliseconds, so no need to update
                                                moveShipsAndWindTo(currentReplayTime, true );
                                              }
                                              if (eventStatus != "" && route['features'] != null) buildRoute(move: false);  // ensures the edge around the routemarkers is changed
                                              setState(() { });
                                            }
                                        )
                                      ]
                                  );
                                }
                            ),
                            const Divider(color: Colors.black38),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize:MainAxisSize.max,
                                children: [
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Text('Open Sea Map overlay'),
                                    ),
                                  ),
                                  Checkbox(
                                      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                      activeColor: Colors.white70,
                                      checkColor: Colors.black87,
                                      side: const BorderSide(color: Colors.white70),
                                      value: openSeaMapOverlay,
                                      onChanged: (value) {
                                        openSeaMapOverlay = value!;
                                        prefs.setBool('openseamapoverlay', openSeaMapOverlay);
                                        showMapMenu = replayPause= false;
                                        setState(() {  });
                                      }
                                  ),
                                ]
                            ),
                            Container(child: (eventStatus == 'pre-event' || eventStatus == '') ? null : Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize:MainAxisSize.max,
                                children: [
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Text('Windpijlen'),
                                    ),
                                  ),
                                  Checkbox(
                                      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                      activeColor: Colors.white70,
                                      checkColor: Colors.black87,
                                      side: const BorderSide(color: Colors.white70),
                                      value: windMarkersOn,
                                      onChanged: (value) {
                                        windMarkersOn = !windMarkersOn;
                                        showMapMenu = replayPause= false;
                                        (windMarkersOn) ? rotateWindTo(currentReplayTime) : windMarkerList = [];      // this turns off the windmarkers
                                        setState(() {  });
                                      }
                                  ),
                                ]
                            )
                            ),
                            const Divider(color: Colors.black38),
                            Container(child: (route['features'] == null) ? null : Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize:MainAxisSize.max,
                                children: [
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Text('Route, havens, boeien'),
                                    ),
                                  ),
                                  Checkbox(
                                      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                      activeColor: Colors.white70,
                                      checkColor: Colors.black87,
                                      side: const BorderSide(color: Colors.white70),
                                      value: showRoute,
                                      onChanged: (value) {
                                        showRoute = !showRoute;
                                        showMapMenu = replayPause= false;
                                        buildRoute(move: false);
                                        setState(() {  });
                                      }
                                  ),
                                ]
                            ),
                            ),
                            Container(child: (route['features'] == null) ? null : Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize:MainAxisSize.max,
                                children: [
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(20,0,5,5),
                                      child: Text('met namen'),
                                    ),
                                  ),
                                  Checkbox(
                                      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                      activeColor: Colors.white70,
                                      checkColor: (showRoute)? Colors.black87 : Colors.black26,
                                      side: const BorderSide(color: Colors.white70),
                                      value: showRouteLabels,
                                      onChanged: (value) {
                                        showRouteLabels = !showRouteLabels;
                                        if (route['features'] != null) buildRoute(move: false);
                                        if (eventStatus != 'pre-event') moveShipsAndWindTo(currentReplayTime, true);
                                        showMapMenu = replayPause= false;
                                        setState(() {  });
                                      }
                                  ),
                                ]
                            ),
                            ),
                            const Divider(color: Colors.black38),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize:MainAxisSize.max,
                                children: [
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Text('Scheepsnamen'),
                                    ),
                                  ),
                                  Checkbox(
                                      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                      activeColor: Colors.white70,
                                      checkColor: Colors.black87,
                                      side: const BorderSide(color: Colors.white70),
                                      value: showShipLabels,
                                      onChanged: (value) {
                                        showShipLabels = !showShipLabels;
                                        if (route['features'] != null) buildRoute(move: false);
                                        if (eventStatus != 'pre-event') moveShipsAndWindTo(currentReplayTime, true);
                                        showMapMenu = replayPause= false;
                                        setState(() {  });
                                      }
                                  ),
                                ]
                            ),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize:MainAxisSize.max,
                                children: [
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(20,0,5,5),
                                      child: Text('met snelheden'),
                                    ),
                                  ),
                                  Checkbox(
                                      visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                      activeColor: Colors.white70,
                                      checkColor: (showShipLabels) ? Colors.black87 : Colors.black26,
                                      side: const BorderSide(color: Colors.white70),
                                      value: showShipSpeeds,
                                      onChanged: (value) {
                                        showShipSpeeds = !showShipSpeeds;
                                        if (eventStatus != 'pre-event') moveShipsAndWindTo(currentReplayTime, true);
                                        showMapMenu = replayPause= false;
                                        setState(() {  });
                                      }
                                  ),
                                ]
                            )
                          ]
                      )
                  )
              ),
              const SizedBox( width: 35 )
            ]
        )
    );
  }

  SizedBox uiInfoPageSizedBox() {
    return SizedBox(                               // Infopage
        child: (!showInfoPage) ? null : Row(
            children: [
              const Expanded(
                  child: SizedBox()
              ),
              GestureDetector(
                  onTap: () {
                    showInfoPage = false;
                    setState(() { });
                  },
                  child: Container(
                      width: (screenWidth > 750) ? 700 : screenWidth - 50,
                      color: Colors.blueGrey[200],
                      padding: const EdgeInsets.fromLTRB(20.0, 105.0, 20.0, 20.0),
                      child: SingleChildScrollView(
                        child: Html(
                          data: infoTextHTML,
                          onLinkTap: (link, _, __) async {
                            await launchUrl(Uri.parse(link!), mode: LaunchMode.externalApplication);
                          },
                        ),
                      )
                  )
              ),
              const SizedBox( width : 50)
            ]
        ));
  }

  SizedBox uiShipInfoSizedBox() {
    return SizedBox(                                // shipInfo
      child: (showShipInfo) ? Row(
          children: [
            const Expanded(                    // fill up the area from the left
              child: Text(''),
            ),
            GestureDetector(
              onTap: () {
                if (!showShipMenu) replayPause = false; // continue the replay if the shipmenu is not open
                showShipInfo = false;           // remove the info again from the screen on a tap
                setState(() { });
              },
              child: Container(                 // the tappable fixed width ship info container with scrollable HTML text
                color: Colors.blueGrey[600],
                width: 350,
                height: 500,
                padding: const EdgeInsets.fromLTRB(10.0, 105.0, 10.0, 10.0),
                child: SingleChildScrollView(child: Html(data: shipInfoHTML)),
              ),
            ),
            const SizedBox(                 // 40 pixels from the right edge of the screen
              width: 40,
            ),
          ]
      )
          : null,
    );
  }
  //
  //----------------------------------------------------------------------------
  //
  // Routines to handle the event selections from the event selection menu
  // First the routine to handle the selection of the event name
  //
  void selectEventYear(event) {
    selectionMessage = '';
    eventName = event;
    eventYearList = [];
    dirList[event].forEach((k, v) => eventYearList.add(k));
    eventYearList = eventYearList.reversed.toList();
    eventYear = 'Kies een jaar';
    eventDay = '';
    eventDayList = [];
    setState(() { }); // redraw the UI
  }
  //
  // routine to handle the selection of an event year
  //
  void selectEventDay(year) {
    selectionMessage = '';
    eventYear = year;
    eventDayList = [];
    if (dirList[eventName][eventYear].length != 0) {
      dirList[eventName][eventYear].forEach((k, v) => eventDayList.add(k));
      eventDay = 'Kies een dag';
    } else {
      newEventSelected('');
    }
    setState(() { }); // redraw the UI
  }
  //
  // Routine to start up a new event after the user selected the day (or year, in case there are no days in the event)
  // This routine is also called immediately after startup of the app,
  // when we found an eventDomain in local storage from a previous session
  //
  void newEventSelected(day) async {
    // first "kill" whatever was running
    if (eventStatus == 'pre-event') {
      preEventTimer.cancel();
    } else if (eventStatus == 'live') {
      liveTimer.cancel();
    }
    if (replayRunning) {
      replayTimer.cancel();
      replayRunning = false;
    }
    // and reset some variables to their default values
    following = {};
    followCounter = 0;
    followAll = true;
    autoZoom = true;
    showRoute = true;
    windMarkersOn = true;
    shipList = [];
    shipColors= [];
    shipMarkerList = [];
    shipLabelList = [];
    shipTrailList = [];
    windMarkerList = [];
    // now handle the input
    eventDay = day;
    eventDomain = '$eventName/$eventYear';
    if (eventDay != '') eventDomain = '$eventDomain/$eventDay';
    // save the selected event in local storage for the next run
    prefs.setString('domain', eventDomain);
    // get the event info from the server end get event start and end stamps
    eventInfo = await fetchEventInfo();
    eventTitle = eventInfo['eventtitle'];
    eventId = eventInfo['eventid'];
    eventStart = int.parse(eventInfo['eventstartstamp']) * 1000;
    eventEnd = int.parse(eventInfo['eventendstamp']) * 1000;
    replayEnd = eventEnd; //  otherwise the slider crashes with max <= min when we redraw in setState
    eventTrailLength = (eventInfo['traillength'] == null) ? 30 : int.parse(eventInfo['traillength']);  // set to default if not available in eventInfo
    actualTrailLength = eventTrailLength;
    switch (eventInfo['mediaframe'].split(':')[0]) {
      case 'facebook': {
        socialMediaUrl = 'https://www.facebook.com/${eventInfo['mediaframe'].split(':')[1]}';
      }
      break;
      case 'twitter': {
        socialMediaUrl = 'https://www.twitter.com/${eventInfo['mediaframe'].split(':')[1]}';
      }
      break;
      case ('http'): {
        socialMediaUrl = eventInfo['mediaframe'];
      }
      break;
      case ('https'): {
        socialMediaUrl = eventInfo['mediaframe'];
      }
      break;
      default: {
        socialMediaUrl = '';
      }
      break;
    }
    route = await fetchRoute();
    // set the event status based on the current time. Are we before, during or after the event
    final now = DateTime.now().millisecondsSinceEpoch;
    if (eventStart > now) { // pre-event
      eventStatus = 'pre-event';
      // clear any previous tracks (just in case the user presses the replay start button)
      replayTracks = jsonDecode('{}');
      // set the timeslider max to the eventstart
      replayEnd = eventStart;
      selectionMessage = 'Het evenement is nog niet begonnen.\n\nKies een ander evenement of wacht rustig af. '
          'De Track & Trace begint op ${DateTime.fromMillisecondsSinceEpoch(eventStart).toString().substring(0,19)}';
      if (route['features'] != null) {
        selectionMessage += '\n\nBekijk intussen de route / havens / boeien op de kaart';
        showRouteLabels = true;
        buildRoute(move: true);       // also calls setstate to rewrite the screen
      }
      // now just countdown seconds until the events starts, then go live
      preEventTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (DateTime.now().millisecondsSinceEpoch > eventStart) {
          timer.cancel();
          eventStatus = 'live';
          startLive();
        }
      });
    } else if (eventEnd > now) { // live
      selectionMessage = 'Het evenement is "live". Wacht tot de "replay" en "live" tracks zijn geladen';
      eventStatus = 'live';
      startLive();
    } else { // replay
      selectionMessage = 'Het evenement is voorbij. Wacht tot de "replay" tracks zijn geladen';
      eventStatus = 'replay';
      startReplay();
    }
    setState(() { }); // redraw the UI
  }
  //----------------------------------------------------------------------------
  //
  // Three routines for handling a live event
  //
  void startLive() async {
    // first see if we already have live tracks of this event in local storage
    String? a = (kIsWeb) ? null: prefs.getString('live-$eventId');
    if (a != null) {
      replayTracks = jsonDecode(a);
      // get additional data from the moment of our last collected data
      liveTrails = await fetchTrails((replayTracks['endtime']/1000).toInt());
    } else {      // no data yet, so get the replay (mx 5 minutes old)
      replayTracks = await fetchReplayTracks();
      // and the latest trails
      liveTrails = await fetchTrails();
    }
    addTrailsToTracks();      // merge the latest track info with the replay info and save it
    buildShipAndWindInfo();      // prepare menu and track info
    if (route['features'] != null) buildRoute(move: false);
    selectionMessage = '"Replay" en "live" tracks zijn geladen, klik op de kaart';
    showEventMenu = false;                 // hide the eventselection menu
    currentReplayTime = DateTime.now().millisecondsSinceEpoch;
    replayEnd = currentReplayTime;         // put the timeslider to 'now'
    moveShipsAndWindTo(currentReplayTime, false);
    liveSecondsTimer = 60;
    liveTimer = Timer.periodic(const Duration(seconds:1), (liveTimer) {liveTimerRoutine();});
    setState(() { }); // redraw the UI
  }
  //
  // The live timer routine, runs every second, but "works" only once per minute
  // the routine continues to be called when the time slider was moved backward in time
  // (currentReplayTime != endReplay). In that case, just continue to get data but update of the
  // ship and wind markers is done by the timeSliderUpdate and replayTimerRoutine
  //
  void liveTimerRoutine() async {
    liveSecondsTimer--;
    if (liveSecondsTimer <= 0) {  // we've waited 60 seconds, so, get new trails and add them to what we have
      liveSecondsTimer = 60;
      int now = DateTime.now().millisecondsSinceEpoch;
      if ((now - replayTracks['endtime']) > (actualTrailLength * 60 * 1000)) {
        liveTrails = await fetchTrails((replayTracks['endtime']/1000).toInt());  // fetch special
      } else {
        liveTrails = await fetchTrails(); // fetch some new data
      }
      addTrailsToTracks();                      // add it to what we already had and store it
      if (currentReplayTime == replayEnd) {     // slider is at the end
        buildShipAndWindInfo();                 // prepare menu and track info
        replayEnd = now;                        // make the slider 60 seconds longer,
        currentReplayTime = replayEnd;          // move the slider itself to the end
        moveShipsAndWindTo (currentReplayTime, false); // and move the ships and wind markers
      } else {                                  // slider has been moved back in time by the user
        replayEnd = now;                        // just make the slider 60 seconds longer
      }
      setState(() { }); // redraw the UI
    } else {      // just one second later
      int now = DateTime.now().millisecondsSinceEpoch;
      if (currentReplayTime == replayEnd) {     // slider is at the end, so
        replayEnd = now;                        // make the slider 1 second longer
        currentReplayTime = replayEnd;          // and move the slider there
      } else {                                  // slider has been moved back in time
        replayEnd = now;                        // so just make the slider longer
      }
      if (!showShipInfo) setState(() { });      // If shipInfo is shown, don't update. It makes the info flash, for whatever reason
    }
  }
  //
  // Routine to merge the latest trails that we get at the initialisation of the app or after 1 minute, to
  // the info we already had, and store that info locally
  // adding b (=liveTrails) to a (=replayTracks) both shiptracks and windtracks
  // Note that there may be more ships in liveTrails then in replayTracks, because a ship may have joined the race later
  // (tracker or AIS data only turned on after eventStart)
  //
  void addTrailsToTracks() {
    for (int bship = 0; bship < liveTrails['shiptracks'].length; bship++) {
      int aship = 0;
      for ( aship ;  aship < replayTracks['shiptracks'].length; aship++) {
        if (replayTracks['shiptracks'][aship]['name'] == liveTrails['shiptracks'][bship]['name']) break;
      }
      if (aship < replayTracks['shiptracks'].length) {     // we already had a ship with this name
        int laststamp = replayTracks['shiptracks'][aship]['stamp'].last;
        for (int i = 0; i < liveTrails['shiptracks'][bship]['stamp'].length; i++) {
          if (liveTrails['shiptracks'][bship]['stamp'][i] > laststamp) {
            replayTracks['shiptracks'][aship]['stamp'].add(liveTrails['shiptracks'][bship]['stamp'][i]);
            replayTracks['shiptracks'][aship]['lat'].add(liveTrails['shiptracks'][bship]['lat'][i]);
            replayTracks['shiptracks'][aship]['lon'].add(liveTrails['shiptracks'][bship]['lon'][i]);
            replayTracks['shiptracks'][aship]['speed'].add(liveTrails['shiptracks'][bship]['speed'][i]);
            replayTracks['shiptracks'][aship]['course'].add(liveTrails['shiptracks'][bship]['course'][i]);
          }
        }
      } else {                    // we had no ship with this name yet
        replayTracks['shiptracks'].add(liveTrails['shiptracks'][bship]);          // add the complete ship
      }
    }
    // and the same for the weather stations
    for (int bws = 0; bws < liveTrails['windtracks'].length; bws++) {
      int aws = 0;
      for ( aws ;  aws < replayTracks['windtracks'].length; aws++) {
        if (replayTracks['windtracks'][aws]['name'] == liveTrails['windtracks'][bws]['name']) break;
      }
      if (aws < replayTracks['windtracks'].length) {     // we already had a weather station with this name
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
      } else {                    // we had no weather station with this name yet
        replayTracks['windtracks'].add(liveTrails['windtracks'][bws]);          // add the complete weather station
      }
    }
    replayTracks['endtime'] = liveTrails['endtime'];  // set the new endtime and store locally
    if (!kIsWeb) prefs.setString('live-$eventId', jsonEncode(replayTracks));
  }
  //----------------------------------------------------------------------------
  //
  // routine to start replay after the event is really over
  //
  void startReplay() async {
    // First get rid of the temporary live file if that existed...
    if (!kIsWeb) prefs.remove('live-$eventId');
    String? a = (kIsWeb) ? null : prefs.getString('replay-$eventId');     // Do we have data in local storage?
    if (a == null) {                                                      // no data yet
      replayTracks = await fetchReplayTracks();                           // get the data from the server and
      if (!kIsWeb) prefs.setString('replay-$eventId', jsonEncode(replayTracks));  // store it locally
    } else {
      // send a get, just for statistics purposes, no need to wait for a response
      http.get(Uri.parse('${server}get?req=replay&dev=$phoneId&event=$eventDomain&nodata=true'));
      replayTracks = jsonDecode(a);                                       // otherwise, just use the data in local storage
    }
    buildShipAndWindInfo();         // prepare menu and track info
    selectionMessage = '"Replay" tracks zijn geladen, klik op de kaart';
    showEventMenu = false;
    speedIndex = speedIndexInitialValue;
    replayRunning = false;
    currentReplayTime = eventStart;
    moveShipsAndWindTo (currentReplayTime, false);
    if (route['features'] != null) buildRoute(move: true);
    setState(() { }); // redraw the UI
    // Now that we plotted the markers on the map and initialized the sliders (by setting eventStart, endReplay and
    // currentReplayTime for the timeslider and speedIndex for the speed slider), there is nothing more to do then wait
    // for the user to move the sliders or hit the start/stop button
  }
  //----------------------------------------------------------------------------
  //
  // Routines to handle the movement of the time and speed sliders, and the start/stop button
  //
  // The user stopped moving the timeslider.
  // Set the new currentReplayTime to the new slider position
  // if the slider is within 1 minute from the end, move him to the end. In case the eventStatus is 'live', we will
  // automatically start displaying the live event again in the liveTimerRoutine
  //
  void timeSliderUpdate(time) {
    currentReplayTime = time.toInt();
    replayPause = false;
    if (replayEnd - time < 60*1000) {
      currentReplayTime - replayEnd;
    }
    moveShipsAndWindTo (currentReplayTime, false);
    setState(() { }); // redraw the UI
  }
  //
  // Handle a speedslider changes
  //
  void changeReplaySpeed (speed) {
    replayPause = false;
    speedIndex = speed.toInt();
    setState(() { }); // redraw the UI
  }
  void increaseReplaySpeed () {
    speedIndex = (speedIndex == speedTable.length-1) ? speedTable.length-1 : speedIndex+1;
    setState(() { }); // redraw the UI
  }
  void decreaseReplaySpeed () {
    speedIndex = (speedIndex == 0) ? 0 : speedIndex-1;
    setState(() { }); // redraw the UI
  }
  //
  // routine to start / stop the replay
  //
  void startStopRunning() {
    if (eventStatus != "pre-event") {
      replayPause = false;
      replayRunning = !replayRunning;
      if (replayRunning && currentReplayTime ==
          replayEnd) { // if he want to run while at the end of the slider, move it to the beginning
        currentReplayTime = eventStart;
      }
      if (replayRunning) {
        replayTimer = Timer.periodic(const Duration(milliseconds: replayRate), (replayTimer) {
          replayTimerRoutine();
        });
      } else {
        replayTimer.cancel();
      }
      setState(() {}); // redraw the UI
    }
  }
  //----------------------------------------------------------------------------
  //
  // the replayTimerRoutine runs every replayRate ms, i.e 1000/replayRate times per second
  //
  void replayTimerRoutine () {
    if ( !replayPause ) {             // paused if a menu is open. just wait another replayRate milliseconds
      currentReplayTime = (currentReplayTime + (speedTable[speedIndex] * replayRate));
      //
      // Now we have different situations:
      //  - we moved beyond the end of the event and eventStatus is live: eventStatus becomes 'replay'
      //  - we moved beyond the last trails received from the server and the event is still live: just stop
      //    If we were live, the liveTimerRoutine will take over. If we were in replay, wait for the user to move the timeslider
      //  - we are still in replay: just move the ships and windmarkers
      //
      if (currentReplayTime > eventEnd) {
        if (eventStatus == 'live') liveTimer.cancel();
        eventStatus = 'replay';
        replayRunning = false;
        replayTimer.cancel();
        currentReplayTime = eventEnd;
        moveShipsAndWindTo(eventEnd, false);
        // Note that we continue to run using the 'live' tracks in memory
        // next session with this event we will start in the startReplay routine, where we delete the
        // locally stored live-xxxx.json file and replace is with the final replay-xxxx.json file
        // where xxxx is the eventId from the eventinfo.json file
      } else if (currentReplayTime > replayEnd) {
        replayRunning = false;
        replayTimer.cancel();
        currentReplayTime = replayEnd;
      } else {
        moveShipsAndWindTo(currentReplayTime, false);
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
  void moveShipsAndWindTo(time, noZoom) {
    moveShipsTo(time, noZoom);
    if (windMarkersOn) rotateWindTo(time);
  }
  //
  void moveShipsTo(time, noZoom) {
    LatLngBounds followBounds = LatLngBounds(const LatLng(0,0), const LatLng(0,0));
    followCounter = 0;
    double calculatedLat = 0.0;
    double calculatedLon = 0.0;
    double calculatedRotation = 0.0;
    shipMarkerList = [];
    shipLabelList = [];
    shipTrailList = [];
    for (int ship = 0; ship < replayTracks['shiptracks'].length; ship++) {
      dynamic track = replayTracks['shiptracks'][ship]; // copy ship part of the track to a new var, to keep things a bit simpler
      int trackLength = track['stamp'].length;
      // see where we are in the time track of the ship
      if (time < track['stamp'][0]) { // before the first timestamp
        shipTimeIndex[ship] = 0;      // set the track index to the first entry
        calculatedLat = track['lat'][0].toDouble();
        calculatedLon = track['lon'][0].toDouble();
        calculatedRotation = track['course'][0].toDouble();
      } else if (time >= track['stamp'][trackLength - 1]) { // after the last timestamp
        shipTimeIndex[ship] = trackLength - 1;              // set the track index to the last entry
        calculatedLat = track['lat'][trackLength - 1].toDouble();
        calculatedLon = track['lon'][trackLength - 1].toDouble();
        calculatedRotation = track['course'][trackLength - 1].toDouble();
      } else {                      // we are somewhere between two stamps
        // travel along the track back or forth to find out where we are
        if (time > track['stamp'][shipTimeIndex[ship]]) {   // move forward in the track
          while (track['stamp'][shipTimeIndex[ship]] < time) {
            shipTimeIndex[ship]++;
          }
          shipTimeIndex[ship]--;    // we went one entry too far
        } else {                    // else move backward in the track
          while (track['stamp'][shipTimeIndex[ship]] > time) {
            shipTimeIndex[ship]--;
          }
        }
        // calculate the ratio of time since previous stamp and next stamp
        double ratio = (time - track['stamp'][shipTimeIndex[ship]]) /
            (track['stamp'][shipTimeIndex[ship] + 1] - track['stamp'][shipTimeIndex[ship]]);
        // and set the ship position and rotation at that ratio between previous and next position/rotation
        calculatedLat = (track['lat'][shipTimeIndex[ship]] +
            ratio * (track['lat'][shipTimeIndex[ship] + 1] - track['lat'][shipTimeIndex[ship]])).toDouble();
        calculatedLon = (track['lon'][shipTimeIndex[ship]] +
            ratio * (track['lon'][shipTimeIndex[ship] + 1] - track['lon'][shipTimeIndex[ship]])).toDouble();
        int diff = track['course'][shipTimeIndex[ship] + 1] - track['course'][shipTimeIndex[ship]];
        if (diff >= 180) {
          calculatedRotation = (track['course'][shipTimeIndex[ship]] + (ratio * (diff - 360)).floor()).toDouble();
        } // anticlockwise through 360 dg
        else if (diff <= -180) {
          calculatedRotation = (track['course'][shipTimeIndex[ship]] + (ratio * (diff + 360)).floor().toDouble());
        } // clockwise through 360 dg
        else {
          calculatedRotation = (track['course'][shipTimeIndex[ship]] + (ratio * diff).floor()).toDouble();
        } // clockwise or anti clockwise less then 180 dg
        if (calculatedRotation >= 360) calculatedRotation = (calculatedRotation - 360);
        if (calculatedRotation < 0) calculatedRotation = (calculatedRotation + 360);
      }
      // Update the bounds with the calculated position of this ship
      // but only if we are supposed to follow this ship
      if (((following[track['name']] == null) ? false : following[track['name']])!) {
        if (followCounter == 0) {
          followBounds = LatLngBounds(LatLng(calculatedLat, calculatedLon), LatLng(calculatedLat,calculatedLon));}
        else {
          followBounds.extend(LatLng(calculatedLat, calculatedLon));
        }
        followCounter++;
      }
      // replace the ship marker
      // first make a new snippet text with the speed, and in case we are 'live' also the time of last received position
      String infoWindowText = '${track['name']}\n';
      if ((eventStatus == 'live' && currentReplayTime == replayEnd)) {
        int positionReceived = ((DateTime.now().millisecondsSinceEpoch - track['stamp'][shipTimeIndex[ship]]) ~/ 60000).toInt();
        String timeAgo = (positionReceived > 60) ? '${positionReceived ~/ 60} uur en ${positionReceived % 60}' : positionReceived.toString();
        infoWindowText += 'Positie $timeAgo minuten geleden\n';
      }
      var speedString = '${((track['speed'][shipTimeIndex[ship]] / 10) /1.852).toStringAsFixed(1)}kn ('
          '${track['speed'][shipTimeIndex[ship]] / 10}km/h)';
      infoWindowText += 'Snelheid $speedString';
      // add the shipMarker
      var color = shipMarkerColorTable[int.parse(replayTracks['shiptracks'][ship]['colorcode'])%32];
      var svgString = '<svg width="22" height="22">'
          '<polygon points="10,1 11,1 14,4 14,18 13,19 8,19 7,18 7,4" '
          'style="fill:$color;stroke:$markerBackgroundColor;stroke-width:1" '
          'transform="rotate($calculatedRotation 11,11)" />'
          '</svg>';
      LatLng currentPosition = LatLng(calculatedLat, calculatedLon);
      shipMarkerList.add(Marker(
          key: Key(infoWindowText),
          point: currentPosition,
          width: 22, height: 22,
          anchorPos: AnchorPos.exactly(Anchor(11, 11)),
          builder: (_) {
            return(InkWell(
              child: SvgPicture.string(svgString) ,
              onTap: () {
                showInfoWindow('ship$ship', infoWindowText, currentPosition, '');
                setState(() { });
              },
            ));
          }),
      );
      // refresh the infowindow if it was open for this ship
      if (infoWindowId == 'ship$ship') showInfoWindow('ship$ship', infoWindowText, currentPosition, '');
      // build the shipLabel
      if (showShipLabels) {
        // NB text backgroundcolor is reversed to the markerbackgroundcolor
        var tbgc = (markerBackgroundColor == bgColorBlack) ? bgColorWhite : bgColorBlack;
        var txt = track['name'] + ((showShipSpeeds) ? ', $speedString' : '');
        var svgString = '<svg width="300" height="35">'
            '<text x="0" y="32" fill="$tbgc">$txt</text>'
            '<text x="2" y="32" fill="$tbgc">$txt</text>'
            '<text x="0" y="30" fill="$tbgc">$txt</text>'
            '<text x="2" y="30" fill="$tbgc">$txt</text>'
            '<text x="1" y="31" fill="$markerBackgroundColor">$txt</text>'
            '</svg>';
        shipLabelList.add(Marker(
            point: LatLng(calculatedLat, calculatedLon),
            width: 300,
            height: 30,
            anchorPos: AnchorPos.exactly(Anchor(265, 25)),
            builder: (_) => SvgPicture.string(svgString)
        ));
      }
      // build the shipTrail
      int index = shipTimeIndex[ship];
      List<LatLng> trail = [LatLng(calculatedLat, calculatedLon)];
      while ((index >= 0) && (track['stamp'][index] > (time - actualTrailLength * 60 * 1000))) {
        trail.add(LatLng(track['lat'][index].toDouble(), track['lon'][index].toDouble()));
        index--;
      }
      shipTrailList.add(Polyline(
        points: trail,
        color: Color(int.parse('FF${shipMarkerColorTable[int.parse(track['colorcode'])%32].toUpperCase().replaceAll("#", "")}', radix:16)),
        strokeWidth: (eventTrailLength == actualTrailLength) ? 2 : 1,   // thick line in case of short trails, thin line when we display full eventlong trails
      ));
    }
    // move the camera to the ships
    if (followCounter == 0) autoZoom = false;
    if (followCounter > 0 && noZoom == false) {            // are there any ships to follow?
      mapController.move(followBounds.center, mapController.zoom);
      if (autoZoom && noZoom == false) {                   // move and zoom with all selected ships in the picture
        mapController.fitBounds(followBounds,
            options: const FitBoundsOptions(padding: EdgeInsets.only(left: 80.0, top: (kIsWeb)?100.0:120.0, right: 80.0, bottom: 110.0 )));
      }
    }
  }
  //
  void rotateWindTo(time) {
    double calculatedRotation = 0.0;
    windMarkerList = [];
    // now rotate all weather station markers and set the correct colors
    for (int windStation = 0; windStation < replayTracks['windtracks'].length; windStation++) {
      dynamic track = replayTracks['windtracks'][windStation];
      int trackLength = track['stamp'].length;
      if (time < track['stamp'][0]) { // before the first time stamp
        windTimeIndex[windStation] = 0;
        calculatedRotation = track['course'][0].toDouble();
      } else if (time >= track['stamp'][trackLength - 1]) { // after the last timestamp
        windTimeIndex[windStation] = trackLength - 1;
        calculatedRotation = track['course'][trackLength - 1].toDouble();
      } else { // somewhere between two stamps
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
        calculatedRotation = track['course'][windTimeIndex[windStation] + 1].toDouble();
      }
      // add the wind markers
      var infoWindowText = '${track['name']}\n'
          '${track['speed'][windTimeIndex[windStation]]} knopen, ${knotsToBft(track['speed'][windTimeIndex[windStation]])} Bft';
      var color = windColorTable[knotsToBft(track['speed'][windTimeIndex[windStation]])];
      var svgString = '<svg width="22" height="22">'
          '<polygon points="7,1 11,20 15,1 11,6" '
          'style="fill:$color;stroke:$markerBackgroundColor;stroke-width:1" '
          'transform="rotate($calculatedRotation 11,11)" />'
          '</svg>';
      LatLng windStationPosition = LatLng(track['lat'][0].toDouble(), track['lon'][0].toDouble());
      windMarkerList.add(Marker(
          point: windStationPosition,
          width: 22, height: 22,
          anchorPos: AnchorPos.exactly(Anchor(11, 11)),
          builder: (_) {
            return(InkWell(
              child: SvgPicture.string(svgString) ,
              onTap: () {
                showInfoWindow('wind$windStation', infoWindowText, windStationPosition, '');
                setState(() { });
              },
            ));
          }),
      );
      // refresh the infowindow if it was open for this ship
      if (infoWindowId == 'wind$windStation') showInfoWindow('wind$windStation', infoWindowText, windStationPosition, '');
    }
  }
  //
  // build the route polyline and routemarkers (and move the map to its bounds)
  //
  void buildRoute({required bool move})  {   // if move = true, move the map to the route after creating it
    routeLineList = [];
    routeMarkerList = [];
    routeLabelList = [];
    if (infoWindowId != '' && infoWindowId.substring(0,4) == 'rout') infoWindowId = '';
    if (showRoute) {
      LatLngBounds routeBounds = LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
      var first = true;
      for (var k = 0; k < route['features'].length; k++) {
        if (route['features'][k]['geometry']['type'] == 'LineString') {
          List<LatLng> points = [];
          List<dynamic> pts = route['features'][k]['geometry']['coordinates'];
          for (var i = 0; i < route['features'][k]['geometry']['coordinates'].length; i++) {
            points.add(LatLng(pts[i][1].toDouble(), pts[i][0].toDouble()));
            if (move) {
              if (first) {
                routeBounds = LatLngBounds(LatLng(pts[i][1].toDouble(), pts[i][0].toDouble()), LatLng(pts[i][1].toDouble(), pts[i][0].toDouble()));
                first = false;
              } else {
                routeBounds.extend(LatLng(pts[i][1].toDouble(), pts[i][0].toDouble()));
              }
            }
          }
          routeLineList.add(Polyline(
            points: points,
            color: Color(int.parse('6F${route['features'][k]['properties']['stroke'].toString().substring(1)}', radix: 16)),
            strokeWidth: 2,
          ));
        } else if (route['features'][k]['geometry']['type'] == 'Point') {
          LatLng routePointPosition = LatLng(route['features'][k]['geometry']['coordinates'][1], route['features'][k]['geometry']['coordinates'][0]);
          String svgString = '<svg width="22" height="22">'
              '<polygon points="8,8 8,14 14,14 14,8" '
              'style="fill:red;stroke:$markerBackgroundColor;stroke-width:1" />'
              '</svg>';
          String infoWindowText = '${route['features'][k]['properties']['name']}';
          var descr = (route['features'][k]['properties']['description'] == null) ? '' : route['features'][k]['properties']['description'];
          infoWindowText +=  (descr == '') ? '' : '\n$descr';
          var lnk = (route['features'][k]['properties']['link'] == null) ? '' : route['features'][k]['properties']['link'];
          infoWindowText +=  (lnk == '')? '' : ((kIsWeb) ? ' (klik)' : ' (tap)');
          routeMarkerList.add(Marker(
              point: routePointPosition,
              anchorPos: AnchorPos.exactly(Anchor(11, 11)),
              builder: (_) {
                return (InkWell(
                  child: SvgPicture.string(svgString),
                  onTap: () {
                    showInfoWindow('rout$k', infoWindowText, routePointPosition, (null ==
                        route['features'][k]['properties']['link']) ? '' : '${route['features'][k]['properties']['link']}');
                    setState(() {});
                  },
                ));
              }
          ));
          if (showRouteLabels) {
            // NB text backgroundcolor is reversed to the markerbackgroundcolor
            var tbgc = (markerBackgroundColor == bgColorBlack) ? bgColorWhite : bgColorBlack;
            var svgString = '<svg width="150" height="35">'
                '<text x="0" y="32" fill="$tbgc">${route['features'][k]['properties']['name']}</text>'
                '<text x="2" y="32" fill="$tbgc">${route['features'][k]['properties']['name']}</text>'
                '<text x="0" y="30" fill="$tbgc">${route['features'][k]['properties']['name']}</text>'
                '<text x="2" y="30" fill="$tbgc">${route['features'][k]['properties']['name']}</text>'
                '<text x="1" y="31" fill="$markerBackgroundColor">${route['features'][k]['properties']['name']}</text>'
                '</svg>';
            routeLabelList.add(Marker(
                point: routePointPosition,
                width: 150,
                height: 30,
                anchorPos: AnchorPos.exactly(Anchor(133, 23)),
                builder: (_) => SvgPicture.string(svgString)
            ));
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
      if (move) { //move the map to the route
        mapController.fitBounds(routeBounds,
            options: const FitBoundsOptions(padding: EdgeInsets.only(left: 80.0, top: (kIsWeb)?100.0:120.0, right: 80.0, bottom: 110.0)));
      }
      setState(() {}); // redraw the UI
    }
  }
  //
  // this routine creates an infoWindow for shipmarkers, windmarkers and routemarkers
  //
  void showInfoWindow(String id, String txt, LatLng pos, String link) {
    infoWindowId = id;
    infoWindowLatLng = pos;
    CustomPoint<double> mapCenterPoint = const Epsg3857().latLngToPoint(mapController.center, mapController.zoom);
    CustomPoint<double> windowPoint = const Epsg3857().latLngToPoint(pos, mapController.zoom);
    CustomPoint<double> screenPoint = mapCenterPoint - windowPoint;
    infoWindowAnchorBottom = screenPoint.y + screenHeight/2 + 10.0;
    infoWindowAnchorRight = screenPoint.x + screenWidth/2 - 150.0;
    infoWindowTextStyle = const TextStyle(fontSize: 13.0, color: Colors.black);
    infoWindowText = txt;
    infoWindowLink = link;
    setState(() { });
  }
  //----------------------------------------------------------------------------
  //
  // Routine to prepare info for the shipmenu: a list of shipnames and shipcolors,
  // and the values for the 'following' checkboxes in the shipmenu
  // In live we only add an entry to the 'following' list if no entry for that ship existed, because
  // we want to retain the contents during the rebuild in live
  //
  // Also set the shipTimeIndices and windTimeIndices to zero (beginning of the tracks)
  //
  void buildShipAndWindInfo() {
    // empty all lists except the 'following' list
    shipList = [];
    shipColors = [];
    shipTimeIndex = [];
    windTimeIndex = [];
    followCounter = 0;
    dynamic ships = replayTracks['shiptracks'];
    for (int k = 0; k < ships.length; k++) {
      shipList.add(ships[k]['name']);           // add the name to the shipList for the menu in the righthand drawer
      shipColors.add(shipMarkerColorTable[int.parse(ships[k]['colorcode'])%32]);
      following.putIfAbsent(ships[k]['name'], () => true);  // set 'following' for this ship to true (if it was not already in the list)
      if (following[ships[k]['name']] == true) followCounter++;
      shipTimeIndex.add(0);                     // set the timeindex to the beginning of the track
    }
    dynamic wind = replayTracks['windtracks'];
    for (var k = 0; k < wind.length; k++) {
      windTimeIndex.add(0);
    }
  }
  //----------------------------------------------------------------------------
  //
  // routine to convert wind knots into Beaufort
  //
  int knotsToBft(speedInKnots) {
    return windKnots.indexOf(windKnots.firstWhere((i) => i >= speedInKnots)).toInt();
  }
}