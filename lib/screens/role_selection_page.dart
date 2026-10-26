import 'package:flutter/material.dart';
import '../theme/crewsync_theme.dart';
import 'login_page.dart';
import 'signup_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _openLogin(String role) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => LoginPage(role: role)),
  );

  void _openSignup(String role) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => SignupPage(role: role)),
  );

  Widget _appear(Widget child, double start) {
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12), end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrewSyncTheme.canvas,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, bounds) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _appear(Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        gradient: CrewSyncTheme.heroGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(
                          color: CrewSyncTheme.indigo.withOpacity(0.22),
                          blurRadius: 24, offset: const Offset(0, 12),
                        )],
                      ),
                      child: const Column(children: [
                        Icon(Icons.groups_rounded, size: 60, color: Colors.white),
                        SizedBox(height: 14),
                        Text('CrewSync', style: TextStyle(
                          fontSize: 33, fontWeight: FontWeight.w900,
                          letterSpacing: -1.2, color: Colors.white,
                        )),
                        SizedBox(height: 8),
                        Text('Find work. Build your future.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 14),
                        ),
                      ]),
                    ), 0),
                    const SizedBox(height: 28),
                    _appear(const Text('How will you use CrewSync?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800,
                        color: CrewSyncTheme.ink),
                    ), 0.1),
                    const SizedBox(height: 8),
                    _appear(const Text('Choose your role to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF71809B)),
                    ), 0.15),
                    const SizedBox(height: 24),
                    _appear(_RoleCard(
                      title: 'Worker',
                      subtitle: 'Discover jobs, apply in seconds, and track your earnings.',
                      icon: Icons.engineering_rounded,
                      accent: CrewSyncTheme.indigo,
                      onLogin: () => _openLogin('worker'),
                      onSignup: () => _openSignup('worker'),
                    ), 0.22),
                    const SizedBox(height: 16),
                    _appear(_RoleCard(
                      title: 'Organizer',
                      subtitle: 'Create events, hire great crews, and manage everything.',
                      icon: Icons.event_available_rounded,
                      accent: CrewSyncTheme.violet,
                      onLogin: () => _openLogin('organizer'),
                      onSignup: () => _openSignup('organizer'),
                    ), 0.35),
                    const SizedBox(height: 25),
                    _appear(const Text('ONE PLATFORM. ENDLESS OPPORTUNITIES.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8994AC), fontSize: 10,
                        letterSpacing: 1.2, fontWeight: FontWeight.w700),
                    ), 0.48),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const _RoleCard({
    required this.title, required this.subtitle, required this.icon,
    required this.accent, required this.onLogin, required this.onSignup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8ECFA)),
        boxShadow: const [BoxShadow(
          color: Color(0x0B172554), blurRadius: 22, offset: Offset(0, 8),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, size: 29, color: accent),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 21,
                fontWeight: FontWeight.w800, color: CrewSyncTheme.ink)),
              const SizedBox(height: 3),
              Text(title == 'Worker' ? 'Find your next opportunity' : 'Build your dream team',
                style: const TextStyle(fontSize: 12, color: Color(0xFF75819B))),
            ],
          )),
        ]),
        const SizedBox(height: 14),
        Text(subtitle, style: const TextStyle(
          color: Color(0xFF66758F), height: 1.45, fontSize: 13,
        )),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: onLogin, child: const Text('Log in'),
          )),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(
            onPressed: onSignup, child: const Text('Sign up'),
          )),
        ]),
      ]),
    );
  }
}
