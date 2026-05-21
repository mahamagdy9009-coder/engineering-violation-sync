import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class DrainFeature {
  final List<LatLng> points;
  final Map<String, dynamic> properties;

  DrainFeature({
    required this.points,
    required this.properties,
  });
}

class SnapResult {
  final LatLng point;
  final double distanceMeters;
  final double cumulativeMeters;

  SnapResult({
    required this.point,
    required this.distanceMeters,
    required this.cumulativeMeters,
  });
}

enum DrawMode {
  none,
  polyline,
  polygon,
  measureDistance,
  measureArea,
}

class GisDrawing {
  final String id;
  final String name;
  final DrawMode type;
  final List<LatLng> points;
  final Color color;

  GisDrawing({
    required this.id,
    required this.name,
    required this.type,
    required this.points,
    required this.color,
  });
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class GisScreen extends StatefulWidget {
  const GisScreen({super.key});

  @override
  State<GisScreen> createState() => _GisScreenState();
}

class _GisScreenState extends State<GisScreen> {
  // ── controllers ──────────────────────────────────────────────────────────
  final MapController mapController = MapController();
  final Distance distance = const Distance();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController coordinateController = TextEditingController();

  // ── state ─────────────────────────────────────────────────────────────────
  final List<DrainFeature> drains = [];
  bool isLoading = true;
  bool satelliteMode = true;

  DrainFeature? selectedDrain;
  LatLng? selectedPoint;
  double selectedKm = 0;

  DrawMode currentMode = DrawMode.none;
  bool drawingMode = false;
  List<LatLng> currentDrawingPoints = [];
  List<GisDrawing> savedDrawings = [];

  String selectedEngineering = 'الجميع';
  final List<String> engineeringFilters = [
    'الجميع',
    'هندسة صرف الفشن',
    'هندسة صرف الواسطى',
    'هندسة صرف ناصر',
    'هندسة صرف بني سويف',
    'هندسة صرف اهناسيا',
    'هندسة صرف ببا',
    'هندسة صرف سمسطا',
  ];

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    loadGeoJson();
  }

