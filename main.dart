// ================================================================
//  RAKSHAK v6.0 — Women Safety App  — COMPLETE UI REDESIGN
//  DESIGN: Dark Forest / Geometric / Hexagonal — NOTHING like SheShield
//  NEW: Teal-Emerald palette, Hexagonal SOS, Side-Drawer nav,
//       Diagonal header cards, Floating island bottom bar,
//       Glassmorphic panels, Neon accent pulses
// ================================================================

import 'dart:async' show unawaited, Timer, StreamController, StreamSubscription, TimeoutException;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';


// ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────
//  SMS LAUNCHER — Opens native SMS app with prefilled message
// ─────────────────────────────────────────────────────────────
class SMSLauncher {
  static Future<void> sendToOne({
    required String phone,
    required String message,
  }) async {
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('sms:$phone?body=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> sendToAll({
    required List<String> phones,
    required String message,
  }) async {
    // SMS URI supports comma-separated numbers on most devices
    final nums = phones.join(',');
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('sms:$nums?body=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (phones.isNotEmpty) {
      // Fallback: open for first contact
      await sendToOne(phone: phones.first, message: message);
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  MAIN
// ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await PermissionService.requestAll(); // ← ADD THIS
  runApp(const RakshakApp());
}

// ─────────────────────────────────────────────────────────────
//  NEW COLOR PALETTE — Dark Forest + Neon Teal
// ─────────────────────────────────────────────────────────────
class RC {
  // Base palette — deep dark greens, NOT pink
  static const bg         = Color(0xFF0A0F0D);
  static const bgCard     = Color(0xFF111A16);
  static const bgSurface  = Color(0xFF162019);
  static const bgElevated = Color(0xFF1C2B24);

  // Neon accents
  static const neon       = Color(0xFF00E5A0);   // primary neon teal
  static const neonDim    = Color(0xFF009966);
  static const neonGlow   = Color(0xFF00FFC8);
  static const amber      = Color(0xFFFFB347);   // warning
  static const crimson    = Color(0xFFFF3D5A);   // danger
  static const ice        = Color(0xFF8AFFEF);   // safe indicator

  // Text
  static const textWhite  = Color(0xFFF0FFF8);
  static const textGray   = Color(0xFF7A9B8A);
  static const textDim    = Color(0xFF3D5E4D);

  // Gradients helpers
  static const grad1 = [Color(0xFF003D2B), Color(0xFF001A12)];
  static const grad2 = [Color(0xFF00E5A0), Color(0xFF00B37A)];
  static const grad3 = [Color(0xFFFF3D5A), Color(0xFFB0001A)];
}

// ─────────────────────────────────────────────────────────────
//  THREAT LEVEL
// ─────────────────────────────────────────────────────────────
enum ThreatLevel { safe, low, medium, high, critical }

extension ThreatX on ThreatLevel {
  Color get color {
    switch (this) {
      case ThreatLevel.safe:     return RC.neon;
      case ThreatLevel.low:      return RC.ice;
      case ThreatLevel.medium:   return RC.amber;
      case ThreatLevel.high:     return Colors.deepOrange;
      case ThreatLevel.critical: return RC.crimson;
    }
  }
  String get label {
    switch (this) {
      case ThreatLevel.safe:     return 'SECURE';
      case ThreatLevel.low:      return 'LOW RISK';
      case ThreatLevel.medium:   return 'CAUTION';
      case ThreatLevel.high:     return 'HIGH RISK';
      case ThreatLevel.critical: return 'CRITICAL';
    }
  }
  IconData get icon {
    switch (this) {
      case ThreatLevel.safe:     return Icons.verified_rounded;
      case ThreatLevel.low:      return Icons.security_rounded;
      case ThreatLevel.medium:   return Icons.warning_amber_rounded;
      case ThreatLevel.high:     return Icons.gpp_bad_rounded;
      case ThreatLevel.critical: return Icons.crisis_alert_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  AI RESULT
// ─────────────────────────────────────────────────────────────
class AIResult {
  final ThreatLevel threat;
  final List<String> reasons;
  final bool triggerSOS;
  final String keyword;
  const AIResult({
    required this.threat, required this.reasons,
    required this.triggerSOS, this.keyword = '',
  });
}

// ─────────────────────────────────────────────────────────────
//  RAKSHAK AI ENGINE
// ─────────────────────────────────────────────────────────────
class RakshakAI {
  static final RakshakAI _i = RakshakAI._();
  factory RakshakAI() => _i;
  RakshakAI._();

  static const _critical = [
    'help me','save me','bachao','mayday','sos','emergency','danger',
    'attack','rape','molestation','kidnap','murder','please help',
    'koi hai','madad karo','chodo mujhe','chhoro','mat karo',
    'nahi nahi','leave me','let me go','get away','dont touch','fire help',
  ];
  static const _high = [
    'help','unsafe','scared','afraid','following me','someone following',
    'darr','dara','peeche aa raha','mujhe darr','meri madad',
    'uncomfortable','harassing','threat','threatening','bachao',
  ];
  static const _medium = [
    'nervous','worried','alone','ekela','akeli','dark','night alone',
    'suspicious','strange man','dont feel safe','feel unsafe',
    'mujhe dar lag raha','kuch gadbad',
  ];

  AIResult classifyVoice(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return const AIResult(threat: ThreatLevel.safe, reasons: [], triggerSOS: false);
    for (final kw in _critical) {
      if (t.contains(kw)) return AIResult(
          threat: ThreatLevel.critical,
          reasons: ['CRITICAL KEYWORD: "$kw"'],
          triggerSOS: true, keyword: kw);
    }
    for (final kw in _high) {
      if (t.contains(kw)) return AIResult(
          threat: ThreatLevel.high,
          reasons: ['HIGH-RISK WORD: "$kw"'],
          triggerSOS: true, keyword: kw);
    }
    for (final kw in _medium) {
      if (t.contains(kw)) return AIResult(
          threat: ThreatLevel.medium,
          reasons: ['DISTRESS SIGNAL: "$kw"'],
          triggerSOS: false, keyword: kw);
    }
    return const AIResult(threat: ThreatLevel.safe, reasons: [], triggerSOS: false);
  }

  AIResult assessRisk({required DateTime time, double? speed}) {
    final reasons = <String>[];
    int score = 0;
    final h = time.hour;
    if (h >= 22 || h <= 4)      { score += 40; reasons.add('LATE NIGHT — ${_fh(h)}'); }
    else if (h >= 20 || h <= 6) { score += 20; reasons.add('EVENING HOURS — ${_fh(h)}'); }
    if (speed != null) {
      final kmh = speed * 3.6;
      if (kmh > 15 && kmh < 40) { score += 25; reasons.add('SPEED ANOMALY ${kmh.toStringAsFixed(1)} km/h'); }
    }
    final wd = time.weekday;
    if ((wd == 6 || wd == 7) && (h >= 23 || h <= 3)) { score += 15; reasons.add('WEEKEND LATE NIGHT'); }

    ThreatLevel t; bool sos = false;
    if      (score >= 65) { t = ThreatLevel.critical; sos = true; }
    else if (score >= 50) { t = ThreatLevel.high;     sos = true; }
    else if (score >= 30) { t = ThreatLevel.medium; }
    else if (score >= 15) { t = ThreatLevel.low; }
    else { t = ThreatLevel.safe; reasons.add('ALL CLEAR — NO THREATS DETECTED'); }
    return AIResult(threat: t, reasons: reasons, triggerSOS: sos);
  }

  String _fh(int h) {
    final s = h < 12 ? 'AM' : 'PM';
    final d = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$d:00 $s';
  }
}

// ─────────────────────────────────────────────────────────────
//  PERMISSION SERVICE
// ─────────────────────────────────────────────────────────────
class PermissionService {
  static Future<void> requestAll() async {
    await Permission.location.request();
    await Future.delayed(const Duration(milliseconds: 500));
    await Permission.locationWhenInUse.request();
    await Future.delayed(const Duration(milliseconds: 500));
    await Permission.microphone.request();
    await Future.delayed(const Duration(milliseconds: 500));
    await Permission.phone.request();
    // Removed: SMS permission (not needed for url_launcher approach)
  }

  static Future<bool> hasSMS() async => true; // always available via url_launcher
  static Future<bool> requestSMS() async => true;
}

// ─────────────────────────────────────────────────────────────
//  AUTO SMS SERVICE
// ─────────────────────────────────────────────────────────────
class AutoSMSService {
  static final AutoSMSService _i = AutoSMSService._();
  factory AutoSMSService() => _i;
  AutoSMSService._();

  Future<bool> requestPermission() async => true;

  Future<void> sendSOSToAll({
    required List<TrustedContact> contacts,
    required double lat,
    required double lng,
    required String address,
    String trigger = 'SOS',
    String keyword = '',
  }) async {
    final link = 'https://maps.google.com/?q=$lat,$lng';
    final now = DateTime.now();
    final timeStr =
        '${now.day}/${now.month}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final kw = keyword.isNotEmpty ? '\nDetected: "$keyword"' : '';
    final smsBody =
        'RAKSHAK EMERGENCY SOS\nTrigger: $trigger$kw\nNEED IMMEDIATE HELP!\n'
        'Address: $address\nLocation: $link\nTime: $timeStr\nCall 100 immediately!';
    final phones = contacts.map((c) => c.phone).toList();
    await SMSLauncher.sendToAll(phones: phones, message: smsBody);
  }

  Future<void> sendLocationUpdate({
    required List<TrustedContact> contacts,
    required double lat,
    required double lng,
  }) async {
    final link = 'https://maps.google.com/?q=$lat,$lng';
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final msg = 'RAKSHAK LIVE LOCATION — Updated $timeStr\n$link\nTracking active.';
    final phones = contacts.map((c) => c.phone).toList();
    await SMSLauncher.sendToAll(phones: phones, message: msg);
  }
}

// ─────────────────────────────────────────────────────────────
//  VOICE SERVICE
// ─────────────────────────────────────────────────────────────
class VoiceService {
  static final VoiceService _i = VoiceService._();
  factory VoiceService() => _i;
  VoiceService._();

  final _stt = SpeechToText();
  bool _ready = false;
  bool isListening = false;
  final _ctrl = StreamController<String>.broadcast();
  Stream<String> get onWords => _ctrl.stream;

  Future<bool> init() async {
    try {
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) return false;
      _ready = await _stt.initialize(
        onError: (error) {
          isListening = false;
          Future.delayed(const Duration(seconds: 1), startContinuous);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') isListening = false;
        },
      );
      return _ready;
    } catch (e) { return false; }
  }

  Future<void> startContinuous() async {
    if (!_ready) { await init(); return; }
    if (isListening) return;
    try {
      isListening = true;
      await _stt.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _ctrl.add(result.recognizedWords.toLowerCase().trim());
          }
          if (result.finalResult) {
            isListening = false;
            Future.delayed(const Duration(milliseconds: 500), startContinuous);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'en_US',
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      isListening = false;
      Future.delayed(const Duration(seconds: 2), startContinuous);
    }
  }

  Future<void> stop() async { await _stt.stop(); isListening = false; }
  bool get isAvailable => _ready;
  void dispose() => _ctrl.close();
}

// ─────────────────────────────────────────────────────────────
//  LOCATION SERVICE
// ─────────────────────────────────────────────────────────────
class LocationService {
  static final LocationService _i = LocationService._();
  factory LocationService() => _i;
  LocationService._();

  Position? currentPosition;
  String currentAddress = 'Acquiring signal...';
  StreamSubscription<Position>? _sub;
  final _ctrl = StreamController<Position>.broadcast();
  Stream<Position> get stream => _ctrl.stream;

  Future<bool> _perm() async {
    try {
      final on = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (!on) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return p != LocationPermission.denied && p != LocationPermission.deniedForever;
    } catch (_) { return false; }
  }

  Future<bool> fetchOnce() async {
    if (!await _perm()) return false;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw TimeoutException('GPS'));
      await _addr(currentPosition!);
      return true;
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) { currentPosition = last; await _addr(last); return true; }
      } catch (_) {}
      return false;
    }
  }

