
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/user_model.dart';

class WorkerProfilePage extends StatefulWidget {
  final UserModel user;

  const WorkerProfilePage({
    super.key,
    required this.user,
  });

  @override
  State<WorkerProfilePage> createState() =>
      _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // CREWSYNC — MIDNIGHT & EMERALD DESIGN SYSTEM
  // ============================================================

  static const Color _midnight = Color(0xFF101828);
  static const Color _navy = Color(0xFF1D2939);
  static const Color _emerald = Color(0xFF00C9A7);
  static const Color _deepEmerald = Color(0xFF009B82);
  static const Color _mint = Color(0xFFE6FAF5);
  static const Color _background = Color(0xFFF5F7FA);
  static const Color _surface = Colors.white;
  static const Color _text = Color(0xFF1D2939);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE4E7EC);
  static const Color _fieldBackground = Color(0xFFF9FAFB);

  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late final TextEditingController _name;
  late final TextEditingController _email;

  final _phone = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _skills = TextEditingController();
  final _years = TextEditingController();
  final _previousWork = TextEditingController();
  final _education = TextEditingController();
  final _languages = TextEditingController();
  final _bio = TextEditingController();

  final _upiId = TextEditingController();
  final _upiMobile = TextEditingController();
  final _accountHolder = TextEditingController();

  String? _gender;
  String? _experienceLevel;

  bool _loading = true;
  bool _saving = false;

  late final AnimationController _animation;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Experienced',
    'Professional',
  ];

  final List<String> _suggestedSkills = [
    'Photography',
    'Video Editing',
    'Catering',
    'Security',
    'Decoration',
    'Event Management',
    'Registration Desk',
    'Hospitality',
  ];

  List<TextEditingController> get _controllers => [
    _name,
    _email,
    _phone,
    _age,
    _city,
    _skills,
    _years,
    _previousWork,
    _education,
    _languages,
    _bio,
    _upiId,
    _upiMobile,
    _accountHolder,
  ];

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(text: widget.user.name);
    _email = TextEditingController(text: widget.user.email);

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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
    if (mounted) {
      setState(() {});
    }
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

  // ============================================================
  // FIREBASE — LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Please log in again.');
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        _name.text =
            (data['name'] ?? widget.user.name).toString();

        _email.text =
            (data['email'] ?? widget.user.email).toString();

        _phone.text = (data['phone'] ?? '').toString();
        _age.text = (data['age'] ?? '').toString();
        _city.text = (data['city'] ?? '').toString();

        _skills.text = _readList(data['skills']);

        _years.text =
            (data['experienceYears'] ?? '').toString();

        _previousWork.text =
            (data['previousWork'] ?? '').toString();

        _education.text =
            (data['education'] ?? '').toString();

        _languages.text = _readList(data['languages']);

        _bio.text = (data['bio'] ?? '').toString();

        final gender = data['gender']?.toString();

        if (_genders.contains(gender)) {
          _gender = gender;
        }

        final level = data['experienceLevel']?.toString();

        if (_levels.contains(level)) {
          _experienceLevel = level;
        }

        _upiId.text = (data['upiId'] ?? '').toString();

        _upiMobile.text =
            (data['upiMobileNumber'] ?? '').toString();

        _accountHolder.text =
            (data['accountHolderName'] ?? '').toString();
      }
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

  String _readList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }

    return value?.toString() ?? '';
  }

  List<String> _asList(String text) {
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  // ============================================================
  // PAYMENT LOGIC
  // ============================================================

  String get _paymentUri {
    if (_upiId.text.trim().isEmpty ||
        _accountHolder.text.trim().isEmpty) {
      return '';
    }

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': _upiId.text.trim(),
        'pn': _accountHolder.text.trim(),
        'cu': 'INR',
      },
    ).toString();
  }

  bool get _validPayment {
    return _upiId.text.trim().isNotEmpty &&
        _upiValidator(_upiId.text) == null &&
        _accountHolder.text.trim().length >= 2 &&
        _upiMobile.text.trim().isNotEmpty &&
        _upiMobileValidator(_upiMobile.text) == null;
  }

  // ============================================================
  // FIREBASE — SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      _message(
        'Please check the highlighted fields.',
        error: true,
      );
      return;
    }

    if (_gender == null || _experienceLevel == null) {
      _message(
        'Please select gender and experience level.',
        error: true,
      );
      return;
    }

    final skills = _asList(_skills.text);
    final languages = _asList(_languages.text);

    if (skills.isEmpty || languages.isEmpty) {
      _message(
        'Please enter skills and languages.',
        error: true,
      );
      return;
    }

    final age = int.tryParse(_age.text.trim());
    final years = int.tryParse(_years.text.trim());

    if (age == null || years == null) {
      _message(
        'Enter valid age and experience.',
        error: true,
      );
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _message(
        'Please log in again.',
        error: true,
      );
      return;
    }

    final upiId = _upiId.text.trim();
    final upiMobile = _upiMobile.text.trim();
    final holder = _accountHolder.text.trim();

    final hasPayment = upiId.isNotEmpty ||
        upiMobile.isNotEmpty ||
        holder.isNotEmpty;

    if (hasPayment && !_validPayment) {
      _message(
        'Please complete all payment details correctly.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'role': 'worker',
          'phone': _phone.text.trim(),
          'age': age,
          'gender': _gender,
          'city': _city.text.trim(),
          'skills': skills,
          'experienceLevel': _experienceLevel,
          'experienceYears': years,
          'previousWork': _previousWork.text.trim(),
          'education': _education.text.trim(),
          'languages': languages,
          'bio': _bio.text.trim(),
          'upiId': upiId,
          'upiMobileNumber': upiMobile,
          'accountHolderName': holder,
          'upiPaymentUri':
          hasPayment ? _paymentUri : '',
          'paymentDetailsCompleted': hasPayment,
          'profileCompleted': true,
          'profileUpdatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

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

  // ============================================================
  // PROFILE COMPLETION
  // ============================================================

  int get _completedFields {
    final filled = [
      _name.text,
      _phone.text,
      _age.text,
      _city.text,
      _skills.text,
      _years.text,
      _previousWork.text,
      _education.text,
      _languages.text,
      _bio.text,
    ].where((text) => text.trim().isNotEmpty).length;

    return filled +
        (_gender == null ? 0 : 1) +
        (_experienceLevel == null ? 0 : 1);
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final progress = _completedFields / 12;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _emerald,
          primary: _deepEmerald,
        ),
        scaffoldBackgroundColor: _background,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: _deepEmerald,
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
                        18,
                        22,
                        18,
                        30,
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          _buildProfileHero(progress),

                          const SizedBox(height: 24),

                          _buildIntro(),

                          const SizedBox(height: 25),

                          // PERSONAL INFORMATION
                          _section(
                            number: '01',
                            title: 'Personal Information',
                            subtitle:
                            'Your basic identity and contact details',
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
                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _field(
                                      _age,
                                      'Age',
                                      Icons.cake_outlined,
                                      type:
                                      TextInputType.number,
                                      validator:
                                      _ageValidator,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _dropdown(
                                      'Gender',
                                      _gender,
                                      _genders,
                                          (value) {
                                        setState(
                                              () => _gender = value,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              _field(
                                _city,
                                'City / Location',
                                Icons.location_on_outlined,
                                validator: _required,
                              ),
                            ],
                          ),

                          // SKILLS
                          _section(
                            number: '02',
                            title: 'Professional Skills',
                            subtitle:
                            'Show organizers what you do best',
                            icon:
                            Icons.workspace_premium_outlined,
                            children: [
                              _field(
                                _skills,
                                'Your Skills',
                                Icons.auto_awesome_outlined,
                                lines: 3,
                                validator: _required,
                              ),
                              const Text(
                                'Separate skills with commas or tap below to add.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                'SUGGESTED SKILLS',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _suggestedSkills
                                    .map(_skillChip)
                                    .toList(),
                              ),
                            ],
                          ),

                          // EXPERIENCE
                          _section(
                            number: '03',
                            title: 'Work Experience',
                            subtitle:
                            'Highlight your professional background',
                            icon:
                            Icons.work_history_outlined,
                            children: [
                              _dropdown(
                                'Experience Level',
                                _experienceLevel,
                                _levels,
                                    (value) {
                                  setState(
                                        () =>
                                    _experienceLevel =
                                        value,
                                  );
                                },
                              ),
                              _field(
                                _years,
                                'Years of Experience',
                                Icons.timeline_outlined,
                                type:
                                TextInputType.number,
                                validator:
                                _yearsValidator,
                              ),
                              _field(
                                _previousWork,
                                'Previous Work / Events',
                                Icons.history_rounded,
                                lines: 4,
                                validator: _required,
                              ),
                            ],
                          ),

                          // ABOUT YOU
                          _section(
                            number: '04',
                            title: 'About You',
                            subtitle:
                            'Education, languages and introduction',
                            icon:
                            Icons.school_outlined,
                            children: [
                              _field(
                                _education,
                                'Education',
                                Icons.school_outlined,
                                validator: _required,
                              ),
                              _field(
                                _languages,
                                'Languages Known',
                                Icons.language_outlined,
                                lines: 2,
                                validator: _required,
                              ),
                              const Text(
                                'Separate multiple languages with commas.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                              _field(
                                _bio,
                                'About Me',
                                Icons.description_outlined,
                                lines: 5,
                                validator: _required,
                              ),
                            ],
                          ),

                          // PAYMENT INFORMATION
                          _section(
                            number: '05',
                            title: 'Payment Information',
                            subtitle:
                            'Set up UPI payments and your QR code',
                            icon:
                            Icons.account_balance_wallet_outlined,
                            children: [
                              _paymentNotice(),

                              _field(
                                _accountHolder,
                                'Account Holder Name',
                                Icons.person_outline,
                                validator:
                                _accountNameValidator,
                              ),
                              _field(
                                _upiId,
                                'UPI ID',
                                Icons.alternate_email_rounded,
                                validator: _upiValidator,
                              ),
                              _field(
                                _upiMobile,
                                'UPI Mobile Number',
                                Icons.phone_android_outlined,
                                type: TextInputType.phone,
                                validator:
                                _upiMobileValidator,
                              ),

                              const SizedBox(height: 4),

                              const Row(
                                children: [
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    color: _deepEmerald,
                                    size: 23,
                                  ),
                                  SizedBox(width: 9),
                                  Text(
                                    'Payment QR Code',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                      FontWeight.w800,
                                      color: _midnight,
                                    ),
                                  ),
                                ],
                              ),

                              _qrCode(),

                              const Center(
                                child: Text(
                                  'Never share your UPI PIN or OTP.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                    Color(0xFFC2414D),
                                    fontWeight:
                                    FontWeight.w700,
                                  ),
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

  // ============================================================
  // MIDNIGHT NAVIGATION BAR
  // ============================================================

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: _midnight,
      foregroundColor: Colors.white,
      surfaceTintColor: _midnight,
      elevation: 0,
      toolbarHeight: 72,
      leadingWidth: 66,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: Material(
            color: Colors.white.withOpacity(0.10),
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
                  color: Colors.white,
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
            'Worker Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'CREWSYNC  /  MY ACCOUNT',
            style: TextStyle(
              color: Color(0xFF98A2B3),
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
                color: _emerald.withOpacity(0.14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _emerald.withOpacity(0.22),
                ),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: _emerald,
                size: 23,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE DASHBOARD HERO
  // ============================================================

  Widget _buildProfileHero(double progress) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _midnight,
            Color(0xFF1C3143),
            Color(0xFF135A58),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _midnight.withOpacity(0.17),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -65,
              top: -75,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _emerald.withOpacity(0.10),
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
                    color: Colors.white.withOpacity(0.09),
                    width: 2,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _emerald,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor:
                          const Color(0xFFE5FAF4),
                          child: Text(
                            _initials(_name.text),
                            style: const TextStyle(
                              color: _midnight,
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
                                  ? 'CrewSync Worker'
                                  : _name.text.trim(),
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight:
                                FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _email.text,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                color:
                                Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _emerald.withOpacity(0.14),
                                borderRadius:
                                BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                  _emerald.withOpacity(0.35),
                                ),
                              ),
                              child: const Text(
                                'EVENT PROFESSIONAL',
                                style: TextStyle(
                                  color: _emerald,
                                  fontSize: 9,
                                  fontWeight:
                                  FontWeight.w900,
                                  letterSpacing: 0.9,
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
                      color: Colors.white.withOpacity(0.08),
                      borderRadius:
                      BorderRadius.circular(17),
                      border: Border.all(
                        color:
                        Colors.white.withOpacity(0.10),
                      ),
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
                                  color: _emerald,
                                  size: 19,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Profile completion',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight:
                                    FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                color: _emerald,
                                fontSize: 20,
                                fontWeight:
                                FontWeight.w900,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 13),

                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(20),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: progress,
                            ),
                            duration: const Duration(
                              milliseconds: 600,
                            ),
                            builder:
                                (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                backgroundColor:
                                Colors.white24,
                                valueColor:
                                const AlwaysStoppedAnimation<
                                    Color>(_emerald),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 11),

                        Text(
                          progress >= 1
                              ? 'Great! Your profile details are filled in.'
                              : 'Complete your details to make your profile stand out.',
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
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

  // ============================================================
  // INTRO SECTION
  // ============================================================

  Widget _buildIntro() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Build your professional profile',
          style: TextStyle(
            color: _midnight,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Keep your information up to date and get ready for new event opportunities.',
          style: TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MODERN SECTION CARD
  // ============================================================

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
                  color: _mint,
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: _deepEmerald,
                    size: 23,
                  ),
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
                        color: _midnight,
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w800,
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
                  color: Color(0xFFD0D5DD),
                  fontSize: 22,
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
              color: _surface,
              borderRadius:
              BorderRadius.circular(22),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _midnight.withOpacity(0.045),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const SizedBox(height: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFESSIONAL INPUT FIELDS
  // ============================================================

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
      style: const TextStyle(
        color: _text,
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
          color: _deepEmerald,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(
          icon,
          color: _deepEmerald,
          size: 21,
        ),
        filled: true,
        fillColor: enabled
            ? _fieldBackground
            : const Color(0xFFF2F4F7),
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _deepEmerald,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        focusedErrorBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWNS
  // ============================================================

  Widget _dropdown(
      String label,
      String? value,
      List<String> options,
      ValueChanged<String?> onChanged,
      ) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: Colors.white,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _deepEmerald,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _muted,
          fontSize: 13,
        ),
        filled: true,
        fillColor: _fieldBackground,
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _deepEmerald,
            width: 1.8,
          ),
        ),
      ),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(
            option,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: _text,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) =>
      value == null ? 'Required' : null,
    );
  }

  // ============================================================
  // INTERACTIVE SKILL CHIPS
  // ============================================================

  Widget _skillChip(String skill) {
    final selected = _asList(_skills.text).any(
          (value) =>
      value.toLowerCase() ==
          skill.toLowerCase(),
    );

    return FilterChip(
      selected: selected,
      showCheckmark: true,
      checkmarkColor: _deepEmerald,
      selectedColor: _mint,
      backgroundColor: _fieldBackground,
      side: BorderSide(
        color: selected
            ? _deepEmerald
            : _border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
      label: Text(
        skill,
        style: TextStyle(
          color: selected
              ? _deepEmerald
              : _text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      onSelected: (isSelected) {
        final skills = _asList(_skills.text);

        skills.removeWhere(
              (value) =>
          value.toLowerCase() ==
              skill.toLowerCase(),
        );

        if (isSelected) {
          skills.add(skill);
        }

        _skills.text = skills.join(', ');
      },
    );
  }

  // ============================================================
  // PAYMENT NOTICE
  // ============================================================

  Widget _paymentNotice() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFBCECE0),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: _deepEmerald,
            size: 23,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Add your UPI information to receive payments from organizers. Payment details are optional.',
              style: TextStyle(
                color: _navy,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT QR CODE
  // ============================================================

  Widget _qrCode() {
    final valid = _validPayment;

    return AnimatedContainer(
      duration:
      const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: valid
            ? _mint
            : _fieldBackground,
        borderRadius:
        BorderRadius.circular(19),
        border: Border.all(
          color: valid
              ? const Color(0xFFBCECE0)
              : _border,
        ),
      ),
      child: AnimatedSwitcher(
        duration:
        const Duration(milliseconds: 300),
        child: valid
            ? Column(
          key: const ValueKey('validQr'),
          children: [
            Container(
              padding:
              const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: _midnight
                        .withOpacity(0.07),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: QrImageView(
                data: _paymentUri,
                version: QrVersions.auto,
                size: 195,
                backgroundColor:
                Colors.white,
                errorCorrectionLevel:
                QrErrorCorrectLevel.M,
              ),
            ),

            const SizedBox(height: 15),

            Text(
              _upiId.text.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _midnight,
                fontSize: 15,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              _accountHolder.text.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Scan using any UPI payment app',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _deepEmerald,
                fontSize: 12,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],
        )
            : const Column(
          key: ValueKey('emptyQr'),
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 80,
              color: Color(0xFF98A2B3),
            ),

            SizedBox(height: 10),

            Text(
              'Your Payment QR',
              style: TextStyle(
                color: _midnight,
                fontSize: 15,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            SizedBox(height: 7),

            Text(
              'Enter valid UPI details to generate your QR code automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM SAVE NAVIGATION
  // ============================================================

  Widget _buildBottomSaveBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          18,
          13,
          18,
          15,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(
              color: _border,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _midnight.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                _deepEmerald,
                _emerald,
              ],
            ),
            borderRadius:
            BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: _deepEmerald.withOpacity(0.24),
                blurRadius: 13,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius:
              BorderRadius.circular(17),
              onTap: _saving
                  ? null
                  : _saveProfile,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 250,
                  ),
                  child: _saving
                      ? const Row(
                    key: ValueKey('saving'),
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Saving Profile...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                      : const Row(
                    key: ValueKey('save'),
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: _midnight,
                        size: 23,
                      ),
                      SizedBox(width: 11),
                      Text(
                        'Save Profile',
                        style: TextStyle(
                          color: _midnight,
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 11),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: _midnight,
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VALIDATION — PRESERVED
  // ============================================================

  String? _required(String? value) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  String? _phoneValidator(String? value) {
    final phone = (value ?? '')
        .replaceAll(' ', '')
        .replaceFirst('+91', '');

    if (!RegExp(r'^[0-9]{10}$')
        .hasMatch(phone)) {
      return 'Enter a valid 10 digit phone number';
    }

    return null;
  }

  String? _ageValidator(String? value) {
    final age =
    int.tryParse(value?.trim() ?? '');

    if (age == null ||
        age < 18 ||
        age > 80) {
      return 'Enter a valid age between 18 and 80';
    }

    return null;
  }

  String? _yearsValidator(String? value) {
    final years =
    int.tryParse(value?.trim() ?? '');

    if (years == null ||
        years < 0 ||
        years > 60) {
      return 'Enter valid experience years';
    }

    return null;
  }

  String? _upiValidator(String? value) {
    final upi = value?.trim() ?? '';

    if (upi.isEmpty) return null;

    if (!RegExp(
      r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$',
    ).hasMatch(upi)) {
      return 'Enter a valid UPI ID';
    }

    return null;
  }

  String? _upiMobileValidator(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) return null;

    if (!RegExp(r'^[0-9]{10}$')
        .hasMatch(phone)) {
      return 'Enter a valid 10 digit UPI mobile number';
    }

    return null;
  }

  String? _accountNameValidator(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) return null;

    if (name.length < 2) {
      return 'Enter a valid account holder name';
    }

    return null;
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _successDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(22),
          ),
          icon: const CircleAvatar(
            radius: 33,
            backgroundColor: _mint,
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: _deepEmerald,
              size: 39,
            ),
          ),
          title: const Text(
            'Profile Saved',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _midnight,
            ),
          ),
          content: const Text(
            'Your worker profile and payment details have been saved successfully.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
            ),
          ),
          actionsAlignment:
          MainAxisAlignment.center,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                _deepEmerald,
                foregroundColor:
                Colors.white,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 35,
                  vertical: 12,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _message(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? const Color(0xFFC83F4A)
            : _deepEmerald,
        behavior:
        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(13),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE INITIALS
  // ============================================================

  String _initials(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return 'W';
    }

    final parts = trimmed
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'
        .toUpperCase();
  }
}
