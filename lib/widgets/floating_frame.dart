//
// lib/floating_frame.dart
// widget to show a floating frame with a child widget
//

import 'package:flutter/material.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';

class FloatingFrame extends StatefulWidget {
  const FloatingFrame(
      {super.key,
      required this.child,
      this.offset = const Offset(40, 40),
      this.initialSize = const Size(100, 100),
      this.barColor = Colors.black,
      this.barIconColor = Colors.white,
      this.barHeight = 20,
      this.clampRect = Rect.zero,
      this.showCloseButton = true,
      this.onClose});

  final Widget child;

  /// initial top-left offset of the
  final Offset offset;

  /// initial size
  final Size initialSize;

  /// the color of the bar at the top of the frame
  final Color barColor;

  /// the color of the close and resize buttons, left and right in the bar
  final Color barIconColor;

  /// the height in pixels of the bar at the top of the frame
  final double barHeight;

  /// the rectangle the frame cannot be moved outside of, if default it is the entire screen
  final Rect clampRect;

  /// should the close button be shown
  final bool showCloseButton;

  /// called when the close button is pressed
  final Function? onClose;

  @override
  FloatingFrameState createState() => FloatingFrameState();
}

class FloatingFrameState extends State<FloatingFrame> {
  late Rect rect;
  late Size size;
  late Rect clamp;

  @override
  void initState() {
    super.initState();
    size = widget.initialSize;
    rect = widget.offset & Size(size.width, size.height + widget.barHeight);
  }

  @override
  void didUpdateWidget(FloatingFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    clamp = (widget.clampRect == Rect.zero)
        ? clamp = Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height)
        : clamp = widget.clampRect;
    return TransformableBox(
        rect: rect,
        clampingRect: clamp,
        allowContentFlipping: false,
        allowFlippingWhileResizing: false,
        constraints: BoxConstraints(minHeight: 100, minWidth: 100),
        visibleHandles: {},
        enabledHandles: {HandlePosition.topRight},
        handleAlignment: HandleAlignment.inside,
        onChanged: (result, event) => setState(() {
              Offset pos = (result.handle == HandlePosition.topRight)
                  ? Offset(result.rect.left, result.oldPosition.dy + result.delta.dy)
                  : result.position;
              rect = pos & Size((((result.rect.size.height - widget.barHeight) / 9) * 16), result.rect.size.height);
            }),
        contentBuilder: (context, rect, flip) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Container(
                    padding: EdgeInsets.zero,
                    width: rect.width,
                    height: widget.barHeight,
                    color: widget.barColor,
                    child: Row(children: [
                      if (widget.showCloseButton)
                        SizedBox(
                            height: widget.barHeight,
                            width: widget.barHeight,
                            child: IconButton(
                                mouseCursor: SystemMouseCursors.click,
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.cancel_sharp,
                                  color: widget.barIconColor,
                                  size: widget.barHeight - 4,
                                ),
                                onPressed: () => widget.onClose!())),
                      Spacer(),
                      Icon(Icons.open_in_full, color: widget.barIconColor, size: widget.barHeight - 4),
                      SizedBox(width: 2)
                    ]))),
            SizedBox(height: rect.height - widget.barHeight, child: widget.child)
          ]);
        });
  }
}
