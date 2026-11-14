import 'package:material_ui/material_ui.dart';

class AnimatedMenu extends StatelessWidget {
  const AnimatedMenu({super.key, required this.isVisible, required this.child});

  /// should the menu be visible
  final bool isVisible;

  /// the widget to show, i.e. the menu
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, -1.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: isVisible ? child : const SizedBox.shrink());
  }
}
