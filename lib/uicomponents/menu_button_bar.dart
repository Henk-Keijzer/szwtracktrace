import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main_common.dart'; // To get MyAppState
import '../default_data.dart';

class MenuButtonBar extends StatefulWidget {
  final MyAppState appState;

  const MenuButtonBar({super.key, required this.appState});

  @override
  State<MenuButtonBar> createState() => _MenuButtonBarState();
}

class _MenuButtonBarState extends State<MenuButtonBar> with TickerProviderStateMixin {
  Timer? _zoomTimer;
  AnimationController? _animationController;
  Animation<double>? _animation;

  @override
  void dispose() {
    _zoomTimer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  void _zoom(double value) {
    widget.appState.mapController.move(widget.appState.mapController.camera.center, widget.appState.mapController.camera.zoom + value);
    if (widget.appState.autoFollow) widget.appState.autoZoom = false;
    widget.appState
        .moveShipsBuoysAndWindTo(widget.appState.currentReplayTime, moveMap: false); // make sure the top-left corner windmarker is moved
    widget.appState.refreshUI();
  }

  void _startZoom(double value) {
    _zoomTimer?.cancel();
    _zoom(value / 1000); // Run first zoom immediately
    _zoomTimer = Timer.periodic(Duration(milliseconds: value.abs().toInt()), (timer) => _zoom(value / 1000));
  }

  void _stopZoom() {
    _zoomTimer?.cancel();
  }

  void _setZoom(double newZoom) {
    widget.appState.mapController.move(widget.appState.mapController.camera.center, newZoom);
    if (widget.appState.autoFollow) widget.appState.autoZoom = false;
    widget.appState
        .moveShipsBuoysAndWindTo(widget.appState.currentReplayTime, moveMap: false); // make sure the top-left corner windmarker is moved
    widget.appState.refreshUI();
  }

  void _animatedZoom(double totalZoomChange) {
    _zoomTimer?.cancel();
    _animationController?.dispose();
    final zoomTween =
        Tween<double>(begin: widget.appState.mapController.camera.zoom, end: widget.appState.mapController.camera.zoom + totalZoomChange);
    _animationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _animation = CurvedAnimation(parent: _animationController!, curve: Curves.easeOutSine)
      ..addListener(() => _setZoom(zoomTween.evaluate(_animation!)));
    _animationController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final txt = appState.txt;

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Column(children: [
        SizedBox(height: appState.menuOffset),
        Container(
            decoration: BoxDecoration(
                color: appState.menuBackgroundColor.withAlpha(appState.activeMenu == OpenMenu.none ? 0x7F : 0xFF),
                borderRadius: BorderRadius.only( bottomLeft: Radius.circular(5))),
            width: 40,
            child: Column(children: [
              if (appState.eventStart != appState.eventEnd)
                IconButton(
                    // button for the shipList
                    mouseCursor: SystemMouseCursors.click,
                    icon: Icon(boatIcons[appState.config['icons']['boatIcon']],
                        color: (appState.activeMenu == OpenMenu.ship || appState.activeMenu == OpenMenu.preEventParticipants)
                            ? appState.menuAccentColor
                            : appState.menuForegroundColor),
                    onPressed: () {
                      appState.showAttribution = appState.showShipInfo = false;
                      if (appState.eventStatus != EventStatus.preEvent && appState.shipList.isNotEmpty) {
                        appState.toggleMenu(OpenMenu.ship);
                      } else {
                        appState.toggleMenu(OpenMenu.preEventParticipants);
                      }
                      appState.refreshUI();
                    }),
              IconButton(
                  // button for the mapMenu
                  mouseCursor: SystemMouseCursors.click,
                  icon:
                      Icon(Icons.map, color: appState.activeMenu == OpenMenu.map ? appState.menuAccentColor : appState.menuForegroundColor),
                  onPressed: () {
                    appState.showAttribution = appState.showShipInfo = false;
                    appState.toggleMenu(OpenMenu.map);
                    appState.refreshUI();
                  }),
              IconButton(
                  // button for the infoPage
                  mouseCursor: SystemMouseCursors.click,
                  icon: Icon(Icons.info,
                      color: appState.activeMenu == OpenMenu.infoPage ? appState.menuAccentColor : appState.menuForegroundColor),
                  onPressed: () {
                    appState.showAttribution = appState.showShipInfo = false;
                    appState.toggleMenu(OpenMenu.infoPage);
                    appState.refreshUI();
                  }),
              if ((appState.config['options']['windy'] == "true") &&
                  (appState.eventStatus == EventStatus.live || appState.eventStatus == EventStatus.preEvent))
                IconButton(
                    //optional button for windy.com
                    mouseCursor: SystemMouseCursors.click,
                    icon: Tooltip(
                        message: txt.str('openWindy'), child: Image.asset('assets/images/windy-logo-full.png', width: 25, height: 25)),
                    onPressed: () {
                      var latlng = appState.mapController.camera.center;
                      var zoom = appState.mapController.camera.zoom;
                      launchUrl(Uri.parse('https://embed.windy.com/embed2.html?lat=${latlng.latitude}&lon=${latlng.longitude}'
                          '&detailLat=${latlng.latitude}&detailLon=${latlng.longitude}&width=${appState.screenWidth}&height=${appState.screenHeight}'
                          '&zoom=$zoom&level=surface&overlay=wind&product=ecmwf&menu=&message=true&marker=&calendar=now&pressure='
                          '&type=map&location=coordinates&detail=true&metricWind=bft&metricTemp=%C2%B0C&radarRange=-1'));
                    }),
              if (kIsWeb &&
                  appState.videoIdList.isNotEmpty &&
                  (appState.eventStatus == EventStatus.live || appState.eventStatus == EventStatus.preEvent))
                IconButton(
                    // optional button for live video
                    mouseCursor: SystemMouseCursors.click,
                    icon: Tooltip(
                        message: txt.str('liveVideo'),
                        child: Icon(Icons.ondemand_video,
                            color: appState.showVideo ? appState.menuAccentColor : appState.menuForegroundColor)),
                    onPressed: () {
                      appState.showVideo = !appState.showVideo;
                      appState.refreshUI();
                    }),
              IconButton(
                  // button for sharing the link to the Track&Trace website
                  mouseCursor: SystemMouseCursors.click,
                  icon: Icon(Icons.share, color: appState.menuForegroundColor),
                  onPressed: () async {
                    await SharePlus.instance.share(ShareParams(
                        text:
                            '${txt.str('linkToTTWebsite')}: ${appState.serverUrl}?event=${appState.eventDomain.replaceAll(' ', '%' '20')}'));
                  }),
              const Divider(),
              // and a + and - button for zoom-in and -out
              GestureDetector(
                  onTap: () => _animatedZoom(0.5),
                  onLongPressStart: (_) => _startZoom(25), // milliseconds and zoomstep/1000, plus = zoom in
                  onLongPressEnd: (_) => _stopZoom(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.add_box, color: appState.menuForegroundColor)),
                  )),
              if (appState.mapReady)
                InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () {
                      if (appState.autoFollow) {
                        appState.autoZoom = !appState.autoZoom;
                        if (appState.autoZoom) {
                          appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: true);
                        }
                        appState.refreshUI();
                      }
                    },
                    child: Text(appState.mapController.camera.zoom.toStringAsFixed(1),
                        style: TextStyle(fontSize: 11, color: appState.menuForegroundColor))),
              GestureDetector(
                  onTap: () => _animatedZoom(-0.5),
                  onLongPressStart: (_) => _startZoom(-25), // milliseconds and zoomstep/1000, minus = zoom out
                  onLongPressEnd: (_) => _stopZoom(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.indeterminate_check_box, color: appState.menuForegroundColor),
                    ),
                  )),
              if (appState.testing)
                Wrap(children: [
                  const Divider(),
                  IconButton(
                      mouseCursor: SystemMouseCursors.click,
                      icon: Icon(Icons.settings,
                          color: appState.activeMenu == OpenMenu.testing ? appState.menuAccentColor : appState.menuForegroundColor),
                      onPressed: () {
                        appState.showAttribution = appState.showShipInfo = false;
                        appState.toggleMenu(OpenMenu.testing);
                        appState.refreshUI();
                      })
                ])
            ]))
      ])
    ]);
  }
}
