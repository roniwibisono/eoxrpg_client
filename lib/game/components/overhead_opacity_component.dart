import 'dart:ui';

import 'package:flame/components.dart';

/// Wraps the Overhead TiledComponent and renders it through a saveLayer
/// with adjustable alpha — GDD §7: "atap/pohon di atas pemain, dengan opsi
/// transparan saat pemain di bawahnya". Implemented as a wrapper because
/// flame_tiled has no per-layer runtime opacity API (verified against
/// flame_tiled 3.1.1 source).
class OverheadOpacityComponent extends PositionComponent {
  OverheadOpacityComponent({required Component child, required super.priority}) {
    add(child);
  }

  double targetOpacity = 1.0;
  double _opacity = 1.0;

  static const _fadeSpeed = 6.0; // per second
  static const fadedOpacity = 0.45;

  @override
  void update(double dt) {
    super.update(dt);
    final diff = targetOpacity - _opacity;
    if (diff.abs() < 0.01) {
      _opacity = targetOpacity;
    } else {
      _opacity += diff.sign * _fadeSpeed * dt;
      _opacity = _opacity.clamp(0.0, 1.0);
    }
  }

  @override
  void renderTree(Canvas canvas) {
    if (_opacity >= 0.995) {
      super.renderTree(canvas);
      return;
    }
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, _opacity),
    );
    super.renderTree(canvas);
    canvas.restore();
  }
}
