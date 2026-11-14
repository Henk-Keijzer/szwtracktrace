import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';

import '../main_common.dart';
import '../widgets/wind_particles.dart';

class MapView extends StatelessWidget {
  final MyAppState appState;

  const MapView({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final selectedMap = appState.baseMapTileProviders[appState.selectedMapType];
    return FlutterMap(
      mapController: appState.mapController,
      options: MapOptions(
          onMapReady: appState.onMapCreated,
          initialCenter: appState.initialMapPosition,
          initialZoom: appState.initialMapZoom,
          maxZoom: selectedMap['maxZoom'],
          backgroundColor: Colors.blueGrey.shade200,
          interactionOptions: appState.enableMapRotation
              ? const InteractionOptions(flags: InteractiveFlag.all, cursorKeyboardRotationOptions: CursorKeyboardRotationOptions())
              : InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  cursorKeyboardRotationOptions: CursorKeyboardRotationOptions.disabled(),
                ),
          onPositionChanged: (_, gesture) {
            if (gesture) {
              appState.autoFollow = false;
              appState.toggleMenu(OpenMenu.none);
              if ((appState.eventStatus == EventStatus.live || appState.eventStatus == EventStatus.replay) && appState.allowShowWind) {
                appState.rotateWindTo(appState.currentReplayTime); // ensure topleft wind arrow remains topleft
              }
              appState.refreshUI();
            }
          },
          onTap: (_, __) {
            appState.infoWindowId = '';
            appState.infoWindowMarkerList = [];
            appState.showAttribution = false;
            appState.showShipInfo = false;
            appState.toggleMenu(OpenMenu.none);
            appState.refreshUI();
          }),
      children: [
        // 1. Base Map Layer
        _buildTileLayer(selectedMap, context),

        // 2. Label Overlay Layer
        if (selectedMap['labels'] != '') _buildTileLayer(appState.labelTileProviders[selectedMap['labels']], context),

        // 3. Selectable Overlay Layer
        if (appState.mapOverlay && appState.overlayTileProviders.isNotEmpty)
          _buildTileLayer(appState.overlayTileProviders[appState.selectedOverlayType], context, forceRetinaFalse: true),

        // 4. Wind Particle Layer
        if (appState.showWindParticles && (appState.replayTracks['windtracks'] ?? []).isNotEmpty)
          WindParticles(
            direction: appState.windParticlesDirection + appState.mapController.camera.rotation.toInt(),
            speed: appState.windParticlesSpeed / 2,
            animate: !appState.windPaused,
            color: appState.markerBackgroundColor.withAlpha(0x60),
          ),

        // 5, 6, 7. Route, Trail, and Marker Layers
        PolylineLayer(polylines: [...appState.routeLineList, ...appState.gpsBuoyLineList, ...appState.shipTrailList]),
        if (appState.testing) PolygonLayer(polygons: appState.routePolygons),
        MarkerLayer(
          markers: [
            ...appState.routeLabelList,
            ...appState.gpsBuoyLabelList,
            ...appState.routeMarkerList,
            ...appState.gpsBuoyMarkerList,
            ...appState.gpsBuoyLineArrowList,
            ...appState.windMarkerList,
            ...appState.shipLabelList,
            ...appState.shipMarkerList,
            ...appState.infoWindowMarkerList,
          ],
        ),

        // 8. Scalebar Layer
        Scalebar(
            alignment: Alignment.topLeft,
            padding:
                EdgeInsets.fromLTRB(((appState.replayTracks['windtracks'] ?? []).isNotEmpty) ? 60 : 15, appState.menuOffset + 15, 0, 0),
            lineColor: appState.markerBackgroundColor,
            textStyle: TextStyle(color: appState.markerBackgroundColor, fontSize: 12),
            strokeWidth: 1),

        // 9. Compass Layer
        if (appState.enableMapRotation)
          MapCompass(
              icon: Icon(Icons.explore_outlined, size: 30, color: appState.markerBackgroundColor.withAlpha(177)),
              padding: EdgeInsets.fromLTRB(10, appState.menuOffset, appState.showMenuButtonBar ? 45 : 10, 10),
              hideIfRotatedNorth: true,
              onPressed: () {
                appState.mapController.rotate(0);
                if ((appState.eventStatus == EventStatus.live || appState.eventStatus == EventStatus.replay) &&
                    appState.showWindMarkers &&
                    appState.allowShowWind) {
                  appState.rotateWindTo(appState.currentReplayTime);
                }
                appState.refreshUI();
              }),
      ],
    );
  }

  // Helper method to avoid repeating the TileLayer logic
  Widget _buildTileLayer(Map<String, dynamic> providerData, BuildContext context, {bool forceRetinaFalse = false}) {
    switch (providerData['service']) {
      case "WMS":
        return TileLayer(
          wmsOptions: WMSTileLayerOptions(baseUrl: providerData['wmsbaseURL'], layers: (providerData['wmslayers'] as List).cast<String>()),
          tileProvider: NetworkTileProvider(cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance()),
          retinaMode: RetinaMode.isHighDensity(context),
          tileDisplay: const TileDisplay.instantaneous(),
          userAgentPackageName: appState.packageInfo.packageName,
        );
      case "WMTS":
        final url = providerData['URL'] as String;
        return TileLayer(
          urlTemplate: url,
          subdomains: List<String>.from(providerData['subDomains']),
          tileProvider: NetworkTileProvider(cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance()),
          retinaMode: !forceRetinaFalse && url.contains('{r}') ? RetinaMode.isHighDensity(context) : false,
          tileDisplay: const TileDisplay.instantaneous(),
          userAgentPackageName: appState.packageInfo.packageName,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
