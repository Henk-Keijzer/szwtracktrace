import 'package:material_ui/material_ui.dart';

import '../main_common.dart';

class CookieConsentBanner extends StatelessWidget {
  final MyAppState appState;

  const CookieConsentBanner({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;

    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(
          color: appState.menuBackgroundColor,
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Expanded(child: Text(txt.str('consentMsg'))),
            Container(
                padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                child: Center(
                    child: ElevatedButton(
                  onPressed: () {
                    appState.cookieConsentGiven = true;
                    appState.prefs.setBool('cookieconsent', true);
                    appState.refreshUI();
                  },
                  child: Text(txt.str('agree')),
                )))
          ]))
    ]);
  }
}
