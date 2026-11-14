import 'package:material_ui/material_ui.dart';
import 'package:flutter_html/flutter_html.dart' show Html, Style;
import 'package:url_launcher/url_launcher.dart';

import '../main_common.dart';

class InfoPage extends StatelessWidget {
  final MyAppState appState;

  const InfoPage({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      SingleChildScrollView(
          child: GestureDetector(
              // Tap anywhere on the page to close it
              onTap: () => appState.toggleMenu(OpenMenu.none),
              child: Container(
                  width: (screenWidth > 750) ? 750 - 45 : screenWidth - 45,
                  color: Color(int.parse(appState.config['colors']['infoPageColor'] ?? 'FFFFFFFF', radix: 16)),
                  padding: EdgeInsets.fromLTRB(20, appState.menuOffset + 20, 20, 20),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      IconButton(
                          padding: EdgeInsets.zero,
                          visualDensity:
                              const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                          icon: Icon(Icons.cancel_sharp, size: 20, color: appState.menuBackgroundColor),
                          onPressed: () {
                            appState.toggleMenu(OpenMenu.none);
                            appState.refreshUI();
                          })
                    ]),
                    Html(
                        data: appState.infoPageHTML,
                        style: {'a:link': Style(color: Colors.blue[800], textDecorationColor: Colors.blue[800])},
                        onLinkTap: (link, _, __) {
                          if (link != null) launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                        })
                  ])))),
      const SizedBox(width: 41)
    ]);
  }
}
