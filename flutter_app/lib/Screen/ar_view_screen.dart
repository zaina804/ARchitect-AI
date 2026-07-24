import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../config.dart';
import '../providers/app_provider.dart';

// ── Building catalogue ────────────────────────────────────────────────────────
const _kBuildings = <Map<String, dynamic>>[
  {'label': 'Single-story House', 'labelAr': 'منزل طابق واحد',    'glb': 'HOUSE1.glb',                 'icon': Icons.home_rounded,           'color': Color(0xFF1A73E8)},
  {'label': 'Two-story House',    'labelAr': 'منزل طابقين',        'glb': 'HOUSE2.glb',                 'icon': Icons.home_work_rounded,      'color': Color(0xFF0D47A1)},
  {'label': 'Residential 4F',    'labelAr': 'سكني 4 طوابق',       'glb': 'Residential building4.glb',  'icon': Icons.apartment_rounded,      'color': Color(0xFF00897B)},
  {'label': 'Residential 5F',    'labelAr': 'سكني 5 طوابق',       'glb': 'Residential building5.glb',  'icon': Icons.apartment_rounded,      'color': Color(0xFF00695C)},
  {'label': 'Residential 6F',    'labelAr': 'سكني 6 طوابق',       'glb': 'Residential building6.glb',  'icon': Icons.apartment_rounded,      'color': Color(0xFF004D40)},
  {'label': 'Hospital',           'labelAr': 'مستشفى',             'glb': 'Hospital.glb',               'icon': Icons.local_hospital_rounded, 'color': Color(0xFFD32F2F)},
  {'label': 'Cafe',               'labelAr': 'كافيه',              'glb': 'Cafe.glb',                   'icon': Icons.local_cafe_rounded,     'color': Color(0xFF6D4C41)},
  {'label': 'Children School',    'labelAr': 'مدرسة أطفال',       'glb': 'children school.glb',        'icon': Icons.school_rounded,         'color': Color(0xFF7B1FA2)},
  {'label': 'Glass Skyscraper',   'labelAr': 'ناطحة سحاب زجاجية', 'glb': 'Glass skyscrapers.glb',      'icon': Icons.location_city_rounded,  'color': Color(0xFF00BCD4)},
];
// ─────────────────────────────────────────────────────────────────────────────

class ArViewScreen extends StatefulWidget {
  const ArViewScreen({super.key});
  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends State<ArViewScreen> {
  // ── ARCore managers ───────────────────────────────────────────────────────
  ARSessionManager? _sessionMgr;
  ARObjectManager?  _objectMgr;
  ARAnchorManager?  _anchorMgr;

  // ── AR + detection state ──────────────────────────────────────────────────
  bool   _arReady      = false;
  bool   _detecting    = false;
  bool   _busy         = false;
  bool   _detected     = false;
  bool   _placeAnyMode = false;
  double _confidence   = 0.0;
  String _statusMsg    = 'Initializing AR…';
  int    _detectGen    = 0;

  // ── Placed model ──────────────────────────────────────────────────────────
  ARNode?        _placedNode;
  ARPlaneAnchor? _placedAnchor;
  bool           _modelPlaced  = false;
  bool           _placingModel = false;
  String         _loadingLabel = '';
  double         _modelScale   = 0.08;

  // ── GLB download cache (filenames already saved to documents dir) ─────────
  final Set<String> _glbCache = {};

  // ── Camera zoom ───────────────────────────────────────────────────────────
  double _zoomLevel = 1.0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _detecting = false;
    _detectGen++;
    _sessionMgr?.dispose();
    super.dispose();
  }

  // ── ARView ready callback ─────────────────────────────────────────────────
  void _onARViewCreated(
    ARSessionManager  sessionManager,
    ARObjectManager   objectManager,
    ARAnchorManager   anchorManager,
    ARLocationManager locationManager,
  ) {
    _sessionMgr = sessionManager;
    _objectMgr  = objectManager;
    _anchorMgr  = anchorManager;

    _sessionMgr!.onInitialize(
      showAnimatedGuide: false,
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
    );
    _objectMgr!.onInitialize();
    _sessionMgr!.onPlaneOrPointTap = _onPlaneTap;

    if (mounted) {
      setState(() {
        _arReady   = true;
        _detecting = true;
        _statusMsg = 'Slowly move camera over the ground to scan it';
      });
      _detectLoop();
    }
  }