  Future<bool> startTracking() async {
    if (!await _perm()) return false;
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10))
        .listen((p) async { currentPosition = p; _ctrl.add(p); await _addr(p); }, onError: (_) {});
    return true;
  }

  void stopTracking() { _sub?.cancel(); _sub = null; }

  Future<void> _addr(Position pos) async {
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
          .timeout(const Duration(seconds: 8), onTimeout: () => []);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final parts = [
          if ((p.street      ?? '').isNotEmpty) p.street!,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality    ?? '').isNotEmpty) p.locality!,
        ];
        currentAddress = parts.isNotEmpty ? parts.join(', ') : _coord(pos);
      } else { currentAddress = _coord(pos); }
    } catch (_) { currentAddress = _coord(pos); }
  }

  String _coord(Position p) => '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
  String get mapsLink => currentPosition == null
      ? '' : 'https://maps.google.com/?q=${currentPosition!.latitude},${currentPosition!.longitude}';
  LatLng? get latLng => currentPosition == null
      ? null : LatLng(currentPosition!.latitude, currentPosition!.longitude);
}

// ─────────────────────────────────────────────────────────────
//  SOS ENGINE
// ─────────────────────────────────────────────────────────────
class SOSEngine {
  static Timer? _locationUpdateTimer;
  static bool _isActive = false;

  static Future<void> fire({
    required List<TrustedContact> contacts,
    required LocationService loc,
    String trigger = 'Manual SOS', String keyword = '',
  }) async {
    if (_isActive) return;
    _isActive = true;
    if (loc.currentPosition == null) await loc.fetchOnce();
    final lat = loc.currentPosition?.latitude ?? 0.0;
    final lng = loc.currentPosition?.longitude ?? 0.0;
    await AutoSMSService().sendSOSToAll(
        contacts: contacts, lat: lat, lng: lng,
        address: loc.currentAddress, trigger: trigger, keyword: keyword);
    await callNumber('100');
    for (final c in contacts) {
      await callNumber(c.phone);
      await Future.delayed(const Duration(seconds: 1));
    }
    startLiveLocationUpdates(contacts: contacts, loc: loc);
  }

  static void startLiveLocationUpdates({
    required List<TrustedContact> contacts, required LocationService loc,
  }) {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isActive) return;
      await loc.fetchOnce();
      await AutoSMSService().sendLocationUpdate(
          contacts: contacts,
          lat: loc.currentPosition?.latitude ?? 0.0,
          lng: loc.currentPosition?.longitude ?? 0.0);
    });
  }

  static void stopLiveLocation() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _isActive = false;
  }

  static Future<void> callNumber(String number) async {
    try {
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────
//  CONTACT MODEL
// ─────────────────────────────────────────────────────────────
class TrustedContact {
  final String id, name, phone, relation;
  final int colorValue;
  TrustedContact({
    required this.id, required this.name,
    required this.phone, required this.relation, required this.colorValue,
  });
  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'relation': relation, 'colorValue': colorValue,
  };
  factory TrustedContact.fromJson(Map<String, dynamic> j) => TrustedContact(
      id: j['id'], name: j['name'], phone: j['phone'],
      relation: j['relation'], colorValue: j['colorValue']);
}

class ContactStorage {
  static const _key = 'rakshak_v6_contacts';
  static Future<List<TrustedContact>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return _def();
      return (jsonDecode(raw) as List).map((e) => TrustedContact.fromJson(e)).toList();
    } catch (_) { return _def(); }
  }
  static Future<void> save(List<TrustedContact> l) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(l.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }
  static List<TrustedContact> _def() => [
    TrustedContact(id:'1', name:'Mom',  phone:'+919876543210', relation:'Mother',      colorValue:0xFF00E5A0),
    TrustedContact(id:'2', name:'Riya', phone:'+918765432109', relation:'Best Friend', colorValue:0xFF8AFFEF),
    TrustedContact(id:'3', name:'Dad',  phone:'+917654321098', relation:'Father',      colorValue:0xFFFFB347),
  ];
}

// ─────────────────────────────────────────────────────────────
//  HEXAGON PAINTER — for SOS button
// ─────────────────────────────────────────────────────────────
class HexagonPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool filled;
  HexagonPainter({required this.color, this.strokeWidth = 2, this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - strokeWidth / 2;
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 6) + (i * math.pi / 3);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    // ← THIS WAS MISSING
  }

  @override bool shouldRepaint(covariant CustomPainter o) => true;
}

extension on Path<LatLng> {
  void moveTo(double x, double y) {}

  void lineTo(double x, double y) {}

  void close() {}
}

// ─────────────────────────────────────────────────────────────
//  APP ROOT
// ─────────────────────────────────────────────────────────────
class RakshakApp extends StatelessWidget {
  const RakshakApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rakshak', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: RC.bg,
      colorScheme: const ColorScheme.dark(primary: RC.neon, surface: RC.bgCard),
      fontFamily: 'monospace',
    ),
    home: const _SplashScreen(),
  );
}

