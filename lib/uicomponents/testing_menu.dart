import 'package:material_ui/material_ui.dart';

import '../main_common.dart';

class TestingMenu extends StatelessWidget {
  final MyAppState appState;

  const TestingMenu({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(color: appState.menuBackgroundColor, borderRadius: BorderRadius.all(Radius.circular(5))),
            width: 280,
            padding: EdgeInsets.fromLTRB(10, appState.menuOffset, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Testing'),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                      icon: Icon(Icons.cancel_sharp, size: 20, color: appState.menuForegroundColor),
                      onPressed: () => appState.toggleMenu(OpenMenu.none),
                    ),
                  ],
                ),
                const Divider(),
                Text('msg: $debugString'),
                const Divider(),
                Text('gpsBuoyLineLength: ${appState.gpsBuoyTotalLineLength} m'),
                Wrap(
                  children: [
                    const Divider(),
                    Row(
                      children: [
                        const Text('Move ships and wind particles\nwhile not in focus'),
                        const Spacer(),
                        Checkbox(
                            visualDensity:
                                const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                            activeColor: appState.menuForegroundColor,
                            checkColor: appState.menuBackgroundColor,
                            side: BorderSide(color: appState.menuForegroundColor),
                            value: appState.moveWhileNotInFocus,
                            onChanged: (_) {
                              appState.moveWhileNotInFocus = !appState.moveWhileNotInFocus;
                              appState.refreshUI();
                            }),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  children: [
                    const Divider(),
                    Row(
                      children: [
                        const Text('Show fences in route'),
                        const Spacer(),
                        Checkbox(
                            visualDensity:
                                const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                            activeColor: appState.menuForegroundColor,
                            checkColor: appState.menuBackgroundColor,
                            side: BorderSide(color: appState.menuForegroundColor),
                            value: appState.showRouteFences,
                            onChanged: (_) {
                              appState.showRouteFences = !appState.showRouteFences;
                              appState.buildRoute();
                              appState.refreshUI();
                            }),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  children: [
                    const Divider(),
                    Row(
                      children: [
                        const Text('Map Only'),
                        const Spacer(),
                        Checkbox(
                            visualDensity:
                                const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                            activeColor: appState.menuForegroundColor,
                            checkColor: appState.menuBackgroundColor,
                            side: BorderSide(color: appState.menuForegroundColor),
                            value: appState.mapOnly,
                            onChanged: (_) {
                              appState.mapOnly = !appState.mapOnly;
                              appState.currentReplayTime = appState.sliderEnd;
                              appState.showMenuButtonBar = !appState.mapOnly;
                              appState.toggleMenu(OpenMenu.testing);
                              appState.buildRoute();
                              appState.refreshUI();
                            }),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Text('displayDelay: ${appState.displayDelay / 1000} sec'),
                Text('predictTime: ${appState.predictTime / 1000} sec'),
                Text('signalLostTime: ${appState.signalLostTime / 1000} sec'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 41),
      ],
    );
  }
}
