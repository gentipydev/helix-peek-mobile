import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_scene/fscene.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../core/catalog/protein_target.dart';
import '../../core/catalog/protein_track.dart';
import '../../core/network/track_source.dart';
import '../../core/theme/anatomy_colors.dart';
import '../folding/fold_skin.dart';

/// How far back of a snug fit the camera sits.
///
/// The model is normalised to a longest axis of 1 when it is baked, so the
/// camera is framed once and left alone: `framing` fits the bounding sphere,
/// and every rotation stays inside that same sphere, so nothing here needs a
/// scale constant and nothing can swing out of shot.
///
/// Measured on the page, and it has to be measured on *this* page. `framing`
/// fits to the vertical field of view, so the shorter the box the larger the
/// molecule: judged in a full-screen harness 1.35 looked lost, but the page
/// gives up 96 points to the header and 48 to the stage bar, and in that
/// box the same number is right. At 1.15 the silhouette reached 96% of the
/// width and touched both edges. 1.35 holds it near 82%, which leaves the
/// widest yaw — the x-z diagonal, 1.30 against the longest axis' 1.0 — clear
/// of the sides.
const double structureFramingMargin = 1.35;

/// The most of the view's half-width a model may reach as it turns.
///
/// [structureFramingMargin] fits the model to the view's height, and a phone's
/// view is about half as wide as it is tall, so a long model swung side-on
/// reached past both edges. On an iPhone 17 Pro Max's fold page (440 × 760)
/// vasopressin reached 116% of the half-width and oxytocin 115%, and ten more
/// of the 54 curated passed 95% (measured 2026-11-15). Those fourteen are
/// drawn just far enough back to stay inside it, vasopressin at 83% of its
/// old size and PAPPA at 98%; the other forty are framed exactly as before.
const double structureSideShare = 0.95;

/// The camera the fold page frames a model with, given the model's bounds.
///
/// Named so that anything drawn in the model's own frame is seen through the
/// same lens: the lab's fold animation projects its CA trace through it, and
/// its last frame lands where the page draws the fold.
///
/// Given the model's [reach] ([structureReach]) and the [view] it is drawn
/// in, the camera stands back as far as the turn needs and no further: a
/// model that stays within [structureSideShare] of the sides at
/// [structureFramingMargin] is framed exactly as before. Without them it is
/// the height's fit alone, as it always was.
PerspectiveCamera structureCamera(
  vm.Aabb3 bounds, {
  double? reach,
  Size? view,
}) {
  final PerspectiveCamera fitted = PerspectiveCamera.framing(
    bounds,
    margin: structureFramingMargin,
  );
  if (reach == null ||
      view == null ||
      !view.isFinite ||
      view.width <= 0 ||
      view.height <= 0) {
    return fitted;
  }
  // The turn is about the vertical axis through the origin, and the camera
  // looks at the box's centre: a vertex that far from the axis sweeps a
  // circle whose widest tangent from the eye, at distance d, is
  // r / sqrt(d² - r²). Held to the share of the half-width's tangent, that
  // is a distance of r · sqrt(1 + 1/k²).
  final double r = reach + math.sqrt(
    bounds.center.x * bounds.center.x + bounds.center.z * bounds.center.z,
  );
  final double k =
      structureSideShare *
      view.width /
      view.height *
      math.tan(fitted.fovRadiansY / 2);
  final double needed = r * math.sqrt(1 + 1 / (k * k));
  final double distance = (fitted.position - fitted.target).length;
  if (needed <= distance) {
    return fitted;
  }
  return PerspectiveCamera.framing(
    bounds,
    margin: structureFramingMargin * needed / distance,
  );
}

/// How far the model reaches from the axis it turns about: the largest
/// distance of any of [positions] (x, y, z triples) from the vertical axis.
double structureReachOf(Float32List positions) {
  double widest = 0;
  for (int i = 0; i + 2 < positions.length; i += 3) {
    final double x = positions[i];
    final double z = positions[i + 2];
    final double squared = x * x + z * z;
    if (squared > widest) {
      widest = squared;
    }
  }
  return math.sqrt(widest);
}

/// [structureReachOf] every vertex of [molecule], in the frame it is turned
/// in, or null where its geometry cannot be read, which leaves the camera
/// the height's fit alone.
double? structureReach(Node molecule) {
  try {
    return structureReachOf(
      molecule.extractMeshData(transform: molecule.localTransform).positions,
    );
  } on StateError {
    return null;
  }
}