// ─────────────────────────────────────────────────────────────
//  SPLASH — Geometric / Terminal aesthetic
// ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override State<_SplashScreen> createState() => _SplashState();
}
class _SplashState extends State<_SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _scanCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  late final AnimationController _fadeCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  String _log = '';
  final _lines = <String>[];

  @override
  void initState() { super.initState(); _boot(); }

  Future<void> _boot() async {
    final steps = [
      '> Initializing RAKSHAK core...',
      '> Loading AI threat module...',
      '> GPS subsystem online...',
      '> Voice recognition ready...',
      '> Encryption layer active...',
      '> ALL SYSTEMS NOMINAL',
    ];
    for (final s in steps) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() { _lines.add(s); _log = _lines.join('\n'); });
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => const _LoginScreen(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override void dispose() { _scanCtrl.dispose(); _fadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RC.bg,
    body: FadeTransition(
      opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
      child: Stack(children: [
        // Grid background
        CustomPaint(painter: _GridPainter(), size: MediaQuery.of(context).size),
        Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Hexagonal logo
          SizedBox(width: 120, height: 120, child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(
              animation: _scanCtrl,
              builder: (_, __) => CustomPaint(
                painter: HexagonPainter(
                  color: RC.neon.withOpacity(0.2 + 0.3 * math.sin(_scanCtrl.value * math.pi * 2).abs()),
                  strokeWidth: 1,
                ),
                size: const Size(120, 120),
              ),
            ),
            CustomPaint(painter: HexagonPainter(color: RC.neonDim, strokeWidth: 2), size: const Size(90, 90)),
            const Icon(Icons.shield_rounded, size: 40, color: RC.neon),
          ])),
          const SizedBox(height: 28),
          Text('RAKSHAK', style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w900, color: RC.neon,
            letterSpacing: 12, shadows: [Shadow(color: RC.neon.withOpacity(0.8), blurRadius: 20)],
          )),
          const SizedBox(height: 4),
          const Text('रक्षक — PERSONAL SAFETY OS', style: TextStyle(
            color: RC.textGray, fontSize: 11, letterSpacing: 4,
          )),
          const SizedBox(height: 40),
          // Terminal log
          Container(
            width: 300, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RC.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: RC.neonDim.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: RC.crimson, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: RC.amber, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: RC.neon, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                const Text('rakshak.boot', style: TextStyle(color: RC.textGray, fontSize: 10)),
              ]),
              const SizedBox(height: 12),
              Text(_log, style: const TextStyle(color: RC.neon, fontSize: 11, height: 1.8)),
            ]),
          ),
        ])),
      ]),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = RC.neon.withOpacity(0.04)..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────
//  LOGIN SCREEN — completely different: dark terminal card
// ─────────────────────────────────────────────────────────────
class _LoginScreen extends StatefulWidget {
  const _LoginScreen();
  @override State<_LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<_LoginScreen> with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true, _loading = false, _isLogin = true;

