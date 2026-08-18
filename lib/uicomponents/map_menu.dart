import 'package:flutter/material.dart';

import '../main_common.dart';
import '../default_data.dart';
import 'trail_length_slider.dart';

class MapMenu extends StatelessWidget {
  final MyAppState appState;

  const MapMenu({super.key, required this.appState});

  // Helper method to handle the complex state update when the map type changes.
  void _onMapTypeChanged(String newMapType) {
    appState.selectedMapType = newMapType;
    appState.prefs.setString('maptype', appState.selectedMapType);

    final mapProvider = appState.baseMapTileProviders[appState.selectedMapType];
    appState.bgColor = (mapProvider?['bgColor'] ?? '#000000') == '#000000' ? bgDark : bgLight;
    appState.markerBackgroundColor = (appState.bgColor == bgDark) ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    appState.labelBackgroundColor = (appState.bgColor == bgDark) ? const Color(0x7FFFFFFF) : const Color(0x7F000000);

    if (appState.eventStatus == EventStatus.live || appState.eventStatus == EventStatus.replay) {
      // force windTimeIndexes to beginning to ensure redrawing of the windmarkers
      appState.windTimeIndex = List.filled(appState.replayTracks['windtracks']?.length ?? 0, -1, growable: true);
      // and redraw all markers and labels
      appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: false);
    }
    if ((appState.route['features'] ?? []).isNotEmpty) {
      appState.buildRoute();
    }
    appState.refreshUI();
  }

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;
    final baseMapKeys = appState.baseMapTileProviders.keys.toList(); // the keys are the names of the maps
    final overlayMapKeys = appState.overlayTileProviders.keys.toList();

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(
          width: 280,
          color: appState.menuBackgroundColor,
          padding: EdgeInsets.fromLTRB(10, appState.menuOffset, 0, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(txt.str('maps')),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                icon: Icon(Icons.cancel_sharp, size: 20, color: appState.menuForegroundColor),
                onPressed: () => appState.toggleMenu(OpenMenu.none),
              ),
              const SizedBox(width: 10),
            ]),
            const Divider(endIndent: 10),
            Flexible(
                child: SingleChildScrollView(
                    child: Container(
                        padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                        child: Column(children: [
                          Row(children: [const SizedBox(width: 4), Text(txt.plural('baseMaps', 0)), const Spacer()]),
                          _RadioListSection(
                            items: baseMapKeys,
                            selectedValue: appState.selectedMapType,
                            activeColor: appState.menuForegroundColor,
                            onChanged: (value) => _onMapTypeChanged(value!),
                          ),
                          if (appState.selectedOverlayType.isNotEmpty)
                            Wrap(children: [
                              const Divider(),
                              Row(children: [
                                const SizedBox(width: 5),
                                Text(txt.str('mapOverlay')),
                                const Spacer(),
                                Checkbox(
                                    mouseCursor: SystemMouseCursors.click,
                                    visualDensity: const VisualDensity(
                                        horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                    activeColor: appState.menuForegroundColor,
                                    checkColor: appState.menuBackgroundColor,
                                    side: BorderSide(color: appState.menuForegroundColor),
                                    value: appState.mapOverlay,
                                    onChanged: (_) {
                                      appState.mapOverlay = !appState.mapOverlay;
                                      appState.prefs.setBool('mapoverlay', appState.mapOverlay);
                                      appState.refreshUI();
                                    }),
                              ]),
                              _RadioListSection(
                                items: overlayMapKeys,
                                selectedValue: appState.selectedOverlayType,
                                activeColor: appState.menuForegroundColor,
                                onChanged: (value) {
                                  appState.selectedOverlayType = value!;
                                  appState.prefs.setString('overlaytype', appState.selectedOverlayType);
                                  appState.refreshUI();
                                },
                              ),
                            ]),
                          if ((appState.replayTracks['windtracks'] ?? []).isNotEmpty && appState.allowShowWind)
                            Wrap(children: [
                              const Divider(),
                              Row(children: [
                                const SizedBox(width: 5),
                                Text(txt.str('windArrows')),
                                const Spacer(),
                                Checkbox(
                                    mouseCursor: SystemMouseCursors.click,
                                    visualDensity: const VisualDensity(
                                        horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                    activeColor: appState.menuForegroundColor,
                                    checkColor: appState.menuBackgroundColor,
                                    side: BorderSide(color: appState.menuForegroundColor),
                                    value: appState.showWindMarkers,
                                    onChanged: (value) {
                                      appState.showWindMarkers = !appState.showWindMarkers;
                                      appState.windTimeIndex = List.filled(appState.windTimeIndex.length, -1, growable: true);
                                      appState.rotateWindTo(appState.currentReplayTime);
                                      if (appState.infoWindowId.startsWith('wind')) {
                                        appState.infoWindowId = '';
                                        appState.infoWindowMarkerList = [];
                                      }
                                      appState.prefs.setBool('windmarkers', appState.showWindMarkers);
                                      appState.refreshUI();
                                    })
                              ]),
                              Row(children: [
                                const SizedBox(width: 5),
                                Text(txt.str('windSimulation')),
                                const Spacer(),
                                Tooltip(
                                    message: txt.str('takeCareSimulation'),
                                    child: Checkbox(
                                        mouseCursor: SystemMouseCursors.click,
                                        visualDensity: const VisualDensity(
                                            horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                        activeColor: appState.menuForegroundColor,
                                        checkColor: appState.menuBackgroundColor,
                                        side: BorderSide(color: appState.menuForegroundColor),
                                        value: appState.showWindParticles,
                                        onChanged: (value) {
                                          appState.showWindParticles = !appState.showWindParticles;
                                          appState.prefs.setBool('windparticles', appState.showWindParticles);
                                          appState.refreshUI();
                                        }))
                              ])
                            ]),
                          if ((appState.route['features'] ?? []).isNotEmpty || (appState.replayTracks['gpsbuoy'] ?? []).isNotEmpty)
                            Wrap(children: [
                              const Divider(),
                              Row(children: [
                                const SizedBox(width: 5),
                                Text(txt.str('routePortsBuoys')),
                                const Spacer(),
                                Checkbox(
                                    mouseCursor: SystemMouseCursors.click,
                                    visualDensity: const VisualDensity(
                                        horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                    activeColor: appState.menuForegroundColor,
                                    checkColor:
                                        appState.showRoute ? appState.menuBackgroundColor : appState.menuBackgroundColor.withAlpha(0x7F),
                                    side: BorderSide(color: appState.menuForegroundColor),
                                    value: appState.showRoute,
                                    onChanged: (_) {
                                      appState.showRoute = !appState.showRoute;
                                      if (appState.infoWindowId.startsWith('rout')) {
                                        appState.infoWindowId = '';
                                        appState.infoWindowMarkerList = [];
                                      }
                                      appState.buildRoute();
                                      appState.updateGPSBuoys(appState.currentReplayTime);
                                      appState.prefs.setBool('showroute', appState.showRoute);
                                      appState.refreshUI();
                                    })
                              ]),
                              Row(children: [
                                const SizedBox(width: 20),
                                Text(txt.str('withNames')),
                                const Spacer(),
                                Checkbox(
                                    mouseCursor: SystemMouseCursors.click,
                                    visualDensity: const VisualDensity(
                                        horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                    activeColor: appState.menuForegroundColor,
                                    checkColor:
                                        appState.showRoute ? appState.menuBackgroundColor : appState.menuBackgroundColor.withAlpha(0x7F),
                                    side: BorderSide(color: appState.menuForegroundColor),
                                    value: appState.showRouteLabels,
                                    onChanged: (value) {
                                      appState.showRouteLabels = !appState.showRouteLabels;
                                      appState.buildRoute();
                                      appState.prefs.setBool('routelabels', appState.showRouteLabels);
                                      appState.refreshUI();
                                    })
                              ])
                            ]),
                          Wrap(children: [
                            const Divider(),
                            Row(children: [
                              const SizedBox(width: 5),
                              Text(txt.str('makeMapRotatable')),
                              const Spacer(),
                              Checkbox(
                                  mouseCursor: SystemMouseCursors.click,
                                  visualDensity:
                                      const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                  activeColor: appState.menuForegroundColor,
                                  checkColor: appState.menuBackgroundColor,
                                  side: BorderSide(color: appState.menuForegroundColor),
                                  value: appState.enableMapRotation,
                                  onChanged: (value) {
                                    appState.enableMapRotation = !appState.enableMapRotation;
                                    appState.mapController.rotate(0);
                                    appState.refreshUI();
                                  })
                            ])
                          ]),
                          const Divider(),
                          TrailLengthSlider(appState: appState)
                        ]))))
          ])),
      const SizedBox(width: 41),
    ]);
  }
}

class _RadioListSection extends StatelessWidget {
  final List<String> items;
  final String selectedValue;
  final Color activeColor;
  final ValueChanged<String?> onChanged;

  const _RadioListSection({
    required this.items,
    required this.selectedValue,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RadioGroup(
          groupValue: selectedValue,
          onChanged: onChanged,
          child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(0),
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (_, index) {
                final itemValue = items[index];
                return Row(children: [
                  const SizedBox(width: 20),
                  Expanded(child: Text(itemValue)),
                  Theme(
                      data: ThemeData.dark(),
                      child: Radio(
                        mouseCursor: SystemMouseCursors.click,
                        activeColor: activeColor,
                        visualDensity:
                            const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                        value: itemValue,
                      ))
                ]);
              }))
    ]);
  }
}
