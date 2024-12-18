import 'package:flutter/material.dart';

//
// you can add key/values as necessary, the values here are merged/added to the config file on the server
// identical keyvalues in this defaultconfig will be overwritten by keyvalues with the same keys in the server file
//
Map<String, dynamic> defaultConfig = {
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