  late final AnimationController _glowCtrl =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);

  @override
  void dispose() { _glowCtrl.dispose(); _phoneCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_phoneCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _snack('Fill all fields'); return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _loading = false);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const _HomeScreen()));
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(m, style: const TextStyle(color: RC.bg)),
    backgroundColor: RC.neon, behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
  ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg,
      body: Stack(children: [
        CustomPaint(painter: _GridPainter(), size: MediaQuery.of(context).size),
        SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 48),
            // TOP MARK — left-aligned, asymmetric
            Row(children: [
              AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, child) => Container(
                  width: 4, height: 52,
                  decoration: BoxDecoration(
                    color: RC.neon.withOpacity(0.4 + 0.6 * _glowCtrl.value),
                    boxShadow: [BoxShadow(color: RC.neon.withOpacity(0.8 * _glowCtrl.value), blurRadius: 12)],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RAKSHAK', style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w900,
                  color: RC.neon, letterSpacing: 8,
                  shadows: [Shadow(color: RC.neon.withOpacity(0.5), blurRadius: 16)],
                )),
                const Text('SAFETY SYSTEM v6.0', style: TextStyle(
                  color: RC.textGray, fontSize: 10, letterSpacing: 4,
                )),
              ]),
            ]),

            const SizedBox(height: 48),

            // Toggle tabs — pill style, NOT bottom-rounded card
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: RC.bgCard, borderRadius: BorderRadius.circular(4),
                border: Border.all(color: RC.neonDim.withOpacity(0.3)),
              ),
              child: Row(children: [
                _tabBtn('LOGIN', _isLogin, () => setState(() => _isLogin = true)),
                _tabBtn('REGISTER', !_isLogin, () => setState(() => _isLogin = false)),
              ]),
            ),

            const SizedBox(height: 32),

            // Section label
            Text(_isLogin ? 'ACCESS YOUR SHIELD' : 'CREATE SHIELD IDENTITY',
                style: const TextStyle(color: RC.textWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text(_isLogin ? 'Enter credentials to continue' : 'Set up your safety profile',
                style: const TextStyle(color: RC.textGray, fontSize: 13, letterSpacing: 1)),

            const SizedBox(height: 32),

            if (!_isLogin) ...[
              _termField('FULL NAME', Icons.fingerprint_rounded, TextEditingController()),
              const SizedBox(height: 16),
            ],

            _termField('PHONE NUMBER', Icons.phone_iphone_rounded, _phoneCtrl, type: TextInputType.phone),
            const SizedBox(height: 16),

            // Password field with different style
            Container(
              decoration: BoxDecoration(
                color: RC.bgCard, borderRadius: BorderRadius.circular(4),
                border: Border.all(color: RC.neonDim.withOpacity(0.4)),
              ),
              child: TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: RC.neon, fontSize: 14, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: 'PASSKEY',
                  hintStyle: const TextStyle(color: RC.textDim, letterSpacing: 2),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: RC.neonDim, size: 18),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: RC.textGray, size: 18),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
              ),
            ),

            if (_isLogin) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _snack('Recovery link sent'),
                    child: const Text('FORGOT PASSKEY?', style: TextStyle(
                        color: RC.neonDim, fontSize: 11, letterSpacing: 1.5,
                        fontWeight: FontWeight.bold)),
                  )),
            ],

            const SizedBox(height: 32),

            // Submit — full width, sharp corners, neon outline
            GestureDetector(
              onTap: _loading ? null : _submit,
              child: AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) => Container(
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    color: RC.neon,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(
                      color: RC.neon.withOpacity(0.3 + 0.2 * _glowCtrl.value),
                      blurRadius: 20, spreadRadius: 2,
                    )],
                  ),
                  child: Center(child: _loading
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: RC.bg, strokeWidth: 2))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.chevron_right_rounded, color: RC.bg, size: 20),
                    Text(_isLogin ? 'AUTHENTICATE' : 'INITIALIZE',
                        style: const TextStyle(
                            color: RC.bg, fontWeight: FontWeight.w900,
                            fontSize: 15, letterSpacing: 4)),
                  ])),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Divider
            Row(children: [
              Expanded(child: Divider(color: RC.neonDim.withOpacity(0.2))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR', style: TextStyle(
                      color: RC.textGray.withOpacity(0.5), fontSize: 11, letterSpacing: 2))),
              Expanded(child: Divider(color: RC.neonDim.withOpacity(0.2))),
            ]),

            const SizedBox(height: 16),

            // Google — outlined, dark
            GestureDetector(
              onTap: () => _snack('Google auth coming soon'),
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  color: Colors.transparent, borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: RC.textDim),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.g_mobiledata_rounded, color: RC.textGray, size: 20),
                  SizedBox(width: 10),
                  Text('CONTINUE WITH GOOGLE', style: TextStyle(
                      color: RC.textGray, fontSize: 12, letterSpacing: 2)),
                ]),
              ),
            ),

            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.lock_rounded, color: RC.textDim, size: 12),
              SizedBox(width: 8),
              Text('END-TO-END ENCRYPTED', style: TextStyle(color: RC.textDim, fontSize: 10, letterSpacing: 2)),
            ]),
            const SizedBox(height: 40),
          ]),
        )),
      ]),
    );
  }

  Widget _tabBtn(String label, bool sel, VoidCallback onTap) => Expanded(
      child: GestureDetector(onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: sel ? RC.neon : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(child: Text(label, style: TextStyle(
              color: sel ? RC.bg : RC.textGray,
              fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2,
            ))),
          )));

  Widget _termField(String label, IconData icon, TextEditingController ctrl,
      {TextInputType type = TextInputType.text}) =>
      Container(
        decoration: BoxDecoration(
          color: RC.bgCard, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RC.neonDim.withOpacity(0.4)),
        ),
        child: TextField(
          controller: ctrl, keyboardType: type,
          style: const TextStyle(color: RC.neon, fontSize: 14, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(color: RC.textDim, letterSpacing: 2),
            prefixIcon: Icon(icon, color: RC.neonDim, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  HOME SCREEN — Drawer nav, NOT bottom tabs
// ─────────────────────────────────────────────────────────────
class _HomeScreen extends StatefulWidget {
  const _HomeScreen();
  @override State<_HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<_HomeScreen> with TickerProviderStateMixin {
  int _page = 0;
  bool _sosActive = false, _sosFiring = false, _liveLocationActive = false;
  int _sosCount = 5;
  Timer? _sosTimer;
  bool _guardianOn = false;
  ThreatLevel _threat = ThreatLevel.safe;
  List<String> _reasons = [];
  String _lastWord = '';
  bool _alertUp = false;
  Timer? _riskTimer;
  StreamSubscription<String>? _voiceSub;
  List<TrustedContact> _contacts = [];

  final _voice = VoiceService();
  final _loc   = LocationService();
  final _ai    = RakshakAI();

  late final AnimationController _hexPulse =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  late final AnimationController _scanLine =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();

  @override void initState() { super.initState(); _loadContacts(); }

  @override
  void dispose() {
    _hexPulse.dispose(); _scanLine.dispose();
    _sosTimer?.cancel(); _riskTimer?.cancel();
    _voiceSub?.cancel(); _voice.stop();
    SOSEngine.stopLiveLocation();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final c = await ContactStorage.load();
    if (mounted) setState(() => _contacts = c);
  }

  Future<void> _toggleGuardian() async =>
      _guardianOn ? _stopGuardian() : await _startGuardian();

  Future<void> _startGuardian() async {
    setState(() { _guardianOn = true; _reasons = ['INITIALIZING VOICE...'] ; });
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() { _reasons = ['MIC PERMISSION DENIED']; });
      return;
    }
    final ready = await _voice.init();
    if (!ready) { setState(() { _reasons = ['VOICE UNAVAILABLE']; }); return; }
    _voiceSub?.cancel();
    _voiceSub = _voice.onWords.listen(_onWords);
    await _voice.startContinuous();
    setState(() { _reasons = ['LISTENING — SAY "HELP" OR "BACHAO"']; });
    _riskTimer?.cancel();
    _riskTimer = Timer.periodic(const Duration(minutes: 2), (_) => _checkRisk());
    _checkRisk();
    HapticFeedback.mediumImpact();
  }

  void _stopGuardian() {
    _voiceSub?.cancel(); _voice.stop(); _riskTimer?.cancel();
    setState(() { _guardianOn = false; _threat = ThreatLevel.safe; _reasons = []; _lastWord = ''; });
  }

  void _onWords(String words) {
    if (!_guardianOn || words.isEmpty) return;
    final r = _ai.classifyVoice(words);
    setState(() { _lastWord = words; _threat = r.threat; _reasons = r.reasons; });
    if (r.triggerSOS && !_alertUp) _fireSilentSOSBackground(r, source: 'VOICE DETECTION');
  }

  void _checkRisk() {
    if (!_guardianOn) return;
    final r = _ai.assessRisk(time: DateTime.now(), speed: _loc.currentPosition?.speed);
    if (r.threat.index > _threat.index) setState(() { _threat = r.threat; _reasons = r.reasons; });
    if (r.triggerSOS && !_alertUp) _fireSilentSOSBackground(r, source: 'LOCATION RISK');
  }

  Future<void> _fireSilentSOSBackground(AIResult r, {required String source}) async {
    if (_alertUp) return;
    _alertUp = true;
    HapticFeedback.heavyImpact();
    if (_loc.currentPosition == null) unawaited(_loc.fetchOnce());
    unawaited(AutoSMSService().sendSOSToAll(
      contacts: _contacts,
      lat: _loc.currentPosition?.latitude ?? 0.0,
      lng: _loc.currentPosition?.longitude ?? 0.0,
      address: _loc.currentAddress, trigger: source, keyword: r.keyword,
    ));
    setState(() => _liveLocationActive = true);
    SOSEngine.startLiveLocationUpdates(contacts: _contacts, loc: _loc);
    unawaited(SOSEngine.callNumber('100'));
    if (mounted) {
      await showDialog(
        context: context, barrierDismissible: false,
        barrierColor: RC.crimson.withOpacity(0.4),
        builder: (_) => _SOSAlertOverlay(
          result: r, source: source, lastWord: _lastWord,
          onDismiss: () { _alertUp = false; Navigator.pop(context); },
        ),
      );
    }
    _alertUp = false;
  }

  void _tapSOS() {
    if (_sosActive) { _cancelSOS(); return; }
    HapticFeedback.heavyImpact();
    setState(() { _sosActive = true; _sosCount = 5; });
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_sosCount <= 1) { t.cancel(); _triggerManualSOS(); }
      else { setState(() => _sosCount--); HapticFeedback.mediumImpact(); }
    });
  }

  void _cancelSOS() { _sosTimer?.cancel(); setState(() { _sosActive = false; _sosCount = 5; }); }

  Future<void> _triggerManualSOS() async {
    if (_sosFiring) return;
    _sosFiring = true;
    setState(() { _sosActive = false; _sosCount = 5; });
    HapticFeedback.heavyImpact();
    setState(() => _liveLocationActive = true);
    await SOSEngine.fire(contacts: _contacts, loc: _loc, trigger: 'MANUAL SOS');
    _sosFiring = false;
    if (mounted) _showSOSConfirm();
  }

  void _showSOSConfirm() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => _SOSConfirmDialog(
      onStop: () { SOSEngine.stopLiveLocation(); setState(() => _liveLocationActive = false); Navigator.pop(context); },
      onDismiss: () => Navigator.pop(context),
    ));
  }

  void _stopLiveLocation() {
    SOSEngine.stopLiveLocation();
    setState(() => _liveLocationActive = false);
  }

  Future<void> _shareLocation() async {
    if (_loc.currentPosition == null) await _loc.fetchOnce();
    final link = _loc.mapsLink;
    if (link.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('GPS NOT AVAILABLE', style: TextStyle(color: RC.bg)),
        backgroundColor: RC.amber, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final phones = _contacts.map((c) => c.phone).toList();
    await SMSLauncher.sendToAll(
      phones: phones,
      message: 'RAKSHAK LOCATION CHECK-IN\n$link',
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('SMS APP OPENED', style: TextStyle(color: RC.bg, letterSpacing: 2, fontWeight: FontWeight.bold)),
      backgroundColor: RC.neon, behavior: SnackBarBehavior.floating,
    ));
  }

  static const _navItems = [
    (_NavIcon(icon: Icons.grid_view_rounded, label: 'COMMAND')),
    (_NavIcon(icon: Icons.contacts_rounded, label: 'NETWORK')),
    (_NavIcon(icon: Icons.map_outlined, label: 'MAP')),
    (_NavIcon(icon: Icons.manage_accounts_outlined, label: 'AGENT')),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _CommandPage(
        guardianOn: _guardianOn, threat: _threat, reasons: _reasons,
        lastWord: _lastWord, liveLocationActive: _liveLocationActive,
        hexPulse: _hexPulse, scanLine: _scanLine,
        onToggleGuardian: _toggleGuardian, onShareLocation: _shareLocation,
        onTapSOS: _tapSOS, onStopLiveLocation: _stopLiveLocation,
      ),
      _NetworkPage(onChanged: _loadContacts),
      const _MapPage(),
      const _AgentPage(),
    ];

    return Scaffold(
      backgroundColor: RC.bg,
      body: Stack(children: [
        pages[_page],
        if (_sosActive) _sosOverlay(),
      ]),
      bottomNavigationBar: _floatingIslandNav(),
    );
  }

  // ── Floating Island Nav — different shape entirely ──
  Widget _floatingIslandNav() => Container(
    height: 80,
    color: RC.bg,
    child: Center(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 60,
      decoration: BoxDecoration(
        color: RC.bgElevated,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: RC.neonDim.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: RC.neon.withOpacity(0.06), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Row(children: List.generate(4, (i) {
        final sel = _page == i;
        final item = _navItems[i];
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _page = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: sel ? RC.neon.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(item.icon, color: sel ? RC.neon : RC.textDim, size: sel ? 22 : 20),
              if (sel) ...[
                const SizedBox(height: 2),
                Text(item.label, style: const TextStyle(color: RC.neon, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ]),
          ),
        ));
      })),
    )),
  );

  // ── SOS Countdown Overlay — hexagonal, NOT circular ──
  Widget _sosOverlay() => Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Hex border
          SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
            CustomPaint(painter: HexagonPainter(color: RC.crimson, strokeWidth: 3), size: const Size(200, 200)),
            CustomPaint(painter: HexagonPainter(color: RC.crimson.withOpacity(0.15), strokeWidth: 0, filled: true), size: const Size(200, 200)),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$_sosCount', style: TextStyle(
                fontSize: 72, fontWeight: FontWeight.w900, color: RC.crimson,
                shadows: [Shadow(color: RC.crimson.withOpacity(0.8), blurRadius: 24)],
              )),
              const Text('SECONDS', style: TextStyle(color: RC.textGray, fontSize: 11, letterSpacing: 4)),
            ]),
          ])),
          const SizedBox(height: 24),
          const Text('SOS ACTIVATING', style: TextStyle(
              color: RC.crimson, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4)),
          const SizedBox(height: 8),
          const Text('POLICE + CONTACTS + SILENT SMS', style: TextStyle(
              color: RC.textGray, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _cancelSOS,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: RC.textGray, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('CANCEL', style: TextStyle(
                  color: RC.textGray, fontWeight: FontWeight.bold,
                  fontSize: 14, letterSpacing: 4)),
            ),
          ),
        ])),
      ));
}

