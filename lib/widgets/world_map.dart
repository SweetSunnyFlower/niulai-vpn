import 'dart:convert';

import 'package:flutter/material.dart';

class WorldMapProjection {
  const WorldMapProjection._();

  /// Natural Earth GeoJSON is rendered against this logical base canvas. The
  /// painter scales the cached paths to whatever screen size the map gets.
  static const Size baseSize = Size(1000, 500);

  static Offset project({
    required double lat,
    required double lon,
    required Size size,
  }) {
    final normalized = _normalize(lat, lon);
    return Offset(
      normalized.dx / baseSize.width * size.width,
      normalized.dy / baseSize.height * size.height,
    );
  }

  static Offset _normalize(double lat, double lon) {
    return Offset(
      (lon + 180) / 360 * baseSize.width,
      (90 - lat) / 180 * baseSize.height,
    );
  }

  static Size fitAspect(Size viewport, double aspectRatio) {
    final widthFromHeight = viewport.height * aspectRatio;
    if (widthFromHeight <= viewport.width) {
      return Size(widthFromHeight, viewport.height);
    }
    final heightFromWidth = viewport.width / aspectRatio;
    return Size(viewport.width, heightFromWidth);
  }

  static Size fullHeight(Size viewport) {
    return Size(viewport.height * 2, viewport.height);
  }
}

class WorldMapGeometry {
  WorldMapGeometry({required this.paths});

  final List<Path> paths;

  static WorldMapGeometry parse(String source) {
    final paths = <Path>[];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return WorldMapGeometry(paths: paths);
      }
      final features = decoded['features'];
      if (features is! List) {
        return WorldMapGeometry(paths: paths);
      }

      for (final feature in features) {
        if (feature is! Map<String, dynamic>) {
          continue;
        }
        final geometry = feature['geometry'];
        if (geometry is! Map<String, dynamic>) {
          continue;
        }
        final coordinates = geometry['coordinates'];
        final type = geometry['type'];
        if (type == 'Polygon') {
          _addPolygon(paths, coordinates);
        } else if (type == 'MultiPolygon' && coordinates is List) {
          for (final polygon in coordinates) {
            _addPolygon(paths, polygon);
          }
        }
      }
    } catch (_) {
      // A malformed asset should not crash the map screen; it just renders
      // without country shapes.
    }
    return WorldMapGeometry(paths: paths);
  }

  static void _addPolygon(List<Path> paths, Object? coordinates) {
    if (coordinates is! List || coordinates.isEmpty) {
      return;
    }

    for (final ring in coordinates) {
      if (ring is! List || ring.length < 2) {
        continue;
      }
      _addRing(paths, ring);
    }
  }

  static void _addRing(List<Path> paths, List ring) {
    if (ring.length < 3) {
      return;
    }

    var path = Path();
    var started = false;
    double? previousLon;

    for (final point in ring) {
      if (point is! List || point.length < 2) {
        continue;
      }
      final lon = (point[0] as num?)?.toDouble();
      final lat = (point[1] as num?)?.toDouble();
      if (lon == null || lat == null) {
        continue;
      }

      final projected = WorldMapProjection._normalize(lat, lon);
      if (!started) {
        path.moveTo(projected.dx, projected.dy);
        started = true;
      } else if (previousLon != null && (lon - previousLon).abs() > 180) {
        path.close();
        if (path.getBounds().isFinite) {
          paths.add(path);
        }
        path = Path()..moveTo(projected.dx, projected.dy);
      } else {
        path.lineTo(projected.dx, projected.dy);
      }
      previousLon = lon;
    }

    path.close();
    if (path.getBounds().isFinite) {
      paths.add(path);
    }
  }
}

class WorldMapPainter extends CustomPainter {
  const WorldMapPainter({
    required this.geometry,
    required this.landColor,
    required this.borderColor,
  });

  final WorldMapGeometry geometry;
  final Color landColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.paths.isEmpty) {
      return;
    }

    canvas.save();
    canvas.scale(
      size.width / WorldMapProjection.baseSize.width,
      size.height / WorldMapProjection.baseSize.height,
    );

    final landPaint = Paint()
      ..color = landColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..strokeJoin = StrokeJoin.round;

    for (final path in geometry.paths) {
      canvas.drawPath(path, landPaint);
      canvas.drawPath(path, borderPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WorldMapPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.landColor != landColor ||
        oldDelegate.borderColor != borderColor;
  }
}