  @override
  void dispose() {
    searchController.dispose();
    coordinateController.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  String safeValue(dynamic value) {
    if (value == null) return '-';
    return value.toString();
  }

  // ── GeoJSON loading ───────────────────────────────────────────────────────
  Future<void> loadGeoJson() async {
    try {
      drains.clear();

      final jsonString = await rootBundle.loadString(
        'assets/gis/central_egypt_drainage_drains.geojson',
      );

      final data = jsonDecode(jsonString);
      final features = data['features'];

      for (final feature in features) {
        final geometry = feature['geometry'];
        if (geometry == null) continue;

        final type = geometry['type'];
        final properties = Map<String, dynamic>.from(
          feature['properties'] ?? {},
        );

        final engineering =
            safeValue(properties['drainage_engineering']).toLowerCase();
        final admin = safeValue(properties['drainage_admin']).toLowerCase();

        final isBeniSuef = engineering.contains('الفشن') ||
            engineering.contains('الواسطى') ||
            engineering.contains('ناصر') ||
            engineering.contains('بني سويف') ||
            engineering.contains('اهناسيا') ||
            engineering.contains('ببا') ||
            engineering.contains('سمسطا') ||
            admin.contains('بني سويف');

        if (!isBeniSuef) continue;

        if (type == 'LineString') {
          final coordinates = geometry['coordinates'];
          final points = (coordinates as List).map<LatLng>((c) {
            return LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            );
          }).toList();
          drains.add(DrainFeature(points: points, properties: properties));
        }

        if (type == 'MultiLineString') {
          final multi = geometry['coordinates'];
          for (final line in multi) {
            final points = (line as List).map<LatLng>((c) {
              return LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              );
            }).toList();
            drains.add(DrainFeature(points: points, properties: properties));
          }
        }
      }
    } catch (e) {
      debugPrint('GIS ERROR => $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  // ── snap logic ────────────────────────────────────────────────────────────
  double projectFactor(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    if (dx == 0 && dy == 0) return 0;
    final t = ((p.longitude - a.longitude) * dx +
            (p.latitude - a.latitude) * dy) /
        (dx * dx + dy * dy);
    return t.clamp(0.0, 1.0);
  }

  LatLng interpolate(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  SnapResult? snapToDrain(LatLng tapPoint, DrainFeature drain) {
    if (drain.points.length < 2) return null;

    double bestDistance = double.infinity;
    LatLng? bestPoint;
    double cumulativeMeters = 0;
    double bestCumulative = 0;

    for (int i = 0; i < drain.points.length - 1; i++) {
      final a = drain.points[i];
      final b = drain.points[i + 1];

      final segmentLength = distance.as(LengthUnit.Meter, a, b);
      final t = projectFactor(tapPoint, a, b);
      final projected = interpolate(a, b, t);
      final d = distance.as(LengthUnit.Meter, tapPoint, projected);

      if (d < bestDistance) {
        bestDistance = d;
        bestPoint = projected;
        bestCumulative = cumulativeMeters + (segmentLength * t);
      }

      cumulativeMeters += segmentLength;
    }

    if (bestPoint == null) return null;

    return SnapResult(
      point: bestPoint,
      distanceMeters: bestDistance,
      cumulativeMeters: bestCumulative,
    );
  }

  // ── map tap ───────────────────────────────────────────────────────────────
  void handleMapTap(TapPosition tapPosition, LatLng point) {
    // Drawing mode: add points, do not run snap logic
    if (drawingMode) {
      setState(() {
        currentDrawingPoints.add(point);
      });
      return;
    }

    // Normal mode: snap to nearest drain
    DrainFeature? bestDrain;
    SnapResult? bestSnap;
    double globalBest = double.infinity;

    final visibleDrains = drains.where((drain) {
      if (selectedEngineering == 'الجميع') return true;
      final eng = safeValue(drain.properties['drainage_engineering']);
      return eng.contains(
        selectedEngineering.replaceAll('هندسة صرف ', ''),
      );
    });

    for (final drain in visibleDrains) {
      final snap = snapToDrain(point, drain);
      if (snap == null) continue;
      if (snap.distanceMeters < globalBest) {
        globalBest = snap.distanceMeters;
        bestDrain = drain;
        bestSnap = snap;
      }
    }

    if (bestDrain != null && bestSnap != null && bestSnap.distanceMeters <= 5) {
      final snappedPoint = bestSnap.point;
      final snappedKm = bestSnap.cumulativeMeters / 1000;
      setState(() {
        selectedDrain = bestDrain;
        selectedPoint = snappedPoint;
        selectedKm = snappedKm;
      });
    } else {
      setState(() {
        selectedDrain = null;
        selectedPoint = null;
        selectedKm = 0;
      });
    }
  }

  // ── search ────────────────────────────────────────────────────────────────
  void searchDrain() {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    for (final drain in drains) {
      final allText = drain.properties.values
          .map((e) => safeValue(e))
          .join(' ')
          .toLowerCase();

      if (allText.contains(query)) {
        mapController.move(drain.points.first, 16);
        setState(() {
          selectedDrain = drain;
          selectedPoint = drain.points.first;
          selectedKm = 0;
        });
        return;
      }
    }
  }

  void searchCoordinates() {
    try {
      final text = coordinateController.text.trim();
      final parts = text.split(',');
      if (parts.length != 2) return;
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      mapController.move(LatLng(lat, lng), 18);
    } catch (_) {}
  }

  // ── measurement helpers ───────────────────────────────────────────────────
  double calculateDistance(List<LatLng> points) {
    double meters = 0;
    for (int i = 0; i < points.length - 1; i++) {
      meters += distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return meters;
  }

  double calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      area += p1.longitude * p2.latitude;
      area -= p2.longitude * p1.latitude;
    }
    return area.abs() * 111139 * 111139 / 2;
  }

  // ── drawing controls ──────────────────────────────────────────────────────
  void startDrawing(DrawMode mode) {
    setState(() {
      currentMode = mode;
      drawingMode = true;
      currentDrawingPoints.clear();
    });
  }

  void finishDrawing() {
    if (currentDrawingPoints.isEmpty) return;

    savedDrawings.add(
      GisDrawing(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'رسم جديد',
        type: currentMode,
        points: List.from(currentDrawingPoints),
        color: Colors.orange,
      ),
    );

    setState(() {
      drawingMode = false;
      currentMode = DrawMode.none;
      currentDrawingPoints.clear();
    });
  }

  void clearCurrentDrawing() {
    setState(() {
      currentDrawingPoints.clear();
      drawingMode = false;
      currentMode = DrawMode.none;
    });
  }

  // ── KML export (dart:io only — no external packages needed) ──────────────
  String generateKml(GisDrawing drawing) {
    final coords = drawing.points
        .map((p) => '${p.longitude},${p.latitude},0')
        .join('\n');

    final isPolygon =
        drawing.type == DrawMode.polygon || drawing.type == DrawMode.measureArea;

    final geometryTag = isPolygon
        ? '<Polygon><outerBoundaryIs><LinearRing>'
            '<coordinates>\n$coords\n</coordinates>'
            '</LinearRing></outerBoundaryIs></Polygon>'
        : '<LineString><coordinates>\n$coords\n</coordinates></LineString>';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
  <name>Al Fashn GIS Export</name>
  <Placemark>
    <name>${drawing.name}</name>
    $geometryTag
  </Placemark>
</Document>
</kml>''';
  }

  Future<void> exportLastDrawing() async {
    if (savedDrawings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد رسومات محفوظة للتصدير')),
        );
      }
      return;
    }

    final drawing = savedDrawings.last;
    final kml = generateKml(drawing);

    try {
      // Save next to the executable on Windows (or current working dir)
      final savePath =
          '${Directory.current.path}${Platform.pathSeparator}${drawing.name}_${drawing.id}.kml';
      final file = File(savePath);
      await file.writeAsString(kml);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ ملف KML:\n$savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الملف: $e')),
        );
      }
    }
  }

  // ── property helpers ──────────────────────────────────────────────────────
  String getProperty(List<String> keys) {
    if (selectedDrain == null) return '-';
    for (final key in keys) {
      if (selectedDrain!.properties.containsKey(key)) {
        final value = selectedDrain!.properties[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
    }
    return '-';
  }

  Widget buildInfoRow(String title, dynamic value, bool dark) {
    return Container(
      color: dark ? const Color(0xFF00695C) : const Color(0xFF00897B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              safeValue(value),
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── measurement label helper ──────────────────────────────────────────────
  String get measurementLabel {
    if (!drawingMode && currentDrawingPoints.isEmpty) return '';
    if (currentMode == DrawMode.measureDistance ||
        currentMode == DrawMode.polyline) {
      if (currentDrawingPoints.length < 2) return 'أضف نقاط';
      final m = calculateDistance(currentDrawingPoints);
      return m >= 1000
          ? 'المسافة: ${(m / 1000).toStringAsFixed(3)} كم'
          : 'المسافة: ${m.toStringAsFixed(1)} م';
    }
    if (currentMode == DrawMode.measureArea ||
        currentMode == DrawMode.polygon) {
      if (currentDrawingPoints.length < 3) return 'أضف نقاط';
      final a = calculatePolygonArea(currentDrawingPoints);
      return a >= 1000000
          ? 'المساحة: ${(a / 1000000).toStringAsFixed(4)} كم²'
          : 'المساحة: ${a.toStringAsFixed(1)} م²';
    }
    return '';
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final visibleDrains = drains.where((drain) {
      if (selectedEngineering == 'الجميع') return true;
      final eng = safeValue(drain.properties['drainage_engineering']);
      return eng.contains(
        selectedEngineering.replaceAll('هندسة صرف ', ''),
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF071B17),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ── 1. FlutterMap (layers only inside children) ─────────────
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(28.893, 30.841),
                    initialZoom: 11,
                    onTap: handleMapTap,
                  ),
                  children: [
                    // Tile layer (satellite or OSM)
                    TileLayer(
                      urlTemplate: satelliteMode
                          ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.al_fashn',
                    ),

                    // Drain polylines
                    PolylineLayer(
                      polylines: visibleDrains.map((drain) {
                        final selected = selectedDrain == drain;
                        return Polyline(
                          points: drain.points,
                          color: selected
                              ? Colors.amber
                              : Colors.redAccent,
                          strokeWidth: selected ? 5 : 3,
                        );
                      }).toList(),
                    ),

                    // Saved & in-progress drawing polylines
                    PolylineLayer(
                      polylines: [
                        ...savedDrawings.map(
                          (e) => Polyline(
                            points: e.points,
                            color: e.color,
                            strokeWidth: 4,
                          ),
                        ),
                        if (currentDrawingPoints.length >= 2)
                          Polyline(
                            points: currentDrawingPoints,
                            color: Colors.orange,
                            strokeWidth: 4,
                          ),
                      ],
                    ),

                    // Polygon layer
                    PolygonLayer(
                      polygons: [
                        ...savedDrawings
                            .where((e) =>
                                e.type == DrawMode.polygon ||
                                e.type == DrawMode.measureArea)
                            .map(
                              (e) => Polygon(
                                points: e.points,
                                color: Colors.orange.withValues(alpha: 0.3),
                                borderColor: Colors.orange,
                                borderStrokeWidth: 3,
                              ),
                            ),
                        if (currentDrawingPoints.length >= 3 &&
                            (currentMode == DrawMode.polygon ||
                                currentMode == DrawMode.measureArea))
                          Polygon(
                            points: currentDrawingPoints,
                            color: Colors.orange.withValues(alpha: 0.3),
                            borderColor: Colors.orange,
                            borderStrokeWidth: 3,
                          ),
                      ],
                    ),

                    // Drawing vertex markers
                    if (currentDrawingPoints.isNotEmpty)
                      MarkerLayer(
                        markers: currentDrawingPoints.map((p) {
                          return Marker(
                            point: p,
                            width: 14,
                            height: 14,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    // Selected drain marker
                    if (selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedPoint!,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.amber,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // ── 2. Top bar (search + coordinate + satellite toggle) ──────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: const Color(0xFF00695C).withValues(alpha: 0.95),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        // Drain name search
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: searchController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'بحث في المصارف...',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor:
                                    const Color(0xFF004D40).withValues(alpha: 0.8),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.search,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: searchDrain,
                                ),
                              ),
                              onSubmitted: (_) => searchDrain(),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Coordinate search
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: coordinateController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'lat, lng',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor:
                                    const Color(0xFF004D40).withValues(alpha: 0.8),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.my_location,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  onPressed: searchCoordinates,
                                ),
                              ),
                              onSubmitted: (_) => searchCoordinates(),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Satellite / OSM toggle
                        Tooltip(
                          message: satelliteMode
                              ? 'التبديل إلى OSM'
                              : 'التبديل إلى Satellite',
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                satelliteMode = !satelliteMode;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF004D40),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                satelliteMode ? Icons.map : Icons.satellite,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 3. Engineering filter dropdown ───────────────────────────
                Positioned(
                  top: 60,
                  left: 12,
                  right: 12,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF004D40).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedEngineering,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF004D40),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        icon: const Icon(
                          Icons.filter_list,
                          color: Colors.white,
                        ),
                        items: engineeringFilters.map((filter) {
                          return DropdownMenuItem<String>(
                            value: filter,
                            child: Text(filter),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedEngineering = value;
                              selectedDrain = null;
                              selectedPoint = null;
                              selectedKm = 0;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),

                // ── 4. Drawing toolbar (left side) ───────────────────────────
                Positioned(
                  top: 115,
                  left: 12,
                  child: Column(
                    children: [
                      _DrawBtn(
                        heroTag: 'line',
                        icon: Icons.timeline,
                        tooltip: 'رسم خط',
                        color: const Color(0xFF004D40),
                        active: currentMode == DrawMode.polyline,
                        onPressed: () => startDrawing(DrawMode.polyline),
                      ),
                      const SizedBox(height: 8),
                      _DrawBtn(
                        heroTag: 'polygon',
                        icon: Icons.hexagon,
                        tooltip: 'رسم مضلع',
                        color: const Color(0xFF004D40),
                        active: currentMode == DrawMode.polygon,
                        onPressed: () => startDrawing(DrawMode.polygon),
                      ),
                      const SizedBox(height: 8),
                      _DrawBtn(
                        heroTag: 'measure',
                        icon: Icons.straighten,
                        tooltip: 'قياس مسافة',
                        color: const Color(0xFF004D40),
                        active: currentMode == DrawMode.measureDistance,
                        onPressed: () =>
                            startDrawing(DrawMode.measureDistance),
                      ),
                      const SizedBox(height: 8),
                      _DrawBtn(
                        heroTag: 'area',
                        icon: Icons.square_foot,
                        tooltip: 'قياس مساحة',
                        color: const Color(0xFF004D40),
                        active: currentMode == DrawMode.measureArea,
                        onPressed: () => startDrawing(DrawMode.measureArea),
                      ),
                      const SizedBox(height: 8),
                      _DrawBtn(
                        heroTag: 'finish',
                        icon: Icons.done,
                        tooltip: 'إنهاء الرسم',
                        color: Colors.green,
                        active: false,
                        onPressed: finishDrawing,
                      ),
                      const SizedBox(height: 8),
                      _DrawBtn(
                        heroTag: 'clear',
                        icon: Icons.delete,
                        tooltip: 'مسح الرسم',
                        color: Colors.red,
                        active: false,
                        onPressed: clearCurrentDrawing,
                      ),
                      const SizedBox(height: 8),
                      _DrawBtn(
                        heroTag: 'kml',
                        icon: Icons.file_download,
                        tooltip: 'تصدير KML',
                        color: Colors.blue,
                        active: false,
                        onPressed: exportLastDrawing,
                      ),
                    ],
                  ),
                ),

                // ── 5. Measurement result label ──────────────────────────────
                if (drawingMode && measurementLabel.isNotEmpty)
                  Positioned(
                    bottom: 160,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004D40).withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          measurementLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── 6. Kilometer card ────────────────────────────────────────
                if (selectedDrain != null && selectedPoint != null)
                  Positioned(
                    bottom: 160,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF004D40).withValues(alpha: 0.93),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.straighten,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ك ${selectedKm.toStringAsFixed(3)} كم',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── 7. Drain info popup ──────────────────────────────────────
                if (selectedDrain != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: const BoxDecoration(
                        color: Color(0xFF004D40),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00332B),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.water,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    getProperty([
                                      'drain_name',
                                      'name',
                                      'DRAIN_NAME',
                                      'NAME',
                                    ]),
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedDrain = null;
                                      selectedPoint = null;
                                      selectedKm = 0;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Info rows
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  buildInfoRow(
                                    'هندسة الصرف',
                                    getProperty([
                                      'drainage_engineering',
                                      'DRAINAGE_ENGINEERING',
                                    ]),
                                    false,
                                  ),
                                  buildInfoRow(
                                    'إدارة الصرف',
                                    getProperty([
                                      'drainage_admin',
                                      'DRAINAGE_ADMIN',
                                    ]),
                                    true,
                                  ),
                                  buildInfoRow(
                                    'رقم المصرف',
                                    getProperty([
                                      'drain_id',
                                      'DRAIN_ID',
                                      'id',
                                    ]),
                                    false,
                                  ),
                                  buildInfoRow(
                                    'الكيلومتراج',
                                    '${selectedKm.toStringAsFixed(3)} كم',
                                    true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── 8. Loading overlay when switching layers ─────────────────
                if (drawingMode)
                  Positioned(
                    top: 110,
                    left: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _drawModeLabel(currentMode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _drawModeLabel(DrawMode mode) {
    switch (mode) {
      case DrawMode.polyline:
        return 'وضع رسم الخط — انقر على الخريطة';
      case DrawMode.polygon:
        return 'وضع رسم المضلع — انقر على الخريطة';
      case DrawMode.measureDistance:
        return 'قياس المسافة — انقر على الخريطة';
      case DrawMode.measureArea:
        return 'قياس المساحة — انقر على الخريطة';
      case DrawMode.none:
        return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Helper widget — drawing toolbar button
// ---------------------------------------------------------------------------

class _DrawBtn extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final String tooltip;
  final Color color;
  final bool active;
  final VoidCallback onPressed;

  const _DrawBtn({
    required this.heroTag,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton(
        heroTag: heroTag,
        mini: true,
        backgroundColor: active ? Colors.amber : color,
        onPressed: onPressed,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