  // ── YOLO detection loop ───────────────────────────────────────────────────
  Future<void> _detectLoop() async {
    final gen = ++_detectGen;
    while (_detecting && mounted && _detectGen == gen) {
      await _detectLand();
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<Uint8List> _resizeForYolo(Uint8List raw) async {
    final codec = await ui.instantiateImageCodec(
        raw, targetWidth: 640, targetHeight: 480);
    final frame = await codec.getNextFrame();
    final bd = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return bd!.buffer.asUint8List();
  }

  Future<void> _detectLand() async {
    if (!_detecting || _sessionMgr == null || !mounted || _busy || _placingModel || _modelPlaced) return;
    _busy = true;
    try {
      final imgProvider = await _sessionMgr!.snapshot();
      if (!mounted || _modelPlaced) return;
      final Uint8List raw = (imgProvider as MemoryImage).bytes;

      final Uint8List bytes = await _resizeForYolo(raw);
      if (!mounted || _modelPlaced) return;

      final request = http.MultipartRequest(
          'POST', Uri.parse('$serverBaseUrl/detect'));
      request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: 'frame.png'));

      final response =
          await request.send().timeout(const Duration(seconds: 20));
      final body = await response.stream.bytesToString();
      if (!mounted || _modelPlaced) return;

      final data = jsonDecode(body) as Map<String, dynamic>;
      final land = data['is_empty_land'] == true;
      final conf = (data['confidence'] as num? ?? 0).toDouble();

      if (mounted) {
        setState(() {
          _detected   = land;
          _confidence = conf;
          // When land is detected, instruct user to tap the green dot to place
          _statusMsg = land
              ? 'Empty land detected ${(conf * 100).round()}% — tap the ● to place a building'
              : 'Scanning… (${(conf * 100).round()}%)';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMsg = 'Server unreachable — check WiFi & server');
    } finally {
      _busy = false;
    }
  }

  // ── Tap on AR surface ─────────────────────────────────────────────────────
  Future<void> _onPlaneTap(List<ARHitTestResult> hits) async {
    if (!mounted) return;

    // ── Model already placed: tap a plane to reposition ───────────────────
    if (_modelPlaced) {
      final planeHits = hits.where((h) => h.type == ARHitTestResultType.plane).toList();
      if (planeHits.isNotEmpty) _repositionBuilding(planeHits.first);
      return;
    }

    // Require YOLO confirmation unless PlaceAnyMode bypasses it
    if (!_detected && !_placeAnyMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aim at empty land and wait for detection, or enable "Place Anywhere"'),
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    // Prefer a real detected plane (most stable anchor).
    // Fall back to any hit type (feature points) when YOLO already confirmed
    // the land — ARCore may not have built a full plane mesh yet.
    final planeHits = hits.where((h) => h.type == ARHitTestResultType.plane).toList();
    final bestHit   = planeHits.isNotEmpty ? planeHits.first
                    : hits.isNotEmpty      ? hits.first
                    : null;

    if (bestHit == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Point the camera directly at the ground and tap again'),
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    // Stop detection and show picker anchored to this hit
    setState(() => _detecting = false);
    _showBuildingPicker(bestHit);
  }

  // ── Building picker — always uses the real plane hit for anchoring ────────
  void _showBuildingPicker(ARHitTestResult hit) {
    final isAr = context.read<AppProvider>().locale.languageCode == 'ar';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1A0B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isAr ? 'اختر نوع المبنى' : 'Choose Building Type',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ..._kBuildings.map((b) => _BuildingTile(
              label: isAr ? b['labelAr'] as String : b['label'] as String,
              icon:  b['icon']  as IconData,
              color: b['color'] as Color,
              onTap: () {
                Navigator.pop(context);
                // Place anchored to the real plane — no floating
                _placeBuilding(hit, b['glb'] as String);
              },
            )),
          ],
        ),
      ),
    ).whenComplete(() {
      // User dismissed without choosing — resume scanning
      if (!_modelPlaced && !_placingModel && mounted) {
        setState(() {
          _detecting = true;
          _detected  = false;
          _statusMsg = 'Point camera at empty land…';
        });
        _detectLoop();
      }
    });
  }

