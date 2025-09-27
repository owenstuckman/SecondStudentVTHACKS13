import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A customizable page route that supports swipe-to-go-back gestures
/// and optional app bar with Material Design styling.
class SwipePageRoute {
  /// Creates a page route with swipe gesture support and optional app bar
  ///
  /// [destination] - The widget to display as the page content
  /// [title] - Optional title for the app bar (enables app bar when provided)
  /// [showAppBar] - Force show/hide app bar regardless of title
  /// [enableSwipeBack] - Enable/disable swipe-to-go-back gesture
  /// [padding] - Optional padding for app bar elements
  /// [backgroundColor] - Custom background color for the app bar
  /// [foregroundColor] - Custom foreground color for app bar elements
  /// [elevation] - App bar elevation (shadow depth)
  /// [swipeThreshold] - Minimum velocity required to trigger swipe back
  static PageRoute<T> create<T>(
      Widget destination, {
        String? title,
        bool? showAppBar,
        bool enableSwipeBack = true,
        EdgeInsets? padding,
        Color? backgroundColor,
        Color? foregroundColor,
        double elevation = 2.0,
        double swipeThreshold = 300.0,
      }) {
    return CupertinoPageRoute<T>(
      builder: (context) => _SwipePageWrapper<T>(
        destination: destination,
        title: title,
        showAppBar: showAppBar,
        enableSwipeBack: enableSwipeBack,
        padding: padding,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: elevation,
        swipeThreshold: swipeThreshold,
      ),
    );
  }
}

/// Internal wrapper widget that handles the page structure and gestures
class _SwipePageWrapper<T> extends StatelessWidget {
  final Widget destination;
  final String? title;
  final bool? showAppBar;
  final bool enableSwipeBack;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final double swipeThreshold;

  const _SwipePageWrapper({
    required this.destination,
    this.title,
    this.showAppBar,
    this.enableSwipeBack = true,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 2.0,
    this.swipeThreshold = 300.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine if app bar should be shown
    final shouldShowAppBar = showAppBar ?? (title != null);

    // Build the main content
    Widget content = shouldShowAppBar
        ? _buildScaffoldWithAppBar(context, theme, colorScheme)
        : destination;

    // Wrap with gesture detector if swipe is enabled
    if (enableSwipeBack) {
      content = _buildSwipeGestureDetector(context, content);
    }

    return content;
  }

  /// Builds the scaffold with app bar
  Widget _buildScaffoldWithAppBar(
      BuildContext context,
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    final hasTitle = title != null && title!.isNotEmpty;
    final appBarBackgroundColor = backgroundColor ?? colorScheme.surface;
    final appBarForegroundColor = foregroundColor ?? colorScheme.onSurface;

    return Scaffold(
      extendBodyBehindAppBar: !hasTitle,
      appBar: AppBar(
        elevation: elevation,
        backgroundColor: appBarBackgroundColor,
        foregroundColor: appBarForegroundColor,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: hasTitle ? null : Colors.transparent,
        leading: _buildBackButton(context, appBarForegroundColor),
        centerTitle: true,
        title: hasTitle ? _buildTitle(context, appBarForegroundColor) : null,
        systemOverlayStyle: theme.appBarTheme.systemOverlayStyle,
      ),
      body: destination,
    );
  }

  /// Builds the back button with improved styling
  Widget _buildBackButton(BuildContext context, Color foregroundColor) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(8.0),
      child: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: foregroundColor,
          size: 24,
        ),
        tooltip: 'Back',
        splashRadius: 24,
      ),
    );
  }

  /// Builds the title text with improved styling
  Widget _buildTitle(BuildContext context, Color foregroundColor) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        title!,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 0.15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Builds the gesture detector for swipe-to-go-back
  Widget _buildSwipeGestureDetector(BuildContext context, Widget child) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > swipeThreshold) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}

/// Extension methods for easier usage
extension SwipePageRouteExtension on Widget {
  /// Converts this widget to a SwipePageRoute
  PageRoute<T> toSwipeRoute<T>({
    String? title,
    bool? showAppBar,
    bool enableSwipeBack = true,
    EdgeInsets? padding,
    Color? backgroundColor,
    Color? foregroundColor,
    double elevation = 2.0,
    double swipeThreshold = 300.0,
  }) {
    return SwipePageRoute.create<T>(
      this,
      title: title,
      showAppBar: showAppBar,
      enableSwipeBack: enableSwipeBack,
      padding: padding,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      swipeThreshold: swipeThreshold,
    );
  }
}

/// BuildContext extension for navigation operations
extension SwipePageNavigationExtension on BuildContext {
  /// Pushes a widget as a SwipePageRoute to the navigator
  Future<T?> pushSwipePage<T>(
      Widget destination, {
        String? title,
        bool? showAppBar,
        bool enableSwipeBack = true,
        EdgeInsets? padding,
        Color? backgroundColor,
        Color? foregroundColor,
        double elevation = 2.0,
        double swipeThreshold = 300.0,
      }) {
    return Navigator.of(this).push<T>(
      SwipePageRoute.create<T>(
        destination,
        title: title,
        showAppBar: showAppBar,
        enableSwipeBack: enableSwipeBack,
        padding: padding,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: elevation,
        swipeThreshold: swipeThreshold,
      ),
    );
  }

  /// Pushes and replaces the current route with a SwipePageRoute
  Future<T?> pushReplacementSwipePage<T, TO>(
      Widget destination, {
        TO? result,
        String? title,
        bool? showAppBar,
        bool enableSwipeBack = true,
        EdgeInsets? padding,
        Color? backgroundColor,
        Color? foregroundColor,
        double elevation = 2.0,
        double swipeThreshold = 300.0,
      }) {
    return Navigator.of(this).pushReplacement<T, TO>(
      SwipePageRoute.create<T>(
        destination,
        title: title,
        showAppBar: showAppBar,
        enableSwipeBack: enableSwipeBack,
        padding: padding,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: elevation,
        swipeThreshold: swipeThreshold,
      ),
      result: result,
    );
  }
}