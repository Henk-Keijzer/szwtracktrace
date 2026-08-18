import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../main_common.dart';

class LanguageMenu extends StatelessWidget {
  final MyAppState appState;

  const LanguageMenu({super.key, required this.appState});

  void setLanguage(String newLanguage) async {
    appState.currentLanguage = newLanguage;
    appState.dtsFormat = DateFormat("${DateFormat.yMMMd(newLanguage).pattern}, HH:mm:ss", newLanguage);
    appState.activeMenu = OpenMenu.none;
    appState.refreshUI();
    await appState.txt.load(newLanguage);
    await appState.prefs.setString('language', newLanguage);
    appState.infoPageHTML = await appState.apiService.getInfoPage(newLanguage);
    appState.infoPageHTML += '<br><br>appname: ${appState.packageInfo.appName}, version ${appState.packageInfo.version}<br>'
        'package: ${appState.packageInfo.packageName}<br>server: ${appState.server}</body></html>';
    Timer(const Duration(milliseconds: 100), () {
      // rebuild map stuff to update the language inside the info windows
      appState.buildRoute();
      appState.moveShipsBuoysAndWindTo(appState.currentReplayTime, moveMap: false);
      appState.refreshUI();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SingleChildScrollView(
          child: Container(
            width: 85,
            color: appState.menuBackgroundColor,
            padding: EdgeInsets.fromLTRB(5, appState.menuOffset, 10, 10),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(0),
              itemCount: appState.supportedLanguages.length,
              itemBuilder: (_, index) {
                final languageCode = appState.supportedLanguages[index];
                return Row(
                  children: [
                    IconButton(
                      icon: CountryFlag.fromLanguageCode(languageCode, theme: ImageTheme(width: 20, height: 15)),
                      onPressed: () => setLanguage(languageCode),
                    ),
                    InkWell(
                      child: Text(languageCode, style: TextStyle(color: appState.menuForegroundColor)),
                      onTap: () => setLanguage(languageCode),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        SizedBox(width: 45),
      ],
    );
  }
}