  // ── Download GLB to app documents dir, return filename on success ─────────
  Future<String?> _downloadGlb(String glbName) async {
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$glbName');
      if (!_glbCache.contains(glbName) || !await file.exists()) {
        final encoded  = Uri.encodeComponent(glbName);
        final response = await http
            .get(Uri.parse('$serverBaseUrl/models/$encoded'))
            .timeout(const Duration(seconds: 120));
        if (response.statusCode != 200) return null;
        await file.writeAsBytes(response.bodyBytes);
        _glbCache.add(glbName);
      }
      return glbName; // plugin expects just the filename, not the full path
    } catch (_) {
      return null;
    }
  }

  // ── Place GLB anchored to a real ARCore plane ─────────────────────────────
  Future<void> _placeBuilding(ARHitTestResult hit, String glbName) async {
    if (_sessionMgr == null || _objectMgr == null || _anchorMgr == null) return;
    setState(() { _placingModel = true; _loadingLabel = 'Downloading model…'; });

    // Download GLB to local storage so ARCore can anchor it properly
    final localName = await _downloadGlb(glbName);
    if (localName == null) {
      setState(() {
        _placingModel = false;
        _loadingLabel = '';
        _detecting    = true;
        _statusMsg    = 'Download failed — check WiFi & server';
      });
      _detectLoop();
      return;
    }

    setState(() => _loadingLabel = 'Placing model…');

    // Create anchor at the exact 3-D point the user tapped
    final anchor   = ARPlaneAnchor(transformation: hit.worldTransform);
    final anchored = await _anchorMgr!.addAnchor(anchor);
    if (anchored != true) {
      setState(() {
        _placingModel = false;
        _loadingLabel = '';
        _detecting    = true;
        _statusMsg    = 'Anchor failed — tap the flat surface again';
      });
      _detectLoop();
      return;
    }

    final node = ARNode(
      type:     NodeType.fileSystemAppFolderGLB,
      uri:      localName,
      scale:    Vector3(_modelScale, _modelScale, _modelScale),
      position: Vector3(0.0, 0.0, 0.0),
      rotation: Vector4(1.0, 0.0, 0.0, 0.0),
    );

    final placed = await _objectMgr!.addNode(node, planeAnchor: anchor);
    if (placed == true) {
      _placedNode   = node;
      _placedAnchor = anchor;
      setState(() {
        _modelPlaced  = true;
        _placingModel = false;
        _loadingLabel = '';
        _statusMsg    = 'Building anchored! Tap any flat surface to reposition';
      });
    } else {
      await _anchorMgr!.removeAnchor(anchor);
      setState(() {
        _placingModel = false;
        _loadingLabel = '';
        _detecting    = true;
        _statusMsg    = 'Model failed to load — tap again';
      });
      _detectLoop();
    }
  }

  // ── Reposition already-placed building to a new plane hit ─────────────────
  Future<void> _repositionBuilding(ARHitTestResult hit) async {
    if (_objectMgr == null || _anchorMgr == null) return;

    // Save URI BEFORE nullifying the node reference
    final uri = _placedNode?.uri ?? '';

    // Remove old placement
    if (_placedNode   != null) _objectMgr?.removeNode(_placedNode!);
    if (_placedAnchor != null) _anchorMgr?.removeAnchor(_placedAnchor!);
    _placedNode   = null;
    _placedAnchor = null;

    if (uri.isEmpty) {
      setState(() {
        _modelPlaced = false;
        _detecting   = true;
        _statusMsg   = 'Point camera at empty land…';
      });
      _detectLoop();
      return;
    }

    setState(() { _placingModel = true; _loadingLabel = 'Repositioning…'; });

    final anchor   = ARPlaneAnchor(transformation: hit.worldTransform);
    final anchored = await _anchorMgr!.addAnchor(anchor);
    if (anchored != true) {
      setState(() {
        _modelPlaced  = false;
        _placingModel = false;
        _loadingLabel = '';
        _statusMsg    = 'Anchor failed — tap flat surface again';
      });
      return;
    }

    final node = ARNode(
      type:     NodeType.fileSystemAppFolderGLB,
      uri:      uri,
      scale:    Vector3(_modelScale, _modelScale, _modelScale),
      position: Vector3(0.0, 0.0, 0.0),
      rotation: Vector4(1.0, 0.0, 0.0, 0.0),
    );

    final placed = await _objectMgr!.addNode(node, planeAnchor: anchor);
    if (placed == true) {
      _placedNode   = node;
      _placedAnchor = anchor;
      setState(() {
        _modelPlaced  = true;
        _placingModel = false;
        _loadingLabel = '';
        _statusMsg    = 'Repositioned! Tap again to move';
      });
    } else {
      await _anchorMgr!.removeAnchor(anchor);
      setState(() {
        _modelPlaced  = false;
        _placingModel = false;
        _loadingLabel = '';
        _detecting    = true;
        _statusMsg    = 'Reposition failed — tap again';
      });
      _detectLoop();
    }
  }

  // ── Camera zoom ───────────────────────────────────────────────────────────
  void _applyZoom(double level) {
    final clamped = level.clamp(1.0, 8.0);
    setState(() => _zoomLevel = clamped);
    _sessionMgr?.setZoom(clamped);
  }

  // ── Resize placed model ───────────────────────────────────────────────────
  void _changeScale(double v) {
    setState(() => _modelScale = v);
    _placedNode?.scale = Vector3(v, v, v);
  }

  // ── Rescan ────────────────────────────────────────────────────────────────
  void _onRescan() {
    if (_placedNode   != null) _objectMgr?.removeNode(_placedNode!);
    if (_placedAnchor != null) _anchorMgr?.removeAnchor(_placedAnchor!);
    setState(() {
      _placedNode   = null;
      _placedAnchor = null;
      _modelPlaced  = false;
      _detected     = false;
      _detecting    = true;
      _loadingLabel = '';
      _statusMsg    = 'Point camera at empty land…';
    });
    _detectLoop();
  }

  // ── Change building ───────────────────────────────────────────────────────
  void _onChangeBuilding() {
    if (_placedNode   != null) _objectMgr?.removeNode(_placedNode!);
    if (_placedAnchor != null) _anchorMgr?.removeAnchor(_placedAnchor!);
    setState(() {
      _placedNode   = null;
      _placedAnchor = null;
      _modelPlaced  = false;
      _detected     = true;  // land still detected, user just wants a different building
      _detecting    = false;
      _loadingLabel = '';
      _statusMsg    = 'Tap the land to place a new building';
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAr   = context.watch<AppProvider>().locale.languageCode == 'ar';
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ── 1. ARCore view ─────────────────────────────────────────────────
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // ── 2. Top bar ─────────────────────────────────────────────────────
          Positioned(
            top: topPad + 8, left: 12, right: 12,
            child: Row(
              children: [
                _TopBtn(
                  icon:  Icons.arrow_back_ios_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.view_in_ar_rounded,
                            color: Color(0xFF00E676), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _loadingLabel.isNotEmpty
                                ? _loadingLabel
                                : 'AR — Google ARCore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Center reticle (IgnorePointer so taps reach the AR view) ───
          if (_arReady && !_modelPlaced)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: _Reticle(detected: _detected || _placeAnyMode),
                ),
              ),
            ),

          // ── Place Anywhere toggle ──────────────────────────────────────────
          if (_arReady && !_modelPlaced)
            Positioned(
              top: topPad + 8, right: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _placeAnyMode = !_placeAnyMode;
                    if (_placeAnyMode) {
                      _detected  = true;
                      _detecting = false;
                      _statusMsg = 'Test mode: tap any flat surface to place';
                    } else {
                      _detected  = false;
                      _detecting = true;
                      _statusMsg = 'Point camera at empty land…';
                    }
                  });
                  if (!_placeAnyMode) _detectLoop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _placeAnyMode
                        ? const Color(0xFFFF9800)
                        : Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _placeAnyMode
                          ? const Color(0xFFFF9800)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _placeAnyMode
                            ? Icons.lock_open_rounded
                            : Icons.lock_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _placeAnyMode ? 'Test Mode ON' : 'Place Anywhere',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── 4. Zoom controls — always visible once AR is ready ─────────────
          if (_arReady)
            Positioned(
              right: 12,
              top: topPad + 60,
              child: Column(
                children: [
                  _ZoomBtn(
                    icon: Icons.zoom_in_rounded,
                    onTap: () => _applyZoom(_zoomLevel + 0.5),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_zoomLevel.toStringAsFixed(1)}×',
                      style: const TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ZoomBtn(
                    icon: Icons.zoom_out_rounded,
                    onTap: () => _applyZoom(_zoomLevel - 0.5),
                  ),
                  if (_zoomLevel > 1.0) ...[
                    const SizedBox(height: 6),
                    _ZoomBtn(
                      icon: Icons.center_focus_strong_rounded,
                      onTap: () => _applyZoom(1.0),
                      color: const Color(0xFF1A73E8),
                    ),
                  ],
                ],
              ),
            ),

          // ── 5. Loading overlay ─────────────────────────────────────────────
          if (_placingModel)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.65),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF00E676),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading building model…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This may take a few seconds',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // ── 6. Status bar ──────────────────────────────────────────────────
          if (_arReady)
            Positioned(
              bottom: botPad + (_modelPlaced ? 110 : 24),
              left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: _detected
                      ? const Color(0xDD001800)
                      : Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _detected
                        ? const Color(0xFF00E676)
                        : Colors.white24,
                    width: _detected ? 1.5 : 1.0,
                  ),
                  boxShadow: _detected
                      ? const [BoxShadow(
                          color: Color(0x4400E676),
                          blurRadius: 14,
                          spreadRadius: 2,
                        )]
                      : null,
                ),
                child: Row(
                  children: [
                    if (_detected)
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF00E676), size: 20)
                    else
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMsg,
                        style: TextStyle(
                          color: _detected
                              ? const Color(0xFF00E676)
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: _detected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 7. Controls after model placed ─────────────────────────────────
          if (_modelPlaced)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, botPad + 14),
                decoration: const BoxDecoration(
                  color: Color(0xDD0B1215),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scale slider + tap icons
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _changeScale((_modelScale / 1.25).clamp(0.01, 100.0)),
                          child: const Icon(Icons.zoom_out_rounded,
                              color: Colors.white, size: 22),
                        ),
                        Expanded(
                          child: Slider(
                            value: _modelScale,
                            min: 0.01,
                            max: 100.0,
                            divisions: 200,
                            activeColor: const Color(0xFF00E676),
                            inactiveColor: Colors.white24,
                            onChanged: _changeScale,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _changeScale((_modelScale * 1.25).clamp(0.01, 100.0)),
                          child: const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(_modelScale * 100).round()}%',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CtrlBtn(
                          icon:  Icons.swap_horiz_rounded,
                          label: isAr ? 'تغيير' : 'Change',
                          color: const Color(0xFF1A73E8),
                          onTap: _onChangeBuilding,
                        ),
                        _CtrlBtn(
                          icon:  Icons.refresh_rounded,
                          label: isAr ? 'إعادة' : 'Rescan',
                          color: Colors.redAccent,
                          onTap: _onRescan,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Shared sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════
class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _ZoomBtn({required this.icon, required this.onTap,
      this.color = Colors.white});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
  );
}

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    ),
  );
}

class _BuildingTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BuildingTile({required this.label, required this.icon,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: color.withOpacity(0.7)),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Animated reticle
// ═══════════════════════════════════════════════════════════════════════════════
class _Reticle extends StatefulWidget {
  final bool detected;
  const _Reticle({required this.detected});
  @override
  State<_Reticle> createState() => _ReticleState();
}

class _ReticleState extends State<_Reticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.detected
        ? const Color(0xFF00E676)
        : Colors.white54;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: widget.detected ? _pulse.value : 1.0,
        child: CustomPaint(
          size: const Size(80, 80),
          painter: _ReticlePainter(color: color),
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 4;
    final p  = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(cx, cy), r, p);

    const sweep = 0.5;
    const gap   = 0.3;
    for (int i = 0; i < 4; i++) {
      final start = i * (3.14159 / 2) + gap;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep, false,
        p..strokeWidth = 3.5,
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      3,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.color != color;
}
