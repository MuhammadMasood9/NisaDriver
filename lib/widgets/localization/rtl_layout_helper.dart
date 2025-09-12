import 'package:flutter/material.dart';
import '../../utils/language_utils.dart';

/// A helper widget that automatically adjusts layout for RTL languages
class RTLLayoutHelper extends StatelessWidget {
  final Widget child;
  final bool forceDirection;
  final TextDirection? textDirection;

  const RTLLayoutHelper({
    super.key,
    required this.child,
    this.forceDirection = false,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    if (!forceDirection && !LanguageUtils.isCurrentLanguageRTL()) {
      return child;
    }

    final direction = textDirection ?? 
        LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage());

    return Directionality(
      textDirection: direction,
      child: child,
    );
  }
}

/// A Row widget that automatically adjusts for RTL languages
class RTLRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  const RTLRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
  });

  @override
  Widget build(BuildContext context) {
    final direction = textDirection ?? 
        LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage());

    // Adjust main axis alignment for RTL
    MainAxisAlignment adjustedAlignment = mainAxisAlignment;
    if (direction == TextDirection.rtl) {
      switch (mainAxisAlignment) {
        case MainAxisAlignment.start:
          adjustedAlignment = MainAxisAlignment.end;
          break;
        case MainAxisAlignment.end:
          adjustedAlignment = MainAxisAlignment.start;
          break;
        default:
          adjustedAlignment = mainAxisAlignment;
      }
    }

    return Directionality(
      textDirection: direction,
      child: Row(
        mainAxisAlignment: adjustedAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        textDirection: direction,
        verticalDirection: verticalDirection,
        textBaseline: textBaseline,
        children: children,
      ),
    );
  }
}

/// A Padding widget that automatically adjusts for RTL languages
class RTLPadding extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const RTLPadding({
    super.key,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry adjustedPadding = padding;
    
    if (LanguageUtils.isCurrentLanguageRTL()) {
      // Flip horizontal padding for RTL
      if (padding is EdgeInsets) {
        final edgeInsets = padding as EdgeInsets;
        adjustedPadding = EdgeInsets.only(
          top: edgeInsets.top,
          bottom: edgeInsets.bottom,
          left: edgeInsets.right,
          right: edgeInsets.left,
        );
      }
    }

    return Padding(
      padding: adjustedPadding,
      child: child,
    );
  }
}

/// A Container widget that automatically adjusts alignment for RTL languages
class RTLContainer extends StatelessWidget {
  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Decoration? decoration;
  final Decoration? foregroundDecoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;

  const RTLContainer({
    super.key,
    this.child,
    this.alignment,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    AlignmentGeometry? adjustedAlignment = alignment;
    
    if (LanguageUtils.isCurrentLanguageRTL() && alignment != null) {
      // Flip alignment for RTL
      if (alignment == Alignment.centerLeft) {
        adjustedAlignment = Alignment.centerRight;
      } else if (alignment == Alignment.centerRight) {
        adjustedAlignment = Alignment.centerLeft;
      } else if (alignment == Alignment.topLeft) {
        adjustedAlignment = Alignment.topRight;
      } else if (alignment == Alignment.topRight) {
        adjustedAlignment = Alignment.topLeft;
      } else if (alignment == Alignment.bottomLeft) {
        adjustedAlignment = Alignment.bottomRight;
      } else if (alignment == Alignment.bottomRight) {
        adjustedAlignment = Alignment.bottomLeft;
      }
    }

    EdgeInsetsGeometry? adjustedPadding = padding;
    EdgeInsetsGeometry? adjustedMargin = margin;
    
    if (LanguageUtils.isCurrentLanguageRTL()) {
      // Flip horizontal padding for RTL
      if (padding is EdgeInsets) {
        final edgeInsets = padding as EdgeInsets;
        adjustedPadding = EdgeInsets.only(
          top: edgeInsets.top,
          bottom: edgeInsets.bottom,
          left: edgeInsets.right,
          right: edgeInsets.left,
        );
      }
      
      // Flip horizontal margin for RTL
      if (margin is EdgeInsets) {
        final edgeInsets = margin as EdgeInsets;
        adjustedMargin = EdgeInsets.only(
          top: edgeInsets.top,
          bottom: edgeInsets.bottom,
          left: edgeInsets.right,
          right: edgeInsets.left,
        );
      }
    }

    return Container(
      alignment: adjustedAlignment,
      padding: adjustedPadding,
      margin: adjustedMargin,
      color: color,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
      width: width,
      height: height,
      constraints: constraints,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// A ListTile widget that automatically adjusts for RTL languages
class RTLListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool isThreeLine;
  final bool? dense;
  final VisualDensity? visualDensity;
  final ShapeBorder? shape;
  final ListTileStyle? style;
  final Color? selectedColor;
  final Color? iconColor;
  final Color? textColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool enabled;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final MouseCursor? mouseCursor;
  final bool selected;
  final Color? focusColor;
  final Color? hoverColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? tileColor;
  final Color? selectedTileColor;
  final bool? enableFeedback;
  final double? horizontalTitleGap;
  final double? minVerticalPadding;
  final double? minLeadingWidth;

  const RTLListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.isThreeLine = false,
    this.dense,
    this.visualDensity,
    this.shape,
    this.style,
    this.selectedColor,
    this.iconColor,
    this.textColor,
    this.contentPadding,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    this.mouseCursor,
    this.selected = false,
    this.focusColor,
    this.hoverColor,
    this.focusNode,
    this.autofocus = false,
    this.tileColor,
    this.selectedTileColor,
    this.enableFeedback,
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.minLeadingWidth,
  });

  @override
  Widget build(BuildContext context) {
    Widget? adjustedLeading = leading;
    Widget? adjustedTrailing = trailing;
    
    // Swap leading and trailing for RTL
    if (LanguageUtils.isCurrentLanguageRTL()) {
      adjustedLeading = trailing;
      adjustedTrailing = leading;
    }

    return ListTile(
      leading: adjustedLeading,
      title: title,
      subtitle: subtitle,
      trailing: adjustedTrailing,
      isThreeLine: isThreeLine,
      dense: dense,
      visualDensity: visualDensity,
      shape: shape,
      style: style,
      selectedColor: selectedColor,
      iconColor: iconColor,
      textColor: textColor,
      contentPadding: contentPadding,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
      mouseCursor: mouseCursor,
      selected: selected,
      focusColor: focusColor,
      hoverColor: hoverColor,
      focusNode: focusNode,
      autofocus: autofocus,
      tileColor: tileColor,
      selectedTileColor: selectedTileColor,
      enableFeedback: enableFeedback,
      horizontalTitleGap: horizontalTitleGap,
      minVerticalPadding: minVerticalPadding,
      minLeadingWidth: minLeadingWidth,
    );
  }
}