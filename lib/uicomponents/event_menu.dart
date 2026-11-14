import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main_common.dart';

class EventMenu extends StatelessWidget {
  final MyAppState appState;

  const EventMenu({super.key, required this.appState});

  String _buildSelectionMessage(dynamic txt) {
    switch (appState.eventStatus) {
      case EventStatus.preEvent:
        Duration difference = DateTime.fromMillisecondsSinceEpoch(appState.eventStart).difference(DateTime.now());
        return '${txt.param('notYetStarted', {
              'startDateTime': appState.dtFormat.format(DateTime.fromMillisecondsSinceEpoch(appState.eventStart))
            })}\n'
            '(${difference.inDays} ${txt.plural('days', difference.inDays)}, '
            '${difference.inHours.remainder(24)} ${txt.plural('hours', difference.inHours.remainder(24))}, '
            '${difference.inMinutes.remainder(60)} ${txt.plural('minutes', difference.inMinutes.remainder(60))} '
            '${txt.str('and')} '
            '${difference.inSeconds.remainder(60)} ${txt.plural('seconds', difference.inSeconds.remainder(60))})';
      case EventStatus.live:
        return appState.shipList.isNotEmpty
            ? txt.param('tracksAreLoadedLive', {'trailsUpdateInterval': '${appState.trailsUpdateInterval ~/ 1000}'})
            : txt.str('eventIsLive');
      case EventStatus.replay:
        if (appState.eventStart == appState.eventEnd) return '';
        return appState.shipList.isNotEmpty ? txt.str('tracksAreLoadedReplay') : txt.str('eventIsOver');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = appState.txt;
    final selectionMessage = _buildSelectionMessage(txt);

    return Container(
        decoration:
        BoxDecoration(color: appState.menuBackgroundColor, borderRadius: BorderRadius.all(Radius.circular(5))),
        width: 280,
        padding: EdgeInsets.fromLTRB(10, appState.menuOffset, 0, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text(txt.str('races'))),
            IconButton(
              padding: EdgeInsets.zero,
              visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
              icon: Icon(Icons.cancel_sharp, size: 20, color: appState.menuForegroundColor),
              onPressed: () => appState.toggleMenu(OpenMenu.none),
            ),
            const SizedBox(width: 10)
          ]),
          const Divider(endIndent: 10),
          Flexible(
              child: SingleChildScrollView(
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
                      child: Column(children: [
                        // 1. First Dropdown (Event Name)
                        _CustomDropdownMenu(
                          buttonKey: appState.dropEventKey,
                          items: appState.eventNameList,
                          currentValue: appState.eventName,
                          displayText: appState.eventName == 'selectAnEvent' ? txt.str('selectAnEvent') : appState.eventName,
                          foregroundColor: appState.menuForegroundColor,
                          onSelected: appState.selectEventYear,
                        ),

                        // 2. Second Dropdown (Event Year)
                        if (appState.eventYear != '')
                          _CustomDropdownMenu(
                            buttonKey: appState.dropYearKey,
                            items: appState.eventYearList,
                            currentValue: appState.eventYear,
                            displayText: appState.eventYear,
                            foregroundColor: appState.menuForegroundColor,
                            onSelected: appState.selectEventDay,
                          ),

                        // 3. Third Dropdown (Event Day/Race)
                        if (appState.eventDay != '')
                          _CustomDropdownMenu(
                            buttonKey: appState.dropDayKey,
                            items: appState.eventDayList,
                            currentValue: appState.eventDay,
                            displayText: appState.eventDay,
                            foregroundColor: appState.menuForegroundColor,
                            onSelected: appState.newEventSelected,
                          ),
                        if (selectionMessage != '') Wrap(children: [const Divider(), Text(selectionMessage)]),
                        if (appState.eventDomain.isNotEmpty)
                          Wrap(children: [
                            const Divider(),
                            Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                                child: InkWell(
                                    mouseCursor: SystemMouseCursors.click,
                                    onTap: () {
                                      if (appState.socialMediaUrl != '') {
                                        launchUrl(Uri.parse(appState.socialMediaUrl), mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Image.network('${appState.server}data/${appState.eventDomain}/logo.png'))),
                            Text((appState.socialMediaUrl == '') ? '' : txt.str('clickLogo')),
                          ]),
                        if (appState.kIsWebOnAndroid && ((appState.config['options']['playstorelink'] ?? '') != ''))
                          Wrap(children: [
                            const Divider(),
                            Text(txt.str('mobAppAndroid')),
                            Container(
                                alignment: Alignment.center,
                                child: InkWell(
                                  mouseCursor: SystemMouseCursors.click,
                                  child: Image.asset('assets/images/googleplaystoreicon.png', width: 150),
                                  onTap: () => launchUrl(Uri.parse(appState.config['options']['playstorelink']),
                                      mode: LaunchMode.externalApplication),
                                ))
                          ]),
                        if (appState.kIsWebOnIOS && ((appState.config['options']['applestorelink'] ?? '') != ''))
                          Wrap(children: [
                            const Divider(),
                            Text(txt.str('mobAppiOS')),
                            Container(
                                alignment: Alignment.center,
                                child: InkWell(
                                  mouseCursor: SystemMouseCursors.click,
                                  child: Image.asset('assets/images/appleappstoreicon.png', width: 150),
                                  onTap: () => launchUrl(Uri.parse(appState.config['options']['applestorelink']),
                                      mode: LaunchMode.externalApplication),
                                ))
                          ])
                      ]))))
        ]));
  }
}

class _CustomDropdownMenu extends StatelessWidget {
  final GlobalKey buttonKey;
  final List<String> items;
  final String currentValue;
  final String displayText;
  final Color foregroundColor;
  final Function(String) onSelected;

  const _CustomDropdownMenu({
    required this.buttonKey,
    required this.items,
    required this.currentValue,
    required this.displayText,
    required this.foregroundColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
        key: buttonKey,
        tooltip: '',
        offset: const Offset(15, 35),
        itemBuilder: (_) => items
            .map((item) => PopupMenuItem(
                  height: 25,
                  value: item,
                  child: Text(item, style: TextStyle(fontWeight: (item == currentValue) ? FontWeight.bold : FontWeight.normal)),
                ))
            .toList(),
        onSelected: onSelected,
        child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(children: [
              Expanded(
                  child: Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 0, 5),
                child: Text(displayText),
              )),
              Icon(Icons.arrow_drop_down, size: 20, color: foregroundColor),
            ])));
  }
}
