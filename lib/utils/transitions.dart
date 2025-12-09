import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// Global page transitions using Material Motion patterns.
/// Provides builders for Theme.pageTransitionsTheme and helpers for route pushes.

class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder({this.curve = Curves.easeInOutCubic});

  final Curve curve;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: curve);
    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: curve,
    );
    return FadeThroughTransition(
      animation: curved,
      secondaryAnimation: secondaryCurved,
      child: child,
    );
  }
}

class SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisPageTransitionsBuilder({
    required this.type,
    this.curve = Curves.easeInOutCubic,
  });

  final SharedAxisTransitionType type;
  final Curve curve;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: curve);
    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: curve,
    );
    return SharedAxisTransition(
      animation: curved,
      secondaryAnimation: secondaryCurved,
      transitionType: type,
      child: child,
    );
  }
}

/// Route helper: Shared Axis
PageRoute<T> sharedAxisRoute<T>({
  required WidgetBuilder builder,
  SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
  Duration duration = const Duration(milliseconds: 220),
  Duration reverseDuration = const Duration(milliseconds: 180),
  Curve curve = Curves.easeInOutCubic,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve);
      final secondaryCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: curve,
      );
      return SharedAxisTransition(
        transitionType: type,
        animation: curved,
        secondaryAnimation: secondaryCurved,
        child: child,
      );
    },
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
  );
}

/// Route helper: Fade Through
PageRoute<T> fadeThroughRoute<T>({
  required WidgetBuilder builder,
  Duration duration = const Duration(milliseconds: 220),
  Duration reverseDuration = const Duration(milliseconds: 180),
  Curve curve = Curves.easeInOutCubic,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve);
      final secondaryCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: curve,
      );
      return FadeThroughTransition(
        animation: curved,
        secondaryAnimation: secondaryCurved,
        child: child,
      );
    },
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
  );
}