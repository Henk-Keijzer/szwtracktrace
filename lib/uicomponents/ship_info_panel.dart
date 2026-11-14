import 'package:material_ui/material_ui.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main_common.dart';

class ShipInfoPanel extends StatefulWidget {
  final MyAppState appState;

  const ShipInfoPanel({super.key, required this.appState});

  @override
  State<ShipInfoPanel> createState() => _ShipInfoPanelState();
}

class _ShipInfoPanelState extends State<ShipInfoPanel> {
  late Offset position;
  late Offset positionAtDragStart;

  @override
  void initState() {
    super.initState();
    position = widget.appState.shipInfoPosition;
    positionAtDragStart = Offset.zero;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return Positioned(
        left: position.dx,
        top: position.dy,
        child: GestureDetector(
            onPanStart: (details) => setState(() => positionAtDragStart = position - details.localPosition),
            onPanUpdate: (details) => setState(() => position = positionAtDragStart + details.localPosition),
            onTap: () {
              appState.showShipInfo = false;
              appState.refreshUI();
            },
            child: Container(
                constraints: BoxConstraints(
                    minHeight: 100, maxHeight: 500, maxWidth: appState.screenWidth - 55 < 350 ? appState.screenWidth - 55 : 350),
                decoration:
                    BoxDecoration(color: appState.menuBackgroundColor, borderRadius: BorderRadius.all(Radius.circular(5))),
                padding: const EdgeInsets.all(10),
                child: Stack(children: [
                  SingleChildScrollView(
                      child: Html(
                          data: appState.shipInfoHTML.replaceFirst('Schipper:', '${appState.txt.str('skipper')}:'),
                          style: {'a:link': Style(color: Colors.white, textDecorationColor: Colors.white)},
                          onLinkTap: (link, _, __) {
                            if (link != null) {
                              launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                            }
                          })),
                  MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(Icons.cancel_sharp, size: 20, color: appState.menuForegroundColor),
                        )
                      ]))
                ]))));
  }
}
