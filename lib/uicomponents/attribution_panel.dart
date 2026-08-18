import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main_common.dart';
import '../default_data.dart';

class AttributionPanel extends StatelessWidget {
  final MyAppState appState;

  const AttributionPanel({super.key, required this.appState});

  Widget _buildAttributionLine(String text, String? url) {
    return GestureDetector(
      onTap: (url != null && url.isNotEmpty) ? () => launchUrl(Uri.parse(url)) : null,
      child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;

    // Prepare data needed for attributions
    final selectedBaseMap = appState.baseMapTileProviders[appState.selectedMapType];
    final selectedOverlayMap = appState.overlayTileProviders[appState.selectedOverlayType];

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [
        // The main attribution card, visibility controlled by main_common state.
        if (appState.showAttribution)
          Card(
              color: Colors.white,
              child: Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  padding: const EdgeInsets.all(10),
                  child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildAttributionLine(
                          '© 2010-${DateTime.now().year} Stichting Zeilvaart Warmond',
                          'https://www.zeilvaartwarmond.nl',
                        ),
                        if (selectedBaseMap != null)
                          _buildAttributionLine(
                              '• ${txt.plural('baseMaps', 1)}: © ${selectedBaseMap['attrib']}', selectedBaseMap['attribLink']),
                        if (appState.mapOverlay && selectedOverlayMap != null)
                          _buildAttributionLine(
                            '• ${txt.str('mapOverlay')}: © ${selectedOverlayMap['attrib']}',
                            selectedOverlayMap['attribLink'],
                          ),
                        if (appState.windMarkerList.isNotEmpty &&
                            (appState.showWindMarkers || appState.showWindParticles) &&
                            appState.allowShowWind)
                          _buildAttributionLine('• ${txt.str('windArrows')}: © buienradar.nl', 'https://www.buienradar.nl'),
                        if (appState.eventInfo['AISHub'] == 'true')
                          _buildAttributionLine('• ${txt.str('aisTrackingBy')} www.AISHub.net', 'https://www.aishub.net'),
                      ])))),
        // The button that toggles the appState.showAttribution state.
        IconButton(
            icon: (appState.showAttribution)
                ? Icon(Icons.cancel_sharp, color: (appState.bgColor == bgDark) ? Colors.black38 : Colors.white60)
                : Icon(Icons.info_outline, color: (appState.bgColor == bgDark) ? Colors.black38 : Colors.white60),
            onPressed: () {
              appState.showAttribution = !appState.showAttribution;
              appState.refreshUI();
            })
      ])
    ]);
  }
}
