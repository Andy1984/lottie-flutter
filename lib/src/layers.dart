import 'package:Lotie_Flutter/src/keyframes.dart';
import 'package:Lotie_Flutter/src/painting.dart';

import 'package:Lotie_Flutter/src/parsers.dart';
import 'package:Lotie_Flutter/src/shapes.dart';
import 'package:Lotie_Flutter/src/transform.dart';
import 'package:Lotie_Flutter/src/utils.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/rendering.dart';


enum LayerType { PreComp, Solid, Image, Null, Shape, Text, Unknown }
enum MatteType { None, Add, Invert, Unknown }

class Layer {

  final int _id;
  final int _parentId;
  final double _solidWidth;
  final double _solidHeight;
  final double _timeStretch;
  final double _startProgress;
  final double _preCompWidth;
  final double _preCompHeight;
  final String _name;
  final String _refId;
  final Color _solidColor;
  final List _shapes;
  final List<Mask> _masks;
  final Scene<double> _inOutKeyframes;
  final LayerType _type;
  final MatteType _matteType;
  final AnimatableTransform _transform;

  int get id => _id;

  int get parentId => _parentId;

  double get solidWidth => _solidWidth;

  double get solidHeight => _solidHeight;

  Color get solidColor => _solidColor;

  double get timeStretch => _timeStretch;

  double get startProgress => _startProgress;

  double get preCompWidth => _preCompWidth;

  double get preCompHeight => _preCompHeight;

  String get name => _name;

  String get refId => _refId;

  List get shapes => _shapes;

  List<Mask> get masks => _masks;

  Scene<double> get inOutKeyframes => _inOutKeyframes;

  LayerType get type => _type;

  MatteType get matteType => _matteType;

  AnimatableTransform get transform => _transform;


  Layer._empty(this._preCompWidth, this._preCompHeight)
      : _id = -1,
        _parentId = -1,
        _solidWidth = 0.0,
        _solidHeight = 0.0,
        _timeStretch = 0.0,
        _startProgress = 0.0,
        _name = null,
        _refId = null,
        _solidColor = const Color(0x0),
        _shapes = const [],
        _masks = const [],
        _inOutKeyframes = const Scene.empty(),
        _type = LayerType.PreComp,
        _matteType = MatteType.None,
        _transform = new AnimatableTransform();


  Layer._(this._id, this._parentId, this._solidWidth, this._solidHeight,
      this._timeStretch, this._startProgress, this._preCompWidth,
      this._preCompHeight, this._name, this._refId,
      this._solidColor, this._shapes, this._masks, this._inOutKeyframes,
      this._type, this._matteType, this._transform);

  factory Layer(
      [dynamic map, double preCompWidth, double preCompHeight,
        double scale, double durationFrames, int endFrame]) {
    if (map == null) {
      return new Layer._empty(preCompWidth, preCompHeight);
    }

    final int rawType = map['ty'];
    final LayerType type = rawType < LayerType.Unknown.index ? rawType
        : LayerType.values[rawType];

    double preCompositionWidth = 0.0;
    double preCompositionHeight = 0.0;
    if (type == LayerType.PreComp) {
      preCompositionWidth = parseMapToDouble(map["w"]) * scale;
      preCompositionHeight = parseMapToDouble(map["h"]) * scale;
    }

    double solidWidth = 0.0;
    double solidHeight = 0.0;
    Color solidColor = const Color(0x0);
    if (type == LayerType.Solid) {
      solidWidth = parseMapToDouble(map['sw']) * scale;
      solidHeight = parseMapToDouble(map['sh']) * scale;
      solidColor = parseColor(map['sc']);
    }

    AnimatableTransform transform = new AnimatableTransform(map['ks'], scale);
    MatteType matteType = MatteType.values[map['tt']];

    List<Mask> masks = parseJsonArray(map['masksProperties'],
            (rawMask) => new Mask.fromMap(rawMask, scale));

    List<ShapeGroup> shapes = parseJsonArray(map['shapes'],
                 (rawShape) => new ShapeGroup.fromMap(rawShape, scale));


    List<Keyframe<double>> inOutKeyframes = [];

    final int inFrame = map['ip'];
    if (inFrame > 0) {
      inOutKeyframes.add(new Keyframe(0, inFrame, durationFrames, 0.0, 0.0));
    }

    final int outFrame = map['op'] > 0 ? map['op'] : endFrame + 1;
    inOutKeyframes.add(
        new Keyframe(outFrame, endFrame, durationFrames, 0.0, 0.0));

    final double startProgress = parseMapToDouble(map['st']) / durationFrames;

    return new Layer._(
        map['ind'],
        map['parent'],
        solidWidth,
        solidHeight,
        map['sr'] == null ? 1.0 : parseMapToDouble(map['sr']),
        startProgress,
        preCompositionWidth,
        preCompositionHeight,
        map['nm'],
        map['refId'],
        solidColor,
        shapes,
        masks,
        new Scene(inOutKeyframes, false),
        type,
        matteType,
        transform);
  }

  static List<T> parseJsonArray<T>(List jsonArray, T mapItem(dynamic rawItem)) {
    if (jsonArray != null) {
      return jsonArray.map(mapItem)
          .toList();
    }

    return [];
  }



}




