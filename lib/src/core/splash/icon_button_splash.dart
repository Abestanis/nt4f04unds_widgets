/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*
*  Copyright (c) The Chromium Authors.
*  See ThirdPartyNotices.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import 'dart:math' as math;
import 'package:flutter/material.dart';

const Duration _kUnconfirmedRippleDuration = Duration(milliseconds: 275);
const Duration _kFadeInDuration = Duration(milliseconds: 120);
const Duration _kRadiusDuration = Duration(milliseconds: 225);
const Duration _kFadeOutDuration = Duration(milliseconds: 475);
const Duration _kCancelDuration = Duration(milliseconds: 250);

/// The fade out start interval, when the cancel wasn't called.
const double _kFadeOutIntervalStart = 0.7;

double _getTargetRadius(RenderBox referenceBox, bool containedInkWell,
    RectCallback? rectCallback, Offset position) {
  final Size size =
      rectCallback != null ? rectCallback().size : referenceBox.size;
  final double d1 = size.bottomRight(Offset.zero).distance;
  final double d2 =
      (size.topRight(Offset.zero) - size.bottomLeft(Offset.zero)).distance;
  return math.max(d1, d2) / 2.0;
}

class _NFIconButtonInkRippleFactory extends InteractiveInkFeatureFactory {
  const _NFIconButtonInkRippleFactory({this.radius});

  final double? radius;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return NFIconButtonInkRipple(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: this.radius ?? radius,
      onRemoved: onRemoved,
      textDirection: textDirection,
    );
  }
}

/// A visual reaction on a piece of [Material] to user input.
///
/// A circular ink feature whose origin starts at the input touch point and
/// whose radius expands from 60% of the final radius. The splash origin
/// animates to the center of its [referenceBox].
///
/// This object is rarely created directly. Instead of creating an ink ripple,
/// consider using an [InkResponse] or [InkWell] widget, which uses
/// gestures (such as tap and long-press) to trigger ink splashes. This class
/// is used when the [Theme]'s [ThemeData.splashFactory] is [InkRipple.splashFactory].
///
/// See also:
///
///  * [InkSplash], which is an ink splash feature that expands less
///    aggressively than the ripple.
///  * [InkResponse], which uses gestures to trigger ink highlights and ink
///    splashes in the parent [Material].
///  * [InkWell], which is a rectangular [InkResponse] (the most common type of
///    ink response).
///  * [Material], which is the widget on which the ink splash is painted.
///  * [InkHighlight], which is an ink feature that emphasizes a part of a
///    [Material].
class NFIconButtonInkRipple extends InteractiveInkFeature {
  /// Begin a ripple, centered at [position] relative to [referenceBox].
  ///
  /// The [controller] argument is typically obtained via
  /// `Material.of(context)`.
  ///
  /// If [containedInkWell] is true, then the ripple will be sized to fit
  /// the well rectangle, then clipped to it when drawn. The well
  /// rectangle is the box returned by [rectCallback], if provided, or
  /// otherwise is the bounds of the [referenceBox].
  ///
  /// If [containedInkWell] is false, then [rectCallback] should be null.
  /// The ink ripple is clipped only to the edges of the [Material].
  /// This is the default.
  ///
  /// When the ripple is removed, [onRemoved] will be called.
  NFIconButtonInkRipple({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  })  : _position = position,
        _targetRadius = radius ??
            _getTargetRadius(
                referenceBox, containedInkWell, rectCallback, position),
        super(
            controller: controller,
            referenceBox: referenceBox,
            color: color,
            onRemoved: onRemoved) {
    // Immediately begin fading-in the initial splash.
    _fadeInController =
        AnimationController(duration: _kFadeInDuration, vsync: controller.vsync)
          ..addListener(controller.markNeedsPaint)
          ..forward();
    _fadeIn = _fadeInController.drive(Tween(
      begin: 0,
      end: color.a,
    ));

    // Controls the splash radius and its center. Starts upon confirm.
    _radiusController = AnimationController(
        duration: _kUnconfirmedRippleDuration, vsync: controller.vsync)
      ..addListener(controller.markNeedsPaint)
      ..forward();
    // Initial splash diameter is 60% of the target diameter, final
    // diameter is 10dps larger than the target diameter.
    _radius = _radiusController.drive(
      Tween<double>(
        begin: _targetRadius * 0.30,
        end: _targetRadius,
      ).chain(_easeCurveTween),
    );

    // Controls the splash radius and its center. Starts upon confirm however its
    // Interval delays changes until the radius expansion has completed.
    _fadeOutController = AnimationController(
        duration: _kFadeOutDuration, vsync: controller.vsync)
      ..addListener(controller.markNeedsPaint)
      ..addStatusListener(_handleAlphaStatusChanged);

    controller.addInkFeature(this);
  }

