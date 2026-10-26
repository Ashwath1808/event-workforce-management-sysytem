
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'application_model.dart';
import 'application_service.dart';
import 'job_model.dart';

// ============================================================
// CREWSYNC — SHARED WORKER & ORGANIZER JOB DETAILS
// MIDNIGHT NAVY + CORAL ORANGE + TEAL
// ============================================================

class JobDetailsPage extends StatefulWidget {
  final JobModel job;

  const JobDetailsPage({
    super.key,
    required this.job,
  });

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  static const Color _bg = Color(0xFF0B1220);
  static const Color _card = Color(0xFF19263B);
  static const Color _softCard = Color(0xFF203149);
  static const Color _border = Color(0xFF2B3D54);
  static const Color _coral = Color(0xFFF06449);
  static const Color _brightCoral = Color(0xFFFF7857);
  static const Color _teal = Color(0xFF35D1AC);
  static const Color _white = Color(0xFFF7F9FC);
  static const Color _muted = Color(0xFFA7B7CD);
  static const Color _amber = Color(0xFFFFC178);

  final ApplicationService _applicationService =
  ApplicationService();

  bool _isApplying = false;
  bool _alreadyApplied = false;
  bool _checkingApplication = true;
  bool _isOrganizer = false;

  bool get _ownsJob =>
      FirebaseAuth.instance.currentUser?.uid ==
          widget.job.organizerId;

  @override
  void initState() {
    super.initState();
    _initializeViewer();
  }

  // ============================================================
  // ROLE VERIFICATION
  // ============================================================

