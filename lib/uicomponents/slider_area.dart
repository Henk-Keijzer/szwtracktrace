//
// Slider Area at the bottom of the screen
//
// o
// |
// | speedslider
// |
// |                                         zoomfollowbuttons o-o
// o                                                           o-o
// > ----------replayslider--------o------------------------------
// 1/1sec                  slidertext                          @ 2
//

import 'package:flutter/material.dart';

import '../main_common.dart';
import '../default_data.dart';

class SliderArea extends StatelessWidget {
  final MyAppState appState;

  const SliderArea({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return appState.mapOnly
        ? SizedBox.shrink()
        : Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const SizedBox(width: 8),
              // Only show the speed slider in replay mode
              if ((appState.eventStatus == EventStatus.replay) ||
                  (appState.eventStatus == EventStatus.live && appState.currentReplayTime != appState.sliderEnd))
                SpeedSlider(appState: appState),
              const Spacer(),
              ZoomFollowButtons(appState: appState),
              const SizedBox(width: 4),
            ]),
            // The main time slider
            ReplaySlider(appState: appState),
            // The text display for speed and time
            ReplaySliderText(appState: appState),
          ]);
  }
}

class ReplaySlider extends StatelessWidget {
  final MyAppState appState;

  const ReplaySlider({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;
    Color sliderColor = (appState.bgColor == bgDark) ? Colors.black54 : Colors.white60;
    Color thumbColor = (appState.bgColor == bgDark) ? Colors.black54 : Colors.white;

    return Container(
        color: Colors.transparent,
        child: Row(children: [
          const SizedBox(width: 3),
          IconButton(
              icon: appState.replayRunning
                  ? const Icon(Icons.pause, color: Colors.red, size: 35)
                  : const Icon(Icons.play_arrow, color: Colors.green, size: 35),
              visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
              tooltip: appState.replayRunning ? txt.str('stopReplay') : txt.str('startReplay'),
              onPressed: appState.startStopRunning // Direct method call
              ),
          Expanded(
              // and the time slider, expanding it to the rest of the row
              child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: sliderColor,
                    inactiveTrackColor: sliderColor,
                    trackShape: const RectangularSliderTrackShape(),
                    thumbColor: thumbColor,
                    showValueIndicator: ShowValueIndicator.onDrag,
                    valueIndicatorColor: appState.menuBackgroundColor.withAlpha(128),
                  ),
                  child: Slider(
                      min: appState.eventStart.toDouble(),
                      max: appState.sliderEnd.toDouble(),
                      value: (appState.currentReplayTime < appState.eventStart || appState.currentReplayTime > appState.sliderEnd)
                          ? appState.eventStart.toDouble()
                          : appState.currentReplayTime.toDouble(),
                      label: " ${appState.dtsFormat.format(DateTime.fromMillisecondsSinceEpoch(appState.currentReplayTime))} ",
                      onChangeStart: (_) {
                        appState.manualSliderMove = true;
                        appState.refreshUI();
                      },
                      onChanged: (time) {
                        appState.currentReplayTime = time.toInt();
                        appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: true);
                        appState.refreshUI();
                      },
                      onChangeEnd: (time) {
                        appState.currentReplayTime = time.toInt();
                        appState.manualSliderMove = false;
                        appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: true);
                        appState.refreshUI();
                      }))),
          const SizedBox(width: 17)
        ]));
  }
}

class ReplaySliderText extends StatelessWidget {
  final MyAppState appState;

  const ReplaySliderText({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;

    final bool isLive = (appState.currentReplayTime == appState.sliderEnd) && (appState.sliderEnd != appState.eventEnd);
    final String statusLabel = isLive ? txt.str('live') : txt.str('replay');
    final int timeToDisplay = (isLive ? appState.currentReplayTime - appState.displayDelay : appState.currentReplayTime);
    final String fullText = '$statusLabel ${appState.dtsFormat.format(DateTime.fromMillisecondsSinceEpoch(timeToDisplay))}';
    final Color textColor = (appState.bgColor == bgDark) ? Colors.black : Colors.white;

    return Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 40, 15),
        color: Colors.transparent, // set a color so that the area does not allow click-through to the map
        child: Row(children: [
          Text(
              (appState.eventStatus == EventStatus.live && appState.currentReplayTime == appState.sliderEnd)
                  ? txt.str('replaySpeed').split('|')[1]
                  : txt.str('replaySpeed').split('|')[appState.speedIndex],
              style: TextStyle(color: textColor)),
          if (appState.eventStatus != EventStatus.preEvent)
            Expanded(
                child: Text(fullText, textAlign: TextAlign.center, style: TextStyle(color: textColor), overflow: TextOverflow.ellipsis)),
          if (appState.eventStatus == EventStatus.live)
            InkWell(
                onTap: () {
                  appState.liveSecondsCounter = 0;
                  appState.refreshUI();
                },
                child: SizedBox(
                    width: 45,
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text((appState.liveSecondsCounter * appState.hfUpdateInterval / 1000).ceil().toString(),
                          textAlign: TextAlign.right, style: TextStyle(color: textColor)),
                      const SizedBox(width: 2),
                      Icon(Icons.refresh, color: textColor, size: 15),
                    ])))
        ]));
  }
}

