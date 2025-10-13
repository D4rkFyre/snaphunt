// lib/services/route_transitions.dart
import 'package:flutter/material.dart';

/// Global speed knob: >1.0 = slower, <1.0 = faster.
const double kGlobalMotionScale = 0.3;

/// Base durations (pre-scale). We’ll multiply by kGlobalMotionScale at runtime.
const Duration _kSlideInBase = Duration(milliseconds: 900);
const Duration _kSlideOutBase = Duration(milliseconds: 700);

const Duration _kSlideInRightBase = Duration(milliseconds: 800);
const Duration _kSlideOutRightBase = Duration(milliseconds: 600);

const Duration _kFadeInBase = Duration(milliseconds: 1000);
const Duration _kFadeOutBase = Duration(milliseconds: 700);

/// Curves tuned for “cinematic” feel.
const Curve _kCurve = Curves.easeInOutCubic;
const Curve _kReverseCurve = Curves.easeInOutCubic;

/// Utility: scale a duration by kGlobalMotionScale
Duration _scale(Duration d) =>
    Duration(milliseconds: (d.inMilliseconds * kGlobalMotionScale).round());

/// ----------------------
/// Slide FROM TOP (down)
/// ----------------------
PageRouteBuilder<T> slideDownFromTop<T>(
    Widget page, {
      Duration? duration,
      Duration? reverseDuration,
      Curve curve = _kCurve,
      Curve reverseCurve = _kReverseCurve,
      bool withFade = false, // subtle dissolve on top of the slide
    }) {
  return PageRouteBuilder<T>(
    transitionDuration: duration ?? _scale(_kSlideInBase),
    reverseTransitionDuration: reverseDuration ?? _scale(_kSlideOutBase),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve, reverseCurve: reverseCurve);
      final slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(curved);
      Widget result = SlideTransition(position: slide, child: child);
      if (withFade) {
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
        result = FadeTransition(opacity: fade, child: result);
      }
      return result;
    },
  );
}

/// ----------------------
/// Slide FROM BOTTOM (up)
/// ----------------------
PageRouteBuilder<T> slideUpFromBottom<T>(
    Widget page, {
      Duration? duration,
      Duration? reverseDuration,
      Curve curve = _kCurve,
      Curve reverseCurve = _kReverseCurve,
      bool withFade = false,
    }) {
  return PageRouteBuilder<T>(
    transitionDuration: duration ?? _scale(_kSlideInBase),
    reverseTransitionDuration: reverseDuration ?? _scale(_kSlideOutBase),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve, reverseCurve: reverseCurve);
      final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved);
      Widget result = SlideTransition(position: slide, child: child);
      if (withFade) {
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
        result = FadeTransition(opacity: fade, child: result);
      }
      return result;
    },
  );
}

/// Alias to match earlier usage
PageRouteBuilder<T> slideUp<T>(Widget page,
    {Duration? duration, Duration? reverseDuration, Curve curve = _kCurve, Curve reverseCurve = _kReverseCurve, bool withFade = false}) =>
    slideUpFromBottom<T>(page, duration: duration, reverseDuration: reverseDuration, curve: curve, reverseCurve: reverseCurve, withFade: withFade);

/// ----------------------
/// Slide FROM RIGHT
/// ----------------------
PageRouteBuilder<T> slideFromRight<T>(
    Widget page, {
      Duration? duration,
      Duration? reverseDuration,
      Curve curve = _kCurve,
      Curve reverseCurve = _kReverseCurve,
      bool withFade = false,
    }) {
  return PageRouteBuilder<T>(
    transitionDuration: duration ?? _scale(_kSlideInRightBase),
    reverseTransitionDuration: reverseDuration ?? _scale(_kSlideOutRightBase),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve, reverseCurve: reverseCurve);
      final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved);
      Widget result = SlideTransition(position: slide, child: child);
      if (withFade) {
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
        result = FadeTransition(opacity: fade, child: result);
      }
      return result;
    },
  );
}

/// ----------------------
/// Fade IN
/// ----------------------
PageRouteBuilder<T> fadeTo<T>(
    Widget page, {
      Duration? duration,
      Duration? reverseDuration,
      Curve curve = _kCurve,
      Curve reverseCurve = _kReverseCurve,
    }) {
  return PageRouteBuilder<T>(
    transitionDuration: duration ?? _scale(_kFadeInBase),
    reverseTransitionDuration: reverseDuration ?? _scale(_kFadeOutBase),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: curve, reverseCurve: reverseCurve);
      return FadeTransition(opacity: curved, child: child);
    },
  );
}
