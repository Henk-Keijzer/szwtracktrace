import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:universal_web/web.dart';

// The helper functions in this file do not rely on data in main_common.dart.
// So, no need to put them in a class

/// Converts windspeed in knots to the Beaufort scale (0-12).
int knotsToBft(double knots) {
  const thresholds = [1, 4, 7, 11, 17, 22, 28, 34, 41, 48, 56, 64];
  // find the index of the first threshold that is greater than the knots value
  final index = thresholds.indexWhere((t) => knots < t);
  // If not found (i.e., knots is >= 64), it's 12. Otherwise, it's the index found.
  return index == -1 ? 12 : index;
}

/// Converts windspeed in knots to a corresponding color from a predefined table.
String knotsToColor(double knots) {
  const List<String> windColorTable = [
    '#FFFFFF',
    '#CCFFCC',
    '#66FF66',
    '#33FF33',
    '#00FF00',
    '#00CCFF',
    '#0066FF',
    '#FFCC00',
    '#FF9900',
    '#FF0000',
    '#990000',
    '#000000',
    '#000000',
  ];
  return windColorTable[knotsToBft(knots)];
}

/// Calculates the bearing (heading) in degrees from one LatLng point to another.
double calculateHeading(LatLng ll1, LatLng ll2) {
  final double phi1 = ll1.latitudeInRad;
  final double phi2 = ll2.latitudeInRad;
  final double deltaLambda = ll2.longitudeInRad - ll1.longitudeInRad;
  final double y = sin(deltaLambda) * cos(phi2);
  final double x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
  final double theta = atan2(y, x);

  // Convert radians to degrees and normalize to a 0-360 compass bearing.
  final double degrees = theta * 180 / pi;
  return (degrees + 360) % 360;
}

/// Predicts a new geographical position based on a starting point, speed (km/h), time (ms), and course.
LatLng predictPosition(LatLng initialPosition, double speed, int time, int course) {
  // Speed is in km/h, time is in milliseconds.
  final double distanceInKm = (speed * time) / 3600000;
  const double earthRadius = 6371; // Earth's radius in km
  final double rdist = distanceInKm / earthRadius; // angular distance in radians

  final double rcourse = course * pi / 180;
  final double rlat1 = initialPosition.latitudeInRad;
  final double rlon1 = initialPosition.longitudeInRad;

  final double rlat2 = asin(sin(rlat1) * cos(rdist) + cos(rlat1) * sin(rdist) * cos(rcourse));
  double rlon2 = rlon1 + atan2(sin(rcourse) * sin(rdist) * cos(rlat1), cos(rdist) - sin(rlat1) * sin(rlat2));

  // Normalize longitude to the range -PI to +PI
  rlon2 = (rlon2 + 3 * pi) % (2 * pi) - pi;

  return LatLng(rlat2 * 180 / pi, rlon2 * 180 / pi);
}

/// Recursively merges the contents of map2 into map1.
void mergeMaps(Map<dynamic, dynamic> map1, Map<dynamic, dynamic> map2) {
  map2.forEach((key, value) {
    if (map1.containsKey(key)) {
      if (map1[key] is Map && value is Map) {
        mergeMaps(map1[key], value);
      }
    } else {
      map1[key] = value;
    }
  });
}

// some helpers for web
//
// Note that 'window.xxx' may return invalid data on non-web platforms
// so, make sure you return a correct 'dummy' value for !kIsWeb
//
// Checks if the app is running inside an iframe.
bool isEmbeddedInIframe() {
  if (!kIsWeb) return false;
  try {
    // In a top-level context, window.parent is the same as window.self.
    // If they are different, the app is running inside an iframe.
    // This is wrapped in a try-catch because accessing window.parent
    // can throw a SecurityError in cross-origin iframes.
    return window.parent != window.self;
  } catch (e) {
    // If a security error occurs, it's almost certain the app is in a cross-origin iframe.
    return true;
  }
}
// Updates the browser's URL without reloading the page.
void setBrowserUrl(String eventDomain) {
  // Use `null` for the state data as we don't need to store anything.
  if (kIsWeb) window.history.pushState(null, '', '?event=$eventDomain');
}

String getWebHostName() {
  return kIsWeb ? window.location.hostname : '';
}

