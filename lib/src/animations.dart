import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:lottie_flutter/src/painting.dart' show Mask;
import 'package:lottie_flutter/src/parsers/parsers.dart';
import 'package:lottie_flutter/src/utils.dart';
import 'package:lottie_flutter/src/values.dart';
import 'package:lottie_flutter/src/keyframes.dart';
import 'package:flutter/painting.dart' show Color, Offset, Path;
import 'package:meta/meta.dart';

abstract class BaseKeyframeAnimation<K, A> {
  final List<ValueChanged<double>> _listeners =
      new List<ValueChanged<double>>();
  bool isDiscrete = false;

  final Scene<K> scene;
  double _progress = 0.0;

  Keyframe<K> cachedKeyframe;

  BaseKeyframeAnimation(this.scene);

  void addListener(ValueChanged<double> onValueChanged) =>
      _listeners.add(onValueChanged);

  double get startDelayProgress =>
      scene.isEmpty ? 0.0 : scene.firstKeyframe.startProgress;

  double get endProgress =>
      scene.isEmpty ? 1.0 : scene.lastKeyframe.endProgress;

  get progress => _progress;

  set progress(double val) {
    if (val < startDelayProgress) {
      val = startDelayProgress;
    } else if (val > endProgress) {
      val = endProgress;
    }

    if (val == _progress) {
      return;
    }

    _progress = val;
    _listeners.forEach((it) => it(progress));
  }

  Keyframe<K> get currentKeyframe {
    if (scene.isEmpty) {
      throw new StateError("There are no keyframes");
    }

    if (cachedKeyframe?.containsProgress(_progress) == true) {
      return cachedKeyframe;
    }

    cachedKeyframe = scene.keyframes.lastWhere(
        (keyframe) => keyframe.containsProgress(_progress),
        orElse: () => scene.firstKeyframe);
    return cachedKeyframe;
  }

  double get currentKeyframeProgress {
    if (isDiscrete) {
      return 0.0;
    }

    final Keyframe keyframe = currentKeyframe;
    if (keyframe.isStatic) {
      return 0.0;
    }

    final progressIntoFrame = _progress - keyframe.startProgress;
    final keyframeProgress = keyframe.endProgress - keyframe.startProgress;
    final linearProgress =
        (progressIntoFrame / keyframeProgress).clamp(0.0, 1.0);
    return keyframe.curve.transform(linearProgress);
  }

  A get value {
    return getValue(currentKeyframe, currentKeyframeProgress);
  }

  // keyframeProgress will be [0, 1] unless the interpolator has overshoot in which case, this
  // should be able to handle values outside of that range.
  @protected
  A getValue(Keyframe<K> keyframe, double keyframeProgress);
}

abstract class KeyframeAnimation<T> extends BaseKeyframeAnimation<T, T> {
  KeyframeAnimation(Scene<T> scene) : super(scene);

  void checkKeyframe(Keyframe keyframe) {
    if (keyframe?.startValue == null || keyframe?.endValue == null) {
      throw new StateError("Missing values for keyframe.");
    }
  }
}

class StaticKeyframeAnimation<T> extends KeyframeAnimation<T> {
  final T _initialValue;

  StaticKeyframeAnimation(this._initialValue) : super(new Scene.empty());

  @override
  set progress(double progress) {
    // Do nothing
  }

  @override
  T get value {
    return _initialValue;
  }

  @override
  T getValue(Keyframe<T> keyframe, double keyframeProgress) {
    return _initialValue;
  }
}

class IntegerKeyframeAnimation extends KeyframeAnimation<int> {
  IntegerKeyframeAnimation(Scene<int> scene) : super(scene);

  @override
  int getValue(Keyframe<int> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);
    return ui
        .lerpDouble(keyframe.startValue, keyframe.endValue,
            keyframeProgress) // lerpInt(keyframe.startValue, keyframe.endValue, keyframeProgress)
        .toInt();
  }
}

class DoubleKeyframeAnimation extends KeyframeAnimation<double> {
  DoubleKeyframeAnimation(Scene<double> scene) : super(scene);

  @override
  double getValue(Keyframe<double> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);
    return ui.lerpDouble(
        keyframe.startValue, keyframe.endValue, keyframeProgress);
  }
}

class ColorKeyframeAnimation extends KeyframeAnimation<Color> {
  ColorKeyframeAnimation(Scene<Color> scene) : super(scene);

