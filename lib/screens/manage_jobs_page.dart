
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'job_model.dart';
import 'job_service.dart';

// ============================================================
// CREWSYNC — PROFESSIONAL ORGANIZER DESIGN
// ============================================================

const Color _bg = Color(0xFF0B1220);
const Color _card = Color(0xFF19263B);
const Color _cardSoft = Color(0xFF203149);
const Color _stroke = Color(0xFF2B3D54);
const Color _coral = Color(0xFFF06449);
const Color _coralBright = Color(0xFFFF7857);
const Color _teal = Color(0xFF35D1AC);
const Color _text = Color(0xFFF7F9FC);
const Color _subtext = Color(0xFFA7B7CD);

class ManageJobsPage extends StatefulWidget {
  const ManageJobsPage({super.key});

  @override
  State<ManageJobsPage> createState() => _ManageJobsPageState();
}

class _ManageJobsPageState extends State<ManageJobsPage> {
  final JobService _jobService = JobService();
  final TextEditingController _search = TextEditingController();

  final Set<String> _busyJobs = {};

  String _filter = 'All';

  static const List<String> _filters = [
    'All',
    'Active',
    'Closed',
    'Completed',
    'Cancelled',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return _teal;
      case 'closed':
        return const Color(0xFFFFC078);
      case 'completed':
        return const Color(0xFF9CA8FF);
      case 'cancelled':
        return const Color(0xFFFF8D96);
      default:
        return _subtext;
    }
  }

  List<JobModel> _filtered(List<JobModel> jobs) {
    final query = _search.text.trim().toLowerCase();

    return jobs.where((job) {
      final textMatch = query.isEmpty ||
          job.title.toLowerCase().contains(query) ||
          job.category.toLowerCase().contains(query) ||
          job.location.toLowerCase().contains(query);

      final statusMatch = _filter == 'All' ||
          job.status.toLowerCase() == _filter.toLowerCase();

      return textMatch && statusMatch;
    }).toList();
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _coral,
          secondary: _teal,
          surface: _card,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: user == null
                    ? _empty(
                  Icons.lock_outline_rounded,
                  'Sign in required',
                  'Sign in as an organizer to manage your jobs.',
                )
                    : StreamBuilder<List<JobModel>>(
                  stream: _jobService.getOrganizerJobs(
                    user.uid,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _empty(
                        Icons.cloud_off_rounded,
                        'Unable to load jobs',
                        '${snapshot.error}',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _coral,
                        ),
                      );
                    }

                    final all = snapshot.data!;
                    final jobs = _filtered(all);

                    final active = all
                        .where(
                          (job) =>
                      job.status.toLowerCase() ==
                          'active',
                    )
                        .length;

                    final applications = all.fold<int>(
                      0,
                          (sum, job) =>
                      sum + job.applicationsCount,
                    );

                    final accepted = all.fold<int>(
                      0,
                          (sum, job) =>
                      sum + job.acceptedWorkers,
                    );

                    return Column(
                      children: [
                        _summary(
                          total: all.length,
                          active: active,
                          applications: applications,
                          accepted: accepted,
                        ),
                        _searchField(),
                        _filterBar(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: jobs.isEmpty
                              ? _empty(
                            Icons.work_outline_rounded,
                            all.isEmpty
                                ? 'No jobs posted yet'
                                : 'No matching jobs',
                            all.isEmpty
                                ? 'Your published jobs will appear here.'
                                : 'Try another keyword or filter.',
                          )
                              : ListView.separated(
                            physics:
                            const BouncingScrollPhysics(),
                            padding:
                            const EdgeInsets.fromLTRB(
                              18,
                              4,
                              18,
                              30,
                            ),
                            itemCount: jobs.length,
                            separatorBuilder:
                                (_, __) =>
                            const SizedBox(
                              height: 14,
                            ),
                            itemBuilder:
                                (context, index) {
                              return _jobCard(
                                jobs[index],
                              );
                            },
                          ),
                        ),
                      ],
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _text,
              size: 21,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Jobs',
                  style: TextStyle(
                    color: _text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage and track your job postings',
                  style: TextStyle(
                    color: _subtext,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _coral.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _coral.withOpacity(0.18),
              ),
            ),
            child: const Icon(
              Icons.work_outline_rounded,
              color: _coralBright,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _summary({
    required int total,
    required int active,
    required int applications,
    required int accepted,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 18),
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
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: _coralBright,
                size: 18,
              ),
              SizedBox(width: 9),
              Text(
                'YOUR JOB OVERVIEW',
                style: TextStyle(
                  color: _subtext,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              _stat(
                'Total',
                '$total',
                Icons.layers_outlined,
                _text,
              ),
              _stat(
                'Active',
                '$active',
                Icons.bolt_rounded,
                _teal,
              ),
              _stat(
                'Applied',
                '$applications',
                Icons.people_outline_rounded,
                _coralBright,
              ),
              _stat(
                'Accepted',
                '$accepted',
                Icons.verified_outlined,
                const Color(0xFFFFC078),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _subtext,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: TextField(
        controller: _search,
        cursorColor: _coral,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: _text,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search jobs, categories, locations...',
          hintStyle: const TextStyle(
            color: _subtext,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _coralBright,
          ),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _search.clear();
              setState(() {});
            },
            icon: const Icon(
              Icons.close_rounded,
              color: _subtext,
            ),
          ),
          filled: true,
          fillColor: _card,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _coral,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================

  Widget _filterBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: _filters.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final label = _filters[index];
          final selected = label == _filter;

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _filter = label);
            },
            backgroundColor: _card,
            selectedColor: _coral,
            side: BorderSide(
              color: selected ? _coral : _stroke,
            ),
            labelStyle: TextStyle(
              color: selected ? _text : _subtext,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // JOB CARD
  // ============================================================

  Widget _jobCard(JobModel job) {
    final statusColor = _statusColor(job.status);
    final busy = _busyJobs.contains(job.id);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: _coral.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: _coralBright,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.category,
                      style: const TextStyle(
                        color: _subtext,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  job.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          _info(
            Icons.location_on_outlined,
            job.location,
          ),
          const SizedBox(height: 10),
          _info(
            Icons.calendar_month_outlined,
            job.date,
          ),
          const SizedBox(height: 10),
          _info(
            Icons.schedule_outlined,
            '${job.startTime} – ${job.endTime}',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _metric(
                '${job.workersNeeded}',
                'Needed',
              ),
              const SizedBox(width: 9),
              _metric(
                '${job.applicationsCount}',
                'Applied',
              ),
              const SizedBox(width: 9),
              _metric(
                '${job.acceptedWorkers}',
                'Accepted',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _teal.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.currency_rupee_rounded,
                  color: _teal,
                  size: 19,
                ),
                Text(
                  '${job.paymentPerWorker.toStringAsFixed(0)} / worker',
                  style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(
            color: _stroke,
            height: 1,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  'View',
                  Icons.visibility_outlined,
                      () => _showJobDetails(job),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _actionButton(
                  'Edit',
                  Icons.edit_outlined,
                      () => _showEditDialog(job),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _actionButton(
                  'More',
                  Icons.more_horiz_rounded,
                      () => _showJobActions(job),
                ),
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 13),
            const LinearProgressIndicator(
              color: _coral,
              backgroundColor: _stroke,
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: _coralBright,
          size: 17,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(
              color: _subtext,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _stroke),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _subtext,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
      String label,
      IconData icon,
      VoidCallback onTap,
      ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _text,
        side: const BorderSide(color: _stroke),
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY / ERROR STATE
  // ============================================================

  Widget _empty(
      IconData icon,
      String title,
      String subtitle,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _coral.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: _coralBright,
                size: 38,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _subtext,
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
  // JOB DETAILS
  // ============================================================

  void _showJobDetails(JobModel job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _subtext,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                job.title,
                style: const TextStyle(
                  color: _text,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _detail('Status', job.status),
              _detail('Category', job.category),
              _detail('Location', job.location),
              _detail('Date', job.date),
              _detail(
                'Time',
                '${job.startTime} – ${job.endTime}',
              ),
              _detail(
                'Workers needed',
                '${job.workersNeeded}',
              ),
              _detail(
                'Applications',
                '${job.applicationsCount}',
              ),
              _detail(
                'Accepted workers',
                '${job.acceptedWorkers}',
              ),
              _detail(
                'Payment per worker',
                '₹${job.paymentPerWorker.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 20),
              _sectionHeading('DESCRIPTION'),
              const SizedBox(height: 9),
              Text(
                job.description.isEmpty
                    ? 'No description provided.'
                    : job.description,
                style: const TextStyle(
                  color: _text,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _sectionHeading('SKILLS REQUIRED'),
              const SizedBox(height: 10),
              job.skills.isEmpty
                  ? const Text(
                'No skills specified',
                style: TextStyle(color: _subtext),
              )
                  : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: job.skills.map((skill) {
                  return Chip(
                    label: Text(skill),
                    backgroundColor: _bg,
                    labelStyle: const TextStyle(
                      color: _text,
                    ),
                    side: const BorderSide(
                      color: _stroke,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              _sectionHeading('FACILITIES'),
              const SizedBox(height: 10),
              _facility(
                'Accommodation',
                job.accommodationRequired,
              ),
              _facility('Food', job.foodProvided),
              _facility('Transport', job.transportProvided),
              if (job.otherRequirements.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionHeading('OTHER REQUIREMENTS'),
                const SizedBox(height: 9),
                Text(
                  job.otherRequirements,
                  style: const TextStyle(
                    color: _text,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _coralBright,
        fontSize: 12,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: _subtext,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _facility(String name, bool available) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            available
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            color: available ? _teal : _coral,
            size: 19,
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(
              color: _text,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT JOB
  // ============================================================

  Future<void> _showEditDialog(JobModel job) async {
    final title = TextEditingController(text: job.title);
    final location = TextEditingController(text: job.location);
    final workers = TextEditingController(
      text: '${job.workersNeeded}',
    );
    final payment = TextEditingController(
      text: job.paymentPerWorker.toStringAsFixed(0),
    );

    final key = GlobalKey<FormState>();
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Edit Job',
              style: TextStyle(
                color: _text,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _editField(title, 'Job title'),
                    const SizedBox(height: 12),
                    _editField(location, 'Location'),
                    const SizedBox(height: 12),
                    _editField(
                      workers,
                      'Workers needed',
                      numeric: true,
                    ),
                    const SizedBox(height: 12),
                    _editField(
                      payment,
                      'Payment per worker',
                      numeric: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _subtext),
                ),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                  if (!(key.currentState?.validate() ??
                      false)) {
                    return;
                  }

                  setDialogState(() => saving = true);

                  try {
                    await _jobService.updateJob(
                      jobId: job.id,
                      data: {
                        'title': title.text.trim(),
                        'location': location.text.trim(),
                        'workersNeeded': int.parse(
                          workers.text.trim(),
                        ),
                        'paymentPerWorker':
                        double.parse(
                          payment.text.trim(),
                        ),
                      },
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }

                    _message('Job updated successfully');
                  } catch (e) {
                    _message(
                      'Update failed: $e',
                      error: true,
                    );

                    if (dialogContext.mounted) {
                      setDialogState(
                            () => saving = false,
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _coral,
                  foregroundColor: _text,
                ),
                child: Text(
                  saving ? 'Saving...' : 'Save Changes',
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        title.dispose();
        location.dispose();
        workers.dispose();
        payment.dispose();
      });
    }
  }

  Widget _editField(
      TextEditingController controller,
      String label, {
        bool numeric = false,
      }) {
    return TextFormField(
      controller: controller,
      cursorColor: _coral,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(
        decimal: true,
      )
          : TextInputType.text,
      inputFormatters: numeric
          ? [
        FilteringTextInputFormatter.allow(
          RegExp(r'[0-9.]'),
        ),
      ]
          : null,
      style: const TextStyle(color: _text),
      validator: (value) {
        final text = (value ?? '').trim();

        if (text.isEmpty) {
          return '$label is required';
        }

        if (numeric) {
          final number = double.tryParse(text);

          if (number == null || number <= 0) {
            return 'Enter a positive number';
          }

          if (label == 'Workers needed' &&
              int.tryParse(text) == null) {
            return 'Enter a whole number';
          }
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _subtext),
        floatingLabelStyle:
        const TextStyle(color: _coralBright),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: _coral,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MORE JOB ACTIONS
  // ============================================================

  void _showJobActions(JobModel job) {
    final status = job.status.toLowerCase();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'JOB ACTIONS',
                style: TextStyle(
                  color: _subtext,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              if (status == 'active')
                _actionTile(
                  sheetContext,
                  Icons.lock_outline,
                  'Close job',
                  'Hide this job from active listings',
                  _coral,
                      () => _changeStatus(job, 'close'),
                ),
              if (status == 'closed')
                _actionTile(
                  sheetContext,
                  Icons.refresh_rounded,
                  'Reopen job',
                  'Make this job active again',
                  _teal,
                      () => _changeStatus(job, 'reopen'),
                ),
              if (status == 'active' ||
                  status == 'closed')
                _actionTile(
                  sheetContext,
                  Icons.task_alt_outlined,
                  'Mark completed',
                  'Finish this job',
                  _teal,
                      () => _changeStatus(job, 'complete'),
                ),
              if (status != 'completed' &&
                  status != 'cancelled')
                _actionTile(
                  sheetContext,
                  Icons.cancel_outlined,
                  'Cancel job',
                  'Cancel this posting',
                  _coral,
                      () => _changeStatus(job, 'cancel'),
                ),
              const Divider(color: _stroke),
              _actionTile(
                sheetContext,
                Icons.delete_outline_rounded,
                'Delete job',
                'Permanently remove this posting',
                const Color(0xFFFF8490),
                    () => _changeStatus(job, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
      BuildContext sheetContext,
      IconData icon,
      String title,
      String subtitle,
      Color color,
      VoidCallback onTap,
      ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: const TextStyle(
          color: _text,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: _subtext,
          fontSize: 12,
        ),
      ),
      onTap: () {
        Navigator.pop(sheetContext);
        onTap();
      },
    );
  }

  // ============================================================
  // CONFIRMATION
  // ============================================================

  Future<bool> _confirm(
      String title,
      String description,
      String action,
      ) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: _text,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          description,
          style: const TextStyle(color: _subtext),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text(
              'Go back',
              style: TextStyle(color: _subtext),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
              foregroundColor: _text,
            ),
            child: Text(action),
          ),
        ],
      ),
    ) ??
        false;
  }

  // ============================================================
  // FIREBASE ACTIONS
  // ============================================================

  Future<void> _changeStatus(
      JobModel job,
      String action,
      ) async {
    if (_busyJobs.contains(job.id)) return;

    if (action == 'close' ||
        action == 'cancel' ||
        action == 'delete' ||
        action == 'complete') {
      final title = {
        'close': 'Close job?',
        'cancel': 'Cancel job?',
        'delete': 'Delete job?',
        'complete': 'Mark job completed?',
      }[action]!;

      final description = action == 'delete'
          ? 'Permanently delete "${job.title}"? This cannot be undone.'
          : 'Are you sure you want to '
          '${action == 'complete' ? 'complete' : action} '
          '"${job.title}"?';

      final confirmed = await _confirm(
        title,
        description,
        'Confirm',
      );

      if (!confirmed) return;
    }

    if (!mounted) return;

    setState(() => _busyJobs.add(job.id));

    try {
      switch (action) {
        case 'close':
          await _jobService.closeJob(job.id);
          break;

        case 'reopen':
          await _jobService.updateJobStatus(
            jobId: job.id,
            status: 'active',
          );
          break;

        case 'complete':
          await _jobService.completeJob(job.id);
          break;

        case 'cancel':
          await _jobService.cancelJob(job.id);
          break;

        case 'delete':
          await _jobService.deleteJob(job.id);
          break;
      }

      final result = switch (action) {
        'reopen' => 'reopened',
        'delete' => 'deleted',
        'complete' => 'completed',
        'close' => 'closed',
        _ => 'cancelled',
      };

      _message('Job $result successfully');
    } catch (e) {
      _message(
        'Action failed: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _busyJobs.remove(job.id));
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _message(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? const Color(0xFFB54151)
            : const Color(0xFF167F74),
      ),
    );
  }
}
