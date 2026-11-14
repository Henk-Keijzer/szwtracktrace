import 'package:material_ui/material_ui.dart';

import '../main_common.dart'; // To get MyAppState

class PreEventParticipantsMenu extends StatelessWidget {
  final MyAppState appState;

  const PreEventParticipantsMenu({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(
          decoration: BoxDecoration(color: appState.menuBackgroundColor, borderRadius: BorderRadius.all(Radius.circular(5))),
          width: 280,
          padding: EdgeInsets.fromLTRB(10, appState.menuOffset, 0, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(appState.shipList.isEmpty ? txt.str('participantsUnknown') : txt.str('preliminaryParticipants')),
              const Spacer(),
              IconButton(
                mouseCursor: SystemMouseCursors.click,
                padding: EdgeInsets.zero,
                visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                icon: Icon(Icons.cancel_sharp, size: 20, color: appState.menuForegroundColor),
                onPressed: () => appState.toggleMenu(OpenMenu.none),
              ),
              const SizedBox(width: 10)
            ]),
            if (appState.shipList.isNotEmpty) const Divider(endIndent: 10),
            if (appState.shipList.isNotEmpty)
              Flexible(
                  child: SingleChildScrollView(
                      child: Container(
                          padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                          child: Column(children: [
                            ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(0),
                                itemCount: appState.shipList.length,
                                itemBuilder: (_, index) {
                                  return Row(children: [
                                    Icon(Icons.square, color: appState.shipColors[index], size: 18),
                                    const SizedBox(width: 5),
                                    InkWell(
                                      mouseCursor: SystemMouseCursors.click,
                                      child: (appState.showTeam) ? Text(appState.teamList[index]) : Text(appState.shipList[index]),
                                      onTap: () => appState.loadAndShowShipDetails(appState.shipList[index], appState.eventDomain),
                                    )
                                  ]);
                                }),
                            if (appState.allowTeams)
                              Wrap(children: [
                                const Divider(),
                                Row(children: [
                                  const SizedBox(width: 20),
                                  Text(txt.str('teamInsteadOfShip')),
                                  const Spacer(),
                                  Checkbox(
                                      mouseCursor: SystemMouseCursors.click,
                                      visualDensity: const VisualDensity(
                                          horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                      activeColor: appState.menuForegroundColor,
                                      checkColor: appState.showShipLabels
                                          ? appState.menuBackgroundColor
                                          : appState.menuBackgroundColor.withAlpha(0x7F),
                                      side: BorderSide(color: appState.menuForegroundColor),
                                      value: appState.showTeam,
                                      onChanged: (_) {
                                        appState.showTeam = !appState.showTeam;
                                        if (appState.eventStatus != EventStatus.preEvent &&
                                            appState.currentReplayTime != appState.sliderEnd) {
                                          appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: false);
                                        }
                                        appState.refreshUI();
                                      })
                                ])
                              ])
                          ]))))
          ])),
      const SizedBox(width: 41)
    ]);
  }
}
