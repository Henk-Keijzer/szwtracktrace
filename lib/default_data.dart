import 'package:material_ui/material_ui.dart';

//------------------------------------------------------------------------------------------------------------------------------------------
// default MapTileProvider
//
const Map<String, dynamic> defaultMapTileProviders = {
  'basemaps': {
    'Standaard': {
      'service': 'WMTS',
      'URL': 'https://service.pdok.nl/brt/achtergrondkaart/wmts/v2_0/standaard/EPSG:3857/{z}/{x}/{y}.png',
      'subDomains': [],
      'labels': '',
      'maxZoom': 19.0,
      'bgColor': '#000000',
      'attrib': 'Kadaster',
      'attribLink': 'https://www.kadaster.nl'
    },
  },
  'labels': {},
  'overlays': {}
};
//------------------------------------------------------------------------------------------------------------------------------------------
// default config file
//
// you can add key/values as necessary, the values here are merged/added to the config file on the server
// values of identical keyvalues in this defaultconfig will be overwritten by values with the same keys in the server file
//
const Map<String, dynamic> defaultConfig = {
  "colors": {
    "menuBackgroundColor": "FF455A64",
    "menuForegroundColor": "FFC8CED1",
    "menuAccentColor": "FFFFFFFF",
    "infoPageColor": "FFB0BEC5"
  },
  "icons": {"boatIcon": "sailing", "boatSVGPath": "10,1 11,1 14,4 14,18 13,19 8,19 7,18 7,4"},
  "options": {
    "windy": "true",
    "applestorelink": "",
    "playstorelink": "",
    "sortyearreverse": "true",
    "localizations": "nl", // comma separated list of languages, e.g. nl,en,fr, no spaces
  },
};

const Map<String, dynamic> boatIcons = {
  "sailing": Icons.sailing,
  "rowing": Icons.rowing,
  "motorboat": Icons.directions_boat,
};

const String bgDark = '#000000'; // marker and label outline colors in #RGB string depending on map background black or white
const String bgLight = '#ffffff';
//
// the next color table was created using an online program to create 32 distinct colors, for example https://mokole.com/palette.html
// or just ask Co-Pilot
const List shipMarkerColorTable = [
  0xFFFF0000,
  0xFF00FF00,
  0xFF0000FF,
  0xFFFFFF00,
  0xFF00FFFF,
  0xFFFF00FF,
  0xFFFFA500,
  0xFF800080,
  0xFF00FF00,
  0xFFFFC0CB,
  0xFF008080,
  0xFFE6E6FA,
  0xFFA52A2A,
  0xFFF5F5DC,
  0xFF800000,
  0xFF808000,
  0xFF000080,
  0xFFFF7F50,
  0xFF40E0D0,
  0xFFC0C0C0,
  0xFFFFD700,
  0xFFFFDAB9,
  0xFFDDA0DD,
  0xFF98FF98,
  0xFFFA8072,
  0xFF4B0082,
  0xFFFFFFF0,
  0xFFF0E68C,
  0xFFDA70D6,
  0xFFDC143C,
  0xFF708090,
  0xFFEE82EE
];
//
// number of nearby stations for the centerwind and windparticles calculations
const nrWindStationsForCenterWindCalculation = 3; // should we make this a flutter_config or eventInfo constant???
//
// constants for the movement of ships and wind markers in time
const int speedIndexInitialValue = 4;
const List<int> speedTable = [0, 1, 10, 30, 60, 180, 300, 900, 1800, 3600];
/* no longer necessary (now in language files), but kept for clarification of the speedtable
const List speedTextTable = ["gestopt", "1 sec/sec", "10 sec/sec", "30 sec/sec", "1 min/sec", "3 min/sec",
  "5 min/sec", "15 min/sec", "30 min/sec", "1 uur/sec"];
*/
