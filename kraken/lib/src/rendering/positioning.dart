import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:kraken/css.dart';

class PositionParentData extends StackParentData {
  RenderBox originalRenderBoxRef;
  int zIndex = 0;
  CSSPositionType position = CSSPositionType.static;

  /// Get element original position offset to global should be.
  Offset get stackedChildOriginalOffset {
    if (originalRenderBoxRef == null) return Offset.zero;
    return originalRenderBoxRef.localToGlobal(Offset.zero);
  }

  @override
  bool get isPositioned => top != null
      || right != null
      || bottom != null
      || left != null;

  @override
  String toString() {
    return 'zIndex=$zIndex; position=$position; originalRenderBoxRef=$originalRenderBoxRef; ${super.toString()}';
  }
}

class RenderPosition extends RenderStack {
  RenderPosition({
    this.children,
    AlignmentGeometry alignment = AlignmentDirectional.topStart,
    TextDirection textDirection = TextDirection.ltr,
    StackFit fit = StackFit.passthrough,
    Overflow overflow = Overflow.visible,
  }) : super(
            children: children,
            alignment: alignment,
            textDirection: textDirection,
            fit: fit,
            overflow: overflow);

  List<RenderBox> children;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! PositionParentData)
      child.parentData = PositionParentData();
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = Size.zero;
      return;
    }

    bool hasNonPositionedChildren = false;
    double width = constraints.minWidth;
    double height = constraints.minHeight;

    RenderBox child = firstChild;
    while (child != null) {
      final PositionParentData childParentData = child.parentData as PositionParentData;

      if (!childParentData.isPositioned) {
        // Should be in it's original position.
        hasNonPositionedChildren = true;
        child.layout(constraints.loosen(), parentUsesSize: true);

        final Size childSize = child.size;
        width = math.max(width, childSize.width);
        height = math.max(height, childSize.height);

        childParentData.offset = childParentData.stackedChildOriginalOffset;
      } else {
        // Default to no constraints. (0 - infinite)
        BoxConstraints childConstraints = const BoxConstraints();
        // if child has not width, should be calculate width by left and right
        if (childParentData.width == 0.0 && childParentData.left != null &&
          childParentData.right != null) {
          childConstraints = childConstraints.tighten(
            width: size.width - childParentData.left - childParentData.right);
        }
        // if child has not height, should be calculate height by top and bottom
        if (childParentData.height == 0.0 && childParentData.top != null &&
          childParentData.bottom != null) {
          childConstraints = childConstraints.tighten(
            height: size.height - childParentData.top - childParentData.bottom);
        }

        child.layout(childConstraints, parentUsesSize: true);

        // Calc x,y by parentData.
        double x, y;

        // Offset to global coordinate system of base
        if (childParentData.position == CSSPositionType.absolute || childParentData.position == CSSPositionType.fixed) {
          Offset baseOffset = childParentData.stackedChildOriginalOffset;
          // Use parent box offset as base.
          Offset parentOffset = localToGlobal(Offset.zero);

          double top = childParentData.top ?? baseOffset.dy;
          if (childParentData.top == null && childParentData.bottom != null)
            top = size.height - child.size.height - (childParentData.bottom ?? 0);
          double left = childParentData.left ?? baseOffset.dx;
          if (childParentData.left == null && childParentData.right != null)
            left = size.width - child.size.width - (childParentData.right ?? 0);

          x = parentOffset.dx + left;
          y = parentOffset.dy + top;
        } else if (childParentData.position == CSSPositionType.relative) {
          Offset baseOffset = (childParentData.originalRenderBoxRef.parentData as BoxParentData).offset;
          double top = childParentData.top ?? -(childParentData.bottom ?? 0);
          double left = childParentData.left ?? -(childParentData.right ?? 0);

          x = baseOffset.dx + left;
          y = baseOffset.dy + top;
        }

        childParentData.offset = Offset(x ?? 0, y ?? 0);
      }

      child = childParentData.nextSibling;
    }

    if (hasNonPositionedChildren) {
      size = Size(width, height);
    }
  }

  /// Paint and order with z-index.
  @override
  void paint(PaintingContext context, Offset offset) {
    List<RenderObject> children =  getChildrenAsList();
    children.sort((RenderObject prev, RenderObject next) {
      PositionParentData prevParentData = prev.parentData as PositionParentData;
      PositionParentData nextParentData = next.parentData as PositionParentData;
      int prevZIndex = prevParentData.zIndex ?? 0;
      int nextZIndex = nextParentData.zIndex ?? 0;
      return prevZIndex - nextZIndex;
    });

    for (var child in children) {
      final PositionParentData childParentData = child.parentData as PositionParentData;
      context.paintChild(child, childParentData.offset + offset);
      child = childParentData.nextSibling;
    }
  }
}