/// Loads the molecule into [scene], under [parent] where one is given, paints
/// and frames it, and compiles what its first frame needs.
///
/// [StructureView.prepare] runs this into a scene it then drops, so that
/// when the page runs it for real everything expensive is already cached.
Future<(Node, PerspectiveCamera)> buildStructureModel(
  Scene scene,
  AnatomyColors anatomy,
  ProteinTarget target,
  TrackSource tracks, {
  Node? parent,
}) async {
  await Scene.initializeStaticResources();
  if (!Scene.isReadyToRender) {
    throw StateError('The 3D renderer did not initialize');
  }
  // The `.fsceneb` the bake compiled, fetched rather than compiled into the
  // bundle by `hook/build.dart`. No glTF is imported on the device: the
  // container is already the realized form, and the `.glb` it came from is
  // kept in storage only so a flutter_scene upgrade — which invalidates every
  // `.fsceneb` — can re-compile without the repo and another PyMOL run.
  final Node molecule = await loadFscenebBytesAsync(
    await tracks.read(target.slug, TrackKind.structure),
  );
  for (final StructureChain chain in target.chains) {
    _paint(molecule, target, chain.node, chain.tint.of(anatomy));
  }

  if (parent == null) {
    scene.add(molecule);
  } else {
    parent.add(molecule);
  }
  final vm.Aabb3? bounds = molecule.combinedWorldBounds;
  final PerspectiveCamera camera = bounds == null
      ? PerspectiveCamera()
      : structureCamera(bounds);

  // Compile the pipelines the first frame needs before the SceneView is
  // mounted, rather than letting it warm up behind a loadingBuilder: that
  // builder is a second pulse, mounted in the frame the page's own is torn
  // down, and it starts over from frame 0. This is the same single view the
  // SceneView would warm up with.
  await scene.warmUp(<RenderView>[RenderView(camera: camera)]);
  return (molecule, camera);
}

/// Gives every primitive of one named node its own material.
///
/// The nodes are named in the `.glb` by the bake, which is what lets the
/// colour live here in the theme rather than baked into vertices where it
/// could never answer to a token. A name the model does not have means the
/// bake and the catalog have come apart, and the page says so rather than
/// drawing what is left.
void _paint(Node root, ProteinTarget target, String name, Color colour) {
  final Mesh? mesh = _find(root, name)?.mesh;
  if (mesh == null) {
    // Thrown, where this used to assert. An assert is right while the model
    // is compiled into the build from a file beside the catalog, because the
    // two can only come apart at build time and the assert fires. A fetched
    // container can be from an older bake than the row that named it, and in
    // release the assert is gone — so the page would draw an unpainted grey
    // molecule and say nothing. It says so instead.
    throw StateError('The model for ${target.slug} has no node named "$name".');
  }
  for (final MeshPrimitive primitive in mesh.primitives) {
    primitive.material = structureMaterial(colour);
  }
}

/// Each of [target]'s nodes in [molecule] as its vertices and triangles, in
/// the frame the molecule is drawn in: what the fold animation copies, and
/// carries to the end, where the copy is the node itself.
///
/// Throws if a node carries no normals, or is placed by a transform of its
/// own: the copy has to land on the node vertex for vertex.
List<SkinMesh> storedMeshesOf(Node molecule, ProteinTarget target) =>
    <SkinMesh>[
      for (final StructureChain chain in target.chains)
        _storedMesh(molecule, target, chain.node),
    ];

SkinMesh _storedMesh(Node molecule, ProteinTarget target, String name) {
  final Node? node = _find(molecule, name);
  if (node == null) {
    throw StateError('The model for ${target.slug} has no node named "$name".');
  }
  for (Node? n = node; n != null; n = n.parent) {
    if (!n.localTransform.isIdentity()) {
      throw StateError(
        'The ${target.slug} model places "${n.name}" by a transform',
      );
    }
    if (identical(n, molecule)) {
      break;
    }
  }
  final MeshData data = node.extractMeshData();
  final Float32List? normals = data.normals;
  final List<int>? indices = data.indices;
  if (normals == null || indices == null) {
    throw StateError('The ${target.slug} model\'s "$name" has no normals');
  }
  return SkinMesh(
    node: name,
    positions: data.positions,
    normals: normals,
    indices: Uint32List.fromList(indices),
  );
}

/// The material every part of a fold is drawn in, the model's and the fold
/// animation's alike, so that the one hands over to the other unseen.
PhysicallyBasedMaterial structureMaterial(Color colour) =>
    structureMaterialOf(linearColour(colour));

/// [structureMaterial] with its base colour already linear: white, for a
/// mesh whose own vertex or instance colours are the colour.
PhysicallyBasedMaterial structureMaterialOf(vm.Vector4 linear) =>
    PhysicallyBasedMaterial()
      ..baseColorFactor = linear
      // Protein illustration convention: matte, so the form is read from
      // shading rather than from highlights sliding over it as it turns.
      ..metallicFactor = 0
      ..roughnessFactor = 0.65;

/// The importer is free to nest what it loads, so the node is looked for
/// rather than indexed.
Node? _find(Node node, String name) {
  if (node.name == name) {
    return node;
  }
  for (final Node child in node.children) {
    final Node? hit = _find(child, name);
    if (hit != null) {
      return hit;
    }
  }
  return null;
}

/// sRGB to linear, per the glTF specification's `baseColorFactor`.
vm.Vector4 linearColour(Color colour) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return vm.Vector4(channel(colour.r), channel(colour.g), channel(colour.b), 1);
}