  @override
  Color getValue(Keyframe<Color> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);
    return GammaEvaluator.evaluate(
        keyframeProgress, keyframe.startValue, keyframe.endValue);
  }
}

class GradientColorKeyframeAnimation extends KeyframeAnimation<GradientColor> {
  GradientColor _gradientColor;

  GradientColorKeyframeAnimation(Scene<GradientColor> scene) : super(scene) {
    GradientColor startValue = scene.firstKeyframe.startValue;
    int length = startValue == null ? 0 : startValue.length;
    _gradientColor = new GradientColor(new List(length), new List(length));
  }

  @override
  GradientColor getValue(
      Keyframe<GradientColor> keyframe, double keyframeProgress) {
    return _gradientColor
      ..lerpGradients(keyframe.startValue, keyframe.endValue, keyframeProgress);
  }
}

class PointKeyframeAnimation extends KeyframeAnimation<Offset> {
  PointKeyframeAnimation(Scene<Offset> scene) : super(scene);

  @override
  Offset getValue(Keyframe<Offset> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);

    Offset startPoint = keyframe.startValue;
    Offset endPoint = keyframe.endValue;

    return new Offset(
        startPoint.dx + keyframeProgress * (endPoint.dx - startPoint.dx),
        startPoint.dy + keyframeProgress * (endPoint.dy - startPoint.dy));
  }
}

class ScaleKeyframeAnimation extends KeyframeAnimation<Offset> {
  ScaleKeyframeAnimation(Scene<Offset> scene) : super(scene);

  @override
  Offset getValue(Keyframe<Offset> keyframe, double keyframeProgress) {
    checkKeyframe(keyframe);

    Offset startTransform = keyframe.startValue;
    Offset endTransform = keyframe.endValue;

    return new Offset(
        ui.lerpDouble(startTransform.dx, endTransform.dx, keyframeProgress),
        ui.lerpDouble(startTransform.dy, endTransform.dy, keyframeProgress));
  }
}

class ShapeKeyframeAnimation extends BaseKeyframeAnimation<ShapeData, Path> {
  ShapeKeyframeAnimation(Scene<ShapeData> scene) : super(scene);

  @override
  Path getValue(Keyframe<ShapeData> keyframe, double keyframeProgress) {
    final shape = new ShapeData.fromInterpolateBetween(
        keyframe.startValue, keyframe.endValue, keyframeProgress);
    return Parsers.pathParser.parseFromShape(shape);
  }
}

class PathKeyframeAnimation extends KeyframeAnimation<Offset> {
  PathKeyframe _pathMeasureKeyframe;
  ui.PathMetric _pathMeasure;

  PathKeyframeAnimation(Scene<Offset> scene) : super(scene);

  @override
  Offset getValue(Keyframe<Offset> keyframe, double keyframeProgress) {
    PathKeyframe pathKeyframe = keyframe;

    if (pathKeyframe.path == null) {
      return keyframe.startValue;
    }

    if (_pathMeasureKeyframe != pathKeyframe) {
      _pathMeasure = pathKeyframe.path.computeMetrics().first;
      _pathMeasureKeyframe = keyframe;
    }

    var posTan = _pathMeasure
        .getTangentForOffset(keyframeProgress * _pathMeasure.length);
    return posTan.position;
  }
}

class SplitDimensionPathKeyframeAnimation extends KeyframeAnimation<Offset> {
  final BaseKeyframeAnimation<double, double> xAnimation;
  final BaseKeyframeAnimation<double, double> yAnimation;

  SplitDimensionPathKeyframeAnimation(this.xAnimation, this.yAnimation)
      : super(new Scene.empty());

  @override
  set progress(double progress) {
    xAnimation.progress = progress;
    yAnimation.progress = progress;
    _listeners.forEach((listener) => listener(progress));
  }

  @override
  Offset getValue(Keyframe<Offset> keyframe, double keyframeProgress) {
    return new Offset(xAnimation.value, yAnimation.value);
  }
}

class MaskKeyframeAnimation {
  final List<BaseKeyframeAnimation<dynamic, Path>> _animations;
  final List<Mask> _masks;

  List<BaseKeyframeAnimation<dynamic, Path>> get animations => _animations;

  List<Mask> get masks => _masks;

  MaskKeyframeAnimation(this._masks) : _animations = new List(_masks.length) {
    for (int i = 0; i < _masks.length; i++) {
      _animations[i] = _masks[i].path.createAnimation();
    }
  }
}