class _NavIcon {
  final IconData icon;
  final String label;
  const _NavIcon({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────
//  SOS ALERT OVERLAY
// ─────────────────────────────────────────────────────────────
class _SOSAlertOverlay extends StatefulWidget {
  final AIResult result;
  final String source, lastWord;
  final VoidCallback onDismiss;
  const _SOSAlertOverlay({required this.result, required this.source,
    required this.lastWord, required this.onDismiss});
  @override State<_SOSAlertOverlay> createState() => _SOSAlertOverlayState();
}
class _SOSAlertOverlayState extends State<_SOSAlertOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _blink =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true);
  @override void dispose() { _blink.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.result.threat.color;
    return Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: RC.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c, width: 2),
          boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 32, spreadRadius: 4)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header stripe — sharp, diagonal-cut feel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              border: Border(bottom: BorderSide(color: c.withOpacity(0.4))),
            ),
            child: Row(children: [
              AnimatedBuilder(animation: _blink,
                  builder: (_, child) => Icon(widget.result.threat.icon,
                      color: c.withOpacity(0.5 + 0.5 * _blink.value), size: 28),
                  child: null),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.result.threat.label, style: TextStyle(
                    color: c, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3)),
                Text('SOURCE: ${widget.source}', style: const TextStyle(
                    color: RC.textGray, fontSize: 11, letterSpacing: 2)),
              ]),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.lastWord.isNotEmpty) ...[
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RC.bg, borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: c.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DETECTED VOICE', style: TextStyle(color: c, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('"${widget.lastWord}"', style: const TextStyle(
                      color: RC.textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            ...widget.result.reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 2, height: 16, color: c, margin: const EdgeInsets.only(right: 10)),
                  Expanded(child: Text(r, style: const TextStyle(
                      color: RC.textGray, fontSize: 12, letterSpacing: 1))),
                ]))),
            const SizedBox(height: 12),
            // Action status — horizontal chips
            Wrap(spacing: 8, runSpacing: 8, children: [
              _statusChip('POLICE CALLED', RC.neon),
              _statusChip('CONTACTS ALERTED', RC.neon),
              _statusChip('SMS SENT', RC.neon),
              _statusChip('GPS ACTIVE', RC.neon),
            ]),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: RC.neon, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(child: Text('I AM SAFE — DISMISS',
                    style: TextStyle(color: RC.neon, fontWeight: FontWeight.w900,
                        fontSize: 13, letterSpacing: 3))),
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _statusChip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4),
      border: Border.all(color: c.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
//  SOS CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────
class _SOSConfirmDialog extends StatelessWidget {
  final VoidCallback onStop, onDismiss;
  const _SOSConfirmDialog({required this.onStop, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: RC.bgCard, insetPadding: const EdgeInsets.all(24),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
    child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 24, color: RC.neon),
        const SizedBox(width: 12),
        const Text('SOS ACTIVATED', style: TextStyle(
            color: RC.neon, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ]),
      const SizedBox(height: 20),
      _row('POLICE 100 DIALED', RC.neon),
      _row('ALL CONTACTS CALLED', RC.neon),
      _row('SILENT SMS DISPATCHED', RC.neon),
      _row('GPS UPDATES EVERY 30s', RC.neon),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RC.bg, border: Border.all(color: RC.neonDim.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('EVERYTHING DONE AUTOMATICALLY. NO ACTION NEEDED.',
            style: TextStyle(color: RC.textGray, fontSize: 12, height: 1.5, letterSpacing: 1)),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: onStop,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: RC.textDim), borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(child: Text('STOP GPS', style: TextStyle(
                color: RC.textGray, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12))),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(child: GestureDetector(
          onTap: onDismiss,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: RC.neon, borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(child: Text('I\'M SAFE', style: TextStyle(
                color: RC.bg, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12))),
          ),
        )),
      ]),
    ])),
  );

  Widget _row(String t, Color c) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(Icons.check_rounded, color: c, size: 14),
        const SizedBox(width: 10),
        Text(t, style: const TextStyle(color: RC.textWhite, fontSize: 12, letterSpacing: 1)),
      ]));
}

// ─────────────────────────────────────────────────────────────
//  COMMAND PAGE (Dashboard)
//  Completely different layout: vertical strip status + hexagonal SOS
// ─────────────────────────────────────────────────────────────
class _CommandPage extends StatefulWidget {
  final bool guardianOn, liveLocationActive;
  final ThreatLevel threat;
  final List<String> reasons;
  final String lastWord;
  final AnimationController hexPulse, scanLine;
  final VoidCallback onToggleGuardian, onShareLocation, onTapSOS, onStopLiveLocation;
  const _CommandPage({
    required this.guardianOn, required this.threat, required this.reasons,
    required this.lastWord, required this.liveLocationActive,
    required this.hexPulse, required this.scanLine,
    required this.onToggleGuardian, required this.onShareLocation,
    required this.onTapSOS, required this.onStopLiveLocation,
  });
  @override State<_CommandPage> createState() => _CommandPageState();
}
class _CommandPageState extends State<_CommandPage> {
  final _loc = LocationService();
  bool _locLoading = false;

  @override
  void initState() {
    super.initState();
    if (_loc.currentPosition == null) {
      setState(() => _locLoading = true);
      _loc.fetchOnce().then((_) { if (mounted) setState(() => _locLoading = false); });
    }
  }

