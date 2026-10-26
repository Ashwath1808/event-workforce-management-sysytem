import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'role_selection_page.dart';
import 'worker_home_page.dart';
import 'organizer_home_page.dart';

/// Crew Sync splash screen, built from the real logo artwork.
///
/// The logo is split into three transparent PNG layers (assets/logo/):
/// teal figure, orange figure and the handshake. The eyes, smiles and sync
/// burst are drawn in code on top of them.
///
/// Timeline (seconds):
///   0.0 - 1.0  teal C and orange S figures slide in from the sides
///   0.85       hands pop in, handshake shakes from 1.3 to 2.7
///   1.6 - 2.2  both figures get eyes and a smile (they blink at 4.3)
///   2.65       sync ring and dots burst out of the handshake
///   3.0 - 3.9  "Crew Sync" letters rise in (C is teal, S is coral)
///   3.7 - 6.3  tagline and load bar
///
/// Setup: add the three assets to pubspec.yaml (see pubspec_snippet.yaml).
/// Optional: add the Fredoka font for the exact wordmark look.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onFinished});

  /// Optional callback after animation; otherwise routes using Firebase auth.
  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

const double _total = 6.5;
const Color _bg = Color(0xFF061326);
const Color _teal = Color(0xFF19E6D4);
const Color _coral = Color(0xFFFF6A45);
const Color _ink = Color(0xFF04101F);
const Color _text = Color(0xFFE8F4F6);
const Color _muted = Color(0xFF7F98A8);

/// Progress 0..1 of an animation that starts at [start] seconds and lasts [dur].
double _ease(double t, double start, double dur, [Curve curve = Curves.linear]) {
  return curve.transform(((t - start) / dur).clamp(0.0, 1.0));
}

class _Layers {
  const _Layers(this.teal, this.orange, this.hands);
  final ui.Image teal;
  final ui.Image orange;
  final ui.Image hands;

  void dispose() {
    teal.dispose();
    orange.dispose();
    hands.dispose();
  }
}

