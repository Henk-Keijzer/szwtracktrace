import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({required this.server, required this.phoneId, required sslCert}) {
    if (!kIsWeb) {
      SecurityContext context = SecurityContext.defaultContext;
      context.setTrustedCertificatesBytes(sslCert);
    }
  }

  /// the server URL to fetch data from
  final String server;

  /// the phoneId to identify this device for statistics
  final String phoneId;

  Future<Map<String, dynamic>> getDirList({bool noStats = false, bool testing = false}) async {
    final response = await http.get(Uri.parse('${server}get/?req=dirlist&dev=$phoneId${(testing)
            ? '&tst=true' : ''}${noStats ? '&nostats=true' : ''}'));
    Map<String, dynamic> dir = (response.statusCode == 200 && response.body != '') ? safeJsonDecode(response.body) : {};
    dir.remove('_Shipinfo');
    return dir;
  }

  Future<Map<String, dynamic>> getConfig() async {
    final response = await http.get(Uri.parse('${server}get/?req=config&dev=$phoneId'));
    return (response.statusCode == 200 && response.body != '') ? safeJsonDecode(response.body) : {};
  }

  Future<Map<String, dynamic>> getEventInfo({required String event, bool noStats = false}) async {
    final response = await http.get(Uri.parse('${server}get/?req=eventinfo&dev=$phoneId&event=$event${noStats
        ? '&nostats=true' : ''}'));
    return (response.statusCode == 200 && response.body != '') ? safeJsonDecode(response.body) : {};
  }

  Future<List<dynamic>> getParticipants({required String event, bool noStats = false}) async {
    final response = await http.get(Uri.parse('${server}get/?req=participants&dev=$phoneId&event=$event${noStats
        ? '&nostats=true' : ''}'));
    return (response.statusCode == 200 && response.body != '') ? jsonDecode(response.body) : [];
  }

  Future<Map<String, dynamic>> getRoute({required String event, bool noStats = false}) async {
    final response = await http.get(Uri.parse('${server}get/?req=route&dev=$phoneId&event=$event${noStats
        ? '&nostats=true' : ''}'));
    return (response.statusCode == 200 && response.body != '') ? safeJsonDecode(response.body) : {};
  }

  Future<String> getAppIconUrl({String event = '', bool noStats = false}) async {
    final response = await http.get(
    Uri.parse('${server}get/?req=appiconurl${(event == '') ? '' : '&event=$event'}&dev=$phoneId${noStats
        ? '&nostats=true' : ''}'));
    return (response.statusCode == 200)
        ? response.body.replaceFirst('/', '|', 8).split('|').last
        : 'assets/assets/images/defaultAppIcon.png';
  }

  Future<String> getInfoPage(String language) async {
    final response = await http.get(Uri.parse('${server}get/?req=appinfopage&dev=$phoneId&lang=$language'));
    return (response.statusCode == 200 && response.body != '') ? response.body : '';
  }

  Future<String> getShipInfo({String ship = '', String event = '', bool team = false}) async {
    final response = await http.get(Uri.parse('${server}get/?req=shipinfo&dev=$phoneId&event=$event'
        '&ship=${Uri.encodeQueryComponent(ship)}&team=${team ? 'true' : 'false'}'));
    return (response.statusCode == 200 && response.body != '') ? response.body : '';
  }

  Future<Map<String, dynamic>> getMapTileProviders() async {
    final response = await http.get(Uri.parse('${server}get/?req=maptileproviders&dev=$phoneId'));
    return (response.statusCode == 200 && response.body != '') ? safeJsonDecode(response.body) : {};
  }

  Future<Map<String, dynamic>> getReplayTracks({required String event, bool noData = false, bool noStats = false}) async {
    final response = await http.get(Uri.parse('${server}get/?req=replay&dev=$phoneId&event=$event${noData
        ? '&nodata=true' : ''}${noStats ? '&nostats=true' : ''}'));
    return (response.statusCode == 200 && response.body != '') ? convertTimes(safeJsonDecode(response.body)) : {};
  }

  Future<Map<String, dynamic>> getTrails({required String event, int fromTime = 0, bool noStats = false}) async {
    final response = await http.get(
    Uri.parse('${server}get/?req=trails&dev=$phoneId&event=$event${(fromTime != 0) ? "&msg=$fromTime" : ""}${noStats
        ? '&nostats=true' : ''}'));
    return (response.statusCode == 200 && response.body != '') ? convertTimes(safeJsonDecode(response.body)) : {};
  }

  //
  // two helper functions, first safely decode json (always returns a decent map, even if it is empty)
  Map<String, dynamic> safeJsonDecode(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  //
  // convert all times in trails and replay tracks to milliseconds
  Map<String, dynamic> convertTimes(Map<String, dynamic> track) {
    track['starttime'] = track['starttime'] * 1000;
    track['endtime'] = track['endtime'] * 1000;
    track['filestamp'] = (track['filestamp'] ?? track['endtime']) * 1000;
    for (final key in ['shiptracks', 'buoytracks', 'windtracks']) {
      track[key] ??= [];
      for (final item in track[key]) {
        final stamps = item['stamp'];
        for (var i = 0; i < stamps.length; i++) {
          stamps[i] = stamps[i] * 1000;
        }
      }
    }
    return track;
  }
}
