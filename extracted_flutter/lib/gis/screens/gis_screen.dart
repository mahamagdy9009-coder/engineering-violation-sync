import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../database/database_service.dart';
import '../../models/case_filter.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class DrainFeature {
  final List<LatLng> points;
  final Map<String, dynamic> properties;
  DrainFeature({required this.points, required this.properties});
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

enum DrawMode { none, polyline, polygon, measureDistance, measureArea }

/// Extended drawing model — holds editable feature properties.
class GisDrawing {
  final String id;
  String name;
  String projectType;
  String description;
  String offenderName;
  String reportNumber;
  String reportYear;
  String notes;
  final DrawMode type;
  final List<LatLng> points;
  Color color;

  GisDrawing({
    required this.id,
    required this.name,
    required this.type,
    required this.points,
    required this.color,
    this.projectType = '',
    this.description = '',
    this.offenderName = '',
    this.reportNumber = '',
    this.reportYear = '',
    this.notes = '',
  });

  /// Converts this drawing's geometry to a GeoJSON Feature string.
  String toGeoJson() {
    final coords = points
        .map((p) => '[${p.longitude}, ${p.latitude}]')
        .join(', ');

    final isPolygon =
        type == DrawMode.polygon || type == DrawMode.measureArea;

    final geometryType = isPolygon ? 'Polygon' : 'LineString';
    final coordsWrapped = isPolygon ? '[[$coords]]' : '[$coords]';

    return jsonEncode({
      'type': 'Feature',
      'geometry': {
        'type': geometryType,
        'coordinates': jsonDecode(coordsWrapped),
      },
      'properties': {
        'name': name,
        'projectType': projectType,
        'description': description,
        'offenderName': offenderName,
        'reportNumber': reportNumber,
        'reportYear': reportYear,
        'notes': notes,
      },
    });
  }
}

// ---------------------------------------------------------------------------
// GisScreen widget
// ---------------------------------------------------------------------------

class GisScreen extends StatefulWidget {
  const GisScreen({
    super.key,
    this.initialCenter,
    this.initialZoom,
    this.jumpToDrainName,
    this.initialKilometer,
  });

  /// If set, the map opens at this position (used when navigating from a case).
  final LatLng? initialCenter;

  /// Zoom level when navigating from a case (defaults to 16).
  final double? initialZoom;

  /// If set, the GIS screen will auto-search and highlight this drain after loading.
  final String? jumpToDrainName;

  /// Pre-filled kilometer value when coming from a case.
  final String? initialKilometer;

  @override
  State<GisScreen> createState() => _GisScreenState();
}

class _GisScreenState extends State<GisScreen> {
  // ── controllers ──────────────────────────────────────────────────────────
  final MapController mapController = MapController();
  final Distance distance = const Distance();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController coordinateController = TextEditingController();

  // ── drain data ────────────────────────────────────────────────────────────
  final List<DrainFeature> drains = [];
  bool isLoading = true;

  // ── map state ─────────────────────────────────────────────────────────────
  bool satelliteMode = true;
  DrainFeature? selectedDrain;
  LatLng? selectedPoint;
  double selectedKm = 0;

  // ── drawing state ─────────────────────────────────────────────────────────
  DrawMode currentMode = DrawMode.none;
  bool drawingMode = false;
  List<LatLng> currentDrawingPoints = [];
  final List<LatLng> _redoStack = []; // for undo/redo
  List<GisDrawing> savedDrawings = [];
  GisDrawing? _editingDrawing; // drawing whose properties popup is open

  // ── filter ────────────────────────────────────────────────────────────────
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
  String safeValue(dynamic value) => value == null ? '-' : value.toString();