Future<ui.Image> _loadImage(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );
  _Layers? _layers;
  late final Future<Widget> _destination = _resolveDestination();
  bool _navigating = false;

  Future<Widget> _resolveDestination() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        return const RoleSelectionPage();
      }
      final user = await AuthService().getCurrentUserModel();
      if (user == null) return const RoleSelectionPage();
      switch (user.role.trim().toLowerCase()) {
        case 'worker':
          return WorkerHomePage(user: user);
        case 'organizer':
          return OrganizerHomePage(user: user);
        default:
          return const RoleSelectionPage();
      }
    } catch (error) {
      debugPrint('Splash authentication error: $error');
      return const RoleSelectionPage();
    }
  }

  Future<void> _finish() async {
    if (!mounted || _navigating) return;
    _navigating = true;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    final destination = await _destination;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => destination),
          (_) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final images = await Future.wait([
        _loadImage('assets/logo/teal.png'),
        _loadImage('assets/logo/orange.png'),
        _loadImage('assets/logo/hands.png'),
      ]);
      if (!mounted) {
        for (final i in images) {
          i.dispose();
        }
        return;
      }
      setState(() => _layers = _Layers(images[0], images[1], images[2]));
      await _c.forward();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _finish();
    } catch (error) {
      debugPrint('Splash asset loading error: $error');
      if (mounted) await _finish();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _layers?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoW = math.min(width * 0.76, 360.0);
    final fontSize = math.min(width * 0.12, 60.0);
    final layers = _layers;

    return Scaffold(
      backgroundColor: _bg,
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 0.8,
              colors: [Color(0x2419E6D4), Color(0x0DFF6A45), Color(0x00061326)],
              stops: [0, 0.62, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: layers == null
                  ? Image.asset(
                'assets/logo.png',
                width: 190,
                height: 190,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'CrewSync',
                  style: TextStyle(
                    color: _teal,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
                  : AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value * _total;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: logoW,
                        height: logoW * 1000 / 1060,
                        child: CustomPaint(
                          painter: _LogoPainter(t, layers),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _wordmark(t, fontSize),
                      const SizedBox(height: 16),
                      _fadeUp(
                        t,
                        3.7,
                        0.7,
                        const Text(
                          'Work together. Stay in sync.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 15,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _fadeUp(t, 3.7, 0.5, _loadBar(t)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fadeUp(double t, double start, double dur, Widget child) {
    final p = _ease(t, start, dur, Curves.easeOut);
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, 8 * (1 - p)), child: child),
    );
  }

  Widget _wordmark(double t, double fs) {
    Widget word(String s, int offset, Color first) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < s.length; i++)
          _letter(t, s[i], offset + i, i == 0 ? first : _text, fs),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        word('Crew', 0, _teal),
        SizedBox(width: fs * 0.3),
        word('Sync', 4, _coral),
      ],
    );
  }

  Widget _letter(double t, String ch, int i, Color color, double fs) {
    final start = 3.0 + i * 0.07;
    final p = _ease(t, start, 0.6, Curves.easeOutBack);
    final o = _ease(t, start, 0.25);
    return Opacity(
      opacity: o,
      child: Transform.translate(
        offset: Offset(0, 34 * (1 - p)),
        child: Transform.scale(
          scale: 0.9 + 0.1 * p,
          child: Text(
            ch,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w600,
              fontSize: fs,
              height: 1,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadBar(double t) {
    final f = _ease(t, 3.9, 2.4, const Cubic(0.4, 0.1, 0.2, 1));
    return Container(
      width: 180,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 180 * f,
            height: 4,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_teal, _coral]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo painter. Coordinates are in the logo's own 1060 x 1000 space, which
// starts at (90, 120) of the original artwork. Each PNG layer is exactly that
// size, so it is drawn at its natural scale and the canvas does the fitting.
// ---------------------------------------------------------------------------

/// One particle of the sync burst: travels (dx, dy) and shrinks away.
class _Dot {
  const _Dot(this.dx, this.dy, this.radius, this.teal);
  final double dx;
  final double dy;
  final double radius;
  final bool teal;
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.t, this.layers);

  /// Seconds since the animation started.
  final double t;
  final _Layers layers;

  static const _dots = <_Dot>[
    _Dot(-210, -120, 8, true),
    _Dot(-120, -230, 6, false),
    _Dot(0, -260, 9, true),
    _Dot(130, -230, 6, false),
    _Dot(220, -120, 8, true),
    _Dot(-250, 20, 7, false),
    _Dot(250, 30, 7, true),
    _Dot(-170, 120, 6, false),
    _Dot(180, 130, 8, true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 1060, size.height / 1000);
    canvas.translate((size.width - 1060 * s) / 2, (size.height - 1000 * s) / 2);
    canvas.scale(s);
    canvas.translate(-90, -120);

    const slide = Cubic(0.2, 0.85, 0.25, 1.08);
    final slideP = _ease(t, 0, 1.0, slide);
    final slideO = _ease(t, 0, 0.35);
    final phase = ((t - 1.3) / 0.28).clamp(0.0, 5.0);
    final wave = math.sin(2 * math.pi * phase); // 0 before and after the shake
    final bob = -10 * wave; // whole handshake moves together

    // Teal C person, slides in from the left.
    _layer(canvas, slideO, () {
      canvas.save();
      canvas.translate(-300 * (1 - slideP), bob);
      _image(canvas, layers.teal);
      _face(
        canvas,
        eyeL: const Offset(408, 524),
        eyeR: const Offset(452, 524),
        eyeRadius: 9,
        smileA: const Offset(403, 552),
        smileC: const Offset(430, 584),
        smileB: const Offset(457, 552),
        smileW: 9,
      );
      canvas.restore();
    });

    // Orange S person, slides in from the right.
    _layer(canvas, slideO, () {
      canvas.save();
      canvas.translate(300 * (1 - slideP), bob);
      _image(canvas, layers.orange);
      _face(
        canvas,
        eyeL: const Offset(878, 542),
        eyeR: const Offset(928, 542),
        eyeRadius: 10,
        smileA: const Offset(872, 574),
        smileC: const Offset(903, 610),
        smileB: const Offset(934, 574),
        smileW: 10,
      );
      canvas.restore();
    });

    // Handshake: pops in, then shakes.
    final popO = _ease(t, 0.85, 0.4);
    final popS = 0.3 + 0.7 * _ease(t, 0.85, 0.4, const Cubic(0.3, 1.5, 0.5, 1));
    _layer(canvas, popO, () {
      canvas.save();
      canvas.translate(0, bob);
      canvas.translate(586, 926);
      canvas.scale(popS);
      canvas.rotate(-2.2 * math.pi / 180 * wave);
      canvas.translate(-586, -926);
      _image(canvas, layers.hands);
      canvas.restore();
    });

    _drawBurst(canvas);
  }

  void _image(Canvas canvas, ui.Image img) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      const Rect.fromLTWH(90, 120, 1060, 1000),
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );
  }

  void _layer(Canvas canvas, double opacity, VoidCallback draw) {
    if (opacity <= 0) return;
    if (opacity >= 1) {
      draw();
      return;
    }
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    draw();
    canvas.restore();
  }

  Paint _stroke(double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _ink;

  void _face(
      Canvas canvas, {
        required Offset eyeL,
        required Offset eyeR,
        required double eyeRadius,
        required Offset smileA,
        required Offset smileC,
        required Offset smileB,
        required double smileW,
      }) {
    final pop = _ease(t, 1.6, 0.3, Curves.easeOutBack);
    final blink = 1 - 0.9 * math.sin(math.pi * _ease(t, 4.3, 0.22));
    final eyePaint = Paint()..color = _ink;
    for (final e in [eyeL, eyeR]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: e,
          width: 2 * eyeRadius * pop,
          height: 2 * eyeRadius * pop * blink,
        ),
        eyePaint,
      );
    }
    final p = _ease(t, 1.75, 0.45, Curves.easeOut);
    if (p > 0) {
      final smile = Path()
        ..moveTo(smileA.dx, smileA.dy)
        ..quadraticBezierTo(smileC.dx, smileC.dy, smileB.dx, smileB.dy);
      final m = smile.computeMetrics().first;
      canvas.drawPath(m.extractPath(0, m.length * p), _stroke(smileW));
    }
  }

  void _drawBurst(Canvas canvas) {
    const center = Offset(595, 900);

    final rp = _ease(t, 2.65, 0.9, Curves.easeOut);
    if (rp > 0 && rp < 1) {
      final scale = 0.3 + 4.7 * rp;
      final r = 50 * scale;
      final a = 0.9 * (1 - rp);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 * scale
          ..shader = LinearGradient(colors: [
            Color.fromRGBO(25, 230, 212, a),
            Color.fromRGBO(255, 106, 69, a),
          ]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    final dp = _ease(t, 2.65, 0.85, Curves.easeOut);
    if (dp > 0 && dp < 1) {
      for (final d in _dots) {
        final a = 1 - dp;
        canvas.drawCircle(
          center + Offset(d.dx, d.dy) * dp,
          d.radius * (1 - 0.8 * dp),
          Paint()
            ..color = d.teal
                ? Color.fromRGBO(25, 230, 212, a)
                : Color.fromRGBO(255, 106, 69, a),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.t != t || old.layers != layers;
}
