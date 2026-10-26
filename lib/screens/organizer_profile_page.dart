
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';

class OrganizerProfilePage extends StatefulWidget {
  final UserModel user;

  const OrganizerProfilePage({
    super.key,
    required this.user,
  });

  @override
  State<OrganizerProfilePage> createState() =>
      _OrganizerProfilePageState();
}

class _OrganizerProfilePageState extends State<OrganizerProfilePage>
    with SingleTickerProviderStateMixin {
  // CREWSYNC — ORGANIZER MIDNIGHT NAVY & CORAL THEME
  static const Color _background = Color(0xFF0B1220);
  static const Color _card = Color(0xFF19263B);
  static const Color _cardLight = Color(0xFF203149);
  static const Color _coral = Color(0xFFF06449);
  static const Color _coralLight = Color(0xFFFF7857);
  static const Color _teal = Color(0xFF35D1AC);
  static const Color _white = Colors.white;
  static const Color _muted = Color(0xFFA7B7CD);
  static const Color _border = Color(0xFF2B3D54);

  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late final TextEditingController _name;
  late final TextEditingController _email;

  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _organization = TextEditingController();
  final _about = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  late final AnimationController _animation;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  List<TextEditingController> get _controllers => [
    _name,
    _email,
    _phone,
    _location,
    _organization,
    _about,
  ];

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: widget.user.name);
    _email = TextEditingController(text: widget.user.email);

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fade = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animation,
        curve: Curves.easeOutCubic,
      ),
    );

    for (final controller in _controllers) {
      controller.addListener(_refresh);
    }

    _loadProfile();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _animation.dispose();

    for (final controller in _controllers) {
      controller.removeListener(_refresh);
      controller.dispose();
    }

    super.dispose();
  }

  // FIREBASE — LOAD PROFILE
  Future<void> _loadProfile() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Please log in again.');
      }

      final snapshot =
      await _firestore.collection('users').doc(user.uid).get();

      if (!mounted) return;

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        _name.text =
            (data['name'] ?? widget.user.name).toString();

        _email.text =
            (data['email'] ?? widget.user.email).toString();

        _phone.text = (data['phone'] ?? '').toString();

        _location.text =
            (data['location'] ?? data['city'] ?? '').toString();

        _organization.text =
            (data['organizationName'] ?? '').toString();

        _about.text =
            (data['organizationAbout'] ?? '').toString();
      }
    } on FirebaseException catch (e) {
      _message(
        e.message ?? 'Unable to load profile.',
        error: true,
      );
    } catch (e) {
      _message(
        'Unable to load profile: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _animation.forward();
      }
    }
  }

  // FIREBASE — SAVE PROFILE
  Future<void> _saveProfile() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      _message(
        'Please check the highlighted fields.',
        error: true,
      );
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _message('Please log in again.', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'location': _location.text.trim(),
        'organizationName': _organization.text.trim(),
        'organizationAbout': _about.text.trim(),
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await _successDialog();
    } on FirebaseException catch (e) {
      _message(
        e.message ?? 'Unable to save profile.',
        error: true,
      );
    } catch (e) {
      _message(
        'Unable to save profile: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  int get _completedFields {
    return [
      _name.text,
      _phone.text,
      _location.text,
      _organization.text,
      _about.text,
    ].where((value) => value.trim().isNotEmpty).length;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'O';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _completedFields / 5;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _coral,
          secondary: _teal,
          surface: _card,
        ),
        scaffoldBackgroundColor: _background,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: _coral,
          ),
        )
            : Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        18, 22, 18, 30,
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          _buildProfileHero(progress),
                          const SizedBox(height: 26),
                          _buildIntro(),
                          const SizedBox(height: 26),

                          _section(
                            number: '01',
                            title: 'Personal Information',
                            subtitle:
                            'Your identity and contact details',
                            icon: Icons.person_outline_rounded,
                            children: [
                              _field(
                                _name,
                                'Full Name',
                                Icons.badge_outlined,
                                validator: _required,
                              ),
                              _field(
                                _email,
                                'Email Address',
                                Icons.email_outlined,
                                enabled: false,
                              ),
                              _field(
                                _phone,
                                'Phone Number',
                                Icons.phone_outlined,
                                type: TextInputType.phone,
                                validator: _phoneValidator,
                              ),
                              _field(
                                _location,
                                'City / Location',
                                Icons.location_on_outlined,
                                validator: _required,
                              ),
                            ],
                          ),

                          _section(
                            number: '02',
                            title: 'Organization Details',
                            subtitle:
                            'Tell workers about your organization',
                            icon: Icons.business_outlined,
                            children: [
                              _field(
                                _organization,
                                'Organization / Company Name',
                                Icons.apartment_rounded,
                              ),
                              _field(
                                _about,
                                'About Your Organization',
                                Icons.description_outlined,
                                lines: 4,
                              ),
                              const Text(
                                'Organization details are optional. '
                                    'Individual organizers can leave '
                                    'them blank.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar:
        _loading ? null : _buildBottomSaveBar(),
      ),
    );
  }

  // APP BAR
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _background,
      foregroundColor: _white,
      surfaceTintColor: _background,
      elevation: 0,
      toolbarHeight: 72,
      leadingWidth: 66,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: Material(
            color: _card,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => Navigator.maybePop(context),
              child: const SizedBox(
                width: 43,
                height: 43,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: _white,
                ),
              ),
            ),
          ),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organizer Profile',
            style: TextStyle(
              color: _white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'CREWSYNC  /  MY PROFILE',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.13),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _coral.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.business_center_outlined,
                color: _coral,
                size: 23,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // PROFILE HERO
  Widget _buildProfileHero(double progress) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _card,
            Color(0xFF17263A),
            Color(0xFF28334A),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            Positioned(
              right: -65,
              top: -70,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _coral.withOpacity(0.09),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -70,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _teal.withOpacity(0.13),
                    width: 2,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _coral,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: _coral,
                          child: Text(
                            _initials(_name.text),
                            style: const TextStyle(
                              color: _white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name.text.trim().isEmpty
                                  ? 'CrewSync Organizer'
                                  : _name.text.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _email.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _coral.withOpacity(0.13),
                                borderRadius:
                                BorderRadius.circular(20),
                                border: Border.all(
                                  color: _coral.withOpacity(0.35),
                                ),
                              ),
                              child: const Text(
                                'ORGANIZER',
                                style: TextStyle(
                                  color: _coralLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _background.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  color: _teal,
                                  size: 19,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Profile completion',
                                  style: TextStyle(
                                    color: _white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                color: _teal,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: progress,
                            ),
                            duration: const Duration(
                              milliseconds: 600,
                            ),
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                backgroundColor: _border,
                                valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                  _teal,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 11),
                        Text(
                          progress >= 1
                              ? 'Your organizer profile is complete.'
                              : 'Add your details to complete your organizer profile.',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // INTRODUCTION
  Widget _buildIntro() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage your profile',
          style: TextStyle(
            color: _white,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Keep your contact and organization details updated '
              'so workers can recognize your organization.',
          style: TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // SECTION CARD
  Widget _section({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _coral.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: _coral,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                number,
                style: const TextStyle(
                  color: _border,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TEXT FIELD
  Widget _field(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType? type,
        int lines = 1,
        bool enabled = true,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: type,
      maxLines: lines,
      validator: validator,
      cursorColor: _coral,
      style: TextStyle(
        color: enabled ? _white : _muted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _muted,
          fontSize: 13,
        ),
        floatingLabelStyle: const TextStyle(
          color: _coral,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(
          icon,
          color: enabled ? _coral : _muted,
          size: 21,
        ),
        filled: true,
        fillColor: enabled ? _background : _cardLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _coral,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // SAVE BUTTON
  Widget _buildBottomSaveBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 15),
        decoration: const BoxDecoration(
          color: _background,
          border: Border(
            top: BorderSide(color: _border),
          ),
        ),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_coral, _coralLight],
            ),
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: _coral.withOpacity(0.23),
                blurRadius: 13,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: _saving ? null : _saveProfile,
              child: Center(
                child: _saving
                    ? const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Saving Profile...',
                      style: TextStyle(
                        color: _white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
                    : const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: _white,
                      size: 23,
                    ),
                    SizedBox(width: 11),
                    Text(
                      'Save Profile',
                      style: TextStyle(
                        color: _white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 11),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: _white,
                      size: 21,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // VALIDATION
  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final phone = (value ?? '')
        .replaceAll(' ', '')
        .replaceFirst('+91', '');

    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      return 'Enter a valid 10 digit phone number';
    }

    return null;
  }

  // SUCCESS DIALOG
  Future<void> _successDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: const CircleAvatar(
            radius: 33,
            backgroundColor: Color(0xFF183D3D),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: _teal,
              size: 39,
            ),
          ),
          title: const Text(
            'Profile Saved',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _white,
            ),
          ),
          content: const Text(
            'Your organizer profile has been saved successfully.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: _white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 35,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // SNACKBAR
  void _message(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        error ? const Color(0xFFC83F4A) : _cardLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );
  }
}
