//
// this file defines the default map and sets the default values for marker and label backgrounds
// the values defined here are in principle overwritten by the contents of the serverfile config/maptileproviders.json
//
import 'package:flutter/material.dart';

Map<String, dynamic> defaultMapTileProviders = {
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
  }
};
String selectedMapType = 'Standaard';
String bgColor = defaultMapTileProviders['basemaps']['bgColor'];
Color markerBackgroundColor = (bgColor == '#000000') ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
Color labelBackgroundColor = (bgColor == '#000000') ? const Color(0xBfFFFFFF) : const Color(0xFF000000);
//
