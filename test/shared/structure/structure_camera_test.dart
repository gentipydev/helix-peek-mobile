import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helixpeek/shared/structure/structure_model.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  // A stored model's box: centred, its longest side 1 (the bake normalises it).
  final vm.Aabb3 bounds = vm.Aabb3.minMax(
    vm.Vector3(-0.358553, -0.319856, -0.5),
    vm.Vector3(0.358553, 0.319856, 0.5),
  );

  test('the fold page frames a model as it always has', () {
    final PerspectiveCamera camera = structureCamera(bounds);
    final PerspectiveCamera framed = PerspectiveCamera.framing(
      bounds,
      margin: 1.35,
    );
    expect(structureFramingMargin, 1.35);
    expect(camera.position, framed.position);
    expect(camera.target, framed.target);
    expect(camera.up, framed.up);
    expect(camera.fovRadiansY, framed.fovRadiansY);
    expect(camera.fovNear, framed.fovNear);
    expect(camera.fovFar, framed.fovFar);
  });

  test('the model sits in the middle of the view it frames', () {
    const Size view = Size(390, 520);
    final Offset? centre = structureCamera(
      bounds,
    ).worldToScreen(vm.Vector3.zero(), view);
    expect(centre!.dx, closeTo(view.width / 2, 1e-9));
    expect(centre.dy, closeTo(view.height / 2, 1e-9));
  });

  /// The widest a ring of [radius] about the vertical axis reaches over a
  /// full turn, as a share of the view's half-width: the idle turn, swept.
  double swept(PerspectiveCamera camera, double radius, Size view) {
    double widest = 0;
    for (int i = 0; i < 3600; i++) {
      final double a = i * 2 * math.pi / 3600;
      final Offset? at = camera.worldToScreen(
        vm.Vector3(radius * math.cos(a), 0, radius * math.sin(a)),
        view,
      );
      widest = math.max(widest, (at!.dx - view.width / 2).abs());
    }
    return widest / (view.width / 2);
  }

  void expectSame(PerspectiveCamera a, PerspectiveCamera b) {
    expect(a.position, b.position);
    expect(a.target, b.target);
    expect(a.up, b.up);
    expect(a.fovRadiansY, b.fovRadiansY);
    expect(a.fovNear, b.fovNear);
    expect(a.fovFar, b.fovFar);
  }

  const List<Size> phones = <Size>[Size(402, 700), Size(375, 520)];

  test('a model that clears the sides is framed exactly as before', () {
    final PerspectiveCamera today = structureCamera(bounds);
    for (final Size view in phones) {
      expect(swept(today, 0.4, view), lessThan(structureSideShare));
      expectSame(structureCamera(bounds, reach: 0.4, view: view), today);
    }
    // Without both, it is the height's fit alone.
    expectSame(structureCamera(bounds, reach: 0.615), today);
    expectSame(structureCamera(bounds, view: phones.first), today);
  });

  test('a long model stands back just far enough to clear the sides', () {
    // The box's own x-z half-diagonal: the reach of a model filling it.
    final double reach = math.sqrt(0.358553 * 0.358553 + 0.5 * 0.5);
    // In a wider view, about an SE's fold page, the same model clears the
    // sides and is framed as before: the view's shape decides, not the model.
    const Size wide = Size(375, 520);
    expect(swept(structureCamera(bounds), reach, wide), lessThan(0.95));
    expectSame(
      structureCamera(bounds, reach: reach, view: wide),
      structureCamera(bounds),
    );
    for (final Size view in <Size>[const Size(402, 700), const Size(360, 690)]) {
      expect(
        swept(structureCamera(bounds), reach, view),
        greaterThan(structureSideShare),
        reason: 'past the sides at the height\'s fit, $view',
      );
      final PerspectiveCamera camera = structureCamera(
        bounds,
        reach: reach,
        view: view,
      );
      expect(
        swept(camera, reach, view),
        closeTo(structureSideShare, 0.002),
        reason: '$view',
      );
      final Offset? centre = camera.worldToScreen(vm.Vector3.zero(), view);
      expect(centre!.dx, closeTo(view.width / 2, 1e-9));
      expect(centre.dy, closeTo(view.height / 2, 1e-9));
      // Further back along the same line, and its clip planes still hold
      // the whole box.
      expect(camera.target, structureCamera(bounds).target);
      final double radius = (bounds.max - bounds.min).length / 2;
      final double distance = (camera.position - camera.target).length;
      expect(
        distance,
        greaterThan((structureCamera(bounds).position - camera.target).length),
      );
      expect(camera.fovNear, lessThanOrEqualTo(distance - radius + 1e-5));
      expect(camera.fovFar, greaterThanOrEqualTo(distance + radius - 1e-5));
    }
  });

  test('a model reaches as far as its vertex furthest from the axis', () {
    expect(
      structureReachOf(Float32List.fromList(<double>[
        3, 0, 4, //
        1, 100, 1, // height is not reach
        -6, 0, 0,
      ])),
      6,
    );
    expect(structureReachOf(Float32List(0)), 0);
  });
}
