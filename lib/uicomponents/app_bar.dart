import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:country_flags/country_flags.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main_common.dart'; // To get MyAppState
import '../services/helpers.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key, required this.appState});

  ///
  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;

    return AppBar(
        // Make the appbar semi-transparent if there are no menus open
        backgroundColor: appState.menuBackgroundColor.withAlpha(appState.activeMenu == OpenMenu.none ? 0x7F : 0xFF),
        foregroundColor: appState.menuForegroundColor,
        elevation: 0,
        toolbarHeight: MyAppState.appBarHeight,
        leading: InkWell(
            // App icon of the T&T organization. Single tap opens event menu, double tap enters testing mode
            child: Image.network('${appState.server}${appState.appIconUrl}'),
            onTap: () {
              appState.showAttribution = appState.showShipInfo = false;
              appState.toggleMenu(OpenMenu.event);
              appState.refreshUI();
            },
            onDoubleTap: () {
              appState.toggleTesting();
              appState.refreshUI();
            }),
        titleSpacing: 0,
        title: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: () {
              appState.showAttribution = appState.showShipInfo = false;
              appState.toggleMenu(OpenMenu.event);
              appState.refreshUI();
            },
            child: Text(
              '${appState.eventTitle == 'selectAnEvent' ? txt.str('selectAnEvent') : appState.eventTitle}'
              '${appState.activeMenu == OpenMenu.event ? ' \u25B4' : ' \u25BE'}',
              overflow: TextOverflow.ellipsis,
            )),
        actions: [
          if (appState.eventStatus == EventStatus.preEvent || appState.eventStatus == EventStatus.live) IconButton(
            onPressed: () {
              appState.unreadNotifications = false;
              appState.refreshUI();
            },
            icon: appState.unreadNotifications ?
              Badge(backgroundColor: Colors.red, smallSize: 9, child: Icon(Icons.notifications)) :
              Icon(Icons.notifications)),
          if (!appState.mapOnly && appState.supportedLanguages.length > 1)
            IconButton(
                mouseCursor: SystemMouseCursors.click,
                icon: CountryFlag.fromLanguageCode(appState.currentLanguage, theme: const ImageTheme(width: 20, height: 15)),
                onPressed: () {
                  appState.showAttribution = appState.showShipInfo = false;
                  appState.toggleMenu(OpenMenu.language);
                  appState.refreshUI();
                }),
          if (!appState.mapOnly && (kIsWeb || appState.kIsDesktop)) // Fullscreen option only in web or on a desktop app
            IconButton(
                mouseCursor: SystemMouseCursors.click,
                icon: appState.fullScreen
                    ? Icon(Icons.close_fullscreen, color: appState.menuForegroundColor, size: 18)
                    : Icon(Icons.open_in_full, color: appState.menuForegroundColor, size: 18),
                tooltip: appState.fullScreen
                    ? txt.str('exitFullScreen')
                    : (isEmbeddedInIframe() ? txt.str('openInANewTab') : txt.str('fullScreen')),
                onPressed: () {
                  appState.fullScreen = !appState.fullScreen;
                  if (kIsWeb && isEmbeddedInIframe()) {
                    launchUrl(Uri.parse(
                      '${appState.serverUrl}?event=${appState.eventDomain}&map=${appState.selectedMapType}'
                      '&overlay=${appState.mapOverlay ? 'true' : 'false'}:${appState.selectedOverlayType}'
                      '&play=${appState.replayRunning ? 'true' : 'false'}:${appState.currentReplayTime == appState.sliderEnd ? '0' : appState.currentReplayTime.toString()}:${appState.speedIndex}',
                    ));
                    if (appState.replayRunning) appState.startStopRunning(); // stop running in this screen
                  } else {
                    FullScreenWindow.setFullScreen(appState.fullScreen);
                    if ((appState.eventStatus == EventStatus.live || appState.eventStatus == EventStatus.replay) &&
                        appState.showWindMarkers &&
                        appState.allowShowWind) {
                      // Give the UI some time to settle and redraw the wind markers
                      Timer(const Duration(milliseconds: 500), () {
                        appState.rotateWindTo(appState.currentReplayTime);
                        appState.refreshUI();
                      });
                    }
                  }
                  appState.refreshUI();
                }),
          // Button to open/close the AppBar extension: uiMenuButtonBar
          IconButton(
              mouseCursor: SystemMouseCursors.click,
              icon: appState.showMenuButtonBar ? const Icon(Icons.expand_less) : const Icon(Icons.expand_more),
              onPressed: () {
                appState.showMenuButtonBar = !appState.showMenuButtonBar;
                if (!appState.showMenuButtonBar) {
                  appState.activeMenu = OpenMenu.none;
                }
                appState.refreshUI();
              })
        ]);
  }

  // This is required for PreferredSizeWidget. It tells the Scaffold in main_common how tall the AppBar is.
  @override
  Size get preferredSize => Size.fromHeight(MyAppState.appBarHeight);
}