class SpeedSlider extends StatelessWidget {
  final MyAppState appState;

  const SpeedSlider({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;
    Color sliderColor = (appState.bgColor == bgDark) ? Colors.black54 : Colors.white60;
    Color thumbColor = (appState.bgColor == bgDark) ? Colors.black54 : Colors.white;

    return Container(
        color: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
          IconButton(
              icon: Icon(Icons.speed_outlined, color: thumbColor),
              visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
              onPressed: () {
                if (appState.speedIndex < speedTable.length - 1) appState.speedIndex++;
                appState.refreshUI();
              }),
          RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: sliderColor,
                    inactiveTrackColor: sliderColor,
                    trackShape: const RectangularSliderTrackShape(),
                    thumbColor: thumbColor,
                  ),
                  child: Tooltip(
                      message: txt.str('upFasterDownSlower'),
                      child: Slider(
                          value: appState.speedIndex.toDouble(),
                          min: 0,
                          max: (speedTable.length - 1).toDouble(),
                          divisions: speedTable.length - 1,
                          onChanged: (newValue) {
                            appState.speedIndex = newValue.toInt();
                            appState.refreshUI();
                          })))),
          IconButton(
              icon: Transform.flip(flipX: true, child: Icon(Icons.speed, color: thumbColor)),
              visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
              onPressed: () {
                if (appState.speedIndex > 0) appState.speedIndex--;
                appState.refreshUI();
              }),
          const SizedBox(height: 10)
        ]));
  }
}

class ZoomFollowButtons extends StatelessWidget {
  final MyAppState appState;

  const ZoomFollowButtons({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;

    return Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (appState.autoFollow)
        Transform.scale(
          scale: 0.8,
          child: Switch(
              activeTrackColor: appState.menuBackgroundColor.withAlpha(0x7F),
              inactiveTrackColor: appState.menuForegroundColor.withAlpha(0x7F),
              trackOutlineWidth: const WidgetStatePropertyAll(0.0),
              thumbIcon: appState.autoZoom ? const WidgetStatePropertyAll(Icon(Icons.check)) : null,
              value: appState.autoZoom,
              onChanged: (value) {
                appState.autoZoom = value;
                if (value) appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: true);
                appState.refreshUI();
              }),
        ),
      if (appState.autoFollow)
        Text(txt.str('zoom'),
            style: TextStyle(fontSize: 13, height: 0.01, color: (appState.bgColor == bgDark) ? Colors.black : Colors.white)),
      const SizedBox(width: 0, height: 10),
      Transform.scale(
          scale: 0.8,
          child: Switch(
              activeTrackColor: appState.menuBackgroundColor.withAlpha(0x7F),
              inactiveTrackColor: appState.menuForegroundColor.withAlpha(0x7F),
              trackOutlineWidth: const WidgetStatePropertyAll(0),
              thumbIcon: appState.autoFollow ? const WidgetStatePropertyAll(Icon(Icons.check)) : null,
              value: appState.autoFollow,
              onChanged: (value) {
                final bool anyShipIsBeingFollowed = appState.following.values.any((v) => v);
                appState.autoFollow = anyShipIsBeingFollowed ? value : false; // Don't allow autoFollow on when no ship to follow
                if (!anyShipIsBeingFollowed) {
                  appState.toggleMenu(OpenMenu.ship); // Show shipmenu if no ships to follow
                }
                if (value) appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: true);
                appState.refreshUI();
              })),
      Text(txt.str('follow'),
          style: TextStyle(fontSize: 13, height: 0.01, color: (appState.bgColor == bgDark) ? Colors.black : Colors.white)),
      const SizedBox(width: 0, height: 10),
      if (appState.eventStatus == EventStatus.replay)
        Transform.scale(
          scale: 0.8,
          child: Switch(
              activeTrackColor: appState.menuBackgroundColor.withAlpha(0x7F),
              inactiveTrackColor: appState.menuForegroundColor.withAlpha(0x7F),
              trackOutlineWidth: const WidgetStatePropertyAll(0),
              thumbIcon: appState.replayLoop ? const WidgetStatePropertyAll(Icon(Icons.check)) : null,
              value: appState.replayLoop,
              onChanged: (value) {
                appState.replayLoop = !appState.replayLoop;
                appState.refreshUI();
              })),
      if (appState.eventStatus == EventStatus.replay)
        Text(txt.str('loop'),
          style: TextStyle(fontSize: 13, height: 0.01, color: (appState.bgColor == bgDark) ? Colors.black : Colors.white)),
      if (appState.eventStatus == EventStatus.replay)
        const SizedBox(height: 10),

    ]);
  }
}