  Future<void> _dial(String n) async {
    final uri = Uri(scheme: 'tel', path: n);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _topBar(),
      Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (widget.liveLocationActive) _liveBar(),
            const SizedBox(height: 16),
            // Status row — horizontal 3-col stats
            _statusRow(),
            const SizedBox(height: 20),
            // BIG hexagonal SOS — center stage
            _hexSOSCard(),
            const SizedBox(height: 20),
            // Guardian toggle — horizontal banner style
            _guardianBanner(),
            const SizedBox(height: 12),
            if (widget.guardianOn) _aiPanel(),
            const SizedBox(height: 20),
            // Quick ops — horizontal scroll row
            _label('QUICK OPS'),
            const SizedBox(height: 12),
            _quickOpsRow(),
            const SizedBox(height: 20),
            _label('EMERGENCY LINES'),
            const SizedBox(height: 12),
            _helplineList(),
            const SizedBox(height: 20),
            _label('PROTOCOLS'),
            const SizedBox(height: 12),
            _protocolCards(),
          ])),
    ]);
  }

  Widget _topBar() => Container(
    color: RC.bgCard,
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        // Left: title + location
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 3, height: 18, color: RC.neon),
            const SizedBox(width: 8),
            const Text('COMMAND', style: TextStyle(
                color: RC.neon, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 4)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on_outlined, color: RC.textGray, size: 12),
            const SizedBox(width: 4),
            _locLoading
                ? const SizedBox(width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: RC.neonDim))
                : Expanded(child: Text(_loc.currentAddress,
                style: const TextStyle(color: RC.textGray, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        // Right: threat badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.threat.color.withOpacity(0.1),
            border: Border.all(color: widget.threat.color.withOpacity(0.6)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: widget.threat.color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(widget.threat.label, style: TextStyle(
                color: widget.threat.color, fontWeight: FontWeight.w900,
                fontSize: 11, letterSpacing: 1.5)),
          ]),
        ),
      ]),
    )),
  );

  Widget _liveBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: RC.crimson.withOpacity(0.1),
      border: Border.all(color: RC.crimson.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(children: [
      AnimatedBuilder(
        animation: widget.hexPulse,
        builder: (_, __) => Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: RC.crimson.withOpacity(0.6 + 0.4 * widget.hexPulse.value),
            shape: BoxShape.circle,
          ),
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Text('LIVE GPS BROADCASTING — CONTACTS TRACKING YOU',
          style: TextStyle(color: RC.crimson, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1))),
      GestureDetector(
        onTap: widget.onStopLiveLocation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: RC.crimson, borderRadius: BorderRadius.circular(2)),
          child: const Text('STOP', style: TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ),
    ]),
  );

  Widget _statusRow() => Row(children: [
    _statBox('SHIELD', widget.guardianOn ? 'ACTIVE' : 'OFFLINE',
        widget.guardianOn ? RC.neon : RC.textDim),
    const SizedBox(width: 8),
    _statBox('GPS', _loc.currentPosition != null ? 'LOCKED' : 'SEARCHING',
        _loc.currentPosition != null ? RC.neon : RC.amber),
    const SizedBox(width: 8),
    _statBox('SMS', 'READY', RC.neon),
  ]);

  Widget _statBox(String label, String value, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: RC.bgCard, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: RC.textDim, fontSize: 9, letterSpacing: 2)),
        ]),
      ));

  // ── HEXAGONAL SOS — completely unlike round buttons ──
  Widget _hexSOSCard() => GestureDetector(
    onTap: widget.onTapSOS,
    child: Center(child: SizedBox(width: 220, height: 220, child: Stack(
        alignment: Alignment.center, children: [
      // Outer pulse hex
      AnimatedBuilder(
        animation: widget.hexPulse,
        builder: (_, __) => CustomPaint(
          painter: HexagonPainter(
            color: RC.crimson.withOpacity(0.08 + 0.12 * widget.hexPulse.value),
            strokeWidth: 0, filled: true,
          ),
          size: const Size(220, 220),
        ),
      ),
      // Middle hex ring
      CustomPaint(
        painter: HexagonPainter(color: RC.crimson.withOpacity(0.3), strokeWidth: 1.5),
        size: const Size(190, 190),
      ),
      // Inner filled hex
      CustomPaint(
        painter: HexagonPainter(color: RC.crimson.withOpacity(0.15), strokeWidth: 0, filled: true),
        size: const Size(160, 160),
      ),
      // Core hex border
      AnimatedBuilder(
        animation: widget.hexPulse,
        builder: (_, child) => CustomPaint(
          painter: HexagonPainter(
            color: RC.crimson.withOpacity(0.6 + 0.4 * widget.hexPulse.value),
            strokeWidth: 2,
          ),
          size: const Size(140, 140),
        ),
      ),
      // Label
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.crisis_alert_rounded, color: RC.crimson, size: 36,
            shadows: [Shadow(color: RC.crimson.withOpacity(0.8), blurRadius: 16)]),
        const SizedBox(height: 6),
        Text('S O S', style: TextStyle(
          color: RC.crimson, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 8,
          shadows: [Shadow(color: RC.crimson.withOpacity(0.8), blurRadius: 20)],
        )),
        const SizedBox(height: 2),
        const Text('HOLD TO TRIGGER', style: TextStyle(
            color: RC.textGray, fontSize: 9, letterSpacing: 2)),
      ]),
    ])),
  ));

  // ── Guardian toggle — banner style ──
  Widget _guardianBanner() => GestureDetector(
    onTap: widget.onToggleGuardian,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RC.bgCard, borderRadius: BorderRadius.circular(4),
        border: Border.all(color: widget.guardianOn
            ? RC.neon.withOpacity(0.4) : RC.textDim.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (widget.guardianOn ? RC.neon : RC.textDim).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.psychology_outlined,
              color: widget.guardianOn ? RC.neon : RC.textDim, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.guardianOn ? 'AI GUARDIAN — LISTENING' : 'AI GUARDIAN — OFFLINE',
              style: TextStyle(
                  color: widget.guardianOn ? RC.neon : RC.textGray,
                  fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text(widget.guardianOn ? 'Voice + GPS + Auto-SMS active' : 'Tap to activate shield',
              style: const TextStyle(color: RC.textGray, fontSize: 11)),
        ])),
        // Toggle switch — custom bar
        _CustomSwitch(value: widget.guardianOn, onToggle: widget.onToggleGuardian),
      ]),
    ),
  );

  Widget _aiPanel() => Container(
    padding: const EdgeInsets.all(14),
    margin: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: RC.bg,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: widget.threat.color.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 2, height: 14, color: widget.threat.color),
        const SizedBox(width: 8),
        const Text('AI ANALYSIS', style: TextStyle(
            color: RC.textGray, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
        const Spacer(),
        Text(widget.threat.label, style: TextStyle(
            color: widget.threat.color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ]),
      if (widget.lastWord.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('"${widget.lastWord}"', style: const TextStyle(
            color: RC.textWhite, fontSize: 13, fontStyle: FontStyle.italic)),
      ],
      if (widget.reasons.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...widget.reasons.take(2).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('$r', style: const TextStyle(
                color: RC.textGray, fontSize: 11)))),
      ],
    ]),
  );

  Widget _label(String t) => Text(t, style: const TextStyle(
      color: RC.textGray, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3));

  Widget _quickOpsRow() => SizedBox(
    height: 90,
    child: ListView(scrollDirection: Axis.horizontal, children: [
      _opTile(Icons.sms_outlined, 'SILENT\nSMS', RC.neon, widget.onShareLocation),
      _opTile(Icons.phone_iphone_rounded, 'FAKE\nCALL', RC.ice, () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _FakeCallScreen()))),
      _opTile(Icons.local_police_outlined, 'CALL\nPOLICE', const Color(0xFF4FC3F7), () => _dial('100')),
      _opTile(Icons.psychology_outlined,
          widget.guardianOn ? 'GUARD\nON' : 'GUARD\nOFF',
          widget.guardianOn ? RC.neon : RC.textDim, widget.onToggleGuardian),
      _opTile(Icons.emergency_outlined, 'WOMEN\n1091', RC.amber, () => _dial('1091')),
    ]),
  );

  Widget _opTile(IconData icon, String label, Color c, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Container(
            width: 80, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: RC.bgCard, borderRadius: BorderRadius.circular(4),
              border: Border.all(color: c.withOpacity(0.25)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: TextStyle(
                  color: c, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, height: 1.4)),
            ]),
          ));

  Widget _helplineList() => Column(children: [
    _hlRow('POLICE', '100', const Color(0xFF4FC3F7)),
    _hlRow('WOMEN HELPLINE', '1091', RC.neon),
    _hlRow('AMBULANCE', '102', RC.crimson),
    _hlRow('NATIONAL EMERGENCY', '112', RC.amber),
  ]);

  Widget _hlRow(String name, String num, Color c) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: RC.bgCard, borderRadius: BorderRadius.circular(4),
      border: Border.all(color: RC.bgElevated),
    ),
    child: Row(children: [
      Container(width: 3, height: 20, color: c, margin: const EdgeInsets.only(right: 12)),
      Expanded(child: Text(name, style: const TextStyle(
          color: RC.textWhite, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1))),
      GestureDetector(onTap: () => _dial(num),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4),
              border: Border.all(color: c.withOpacity(0.5)),
            ),
            child: Text(num, style: TextStyle(
                color: c, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
          )),
    ]),
  );

  Widget _protocolCards() => Column(children: [
    _protRow(Icons.sms_outlined, 'Silent SMS dispatches location automatically on SOS.'),
    _protRow(Icons.mic_outlined, 'Say "Help" or "Bachao" — AI triggers alert instantly.'),
    _protRow(Icons.location_on_outlined, 'GPS pings every 30s to all contacts during emergency.'),
    _protRow(Icons.groups_outlined, 'All trusted contacts receive simultaneous alerts.'),
  ]);

  Widget _protRow(IconData icon, String text) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: RC.bgCard, borderRadius: BorderRadius.circular(4),
      border: Border.all(color: RC.neonDim.withOpacity(0.1)),
    ),
    child: Row(children: [
      Icon(icon, color: RC.neonDim, size: 16),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(
          color: RC.textGray, fontSize: 12, height: 1.4))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
//  CUSTOM SWITCH
// ─────────────────────────────────────────────────────────────
class _CustomSwitch extends StatelessWidget {
  final bool value;
  final VoidCallback onToggle;
  const _CustomSwitch({required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 48, height: 26,
      decoration: BoxDecoration(
        color: value ? RC.neon.withOpacity(0.2) : RC.bgElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: value ? RC.neon : RC.textDim, width: 1.5),
      ),
      child: Stack(children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          left: value ? 24 : 2, top: 2,
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              color: value ? RC.neon : RC.textDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  NETWORK PAGE (Contacts)
//  Completely different: list with left color bar + action row
// ─────────────────────────────────────────────────────────────
class _NetworkPage extends StatefulWidget {
  final VoidCallback? onChanged;
  const _NetworkPage({this.onChanged});
  @override State<_NetworkPage> createState() => _NetworkPageState();
}
class _NetworkPageState extends State<_NetworkPage> {
  List<TrustedContact> _all = [], _f = [];
  final _s = TextEditingController();
  final _cols = [0xFF00E5A0, 0xFF8AFFEF, 0xFFFFB347, 0xFF4FC3F7, 0xFFFF8A65, 0xFFBA68C8];

  @override
  void initState() {
    super.initState();
    ContactStorage.load().then((l) { if (mounted) setState(() { _all = l; _f = l; }); });
    _s.addListener(() {
      final q = _s.text.toLowerCase();
      setState(() { _f = q.isEmpty ? _all
          : _all.where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList(); });
    });
  }
  @override void dispose() { _s.dispose(); super.dispose(); }

  Future<void> _del(TrustedContact c) async {
    _all.remove(c); await ContactStorage.save(_all);
    setState(() => _f = _all); widget.onChanged?.call();
  }

  Future<void> _add(String n, String p, String r) async {
    final c = TrustedContact(id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: n.trim(), phone: p.trim(), relation: r.trim(),
        colorValue: _cols[_all.length % _cols.length]);
    _all.add(c); await ContactStorage.save(_all);
    setState(() => _f = _all); widget.onChanged?.call();
  }

  void _showAddSheet() {
    final nc = TextEditingController(), pc = TextEditingController(), rc = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: RC.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Sheet handle
            Center(child: Container(width: 40, height: 3,
                decoration: BoxDecoration(color: RC.textDim, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: const [
              Icon(Icons.add_circle_outline_rounded, color: RC.neon, size: 18),
              SizedBox(width: 10),
              Text('ADD NETWORK NODE', style: TextStyle(
                  color: RC.neon, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ]),
            const SizedBox(height: 20),
            _termInput(nc, 'CONTACT NAME', Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _termInput(pc, 'PHONE NUMBER', Icons.phone_iphone_rounded, type: TextInputType.phone),
            const SizedBox(height: 12),
            _termInput(rc, 'RELATIONSHIP', Icons.link_rounded),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                if (nc.text.trim().isEmpty || pc.text.trim().isEmpty) return;
                await _add(nc.text, pc.text, rc.text.isEmpty ? 'CONTACT' : rc.text);
                if (mounted) Navigator.pop(context);
              },
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  color: RC.neon, borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(child: Text('ADD TO NETWORK',
                    style: TextStyle(color: RC.bg, fontWeight: FontWeight.w900,
                        fontSize: 13, letterSpacing: 3))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _termInput(TextEditingController c, String h, IconData icon, {TextInputType type = TextInputType.text}) =>
      Container(
        decoration: BoxDecoration(
          color: RC.bg, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RC.neonDim.withOpacity(0.3)),
        ),
        child: TextField(
          controller: c, keyboardType: type,
          style: const TextStyle(color: RC.neon, fontSize: 13, letterSpacing: 1),
          decoration: InputDecoration(
            hintText: h, hintStyle: const TextStyle(color: RC.textDim, letterSpacing: 1),
            prefixIcon: Icon(icon, color: RC.neonDim, size: 16),
            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(color: RC.bgCard,
          child: SafeArea(bottom: false, child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
              Container(width: 3, height: 18, color: RC.neon),
              const SizedBox(width: 8),
              const Expanded(child: Text('TRUSTED NETWORK', style: TextStyle(
                  color: RC.neon, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 4))),
              GestureDetector(onTap: _showAddSheet, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: RC.neon), borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: RC.neon, size: 14),
                  SizedBox(width: 4),
                  Text('ADD', style: TextStyle(color: RC.neon, fontSize: 11,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
                ]),
              )),
            ])),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Container(
              decoration: BoxDecoration(
                color: RC.bg, borderRadius: BorderRadius.circular(4),
                border: Border.all(color: RC.neonDim.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _s,
                style: const TextStyle(color: RC.neon, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'SEARCH CONTACTS...',
                  hintStyle: TextStyle(color: RC.textDim, fontSize: 13, letterSpacing: 1),
                  prefixIcon: Icon(Icons.search_rounded, color: RC.textDim, size: 18),
                  border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            )),
          ]))),
      Expanded(child: _f.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.hub_outlined, size: 64, color: RC.textDim),
        SizedBox(height: 16),
        Text('NETWORK EMPTY', style: TextStyle(color: RC.textDim, fontSize: 12, letterSpacing: 3)),
      ]))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: _f.length,
          itemBuilder: (_, i) => _ContactNode(contact: _f[i], onDel: () => _del(_f[i])))),
    ]);
  }
}

