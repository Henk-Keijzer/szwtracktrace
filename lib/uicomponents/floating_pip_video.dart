import 'package:material_ui/material_ui.dart';
import 'package:szwtracktrace/widgets/video_player_widget.dart';

import '../main_common.dart';
import '../widgets/floating_frame.dart';

class FloatingPipVideo extends StatelessWidget {
  final MyAppState appState;

  const FloatingPipVideo({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return FloatingFrame(
      offset: Offset(45, appState.screenHeight - 70 - (300 / 16) * 9 - 25), // 300 is the initialWidth
      initialSize: Size(300, 300 * 9 / 16),
      clampRect: Rect.fromLTWH(0, appState.menuOffset, appState.screenWidth, appState.screenHeight - appState.menuOffset),
      barColor: appState.menuBackgroundColor,
      barIconColor: appState.menuForegroundColor,
      showCloseButton: true,
      onClose: () {
        appState.showVideo = false;
        appState.refreshUI();
      },
      child:
          VideoPlayerWidget(videoIdList: appState.videoIdList, index: appState.videoIndex, onClose: (index) => appState.videoIndex = index),
    );
  }
}