  final Offset _position;
  final double _targetRadius;

  bool isCancelled = false;

  late Animation<double> _radius;
  late AnimationController _radiusController;

  late Animation<double> _fadeIn;
  late AnimationController _fadeInController;

  late AnimationController _fadeOutController;

  /// Used to specify this type of ink splash for an [InkWell], [InkResponse]
  /// or material [Theme].
  static InteractiveInkFeatureFactory splashFactory({double? radius}) {
    return _NFIconButtonInkRippleFactory(radius: radius);
  }

  static final Animatable<double> _easeCurveTween =
      CurveTween(curve: Curves.ease);
  static final Animatable<double> _fadeOutIntervalTween =
      CurveTween(curve: const Interval(_kFadeOutIntervalStart, 1.0));

  @override
  void confirm() {
    _radiusController
      ..duration = _kRadiusDuration
      ..forward();
    // This confirm may have been preceded by a cancel.
    _fadeInController.forward();
    _fadeOutController.animateTo(1.0, duration: _kFadeOutDuration);
  }

  @override
  void cancel() {
    isCancelled = true;
    if (_radiusController.isAnimating) {
      _radiusController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _startFadeOut();
        }
      });
    } else {
      _startFadeOut();
    }
  }

  void _handleAlphaStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) dispose();
  }

  @override
  void dispose() {
    _radiusController.dispose();
    _fadeInController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  void _startFadeOut() {
    _fadeInController.stop();
    // Watch out: setting _fadeOutController's value to 1.0 will
    // trigger a call to _handleAlphaStatusChanged() which will
    // dispose _fadeOutController.
    final double fadeOutValue = 1.0 - _fadeInController.value;
    _fadeOutController.value = fadeOutValue;
    if (fadeOutValue < 1.0)
      _fadeOutController.animateTo(1.0, duration: _kCancelDuration);
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final double alpha = _fadeInController.isAnimating
        ? _fadeIn.value
        : !isCancelled
            ? _fadeOutController
                .drive(Tween<double>(
                  begin: color.a,
                  end: 0,
                ).chain(_fadeOutIntervalTween))
                .value
            : _fadeOutController
                .drive(
                  Tween<double>(
                    begin: color.a,
                    end: 0,
                  ).chain(
                    CurveTween(curve: Curves.easeOutCubic),
                  ),
                )
                .value;
    final Paint paint = Paint()..color = color.withValues(alpha: alpha);
    // final Paint paint = Paint()..color = color.withAlpha(200);
    // Splash moves to the center of the reference box.
    final Offset center = Offset.lerp(
      _position,
      referenceBox.size.center(Offset.zero),
      Curves.ease.transform(_radiusController.value),
    )!;
    final Offset? originOffset = MatrixUtils.getAsTranslation(transform);
    canvas.save();
    if (originOffset == null) {
      canvas.transform(transform.storage);
    } else {
      canvas.translate(originOffset.dx, originOffset.dy);
    }

    // Commented out section that limits splash effect

    // if (_clipCallback != null) {
    //   final Rect rect = _clipCallback();
    //   if (_customBorder != null) {
    //     canvas.clipPath(_customBorder.getOuterPath(rect, textDirection: _textDirection));
    //   } else if (_borderRadius != BorderRadius.zero) {
    //     canvas.clipRRect(RRect.fromRectAndCorners(
    //       rect,
    //       topLeft: _borderRadius.topLeft, topRight: _borderRadius.topRight,
    //       bottomLeft: _borderRadius.bottomLeft, bottomRight: _borderRadius.bottomRight,
    //     ));
    //   } else {
    //     canvas.clipRect(rect);
    //   }
    // }
    canvas.drawCircle(center, _radius.value, paint);
    canvas.restore();
  }
}
