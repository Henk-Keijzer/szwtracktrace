import 'package:flutter/material.dart';

import '../main_common.dart';

class TrailLengthSlider extends StatelessWidget {
  final MyAppState appState;

  const TrailLengthSlider({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;

    // Prepare the trail length text (logic moved from participants_menu.dart)
    final hrs = appState.trailLength ~/ 60;
    final mins = appState.trailLength % 60;
    String trailLengthText = txt.param('trailLengthMessage', {'selected': appState.followAll ? '' : txt.str('selected')});
    if (appState.trailLength == 0) {
      trailLengthText += ' 0 ${txt.plural('minutes', mins)}';
    } else {
      if (hrs > 0) trailLengthText += ' $hrs ${txt.plural('hours', hrs)}';
      if (hrs > 0 && mins > 0) trailLengthText += ' ${txt.str('and')}';
      if (mins > 0) trailLengthText += ' $mins ${txt.plural('minutes', mins)}';
    }

    return appState.sliderEnd == 0
        ? SizedBox.shrink()
        : Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(5, 0, 2, 0),
              height: 50,
              child: Text(trailLengthText),
            ),
            if (appState.allowMaxTrailLengths)
              Column(children: [
                const SizedBox(height: 5),
                SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: Colors.white60,
                      inactiveTrackColor: Colors.white60,
                      trackShape: const RectangularSliderTrackShape(),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                        min: 0.0, //appState.eventTrailLength.toDouble(),
                        max: ((appState.sliderEnd - appState.eventStart) / 60000).toDouble(),
                        value: appState.trailLength
                            .toDouble()
                            .clamp(0, ((appState.sliderEnd - appState.eventStart) / 60000).toDouble()),
                        onChanged: (val) {
                          appState.trailLength = val.round();
                          appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: false);
                        }))
              ])
          ]);
  }
}