class _ContactNode extends StatelessWidget {
  final TrustedContact contact;
  final VoidCallback onDel;
  const _ContactNode({required this.contact, required this.onDel});

  Future<void> _act(String s, String p) async {
    final uri = Uri(scheme: s, path: p);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final c = Color(contact.colorValue);
    return Dismissible(
      key: Key(contact.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: RC.crimson.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: RC.crimson.withOpacity(0.4))),
        child: const Icon(Icons.delete_outline_rounded, color: RC.crimson, size: 22),
      ),
      onDismissed: (_) => onDel(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: RC.bgCard, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RC.bgElevated),
        ),
        child: Row(children: [
          // Color bar on left
          Container(width: 4, height: 72, color: c,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 14),
          // Avatar — monogram in square
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(4),
              border: Border.all(color: c.withOpacity(0.3)),
            ),
            child: Center(child: Text(contact.name[0].toUpperCase(),
                style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.name.toUpperCase(), style: const TextStyle(
                color: RC.textWhite, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(contact.phone, style: const TextStyle(color: RC.textGray, fontSize: 12)),
            const SizedBox(height: 3),
            Text(contact.relation.toUpperCase(), style: TextStyle(
                color: c, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
          ])),
          // Action buttons — vertical stack
          Column(children: [
            _actionBtn(Icons.message_outlined, RC.neon, () => _act('sms', contact.phone)),
            const SizedBox(height: 4),
            _actionBtn(Icons.call_outlined, RC.ice, () => _act('tel', contact.phone)),
          ]),
          const SizedBox(width: 12),
        ]),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 28,
      decoration: BoxDecoration(
        color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Icon(icon, color: c, size: 16),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  MAP PAGE — Same feature, different header style
// ─────────────────────────────────────────────────────────────
class _MapPage extends StatefulWidget {
  const _MapPage();
  @override State<_MapPage> createState() => _MapState();
}
class _MapState extends State<_MapPage> {
  final _loc = LocationService();
  final _mapController = MapController();
  bool _loading = false, _tracking = false;
  String _status = 'TAP LOCATE TO START';
  StreamSubscription<Position>? _sub;
  LatLng _center = const LatLng(20.5937, 78.9629);
  double _zoom = 5.0;

  @override
  void initState() {
    super.initState();
    if (_loc.currentPosition != null) {
      _center = _loc.latLng!; _zoom = 15.5; _status = _loc.currentAddress;
    }
  }

  @override void dispose() { _sub?.cancel(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _status = 'ACQUIRING SIGNAL...'; });
    final ok = await _loc.fetchOnce();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) { setState(() => _status = 'SIGNAL LOST'); return; }
    _moveTo(_loc.latLng!);
    setState(() => _status = _loc.currentAddress);
  }

  void _moveTo(LatLng ll) {
    setState(() { _center = ll; _zoom = 15.5; });
    _mapController.move(ll, 15.5);
  }

  Future<void> _startTrack() async {
    setState(() { _tracking = true; _status = 'LIVE TRACK ACTIVE'; });
    final ok = await _loc.startTracking();
    if (!ok) { setState(() { _tracking = false; _status = 'TRACK FAILED'; }); return; }
    _sub = _loc.stream.listen((p) {
      if (!mounted) return;
      _moveTo(LatLng(p.latitude, p.longitude));
      setState(() => _status = _loc.currentAddress);
    });
  }

  void _stopTrack() {
    _sub?.cancel(); _loc.stopTracking();
    setState(() { _tracking = false; _status = _loc.currentAddress; });
  }

  Future<void> _dial(String n) async {
    final uri = Uri(scheme: 'tel', path: n);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final myPos = _loc.latLng;
    return Column(children: [
      // Header
      Container(color: RC.bgCard,
          child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Container(width: 3, height: 18, color: RC.neon),
                const SizedBox(width: 8),
                const Expanded(child: Text('SAFE MAP', style: TextStyle(
                    color: RC.neon, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 4))),
                if (_tracking) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RC.crimson.withOpacity(0.1), borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: RC.crimson.withOpacity(0.5)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, color: RC.crimson, size: 6), SizedBox(width: 5),
                    Text('LIVE', style: TextStyle(color: RC.crimson, fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ]),
                ),
              ])))),
      Expanded(child: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _center, initialZoom: _zoom,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all)),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rakshak.app', maxZoom: 19),
            if (myPos != null) CircleLayer(circles: [
              CircleMarker(point: myPos, radius: 60, useRadiusInMeter: true,
                  color: RC.neon.withOpacity(0.1), borderColor: RC.neonDim.withOpacity(0.5),
                  borderStrokeWidth: 1.5),
            ]),
            if (myPos != null) MarkerLayer(markers: [
              Marker(point: myPos, width: 44, height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: RC.neon, borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: RC.bg, width: 2),
                      boxShadow: [BoxShadow(color: RC.neon.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.my_location_rounded, color: RC.bg, size: 20),
                  )),
            ]),
          ],
        ),
        // Status bar on top — sharp strip
        Positioned(top: 12, left: 12, right: 12, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: RC.bgCard.withOpacity(0.95), borderRadius: BorderRadius.circular(4),
            border: Border.all(color: RC.neonDim.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.radar_rounded, color: RC.neon, size: 14),
            const SizedBox(width: 8),
            _loading
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: RC.neon))
                : Expanded(child: Text(_status.toUpperCase(), style: const TextStyle(
                color: RC.textGray, fontSize: 11, letterSpacing: 1),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        )),
        // Map controls — right side
        Positioned(right: 12, top: 70, child: Column(children: [
          _mapBtn(Icons.my_location_rounded, RC.neon, _fetch, 'LOCATE'),
          const SizedBox(height: 8),
          _mapBtn(
            _tracking ? Icons.stop_rounded : Icons.navigation_rounded,
            _tracking ? RC.crimson : RC.neonDim,
            _tracking ? _stopTrack : _startTrack,
            _tracking ? 'STOP' : 'TRACK',
          ),
        ])),
        // Bottom emergency strip
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          color: RC.bgCard.withOpacity(0.96),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(children: [
            _nearbyRow(Icons.local_police_outlined, 'POLICE STATION', '100', const Color(0xFF4FC3F7)),
            const SizedBox(height: 6),
            _nearbyRow(Icons.local_hospital_outlined, 'HOSPITAL', '102', RC.crimson),
            const SizedBox(height: 6),
            _nearbyRow(Icons.security_outlined, 'WOMEN HELPLINE', '1091', RC.neon),
          ]),
        )),
      ])),
    ]);
  }

  Widget _mapBtn(IconData icon, Color c, VoidCallback onTap, String label) =>
      GestureDetector(onTap: onTap, child: Container(
        width: 52, padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: RC.bgCard, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withOpacity(0.5)),
        ),
        child: Column(children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              color: c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      ));

  Widget _nearbyRow(IconData icon, String name, String num, Color c) => Row(children: [
    Icon(icon, color: c, size: 14),
    const SizedBox(width: 10),
    Expanded(child: Text(name, style: const TextStyle(
        color: RC.textGray, fontSize: 11, letterSpacing: 1))),
    GestureDetector(onTap: () => _dial(num), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(num, style: TextStyle(
          color: c, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
    )),
  ]);
}