  Future<void> _initializeViewer() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _checkingApplication = false;
          _isOrganizer = true;
        });
      }
      return;
    }

    if (_ownsJob) {
      if (mounted) {
        setState(() {
          _isOrganizer = true;
          _checkingApplication = false;
        });
      }
      return;
    }

    try {
      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final data = userDocument.data() ?? {};

      final role = (data['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (!mounted) return;

      if (role == 'organizer' || role == 'organiser') {
        setState(() {
          _isOrganizer = true;
          _checkingApplication = false;
        });
        return;
      }

      if (role != 'worker') {
        setState(() {
          _isOrganizer = true;
          _checkingApplication = false;
        });
        return;
      }

      await _checkAlreadyApplied();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isOrganizer = true;
        _checkingApplication = false;
      });

      _showError('Unable to verify your account: $e');
    }
  }

  Future<void> _checkAlreadyApplied() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || _ownsJob || _isOrganizer) {
      if (mounted) {
        setState(() {
          _checkingApplication = false;
        });
      }
      return;
    }

    try {
      final applied =
      await _applicationService.hasWorkerApplied(
        jobId: widget.job.id,
        workerId: currentUser.uid,
      );

      if (!mounted) return;

      setState(() {
        _alreadyApplied = applied;
        _checkingApplication = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _alreadyApplied = true;
        _checkingApplication = false;
      });

      _showError('Unable to check application status: $e');
    }
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _coral,
          secondary: _teal,
          surface: _card,
          onSurface: _white,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    4,
                    18,
                    30,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      _buildHeroCard(job),
                      const SizedBox(height: 17),
                      _buildEventDetails(job),
                      const SizedBox(height: 17),
                      _buildSkills(job),
                      const SizedBox(height: 17),
                      _buildDescription(job),
                      const SizedBox(height: 17),
                      _buildRequirements(job),
                      const SizedBox(height: 23),

                      if (_checkingApplication)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(15),
                            child: CircularProgressIndicator(
                              color: _coral,
                            ),
                          ),
                        )
                      else if (!_isOrganizer && !_ownsJob)
                        _buildApplyButton()
                      else
                        _buildOrganizerNotice(),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEAMLESS HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        18,
        15,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _white,
              size: 21,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job Details',
                  style: TextStyle(
                    color: _white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Everything you need to know',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: _coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _coral.withValues(alpha: 0.20),
              ),
            ),
            child: const Icon(
              Icons.work_outline_rounded,
              color: _brightCoral,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================

  Widget _buildHeroCard(JobModel job) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF293A52),
            Color(0xFF19263B),
            Color(0xFF152338),
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: _coral.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  color: _brightCoral,
                  size: 26,
                ),
              ),
              const Spacer(),
              _smallBadge(
                job.status.toUpperCase(),
                _teal,
              ),
            ],
          ),
          const SizedBox(height: 19),
          Text(
            job.title,
            style: const TextStyle(
              color: _white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            job.category,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 19),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _bg.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 41,
                  height: 41,
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.currency_rupee_rounded,
                    color: _teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PAYMENT PER WORKER',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '₹${job.paymentPerWorker.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _teal,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.payments_outlined,
                  color: _teal,
                  size: 23,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EVENT DETAILS
  // ============================================================

  Widget _buildEventDetails(JobModel job) {
    return _sectionCard(
      icon: Icons.event_note_outlined,
      title: 'Event Information',
      children: [
        _detailRow(
          Icons.location_on_outlined,
          'Location',
          job.location,
        ),
        _detailRow(
          Icons.calendar_today_outlined,
          'Event Date',
          job.date,
        ),
        _detailRow(
          Icons.access_time_outlined,
          'Working Hours',
          '${job.startTime} - ${job.endTime}',
        ),
        _detailRow(
          Icons.groups_outlined,
          'Workers Needed',
          '${job.workersNeeded}',
        ),
        _detailRow(
          Icons.payments_outlined,
          'Payment',
          '₹${job.paymentPerWorker.toStringAsFixed(0)} / worker',
          last: true,
        ),
      ],
    );
  }

  // ============================================================
  // SKILLS
  // ============================================================

  Widget _buildSkills(JobModel job) {
    return _sectionCard(
      icon: Icons.workspace_premium_outlined,
      title: 'Skills Required',
      children: [
        if (job.skills.isEmpty)
          const Text(
            'No specific skills required for this job.',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              height: 1.5,
            ),
          )
        else
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: job.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _teal.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================

  Widget _buildDescription(JobModel job) {
    return _sectionCard(
      icon: Icons.description_outlined,
      title: 'Job Description',
      children: [
        Text(
          job.description.trim().isEmpty
              ? 'No description provided.'
              : job.description,
          style: const TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REQUIREMENTS
  // ============================================================

  Widget _buildRequirements(JobModel job) {
    return _sectionCard(
      icon: Icons.fact_check_outlined,
      title: 'Facilities & Requirements',
      children: [
        _requirementRow(
          Icons.bed_outlined,
          'Accommodation',
          job.accommodationRequired,
        ),
        _requirementRow(
          Icons.restaurant_outlined,
          'Food Provided',
          job.foodProvided,
        ),
        _requirementRow(
          Icons.directions_bus_outlined,
          'Transport',
          job.transportProvided,
        ),
        if (job.otherRequirements.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(color: _border),
          const SizedBox(height: 11),
          const Text(
            'ADDITIONAL REQUIREMENTS',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            job.otherRequirements,
            style: const TextStyle(
              color: _white,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // REUSABLE SECTION CARD
  // ============================================================

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _coral.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: _brightCoral,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(
      IconData icon,
      String label,
      String value, {
        bool last = false,
      }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: _coral,
            size: 18,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value.trim().isEmpty
                  ? 'Not provided'
                  : value,
              style: const TextStyle(
                color: _white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requirementRow(
      IconData icon,
      String title,
      bool available,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _muted,
            size: 19,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            available
                ? Icons.check_circle_rounded
                : Icons.cancel_outlined,
            color: available ? _teal : _muted,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            available ? 'Yes' : 'No',
            style: TextStyle(
              color: available ? _teal : _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // ORGANIZER VIEW
  // ============================================================

  Widget _buildOrganizerNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softCard,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            color: _brightCoral,
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'You are viewing the job details. '
                  'Only workers can submit applications.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WORKER APPLY BUTTON
  // ============================================================

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: FilledButton(
        onPressed: _isApplying || _alreadyApplied
            ? null
            : _showApplyConfirmation,
        style: FilledButton.styleFrom(
          backgroundColor: _coral,
          disabledBackgroundColor:
          _alreadyApplied ? const Color(0xFF17695D) : _softCard,
          foregroundColor: _white,
          disabledForegroundColor: _white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isApplying
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                strokeWidth: 2.3,
                color: _white,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Submitting...',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        )
            : _alreadyApplied
            ? const Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded),
            SizedBox(width: 9),
            Text(
              'Application Submitted',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        )
            : const Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(Icons.send_rounded, size: 19),
            SizedBox(width: 9),
            Text(
              'Apply for this Job',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APPLY CONFIRMATION
  // ============================================================

  Future<void> _showApplyConfirmation() async {
    if (_isOrganizer ||
        _ownsJob ||
        _checkingApplication ||
        _alreadyApplied ||
        _isApplying) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Apply for Job',
            style: TextStyle(
              color: _white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Do you want to apply for "${widget.job.title}"?',
            style: const TextStyle(
              color: _muted,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _muted),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: _white,
              ),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _applyForJob();
  }

  // ============================================================
  // FIREBASE APPLICATION SUBMISSION
  // ============================================================

  Future<void> _applyForJob() async {
    if (_isApplying ||
        _alreadyApplied ||
        _checkingApplication ||
        _isOrganizer ||
        _ownsJob) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showError('Please login again before applying.');
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDocument.exists) {
        if (mounted) {
          await _showProfileRequiredDialog();
        }
        return;
      }

      final Map<String, dynamic> data =
          userDocument.data() ?? {};

      final role = (data['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (role != 'worker' || _ownsJob) {
        if (mounted) {
          setState(() {
            _isOrganizer = true;
          });
          _showError('Only workers can apply for jobs.');
        }
        return;
      }

      final profileCompleted =
          data['profileCompleted'] == true;

      if (!profileCompleted) {
        if (mounted) {
          await _showProfileRequiredDialog();
        }
        return;
      }

      final alreadyApplied =
      await _applicationService.hasWorkerApplied(
        jobId: widget.job.id,
        workerId: currentUser.uid,
      );

      if (alreadyApplied) {
        if (mounted) {
          setState(() {
            _alreadyApplied = true;
          });
        }
        return;
      }

      String workerName =
          data['name']?.toString().trim() ?? '';

      String workerEmail =
          data['email']?.toString().trim() ?? '';

      final String workerPhone =
          data['phone']?.toString().trim() ?? '';

      final int workerAge = _parseInt(data['age']);

      final String workerGender =
          data['gender']?.toString().trim() ?? '';

      final String workerCity =
          data['city']?.toString().trim() ?? '';

      final List<String> workerSkills =
      _parseStringList(data['skills']);

      final String workerExperienceLevel =
          data['experienceLevel']?.toString().trim() ?? '';

      final int workerExperienceYears =
      _parseInt(data['experienceYears']);

      final String workerPreviousWork =
          data['previousWork']?.toString().trim() ?? '';

      final String workerEducation =
          data['education']?.toString().trim() ?? '';

      final List<String> workerLanguages =
      _parseStringList(data['languages']);

      final String workerBio =
          data['bio']?.toString().trim() ?? '';

      if (workerName.isEmpty) {
        workerName = currentUser.displayName ?? 'Worker';
      }

      if (workerName.trim().isEmpty) {
        workerName = 'Worker';
      }

      if (workerEmail.isEmpty) {
        workerEmail = currentUser.email ?? '';
      }

      final application = ApplicationModel(
        id: '',
        jobId: widget.job.id,
        jobTitle: widget.job.title,
        organizerId: widget.job.organizerId,
        workerId: currentUser.uid,
        workerName: workerName,
        workerEmail: workerEmail,
        workerPhone: workerPhone,
        workerAge: workerAge,
        workerGender: workerGender,
        workerCity: workerCity,
        workerSkills: workerSkills,
        workerExperienceLevel: workerExperienceLevel,
        workerExperienceYears: workerExperienceYears,
        workerPreviousWork: workerPreviousWork,
        workerEducation: workerEducation,
        workerLanguages: workerLanguages,
        workerBio: workerBio,
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      await _applicationService.applyForJob(
        application: application,
      );

      if (!mounted) return;

      setState(() {
        _alreadyApplied = true;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(
              Icons.check_circle_rounded,
              color: _teal,
              size: 54,
            ),
            title: const Text(
              'Application Submitted',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text(
              'Your application has been sent to the organizer successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext),
                child: const Text(
                  'OK',
                  style: TextStyle(color: _teal),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  // ============================================================
  // PROFILE COMPLETION DIALOG
  // ============================================================

  Future<void> _showProfileRequiredDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.person_outline_rounded,
            color: _brightCoral,
            size: 53,
          ),
          title: const Text(
            'Complete Your Profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Please complete your worker profile before applying for jobs.\n\n'
                'Add your skills, experience and other details from the '
                'Profile section in the Worker Dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: _coral,
                foregroundColor: _white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DATA HELPERS
  // ============================================================

  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  void _showError(String error) {
    if (!mounted) return;

    final cleanError = error
        .replaceFirst('Exception: ', '')
        .replaceFirst(
      '[cloud_firestore/permission-denied] ',
      '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanError),
        backgroundColor: const Color(0xFFB83F4D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