  // ── GeoJSON loading ───────────────────────────────────────────────────────
  Future<void> loadGeoJson() async {
    try {
      drains.clear();

      final jsonString = await rootBundle.loadString(
        'assets/gis/central_egypt_drainage_drains.geojson',
      );

      final data = jsonDecode(jsonString);
      for (final feature in data['features']) {
        final geometry = feature['geometry'];
        if (geometry == null) continue;

        final type = geometry['type'];
        final properties = Map<String, dynamic>.from(
          feature['properties'] ?? {},
        );

        final eng =
            safeValue(properties['drainage_engineering']).toLowerCase();
        final admin = safeValue(properties['drainage_admin']).toLowerCase();

        final isBeniSuef = eng.contains('الفشن') ||
            eng.contains('الواسطى') ||
            eng.contains('ناصر') ||
            eng.contains('بني سويف') ||
            eng.contains('اهناسيا') ||
            eng.contains('ببا') ||
            eng.contains('سمسطا') ||
            admin.contains('بني سويف');

        if (!isBeniSuef) continue;

        void addLine(List<dynamic> coords) {
          final points = coords.map<LatLng>((c) {
            return LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            );
          }).toList();
          drains.add(DrainFeature(points: points, properties: properties));
        }

        if (type == 'LineString') {
          addLine(geometry['coordinates']);
        } else if (type == 'MultiLineString') {
          for (final line in geometry['coordinates']) {
            addLine(line);
          }
        }
      }
    } catch (e) {
      debugPrint('GIS ERROR => $e');
    }

    setState(() => isLoading = false);

    // Auto-navigate if coming from a case
    if (widget.initialCenter != null) {
      mapController.move(
        widget.initialCenter!,
        widget.initialZoom ?? 16,
      );
    }

    // Auto-search drain name if navigating from case details
    if (widget.jumpToDrainName != null && widget.jumpToDrainName!.isNotEmpty) {
      searchController.text = widget.jumpToDrainName!;
      searchDrain();
    }
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
      final segLen = distance.as(LengthUnit.Meter, a, b);
      final t = projectFactor(tapPoint, a, b);
      final projected = interpolate(a, b, t);
      final d = distance.as(LengthUnit.Meter, tapPoint, projected);

      if (d < bestDistance) {
        bestDistance = d;
        bestPoint = projected;
        bestCumulative = cumulativeMeters + (segLen * t);
      }
      cumulativeMeters += segLen;
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
    // Drawing mode: accumulate points, clear redo history
    if (drawingMode) {
      setState(() {
        currentDrawingPoints.add(point);
        _redoStack.clear();
      });
      return;
    }

