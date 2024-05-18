import 'package:flutter/material.dart';

// If you want to add new keys/values: not more then the two current levels and all keys/values must be Strings,
// otherwise the merge with the user provided config/flutter_config.json file will fail
//
Map<String, dynamic> config = {
  "text": {"participants": "schepen", "shipNames": "Scheepsnamen", "skipper": "Schipper"},
  "colors": {
    "menuBackgroundColor": "FF455A64",
    "menuForegroundColor": "FFC8CED1",
    "menuAccentColor": "FFFFFFFF",
    "infoPageColor": "FFB0BEC5"
  },
  "icons": {"boatIcon": "sailing", "boatSVGPath": "10,1 11,1 14,4 14,18 13,19 8,19 7,18 7,4"},
  "options": {"windy": "true", "applestorelink": "", "playstorelink": ""},
};

Map<String, dynamic> boatIcons = {
  "sailing": Icons.sailing,
  "rowing": Icons.rowing,
  "motorboat": Icons.directions_boat,
};
