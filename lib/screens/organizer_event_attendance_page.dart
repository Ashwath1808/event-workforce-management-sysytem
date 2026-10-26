
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'application_model.dart';
import 'application_service.dart';
import 'attendance_model.dart';
import 'attendance_service.dart';
import 'job_model.dart';

class OrganizerEventAttendancePage extends StatefulWidget {
  final JobModel job;

  const OrganizerEventAttendancePage({
    super.key,
    required this.job,
  });

  @override
  State<OrganizerEventAttendancePage> createState() =>
      _OrganizerEventAttendancePageState();
}

class _OrganizerEventAttendancePageState
    extends State<OrganizerEventAttendancePage> {
  // ============================================================
  // CREWSYNC — MIDNIGHT NAVY & CORAL THEME
  // ============================================================

  static const Color navy = Color(0xFF0B1220);
  static const Color panel = Color(0xFF19263B);
  static const Color panelLight = Color(0xFF203149);
  static const Color coral = Color(0xFFF06449);
  static const Color coralBright = Color(0xFFFF7857);
  static const Color teal = Color(0xFF35D1AC);
  static const Color muted = Color(0xFFA7B7CD);
  static const Color white = Color(0xFFF7F9FC);
  static const Color border = Color(0xFF2B3D54);
  static const Color amber = Color(0xFFFFC178);
  static const Color red = Color(0xFFFF8490);

  final ApplicationService _applicationService =
  ApplicationService();

  final AttendanceService _attendanceService =
  AttendanceService();

  final TextEditingController _searchController =
  TextEditingController();

  final Set<String> _processingWorkers = {};

  String _selectedFilter = 'All';
  String _searchQuery = '';

  static const List<String> _filters = [
    'All',
    'Pending',
    'Present',
    'Absent',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // MAIN PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: const ColorScheme.dark(
          primary: coral,
          secondary: teal,
          surface: panel,
          onSurface: white,
        ),
      ),
      child: Scaffold(
        backgroundColor: navy,
        body: SafeArea(
          child: Column(
            children: [
              _buildPageHeader(),
              Expanded(
                child: currentUser == null
                    ? _buildError(
                  'Session expired. Please log in again.',
                )
                    : StreamBuilder<List<ApplicationModel>>(
                  stream: _applicationService
                      .getOrganizerApplications(
                    currentUser.uid,
                  ),
                  builder: (context, applicationSnapshot) {
                    if (applicationSnapshot.hasError) {
                      return _buildError(
                        'Unable to load accepted workers.\n'
                            '${applicationSnapshot.error}',
                      );
                    }

                    if (!applicationSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: coral,
                        ),
                      );
                    }

                    final acceptedWorkers =
                    applicationSnapshot.data!
                        .where(
                          (application) =>
                      application.jobId ==
                          widget.job.id &&
                          application.status
                              .trim()
                              .toLowerCase() ==
                              'accepted',
                    )
                        .toList();

                    return StreamBuilder<
                        List<AttendanceModel>>(
                      stream: _attendanceService
                          .getOrganizerJobAttendance(
                        organizerId: currentUser.uid,
                        jobId: widget.job.id,
                      ),
                      builder: (
                          context,
                          attendanceSnapshot,
                          ) {
                        if (attendanceSnapshot.hasError) {
                          return _buildError(
                            'Unable to load attendance records.\n'
                                '${attendanceSnapshot.error}',
                          );
                        }

                        if (!attendanceSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: coral,
                            ),
                          );
                        }

                        final attendanceMap =
                        <String, AttendanceModel>{};

                        for (final record
                        in attendanceSnapshot.data!) {
                          attendanceMap[record.workerId] =
                              record;
                        }

                        return _buildBody(
                          acceptedWorkers: acceptedWorkers,
                          attendanceMap: attendanceMap,
                          organizerId: currentUser.uid,
                        );
                      },
                    );
                  },
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

  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 18, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: white,
              size: 21,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Attendance',
                  style: TextStyle(
                    color: white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage accepted workers',
                  style: TextStyle(
                    color: muted,
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
              color: coral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: coral.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: coralBright,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BODY AND ATTENDANCE CALCULATIONS
  // ============================================================

  Widget _buildBody({
    required List<ApplicationModel> acceptedWorkers,
    required Map<String, AttendanceModel> attendanceMap,
    required String organizerId,
  }) {
    int present = 0;
    int absent = 0;
    int pending = 0;

    for (final worker in acceptedWorkers) {
      final status = attendanceMap[worker.workerId]
          ?.status
          .trim()
          .toLowerCase() ??
          'not_marked';

      if (status == 'present') {
        present++;
      } else if (status == 'absent') {
        absent++;
      } else {
        pending++;
      }
    }

    final query = _searchQuery.trim().toLowerCase();

    final filteredWorkers = acceptedWorkers.where((worker) {
      final status = attendanceMap[worker.workerId]
          ?.status
          .trim()
          .toLowerCase() ??
          'not_marked';

      final matchesSearch = query.isEmpty ||
          worker.workerName.toLowerCase().contains(query) ||
          worker.workerEmail.toLowerCase().contains(query) ||
          worker.workerCity.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      switch (_selectedFilter) {
        case 'Pending':
          return status != 'present' && status != 'absent';
        case 'Present':
          return status == 'present';
        case 'Absent':
          return status == 'absent';
        default:
          return true;
      }
    }).toList();

    return Column(
      children: [
        _buildEventHeader(),
        const SizedBox(height: 14),
        _buildSummary(
          total: acceptedWorkers.length,
          present: present,
          absent: absent,
          pending: pending,
        ),
        const SizedBox(height: 17),
        _buildSearch(),
        const SizedBox(height: 13),
        _buildFilters(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Row(
            children: [
              const Text(
                'WORKFORCE',
                style: TextStyle(
                  color: white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${filteredWorkers.length} workers',
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: acceptedWorkers.isEmpty
              ? _noAcceptedWorkers()
              : filteredWorkers.isEmpty
              ? _noFilteredWorkers()
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              18,
              2,
              18,
              30,
            ),
            itemCount: filteredWorkers.length,
            itemBuilder: (context, index) {
              final worker = filteredWorkers[index];

              return _buildWorkerCard(
                worker: worker,
                attendance:
                attendanceMap[worker.workerId],
                organizerId: organizerId,
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EVENT OVERVIEW CARD
  // ============================================================

  Widget _buildEventHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 5, 18, 0),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF25344B),
            Color(0xFF19263B),
            Color(0xFF152338),
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: coral.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: coralBright,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EVENT DETAILS',
                      style: TextStyle(
                        color: coralBright,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(
            color: border,
            height: 1,
          ),
          const SizedBox(height: 15),
          _headerDetail(
            Icons.calendar_today_outlined,
            widget.job.date.isEmpty
                ? 'Date not provided'
                : widget.job.date,
          ),
          const SizedBox(height: 11),
          _headerDetail(
            Icons.access_time_outlined,
            _jobTime(),
          ),
          const SizedBox(height: 11),
          _headerDetail(
            Icons.location_on_outlined,
            widget.job.location.isEmpty
                ? 'Location not provided'
                : widget.job.location,
          ),
        ],
      ),
    );
  }

  Widget _headerDetail(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: coralBright,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ATTENDANCE SUMMARY
  // ============================================================

  Widget _buildSummary({
    required int total,
    required int present,
    required int absent,
    required int pending,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(
        vertical: 17,
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _summaryItem(
            'Accepted',
            total,
            white,
            Icons.groups_outlined,
          ),
          _summaryDivider(),
          _summaryItem(
            'Present',
            present,
            teal,
            Icons.check_circle_outline,
          ),
          _summaryDivider(),
          _summaryItem(
            'Absent',
            absent,
            red,
            Icons.cancel_outlined,
          ),
          _summaryDivider(),
          _summaryItem(
            'Pending',
            pending,
            amber,
            Icons.schedule_outlined,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
      String title,
      int value,
      Color color,
      IconData icon,
      ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 43,
      color: border,
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: TextField(
        controller: _searchController,
        cursorColor: coral,
        style: const TextStyle(
          color: white,
          fontSize: 14,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search name, email or city...',
          hintStyle: const TextStyle(
            color: muted,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: coralBright,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: muted,
            ),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          ),
          filled: true,
          fillColor: panel,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: coral,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTER CHIPS
  // ============================================================

  Widget _buildFilters() {
    return SizedBox(
      height: 41,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: _filters.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = _selectedFilter == filter;

          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            showCheckmark: false,
            selectedColor: coral,
            backgroundColor: panel,
            side: BorderSide(
              color: selected ? coral : border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            labelStyle: TextStyle(
              color: selected ? white : muted,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // WORKER CARD
  // ============================================================

  Widget _buildWorkerCard({
    required ApplicationModel worker,
    required AttendanceModel? attendance,
    required String organizerId,
  }) {
    final status =
        attendance?.status.trim().toLowerCase() ??
            'not_marked';

    final processing =
    _processingWorkers.contains(worker.workerId);

    final eventCancelled =
        widget.job.status.trim().toLowerCase() ==
            'cancelled';

    final canMark = !eventCancelled &&
        !processing &&
        (attendance == null || status == 'not_marked');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF31445B),
                      Color(0xFF203149),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Center(
                  child: Text(
                    _initials(worker.workerName),
                    style: const TextStyle(
                      color: coralBright,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.workerName.trim().isEmpty
                          ? 'Worker'
                          : worker.workerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      worker.workerEmail.trim().isEmpty
                          ? 'Email not provided'
                          : worker.workerEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: muted,
                size: 15,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  worker.workerCity.trim().isEmpty
                      ? 'Location not provided'
                      : worker.workerCity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
              ),
              _attendanceStatus(status),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(
            color: border,
            height: 1,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 43,
            child: OutlinedButton.icon(
              onPressed: () => _showWorkerProfile(worker),
              style: OutlinedButton.styleFrom(
                foregroundColor: coralBright,
                side: const BorderSide(
                  color: border,
                ),
                backgroundColor: panelLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.person_search_outlined,
                size: 18,
              ),
              label: const Text(
                'View Full Profile',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (attendance?.markedAt != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_outlined,
                    size: 15,
                    color: teal,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Attendance marked on '
                          '${_formatDateTime(attendance!.markedAt!)}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (eventCancelled)
            _cancelledMessage()
          else if (processing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: coral,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          else if (!canMark)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: muted,
                      size: 17,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Attendance already recorded. '
                            'Your current Firestore rules do not allow '
                            'changing or resetting marked attendance.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _attendanceButtons(
                worker: worker,
                organizerId: organizerId,
                attendance: attendance,
              ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE BUTTONS
  // ============================================================

  Widget _attendanceButtons({
    required ApplicationModel worker,
    required String organizerId,
    required AttendanceModel? attendance,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _markAttendance(
                worker: worker,
                organizerId: organizerId,
                attendance: attendance,
                status: 'present',
              );
            },
            icon: const Icon(
              Icons.check_circle_outline,
              size: 18,
            ),
            label: const Text('Present'),
            style: ElevatedButton.styleFrom(
              backgroundColor: teal,
              foregroundColor: navy,
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _markAttendance(
                worker: worker,
                organizerId: organizerId,
                attendance: attendance,
                status: 'absent',
              );
            },
            icon: const Icon(
              Icons.cancel_outlined,
              size: 18,
            ),
            label: const Text('Absent'),
            style: ElevatedButton.styleFrom(
              backgroundColor: red,
              foregroundColor: navy,
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MARK ATTENDANCE — ORIGINAL FIREBASE LOGIC
  // ============================================================

  Future<void> _markAttendance({
    required ApplicationModel worker,
    required String organizerId,
    required AttendanceModel? attendance,
    required String status,
  }) async {
    if (_processingWorkers.contains(worker.workerId)) {
      return;
    }

    if (attendance != null &&
        attendance.status.trim().toLowerCase() !=
            'not_marked') {
      _showMessage(
        'Attendance is already marked for this worker.',
        error: true,
      );
      return;
    }

    setState(() {
      _processingWorkers.add(worker.workerId);
    });

    try {
      if (attendance == null) {
        await _attendanceService.createAttendanceIfMissing(
          jobId: widget.job.id,
          jobTitle: widget.job.title,
          organizerId: organizerId,
          workerId: worker.workerId,
          workerName: worker.workerName,
          workerEmail: worker.workerEmail,
        );
      }

      if (status == 'present') {
        await _attendanceService.markPresent(
          jobId: widget.job.id,
          workerId: worker.workerId,
          organizerId: organizerId,
        );
      } else {
        await _attendanceService.markAbsent(
          jobId: widget.job.id,
          workerId: worker.workerId,
          organizerId: organizerId,
        );
      }

      if (!mounted) return;

      _showMessage(
        status == 'present'
            ? '${worker.workerName} marked Present'
            : '${worker.workerName} marked Absent',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error.toString()),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingWorkers.remove(worker.workerId);
        });
      }
    }
  }

  void _showMessage(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? red : teal,
        content: Text(
          message,
          style: const TextStyle(
            color: navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ATTENDANCE STATUS BADGE
  // ============================================================

  Widget _attendanceStatus(String status) {
    final Color color;
    final String label;
    final IconData icon;

    if (status == 'present') {
      color = teal;
      label = 'Present';
      icon = Icons.check_circle_rounded;
    } else if (status == 'absent') {
      color = red;
      label = 'Absent';
      icon = Icons.cancel_rounded;
    } else {
      color = amber;
      label = 'Pending';
      icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FULL WORKER PROFILE
  // ============================================================

  void _showWorkerProfile(ApplicationModel worker) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: panel,
          insetPadding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 650,
              maxWidth: 520,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: panelLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundColor:
                        coral.withValues(alpha: 0.13),
                        child: Text(
                          _initials(worker.workerName),
                          style: const TextStyle(
                            color: coralBright,
                            fontWeight: FontWeight.w900,
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
                              worker.workerName.trim().isEmpty
                                  ? 'Worker'
                                  : worker.workerName,
                              style: const TextStyle(
                                color: white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              worker.workerEmail.trim().isEmpty
                                  ? 'Email not provided'
                                  : worker.workerEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: white,
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      _sectionTitle('Personal Information'),
                      const SizedBox(height: 12),
                      _dialogInfo(
                        'Full Name',
                        worker.workerName,
                      ),
                      _dialogInfo(
                        'Email',
                        worker.workerEmail,
                      ),
                      _dialogInfo(
                        'Phone',
                        worker.workerPhone,
                      ),
                      _dialogInfo(
                        'Age',
                        worker.workerAge <= 0
                            ? ''
                            : worker.workerAge.toString(),
                      ),
                      _dialogInfo(
                        'Gender',
                        worker.workerGender,
                      ),
                      _dialogInfo(
                        'City / Location',
                        worker.workerCity,
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('Skills & Experience'),
                      const SizedBox(height: 12),
                      _dialogInfo(
                        'Skills',
                        worker.workerSkills.join(', '),
                      ),
                      _dialogInfo(
                        'Experience Level',
                        worker.workerExperienceLevel,
                      ),
                      _dialogInfo(
                        'Years of Experience',
                        worker.workerExperienceYears <= 0
                            ? ''
                            : '${worker.workerExperienceYears} years',
                      ),
                      _dialogInfo(
                        'Previous Work / Events',
                        worker.workerPreviousWork,
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('Additional Information'),
                      const SizedBox(height: 12),
                      _dialogInfo(
                        'Education',
                        worker.workerEducation,
                      ),
                      _dialogInfo(
                        'Languages Known',
                        worker.workerLanguages.join(', '),
                      ),
                      _dialogInfo(
                        'About Me / Bio',
                        worker.workerBio,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: coral,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _dialogInfo(String label, String value) {
    final displayValue =
    value.trim().isEmpty ? 'Not provided' : value;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            displayValue,
            style: const TextStyle(
              color: white,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CANCELLED EVENT NOTICE
  // ============================================================

  Widget _cancelledMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: red.withValues(alpha: 0.18),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: red,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Attendance cannot be changed because '
                  'this event is cancelled.',
              style: TextStyle(
                color: red,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATES
  // ============================================================

  Widget _noAcceptedWorkers() {
    return _emptyState(
      Icons.groups_outlined,
      'No Accepted Workers',
      'Only workers whose applications are accepted '
          'will appear here.',
    );
  }

  Widget _noFilteredWorkers() {
    return _emptyState(
      Icons.search_off_rounded,
      'No Matching Workers',
      _searchQuery.trim().isNotEmpty
          ? 'No worker matches your search.'
          : 'No workers found in the '
          '$_selectedFilter category.',
    );
  }

  Widget _emptyState(
      IconData icon,
      String title,
      String description,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: coral.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 37,
                color: coralBright,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: muted,
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
  // ERROR STATE
  // ============================================================

  Widget _buildError(String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: red,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: red,
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
  // HELPERS
  // ============================================================

  String _jobTime() {
    final start = widget.job.startTime.trim();
    final end = widget.job.endTime.trim();

    if (start.isEmpty && end.isEmpty) {
      return 'Time not provided';
    }

    if (start.isEmpty) return end;
    if (end.isEmpty) return start;

    return '$start - $end';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'W';

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'
        .toUpperCase();
  }

  String _formatDateTime(DateTime value) {
    final date = value.toLocal();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    int hour = date.hour;
    final period = hour >= 12 ? 'PM' : 'AM';

    hour %= 12;
    if (hour == 0) hour = 12;

    final minute =
    date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} • '
        '$hour:$minute $period';
  }

  String _cleanError(String error) {
    return error.replaceFirst('Exception: ', '').trim();
  }
}