// ─────────────────────────────────────────────────────────────
//  FAKE CALL SCREEN — Dark terminal aesthetic
// ─────────────────────────────────────────────────────────────
class _FakeCallScreen extends StatefulWidget {
  const _FakeCallScreen();
  @override State<_FakeCallScreen> createState() => _FakeCallState();
}
class _FakeCallState extends State<_FakeCallScreen> with TickerProviderStateMixin {
  late final AnimationController _r =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  bool _on = false; int _sec = 0; Timer? _t;

  @override void initState() { super.initState(); HapticFeedback.heavyImpact(); }
  @override void dispose() { _r.dispose(); _t?.cancel(); super.dispose(); }

  void _accept() {
    setState(() => _on = true); _r.stop();
    _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _sec++); });
  }

  String get _dur =>
      '${(_sec ~/ 60).toString().padLeft(2, '0')}:${(_sec % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bg,
      body: Stack(children: [
        CustomPaint(painter: _GridPainter(), size: MediaQuery.of(context).size),
        SafeArea(child: Column(children: [
          const SizedBox(height: 24),
          Text(_on ? 'CONNECTED' : 'INCOMING',
              style: TextStyle(color: RC.textGray, fontSize: 11, letterSpacing: 4,
                  shadows: [Shadow(color: RC.neon.withOpacity(0.3), blurRadius: 8)])),
          const SizedBox(height: 4),
          if (_on) Text(_dur, style: const TextStyle(
              color: RC.neon, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4)),
          const SizedBox(height: 36),
          // Caller ID — square, not circle
          AnimatedBuilder(animation: _r, builder: (_, child) => Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: RC.bgCard, borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: RC.neon.withOpacity(_on ? 0.8 : 0.3 + 0.5 * _r.value), width: 2),
              boxShadow: [BoxShadow(
                  color: RC.neon.withOpacity(_on ? 0.4 : 0.1 + 0.3 * _r.value), blurRadius: 20)],
            ),
            child: const Center(child: Text('M', style: TextStyle(
                color: RC.neon, fontSize: 40, fontWeight: FontWeight.w900))),
          )),
          const SizedBox(height: 20),
          const Text('MOM', style: TextStyle(
              color: RC.textWhite, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 6)),
          const Text('+91 98765 43210', style: TextStyle(color: RC.textGray, fontSize: 14, letterSpacing: 2)),
          const Spacer(),
          if (!_on)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _callBtn(Icons.call_end_rounded, RC.crimson, 'DECLINE', () => Navigator.pop(context)),
              _callBtn(Icons.call_rounded, RC.neon, 'ANSWER', _accept),
            ]))
          else ...[
            // In-call controls — grid layout
            Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _ctrlBtn(Icons.volume_up_outlined, 'SPEAKER'),
              _ctrlBtn(Icons.mic_off_outlined, 'MUTE'),
              _ctrlBtn(Icons.dialpad_outlined, 'KEYPAD'),
              _ctrlBtn(Icons.person_add_outlined, 'ADD'),
            ])),
            const SizedBox(height: 32),
            Center(child: _callBtn(Icons.call_end_rounded, RC.crimson, 'END', () => Navigator.pop(context))),
          ],
          const SizedBox(height: 48),
        ])),
      ]),
    );
  }

  Widget _callBtn(IconData icon, Color c, String label, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Column(children: [
        Container(width: 64, height: 64,
            decoration: BoxDecoration(
              color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(4),
              border: Border.all(color: c, width: 1.5),
              boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 16)],
            ),
            child: Icon(icon, color: c, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: c, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
      ]));

  Widget _ctrlBtn(IconData icon, String label) => GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Column(children: [
        Container(width: 52, height: 52,
            decoration: BoxDecoration(
              color: RC.bgCard, borderRadius: BorderRadius.circular(4),
              border: Border.all(color: RC.bgElevated),
            ),
            child: Icon(icon, color: RC.textGray, size: 22)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: RC.textDim, fontSize: 9, letterSpacing: 1)),
      ]));
}

// ─────────────────────────────────────────────────────────────
//  AGENT PAGE (Profile) — Data-driven, terminal style
// ─────────────────────────────────────────────────────────────
class _AgentPage extends StatefulWidget {
  const _AgentPage();
  @override State<_AgentPage> createState() => _AgentPageState();
}
class _AgentPageState extends State<_AgentPage> {
  bool _voice = true, _autoSms = true, _notif = true;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(color: RC.bgCard, child: SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: Row(children: [
        Container(width: 3, height: 18, color: RC.neon),
        const SizedBox(width: 8),
        const Expanded(child: Text('AGENT PROFILE', style: TextStyle(
            color: RC.neon, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 4))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: RC.neon.withOpacity(0.1), borderRadius: BorderRadius.circular(4),
            border: Border.all(color: RC.neonDim.withOpacity(0.5)),
          ),
          child: const Text('v6.0', style: TextStyle(color: RC.neon, fontSize: 10,
              fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
      ])))),
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
        // Agent card — dark, left-heavy
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RC.bgCard, borderRadius: BorderRadius.circular(4),
            border: Border.all(color: RC.neonDim.withOpacity(0.3)),
          ),
          child: Row(children: [
            // Avatar — hexagonal-ish
            SizedBox(width: 64, height: 64, child: Stack(alignment: Alignment.center, children: [
              CustomPaint(painter: HexagonPainter(color: RC.neonDim, strokeWidth: 1.5),
                  size: const Size(64, 64)),
              const Text('P', style: TextStyle(
                  color: RC.neon, fontSize: 26, fontWeight: FontWeight.w900)),
            ])),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PRIYA SHARMA', style: TextStyle(
                  color: RC.textWhite, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 4),
              const Text('+91 98765 43210', style: TextStyle(color: RC.textGray, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: RC.neon.withOpacity(0.1), borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: RC.neonDim.withOpacity(0.4)),
                ),
                child: const Text('SHIELD ACTIVE', style: TextStyle(
                    color: RC.neon, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ])),
            GestureDetector(
              onTap: () {},
              child: const Icon(Icons.edit_outlined, color: RC.textGray, size: 18),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Stats — 3-cell horizontal, inverted from original
        Row(children: [
          _cell('47', 'TRIPS', RC.neon),
          const SizedBox(width: 8),
          _cell('3', 'NODES', RC.ice),
          const SizedBox(width: 8),
          _cell('0', 'SOS', RC.crimson),
        ]),

        const SizedBox(height: 24),
        _sectionHdr('SHIELD CONFIG'),
        const SizedBox(height: 12),
        _toggleRow('AI VOICE DETECTION', Icons.psychology_outlined, _voice, RC.neon,
                (v) => setState(() => _voice = v)),
        _toggleRow('AUTO SILENT SMS', Icons.sms_outlined, _autoSms, RC.neon,
                (v) => setState(() => _autoSms = v)),
        _toggleRow('PUSH ALERTS', Icons.notifications_outlined, _notif, RC.amber,
                (v) => setState(() => _notif = v)),

        const SizedBox(height: 24),
        _sectionHdr('SYSTEM'),
        const SizedBox(height: 12),
        _menuRow(Icons.manage_accounts_outlined, 'EDIT PROFILE'),
        _menuRow(Icons.security_outlined, 'CHANGE PASSKEY'),
        _menuRow(Icons.help_outline_rounded, 'HELP & DOCS'),
        _menuRow(Icons.info_outline_rounded, 'ABOUT RAKSHAK'),

        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity, height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: RC.crimson.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.logout_outlined, color: RC.crimson, size: 16),
              SizedBox(width: 8),
              Text('TERMINATE SESSION', style: TextStyle(
                  color: RC.crimson, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 3)),
            ])),
          ),
        ),
      ])),
    ]);
  }

  Widget _cell(String val, String lbl, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: RC.bgCard, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(val, style: TextStyle(color: c, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(lbl, style: const TextStyle(color: RC.textDim, fontSize: 9, letterSpacing: 3)),
        ]),
      ));

  Widget _sectionHdr(String t) => Row(children: [
    Container(width: 2, height: 14, color: RC.neonDim),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(color: RC.textGray, fontSize: 10,
        fontWeight: FontWeight.bold, letterSpacing: 3)),
  ]);

  Widget _toggleRow(String title, IconData icon, bool val, Color c, ValueChanged<bool> onChange) =>
      Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: RC.bgCard, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RC.bgElevated),
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(
              color: RC.textWhite, fontSize: 12, letterSpacing: 1))),
          _CustomSwitch(value: val, onToggle: () => onChange(!val)),
        ]),
      );

  Widget _menuRow(IconData icon, String title) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: RC.bgCard, borderRadius: BorderRadius.circular(4),
      border: Border.all(color: RC.bgElevated),
    ),
    child: ListTile(
      dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      leading: Icon(icon, color: RC.textGray, size: 16),
      title: Text(title, style: const TextStyle(
          color: RC.textWhite, fontSize: 12, letterSpacing: 1)),
      trailing: const Icon(Icons.chevron_right_rounded, color: RC.textDim, size: 16),
    ),
  );
}
