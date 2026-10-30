import 'package:flutter/material.dart';

enum ResponsiveSize { compact, medium, expanded }

class ResponsiveBreakpoints {
  static const double compact = 600;
  static const double medium = 900;

  static ResponsiveSize fromWidth(double width) {
    if (width < compact) return ResponsiveSize.compact;
    if (width < medium) return ResponsiveSize.medium;
    return ResponsiveSize.expanded;
  }

  static ResponsiveSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static bool isCompact(BuildContext context) =>
      of(context) == ResponsiveSize.compact;

  static bool isMedium(BuildContext context) =>
      of(context) == ResponsiveSize.medium;

  static bool isExpanded(BuildContext context) =>
      of(context) == ResponsiveSize.expanded;
}

double responsivePageHorizontalPadding(double width) {
  if (width < ResponsiveBreakpoints.compact) return 16.0;
  if (width < ResponsiveBreakpoints.medium) return 24.0;
  return 40.0;
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveSize size) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) =>
      builder(context, ResponsiveBreakpoints.of(context));
}

class ResponsivePagePadding extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double? horizontalPadding;

  const ResponsivePagePadding({
    super.key,
    required this.child,
    this.maxWidth = 1440,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal =
        horizontalPadding ?? responsivePageHorizontalPadding(width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : width;
        final frameWidth = availableWidth.clamp(0.0, maxWidth).toDouble();

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: frameWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 280,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: _columns(MediaQuery.sizeOf(context).width),
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1.45,
        children: children,
      );

  int _columns(double width) {
    final available = width - 32;
    return (available / (minItemWidth + spacing)).floor().clamp(1, 6).toInt();
  }
}
