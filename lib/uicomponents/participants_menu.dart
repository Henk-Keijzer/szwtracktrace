import 'package:flutter/material.dart';

import '../main_common.dart';
import 'trail_length_slider.dart';

class ParticipantsMenu extends StatelessWidget {
  final MyAppState appState;

  const ParticipantsMenu({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;

    // Prepare the signal lost time text
    final duration = Duration(milliseconds: appState.signalLostTime);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final parts = <String>[];
    if (minutes > 0) parts.add('$minutes ${txt.plural('minutes', minutes)}');
    if (seconds > 0) parts.add('$seconds ${txt.plural('seconds', seconds)}');
    final signalLostTimeText = parts.join(' ${txt.str('and')} ');

    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(
          width: 280,
          color: appState.menuBackgroundColor,
          padding: EdgeInsets.fromLTRB(10, appState.menuOffset, 0, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(txt.str('participants')),
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
            const Divider(endIndent: 10),
            Row(children: [
              const SizedBox(width: 5),
              Text(txt.str('followAll')),
              const Spacer(),
              Checkbox(
                  mouseCursor: SystemMouseCursors.click,
                  visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                  activeColor: appState.menuForegroundColor,
                  checkColor: appState.menuBackgroundColor,
                  side: BorderSide(color: appState.menuForegroundColor),
                  value: appState.followAll,
                  onChanged: (value) {
                    appState.following.forEach((k, v) => appState.following[k] = value!);
                    appState.followAll = value!;
                    appState.autoZoom = appState.autoFollow = value;
                    appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: true);
                    appState.refreshUI();
                  }),
              const SizedBox(width: 10)
            ]),
            const Divider(endIndent: 10),
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
                                    child: (appState.showTeam)
                                        ? Text('${appState.teamList[index]}${appState.shipLostSignalIndicators[index]}')
                                        : Text('${appState.shipList[index]}${appState.shipLostSignalIndicators[index]}'),
                                    onTap: () => appState.loadAndShowShipDetails(appState.shipList[index], appState.eventDomain),
                                  ),
                                  const Spacer(),
                                  ((appState.replayTracks['shiptracks'][index]['stamp'] ?? []).isNotEmpty)
                                      ? Checkbox(
                                          mouseCursor: SystemMouseCursors.click,
                                          visualDensity: const VisualDensity(
                                              horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                          activeColor: appState.menuForegroundColor,
                                          checkColor: appState.menuBackgroundColor,
                                          side: BorderSide(color: appState.menuForegroundColor),
                                          value: appState.following[appState.shipList[index]] ?? false,
                                          onChanged: (value) {
                                            appState.following[appState.shipList[index]] = value!;
                                            if (value) appState.autoFollow = appState.autoZoom = value;
                                            if (!value) appState.followAll = false;
                                            if (value && appState.showShipInfo) {
                                              appState.loadAndShowShipDetails(appState.shipList[index], appState.eventDomain);
                                            }
                                            appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: true);
                                            appState.refreshUI();
                                          })
                                      : Icon(Icons.close, color: appState.menuForegroundColor)
                                ]);
                              }),
                          if ((appState.replayTracks['shiptracks'] ?? []).isNotEmpty)
                            Wrap(children: [
                              const Divider(),
                              Row(children: [
                                const SizedBox(width: 5),
                                Text(txt.str('shipNamesOnTheMap')),
                                const Spacer(),
                                Checkbox(
                                    mouseCursor: SystemMouseCursors.click,
                                    visualDensity: const VisualDensity(
                                        horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                    activeColor: appState.menuForegroundColor,
                                    checkColor: appState.menuBackgroundColor,
                                    side: BorderSide(color: appState.menuForegroundColor),
                                    value: appState.showShipLabels,
                                    onChanged: (_) {
                                      appState.showShipLabels = !appState.showShipLabels;
                                      appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: false);
                                      appState.prefs.setBool('shiplabels', appState.showShipLabels);
                                      appState.refreshUI();
                                    })
                              ]),
                              if (appState.allowShowSpeed)
                                Row(children: [
                                  const SizedBox(width: 20),
                                  Text(txt.str('withSpeeds')),
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
                                      value: appState.showShipSpeeds,
                                      onChanged: (_) {
                                        appState.showShipSpeeds = !appState.showShipSpeeds;
                                        appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: false);
                                        appState.prefs.setBool('shipspeeds', appState.showShipSpeeds);
                                        appState.refreshUI();
                                      })
                                ]),
                              if (appState.allowTeams)
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
                                        appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: false);
                                        appState.refreshUI();
                                      })
                                ])
                            ]),
                          const Divider(),
                          Row(children: [
                            const SizedBox(width: 5),
                            Expanded(child: Text("${txt.str('quoteBehindName')} $signalLostTimeText"))
                          ]),
                          const Divider(),
                          TrailLengthSlider(appState: appState),
                        ]))))
          ])),
      const SizedBox(width: 41)
    ]);
  }
}