    // Check if tap is near a saved drawing vertex (20 m threshold)
    for (final drawing in savedDrawings.reversed) {
      for (final p in drawing.points) {
        if (distance.as(LengthUnit.Meter, point, p) < 20) {
          _openFeaturePropertiesDialog(drawing);
          return;
        }
      }
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
      final parts = coordinateController.text.trim().split(',');
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

  String get measurementLabel {
    if (!drawingMode && currentDrawingPoints.isEmpty) return '';
    if (currentMode == DrawMode.measureDistance ||
        currentMode == DrawMode.polyline) {
      if (currentDrawingPoints.length < 2) return 'أضف نقاط للقياس';
      final m = calculateDistance(currentDrawingPoints);
      return m >= 1000
          ? 'المسافة: ${(m / 1000).toStringAsFixed(3)} كم'
          : 'المسافة: ${m.toStringAsFixed(1)} م';
    }
    if (currentMode == DrawMode.measureArea ||
        currentMode == DrawMode.polygon) {
      if (currentDrawingPoints.length < 3) return 'أضف 3 نقاط على الأقل';
      final a = calculatePolygonArea(currentDrawingPoints);
      return a >= 1000000
          ? 'المساحة: ${(a / 1000000).toStringAsFixed(4)} كم²'
          : 'المساحة: ${a.toStringAsFixed(1)} م²';
    }
    return '';
  }

  // ── drawing controls ──────────────────────────────────────────────────────
  void startDrawing(DrawMode mode) {
    setState(() {
      currentMode = mode;
      drawingMode = true;
      currentDrawingPoints.clear();
      _redoStack.clear();
    });
  }

  void undoPoint() {
    if (currentDrawingPoints.isEmpty) return;
    setState(() {
      _redoStack.add(currentDrawingPoints.removeLast());
    });
  }

  void redoPoint() {
    if (_redoStack.isEmpty) return;
    setState(() {
      currentDrawingPoints.add(_redoStack.removeLast());
    });
  }

  void finishDrawing() {
    if (currentDrawingPoints.isEmpty) return;

    final drawing = GisDrawing(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'رسم جديد',
      type: currentMode,
      points: List.from(currentDrawingPoints),
      color: Colors.orange,
    );

    savedDrawings.add(drawing);

    setState(() {
      drawingMode = false;
      currentMode = DrawMode.none;
      currentDrawingPoints.clear();
      _redoStack.clear();
    });

    // Open properties dialog immediately after finishing
    _openFeaturePropertiesDialog(drawing);
  }

  void clearCurrentDrawing() {
    setState(() {
      currentDrawingPoints.clear();
      _redoStack.clear();
      drawingMode = false;
      currentMode = DrawMode.none;
    });
  }

  // ── feature properties dialog ─────────────────────────────────────────────
  void _openFeaturePropertiesDialog(GisDrawing drawing) {
    setState(() => _editingDrawing = drawing);

    final nameCtrl = TextEditingController(text: drawing.name);
    final typeCtrl = TextEditingController(text: drawing.projectType);
    final descCtrl = TextEditingController(text: drawing.description);
    final offenderCtrl = TextEditingController(text: drawing.offenderName);
    final reportNumCtrl = TextEditingController(text: drawing.reportNumber);
    final reportYearCtrl = TextEditingController(text: drawing.reportYear);
    final notesCtrl = TextEditingController(text: drawing.notes);
    Color selectedColor = drawing.color;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: const Color(0xFF003A30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 560, maxHeight: 700),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Icon(Icons.edit_location_alt,
                                color: Colors.amber),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'خصائص العنصر',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _GisTextField(
                                  label: 'اسم الشكل',
                                  controller: nameCtrl,
                                ),
                                _GisTextField(
                                  label: 'نوع المشروع',
                                  controller: typeCtrl,
                                ),
                                _GisTextField(
                                  label: 'وصف',
                                  controller: descCtrl,
                                  maxLines: 2,
                                ),
                                _GisTextField(
                                  label: 'اسم المخالف',
                                  controller: offenderCtrl,
                                ),
                                _GisTextField(
                                  label: 'رقم المحضر',
                                  controller: reportNumCtrl,
                                ),
                                _GisTextField(
                                  label: 'سنة المحضر',
                                  controller: reportYearCtrl,
                                ),
                                _GisTextField(
                                  label: 'ملاحظات',
                                  controller: notesCtrl,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 10),
                                // Color picker row
                                Row(
                                  children: [
                                    const Text(
                                      'لون الشكل:',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                    ),
                                    const SizedBox(width: 12),
                                    ...[
                                      Colors.orange,
                                      Colors.red,
                                      Colors.blue,
                                      Colors.green,
                                      Colors.purple,
                                      Colors.yellow,
                                    ].map((c) {
                                      final selected = selectedColor == c;
                                      return GestureDetector(
                                        onTap: () =>
                                            setLocal(() => selectedColor = c),
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          margin: const EdgeInsets.only(
                                              left: 6),
                                          decoration: BoxDecoration(
                                            color: c,
                                            shape: BoxShape.circle,
                                            border: selected
                                                ? Border.all(
                                                    color: Colors.white,
                                                    width: 3,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white54,
                                side: const BorderSide(color: Colors.white24),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('إلغاء'),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00897B),
                              ),
                              icon: const Icon(Icons.save),
                              label: const Text('حفظ الخصائص'),
                              onPressed: () {
                                setState(() {
                                  drawing.name = nameCtrl.text.trim().isEmpty
                                      ? 'رسم جديد'
                                      : nameCtrl.text.trim();
                                  drawing.projectType = typeCtrl.text.trim();
                                  drawing.description = descCtrl.text.trim();
                                  drawing.offenderName =
                                      offenderCtrl.text.trim();
                                  drawing.reportNumber =
                                      reportNumCtrl.text.trim();
                                  drawing.reportYear =
                                      reportYearCtrl.text.trim();
                                  drawing.notes = notesCtrl.text.trim();
                                  drawing.color = selectedColor;
                                  _editingDrawing = null;
                                });
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) setState(() => _editingDrawing = null);
    });
  }

  // ── export menu ───────────────────────────────────────────────────────────
  void _showExportMenu(BuildContext context, Offset offset) async {
    if (savedDrawings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد رسومات محفوظة')),
      );
      return;
    }

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 1,
        offset.dy + 1,
      ),
      color: const Color(0xFF003A30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _menuItem('kml', Icons.download_outlined, 'تصدير KML'),
        _menuItem('violation', Icons.report_outlined, 'حفظ كموقع مخالفة'),
        _menuItem('legalization', Icons.check_circle_outline,
            'حفظ كموقع تقنين'),
        _menuItem('project', Icons.folder_outlined, 'حفظ كمشروع'),
      ],
    );

    if (!mounted || result == null) return;

    switch (result) {
      case 'kml':
        await _exportKml();
      case 'violation':
        await _saveAsViolation();
      case 'legalization':
        await _saveWithTag('تقنين');
      case 'project':
        await _saveWithTag('مشروع');
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  // ── KML export (dart:io only) ─────────────────────────────────────────────
  String _generateKml(GisDrawing drawing) {
    final coords = drawing.points
        .map((p) => '${p.longitude},${p.latitude},0')
        .join('\n');
    final isPolygon =
        drawing.type == DrawMode.polygon || drawing.type == DrawMode.measureArea;
    final geoTag = isPolygon
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
    <description>${drawing.description}</description>
    $geoTag
  </Placemark>
</Document>
</kml>''';
  }

  Future<void> _exportKml() async {
    final drawing = savedDrawings.last;
    final kml = _generateKml(drawing);
    try {
      final path =
          '${Directory.current.path}${Platform.pathSeparator}${drawing.name}_${drawing.id}.kml';
      await File(path).writeAsString(kml);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ KML:\n$path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    }
  }

  Future<void> _saveWithTag(String tag) async {
    final drawing = savedDrawings.last;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تسجيل "${drawing.name}" كـ $tag (${drawing.points.length} نقطة)',
        ),
        backgroundColor: const Color(0xFF00695C),
      ),
    );
  }

  // ── save as violation (links to DB case) ──────────────────────────────────
  Future<void> _saveAsViolation() async {
    final drawing = savedDrawings.last;
    final reportNumCtrl = TextEditingController(text: drawing.reportNumber);
    final reportYearCtrl = TextEditingController(text: drawing.reportYear);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF003A30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ربط بمحضر مخالفة',
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل بيانات المحضر لربط هذا الموقع به:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              _GisTextField(
                label: 'رقم المحضر',
                controller: reportNumCtrl,
              ),
              const SizedBox(height: 8),
              _GisTextField(
                label: 'سنة المحضر',
                controller: reportYearCtrl,
              ),
              const SizedBox(height: 12),
              // Summary of what will be saved
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سيتم حفظ:',
                      style: const TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• الموقع الكيلومتري: ${selectedKm.toStringAsFixed(3)} كم',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (selectedPoint != null)
                      Text(
                        '• الإحداثيات: ${selectedPoint!.latitude.toStringAsFixed(6)}, ${selectedPoint!.longitude.toStringAsFixed(6)}',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    Text(
                      '• الهندسة: ${drawing.type == DrawMode.polygon || drawing.type == DrawMode.measureArea ? "مضلع" : "خط"} (${drawing.points.length} نقطة)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
              ),
              icon: const Icon(Icons.link),
              label: const Text('ربط بالمحضر'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final reportNumber = int.tryParse(reportNumCtrl.text.trim());
    final reportYear = int.tryParse(reportYearCtrl.text.trim());

    if (reportNumber == null || reportYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال رقم وسنة صحيحين'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Build the geometry GeoJSON string
    final geometryJson = drawing.toGeoJson();

    try {
      // ── Step 1: find the case in the database by report number + year ──
      final allCases = await DatabaseService.getCases(
        search: reportNumber.toString(),
        filter: CaseFilter(),
      );

      final matchingCase = allCases.where((c) {
        final num = int.tryParse(c['report_number']?.toString() ?? '');
        final year = int.tryParse(c['report_year']?.toString() ?? '');
        return num == reportNumber && year == reportYear;
      }).firstOrNull;

      if (!mounted) return;

      if (matchingCase == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لم يُعثر على محضر رقم $reportNumber لسنة $reportYear في قاعدة البيانات',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final caseId = int.tryParse(matchingCase['id']?.toString() ?? '');

      // ── Step 2: build before/after payloads ───────────────────────────
      final after = Map<String, dynamic>.from(matchingCase)
        ..addAll({
          'kilometer_location': selectedKm.toStringAsFixed(3),
          'gis_geometry': geometryJson,
          if (selectedPoint != null) 'gis_lat': selectedPoint!.latitude,
          if (selectedPoint != null) 'gis_lng': selectedPoint!.longitude,
          if (selectedDrain != null)
            'drain_id': selectedDrain!.properties['drain_id'],
        });

      // ── Step 3: submit as 'update' — the only type allowed by the DB ──
      await DatabaseService.submitCaseChangeRequest(
        requestType: 'update',
        targetId: caseId,
        before: matchingCase,
        after: after,
        requestedBy: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال طلب ربط الموقع للمحضر $reportNumber/$reportYear للمدير ✓',
            ),
            backgroundColor: const Color(0xFF00897B),
          ),
        );
        setState(() {
          drawing.reportNumber = reportNumCtrl.text.trim();
          drawing.reportYear = reportYearCtrl.text.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الإرسال: $e'),
            backgroundColor: Colors.red,
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
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

  String _drawModeLabel(DrawMode mode) {
    switch (mode) {
      case DrawMode.polyline:
        return 'رسم خط — انقر على الخريطة';
      case DrawMode.polygon:
        return 'رسم مضلع — انقر على الخريطة';
      case DrawMode.measureDistance:
        return 'قياس مسافة — انقر على الخريطة';
      case DrawMode.measureArea:
        return 'قياس مساحة — انقر على الخريطة';
      case DrawMode.none:
        return '';
    }
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
                // ─────────────────────────────────────────────────────────
                // 1. FlutterMap — layers only inside children
                // ─────────────────────────────────────────────────────────
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: widget.initialCenter ??
                        const LatLng(28.893, 30.841),
                    initialZoom: widget.initialZoom ?? 11,
                    onTap: handleMapTap,
                  ),
                  children: [
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
                          color: selected ? Colors.amber : Colors.redAccent,
                          strokeWidth: selected ? 5 : 3,
                        );
                      }).toList(),
                    ),

                    // Saved + in-progress drawing polylines
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
                                color: e.color.withValues(alpha: 0.25),
                                borderColor: e.color,
                                borderStrokeWidth: 3,
                              ),
                            ),
                        if (currentDrawingPoints.length >= 3 &&
                            (currentMode == DrawMode.polygon ||
                                currentMode == DrawMode.measureArea))
                          Polygon(
                            points: currentDrawingPoints,
                            color: Colors.orange.withValues(alpha: 0.25),
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
                                border:
                                    Border.all(color: Colors.white, width: 2),
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

                // ─────────────────────────────────────────────────────────
                // 2. Top bar
                // ─────────────────────────────────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: const Color(0xFF00695C).withValues(alpha: 0.95),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        // Back button — only when navigated from another screen
                        if (Navigator.canPop(context)) ...[
                          _IconBtn(
                            icon: Icons.arrow_forward_ios,
                            tooltip: 'رجوع',
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          flex: 3,
                          child: _SearchField(
                            controller: searchController,
                            hint: 'بحث في المصارف...',
                            icon: Icons.search,
                            onSubmit: searchDrain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _SearchField(
                            controller: coordinateController,
                            hint: 'lat, lng',
                            icon: Icons.my_location,
                            onSubmit: searchCoordinates,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _IconBtn(
                          icon: satelliteMode ? Icons.map : Icons.satellite,
                          tooltip: satelliteMode
                              ? 'التبديل إلى OSM'
                              : 'التبديل إلى Satellite',
                          onTap: () =>
                              setState(() => satelliteMode = !satelliteMode),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─────────────────────────────────────────────────────────
                // 3. Engineering filter
                // ─────────────────────────────────────────────────────────
                Positioned(
                  top: 56,
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
                        icon: const Icon(Icons.filter_list, color: Colors.white),
                        items: engineeringFilters.map((f) {
                          return DropdownMenuItem<String>(
                            value: f,
                            child: Text(f),
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

                // ─────────────────────────────────────────────────────────
                // 4. Drawing toolbar (left)
                // ─────────────────────────────────────────────────────────
                Positioned(
                  top: 108,
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
                      const SizedBox(height: 6),
                      _DrawBtn(
                        heroTag: 'polygon',
                        icon: Icons.hexagon,
                        tooltip: 'رسم مضلع',
                        color: const Color(0xFF004D40),
                        active: currentMode == DrawMode.polygon,
                        onPressed: () => startDrawing(DrawMode.polygon),
                      ),
                      const SizedBox(height: 6),
                      _DrawBtn(
                        heroTag: 'measure',
                        icon: Icons.straighten,
                        tooltip: 'قياس مسافة',
                        color: const Color(0xFF004D40),
                        active: currentMode == DrawMode.measureDistance,
                        onPressed: () =>
                            startDrawing(DrawMode.measureDistance),
                      ),
                      const SizedBox(height: 6),
                      _DrawBtn(
                        heroTag: 'area',
                        icon: Icons.square_foot,
                        tooltip: 'قياس مساحة',
                        color: const Color(0xFF004D40),
                        active: currentMode == DrawMode.measureArea,
                        onPressed: () => startDrawing(DrawMode.measureArea),
                      ),
                      const Divider(color: Colors.white24, height: 16),
                      // Undo
                      _DrawBtn(
                        heroTag: 'undo',
                        icon: Icons.undo,
                        tooltip: 'تراجع (Undo)',
                        color: const Color(0xFF004D40),
                        active: false,
                        onPressed: drawingMode ? undoPoint : null,
                      ),
                      const SizedBox(height: 6),
                      // Redo
                      _DrawBtn(
                        heroTag: 'redo',
                        icon: Icons.redo,
                        tooltip: 'إعادة (Redo)',
                        color: const Color(0xFF004D40),
                        active: false,
                        onPressed:
                            (drawingMode && _redoStack.isNotEmpty) ? redoPoint : null,
                      ),
                      const Divider(color: Colors.white24, height: 16),
                      _DrawBtn(
                        heroTag: 'finish',
                        icon: Icons.done,
                        tooltip: 'إنهاء الرسم',
                        color: Colors.green,
                        active: false,
                        onPressed: drawingMode ? finishDrawing : null,
                      ),
                      const SizedBox(height: 6),
                      _DrawBtn(
                        heroTag: 'clear',
                        icon: Icons.delete,
                        tooltip: 'مسح الرسم',
                        color: Colors.red,
                        active: false,
                        onPressed: drawingMode ? clearCurrentDrawing : null,
                      ),
                      const SizedBox(height: 6),
                      // Export menu button
                      Builder(
                        builder: (btnCtx) => _DrawBtn(
                          heroTag: 'export',
                          icon: Icons.file_download,
                          tooltip: 'قائمة التصدير',
                          color: Colors.blue,
                          active: false,
                          onPressed: () {
                            final box = btnCtx.findRenderObject()
                                as RenderBox;
                            final offset =
                                box.localToGlobal(Offset.zero);
                            _showExportMenu(context, offset);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ─────────────────────────────────────────────────────────
                // 5. Drain info popup — floating card top-right
                // ─────────────────────────────────────────────────────────
                if (selectedDrain != null)
                  Positioned(
                    top: 108,
                    right: 12,
                    width: 300,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF004D40),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00332B),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.water,
                                      color: Colors.amber, size: 18),
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
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      selectedDrain = null;
                                      selectedPoint = null;
                                      selectedKm = 0;
                                    }),
                                    child: const Icon(Icons.close,
                                        color: Colors.white54, size: 18),
                                  ),
                                ],
                              ),
                            ),
                            // KM row
                            buildInfoRow(
                              'الكيلومتراج',
                              '${selectedKm.toStringAsFixed(3)} كم',
                              false,
                            ),
                            buildInfoRow(
                              'هندسة الصرف',
                              getProperty([
                                'drainage_engineering',
                                'DRAINAGE_ENGINEERING',
                              ]),
                              true,
                            ),
                            buildInfoRow(
                              'إدارة الصرف',
                              getProperty([
                                'drainage_admin',
                                'DRAINAGE_ADMIN',
                              ]),
                              false,
                            ),
                            buildInfoRow(
                              'رقم المصرف',
                              getProperty(['drain_id', 'DRAIN_ID', 'id']),
                              true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ─────────────────────────────────────────────────────────
                // 6. Drawing mode banner
                // ─────────────────────────────────────────────────────────
                if (drawingMode)
                  Positioned(
                    top: 108,
                    left: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.92),
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

                // ─────────────────────────────────────────────────────────
                // 7. Measurement result label (center bottom)
                // ─────────────────────────────────────────────────────────
                if (drawingMode && measurementLabel.isNotEmpty)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004D40).withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange, width: 1.5),
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

                // ─────────────────────────────────────────────────────────
                // 8. Saved drawings mini-list (bottom-left, collapsible)
                // ─────────────────────────────────────────────────────────
                if (savedDrawings.isNotEmpty && !drawingMode)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: _SavedDrawingsPanel(
                      drawings: savedDrawings,
                      onEdit: _openFeaturePropertiesDialog,
                      onDelete: (d) {
                        setState(() => savedDrawings.remove(d));
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Saved drawings collapsible panel
// ---------------------------------------------------------------------------

class _SavedDrawingsPanel extends StatefulWidget {
  const _SavedDrawingsPanel({
    required this.drawings,
    required this.onEdit,
    required this.onDelete,
  });

  final List<GisDrawing> drawings;
  final void Function(GisDrawing) onEdit;
  final void Function(GisDrawing) onDelete;

  @override
  State<_SavedDrawingsPanel> createState() => _SavedDrawingsPanelState();
}

class _SavedDrawingsPanelState extends State<_SavedDrawingsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF003A30).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.layers, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'الرسومات المحفوظة (${widget.drawings.length})',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    color: Colors.white54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.drawings.length,
                itemBuilder: (context, i) {
                  final d = widget.drawings[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 8,
                      backgroundColor: d.color,
                    ),
                    title: Text(
                      d.name,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => widget.onEdit(d),
                          child: const Icon(Icons.edit,
                              color: Colors.white54, size: 16),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => widget.onDelete(d),
                          child: const Icon(Icons.delete,
                              color: Colors.red, size: 16),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF004D40).withValues(alpha: 0.8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            icon: Icon(icon, color: Colors.white, size: 18),
            onPressed: onSubmit,
          ),
        ),
        onSubmitted: (_) => onSubmit(),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF004D40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _DrawBtn extends StatelessWidget {
  const _DrawBtn({
    required this.heroTag,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.active,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final String tooltip;
  final Color color;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton(
        heroTag: heroTag,
        mini: true,
        backgroundColor:
            onPressed == null ? Colors.grey.shade800 : (active ? Colors.amber : color),
        onPressed: onPressed,
        child: Icon(icon,
            color: onPressed == null ? Colors.white38 : Colors.white,
            size: 20),
      ),
    );
  }
}

class _GisTextField extends StatelessWidget {
  const _GisTextField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF004D40),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.amber),
          ),
        ),
      ),
    );
  }
}
