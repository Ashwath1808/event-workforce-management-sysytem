
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'application_model.dart';
import 'application_service.dart';

// ============================================================
// CREWSYNC — ORGANIZER APPLICATIONS
// PROFESSIONAL MIDNIGHT NAVY & CORAL DESIGN
// ============================================================

const Color _bg = Color(0xFF0B1220);
const Color _card = Color(0xFF19263B);
const Color _cardLight = Color(0xFF203149);
const Color _stroke = Color(0xFF2B3D54);
const Color _coral = Color(0xFFF06449);
const Color _coralBright = Color(0xFFFF7857);
const Color _teal = Color(0xFF35D1AC);
const Color _text = Color(0xFFF7F9FC);
const Color _subtext = Color(0xFFA7B7CD);
const Color _amber = Color(0xFFFFC178);
const Color _red = Color(0xFFFF8490);

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key});

  @override
  State<ApplicationsPage> createState() =>
      _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  final ApplicationService _applicationService =
  ApplicationService();

  final TextEditingController _searchController =
  TextEditingController();

  final Set<String> _busyApplications = {};

  String _selectedStatus = 'All';

  static const List<String> _filters = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
        return _teal;
      case 'rejected':
        return _red;
      case 'pending':
        return _amber;
      default:
        return _subtext;
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
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

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final applied = DateTime(
      date.year,
      date.month,
      date.day,
    );

    if (applied == today) return 'Today';

    if (applied ==
        today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  List<ApplicationModel> _filterApplications(
      List<ApplicationModel> applications,
      ) {
    final query =
    _searchController.text.trim().toLowerCase();

    return applications.where((application) {
      final matchesStatus = _selectedStatus == 'All' ||
          application.status.trim().toLowerCase() ==
              _selectedStatus.toLowerCase();

      final matchesSearch = query.isEmpty ||
          application.jobTitle.toLowerCase().contains(query) ||
          application.workerName.toLowerCase().contains(query) ||
          application.workerEmail.toLowerCase().contains(query) ||
          application.workerCity.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        cardColor: _card,
        dialogTheme: const DialogThemeData(
          backgroundColor: _card,
        ),
        colorScheme: const ColorScheme.dark(
          primary: _coral,
          secondary: _teal,
          surface: _card,
          onSurface: _text,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: currentUser == null
                    ? _messageState(
                  Icons.lock_outline_rounded,
                  'Session expired',
                  'Please log in again.',
                )
                    : StreamBuilder<List<ApplicationModel>>(
                  stream: _applicationService
                      .getOrganizerApplications(
                    currentUser.uid,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _messageState(
                        Icons.cloud_off_rounded,
                        'Unable to load applications',
                        '${snapshot.error}',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child:
                        CircularProgressIndicator(
                          color: _coral,
                        ),
                      );
                    }

                    final allApplications =
                    snapshot.data!;

                    final pending = allApplications
                        .where(
                          (a) =>
                      a.status
                          .trim()
                          .toLowerCase() ==
                          'pending',
                    )
                        .length;

                    final accepted = allApplications
                        .where(
                          (a) =>
                      a.status
                          .trim()
                          .toLowerCase() ==
                          'accepted',
                    )
                        .length;

                    final rejected = allApplications
                        .where(
                          (a) =>
                      a.status
                          .trim()
                          .toLowerCase() ==
                          'rejected',
                    )
                        .length;

                    final applications =
                    _filterApplications(
                      allApplications,
                    );

                    return Column(
                      children: [
                        _overviewCard(
                          allApplications.length,
                          pending,
                          accepted,
                          rejected,
                        ),
                        _searchBar(),
                        _filterBar(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: applications.isEmpty
                              ? _messageState(
                            Icons
                                .assignment_outlined,
                            allApplications.isEmpty
                                ? 'No applications yet'
                                : 'No matching applications',
                            allApplications.isEmpty
                                ? 'Applications from workers will appear here.'
                                : 'Try another search or filter.',
                          )
                              : ListView.builder(
                            physics:
                            const BouncingScrollPhysics(),
                            padding:
                            const EdgeInsets
                                .fromLTRB(
                              18,
                              4,
                              18,
                              30,
                            ),
                            itemCount:
                            applications.length,
                            itemBuilder:
                                (context, index) {
                              return _applicationCard(
                                applications[index],
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
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        20,
        14,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _text,
              size: 21,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Applications',
                  style: TextStyle(
                    color: _text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review and manage your workforce',
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
              Icons.groups_outlined,
              color: _coralBright,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _overviewCard(
      int total,
      int pending,
      int accepted,
      int rejected,
      ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        18,
        4,
        18,
        18,
      ),
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
        crossAxisAlignment:
        CrossAxisAlignment.start,
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
                'APPLICATION OVERVIEW',
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
              _overviewStat(
                'Total',
                total,
                Icons.layers_outlined,
                _text,
              ),
              _overviewStat(
                'Pending',
                pending,
                Icons.schedule_rounded,
                _amber,
              ),
              _overviewStat(
                'Accepted',
                accepted,
                Icons.verified_outlined,
                _teal,
              ),
              _overviewStat(
                'Rejected',
                rejected,
                Icons.cancel_outlined,
                _coralBright,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(
      String label,
      int value,
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
            '$value',
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

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        14,
      ),
      child: TextField(
        controller: _searchController,
        cursorColor: _coral,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: _text,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search workers or jobs...',
          hintStyle: const TextStyle(
            color: _subtext,
            fontSize: 12,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _coralBright,
          ),
          suffixIcon:
          _searchController.text.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchController.clear();
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
          const EdgeInsets.symmetric(
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
            const BorderSide(color: _stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
            const BorderSide(color: _stroke),
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
  // FILTERS
  // ============================================================

  Widget _filterBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected =
              _selectedStatus == filter;

          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            showCheckmark: false,
            selectedColor: _coral,
            backgroundColor: _card,
            side: BorderSide(
              color: selected ? _coral : _stroke,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(20),
            ),
            labelStyle: TextStyle(
              color: selected ? _text : _subtext,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            onSelected: (_) {
              setState(() {
                _selectedStatus = filter;
              });
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // APPLICATION CARD
  // ============================================================

  Widget _applicationCard(
      ApplicationModel application,
      ) {
    final status =
    application.status.trim().toLowerCase();

    final busy =
    _busyApplications.contains(application.id);

    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: _coral.withOpacity(0.12),
                  borderRadius:
                  BorderRadius.circular(15),
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
                      application.jobTitle,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Applied ${_formatDate(application.appliedAt)}',
                      style: const TextStyle(
                        color: _subtext,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _statusChip(application.status),
            ],
          ),

          const SizedBox(height: 17),
          const Divider(
            color: _stroke,
            height: 1,
          ),
          const SizedBox(height: 17),

          // WORKER INFORMATION

          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                _teal.withOpacity(0.12),
                child: Text(
                  _initials(
                    application.workerName,
                  ),
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.workerName
                          .trim()
                          .isEmpty
                          ? 'Worker'
                          : application.workerName,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      application.workerEmail,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _subtext,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // WORKER SUMMARY

          if (application.workerCity.trim().isNotEmpty ||
              application.workerExperienceLevel
                  .trim()
                  .isNotEmpty ||
              application.workerSkills.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius:
                BorderRadius.circular(14),
                border: Border.all(
                  color: _stroke,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  if (application.workerCity
                      .trim()
                      .isNotEmpty)
                    _summaryRow(
                      Icons.location_on_outlined,
                      application.workerCity,
                    ),

                  if (application.workerExperienceLevel
                      .trim()
                      .isNotEmpty)
                    _summaryRow(
                      Icons.workspace_premium_outlined,
                      '${application.workerExperienceLevel}'
                          '${application.workerExperienceYears > 0 ? ' • ${application.workerExperienceYears} years' : ''}',
                    ),

                  if (application.workerSkills.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: application.workerSkills
                          .take(3)
                          .map(
                            (skill) => Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.10),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              color: _teal,
                              fontSize: 10,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // VIEW WORKER PROFILE

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showWorkerProfile(application),
              icon: const Icon(
                Icons.person_search_outlined,
                size: 19,
              ),
              label: const Text(
                'View Worker Profile',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _coralBright,
                side: const BorderSide(
                  color: _coral,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(13),
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // APPLICATION ACTIONS

          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  color: _coral,
                ),
              ),
            )
          else if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmReject(application),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                    ),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(
                        color: _red,
                      ),
                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _confirmAccept(application),
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 18,
                    ),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _coral,
                      foregroundColor: _text,
                      elevation: 0,
                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (status == 'accepted')
              Row(
                children: [
                  Expanded(
                    child: _statusBanner(
                      'Worker Accepted',
                      Icons.check_circle_outline_rounded,
                      _teal,
                    ),
                  ),
                  _statusMenu(application, status),
                ],
              )
            else if (status == 'rejected')
                Row(
                  children: [
                    Expanded(
                      child: _statusBanner(
                        'Application Rejected',
                        Icons.cancel_outlined,
                        _red,
                      ),
                    ),
                    _statusMenu(application, status),
                  ],
                )
              else
                _statusBanner(
                  _capitalize(application.status),
                  Icons.info_outline,
                  statusColor,
                ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD HELPERS
  // ============================================================

  Widget _summaryRow(
      IconData icon,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: _coralBright,
            size: 16,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _subtext,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _statusBanner(
      String title,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusMenu(
      ApplicationModel application,
      String status,
      ) {
    return PopupMenuButton<String>(
      tooltip: 'Change application status',
      color: _cardLight,
      icon: const Icon(
        Icons.more_vert_rounded,
        color: _subtext,
      ),
      onSelected: (value) {
        if (value == 'pending') {
          _confirmPending(application);
        } else if (value == 'accept') {
          _confirmAccept(application);
        } else if (value == 'reject') {
          _confirmReject(application);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'pending',
          child: Text(
            'Move to Pending',
            style: TextStyle(color: _text),
          ),
        ),
        if (status == 'accepted')
          const PopupMenuItem(
            value: 'reject',
            child: Text(
              'Reject Application',
              style: TextStyle(color: _text),
            ),
          ),
        if (status == 'rejected')
          const PopupMenuItem(
            value: 'accept',
            child: Text(
              'Accept Application',
              style: TextStyle(color: _text),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // WORKER PROFILE DIALOG
  // ============================================================

  Future<void> _showWorkerProfile(
      ApplicationModel application,
      ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _card,
          insetPadding:
          const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(23),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
              MediaQuery.of(dialogContext)
                  .size
                  .height *
                  0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(21),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // PROFILE HEADER

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                        _teal.withOpacity(0.13),
                        child: Text(
                          _initials(
                            application.workerName,
                          ),
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 21,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              application.workerName
                                  .trim()
                                  .isEmpty
                                  ? 'Worker'
                                  : application.workerName,
                              style: const TextStyle(
                                color: _text,
                                fontSize: 19,
                                fontWeight:
                                FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              application.workerEmail,
                              style: const TextStyle(
                                color: _subtext,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(
                              dialogContext,
                            ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _subtext,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: _stroke),
                  const SizedBox(height: 16),

                  _profileSectionTitle(
                    Icons.person_outline_rounded,
                    'Personal Information',
                  ),

                  _profileDetail(
                    'Phone',
                    application.workerPhone,
                  ),
                  _profileDetail(
                    'Age',
                    application.workerAge > 0
                        ? '${application.workerAge} years'
                        : '',
                  ),
                  _profileDetail(
                    'Gender',
                    application.workerGender,
                  ),
                  _profileDetail(
                    'City',
                    application.workerCity,
                  ),

                  const SizedBox(height: 19),

                  _profileSectionTitle(
                    Icons.workspace_premium_outlined,
                    'Skills & Experience',
                  ),

                  const SizedBox(height: 8),

                  if (application.workerSkills.isEmpty)
                    const Text(
                      'No skills provided',
                      style: TextStyle(
                        color: _subtext,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: application.workerSkills
                          .map(
                            (skill) => Chip(
                          label: Text(skill),
                          backgroundColor: _bg,
                          labelStyle:
                          const TextStyle(
                            color: _teal,
                            fontSize: 11,
                          ),
                          side: const BorderSide(
                            color: _stroke,
                          ),
                        ),
                      )
                          .toList(),
                    ),

                  const SizedBox(height: 15),

                  _profileDetail(
                    'Experience Level',
                    application.workerExperienceLevel,
                  ),
                  _profileDetail(
                    'Years of Experience',
                    '${application.workerExperienceYears} years',
                  ),
                  _profileLongText(
                    'Previous Work / Events',
                    application.workerPreviousWork,
                  ),

                  const SizedBox(height: 19),

                  _profileSectionTitle(
                    Icons.info_outline_rounded,
                    'Additional Information',
                  ),

                  _profileDetail(
                    'Education',
                    application.workerEducation,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Languages Known',
                    style: TextStyle(
                      color: _subtext,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 9),

                  if (application.workerLanguages.isEmpty)
                    const Text(
                      'Not provided',
                      style: TextStyle(
                        color: _subtext,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: application.workerLanguages
                          .map(
                            (language) => Chip(
                          label: Text(language),
                          backgroundColor: _bg,
                          labelStyle:
                          const TextStyle(
                            color: _text,
                          ),
                          side: const BorderSide(
                            color: _stroke,
                          ),
                        ),
                      )
                          .toList(),
                    ),

                  const SizedBox(height: 15),

                  _profileLongText(
                    'About Worker',
                    application.workerBio,
                  ),

                  const SizedBox(height: 20),

                  // APPLICATION DETAILS

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius:
                      BorderRadius.circular(14),
                      border: Border.all(
                        color: _stroke,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'APPLICATION DETAILS',
                          style: TextStyle(
                            color: _coralBright,
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _profileDetail(
                          'Job',
                          application.jobTitle,
                        ),
                        _profileDetail(
                          'Applied',
                          _formatDate(
                            application.appliedAt,
                          ),
                        ),
                        _profileDetail(
                          'Status',
                          _capitalize(
                            application.status,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 19),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(
                            dialogContext,
                          ),
                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor: _coral,
                        foregroundColor: _text,
                        elevation: 0,
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Close Profile',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // PROFILE HELPERS
  // ============================================================

  Widget _profileSectionTitle(
      IconData icon,
      String title,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _coral.withOpacity(0.12),
              borderRadius:
              BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: _coralBright,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileDetail(
      String title,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: const TextStyle(
                color: _subtext,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty
                  ? 'Not provided'
                  : value,
              style: const TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileLongText(
      String title,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 13,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _subtext,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius:
              BorderRadius.circular(12),
              border: Border.all(
                color: _stroke,
              ),
            ),
            child: Text(
              value.trim().isEmpty
                  ? 'Not provided'
                  : value,
              style: const TextStyle(
                color: _text,
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
  // ACCEPT APPLICATION
  // ============================================================

  Future<void> _confirmAccept(
      ApplicationModel application,
      ) async {
    final confirmed = await _showConfirmation(
      title: 'Accept Worker',
      message:
      'Do you want to accept ${application.workerName} '
          'for ${application.jobTitle}?',
      action: 'Accept',
      color: _teal,
    );

    if (confirmed) {
      await _performAction(
        application,
            () => _applicationService.acceptApplication(
          application: application,
        ),
        'Application accepted successfully.',
      );
    }
  }

  // ============================================================
  // REJECT APPLICATION
  // ============================================================

  Future<void> _confirmReject(
      ApplicationModel application,
      ) async {
    final confirmed = await _showConfirmation(
      title: 'Reject Application',
      message:
      'Do you want to reject ${application.workerName}?',
      action: 'Reject',
      color: _red,
    );

    if (confirmed) {
      await _performAction(
        application,
            () => _applicationService.rejectApplication(
          application: application,
        ),
        'Application rejected successfully.',
      );
    }
  }

  // ============================================================
  // MOVE APPLICATION TO PENDING
  // ============================================================

  Future<void> _confirmPending(
      ApplicationModel application,
      ) async {
    final confirmed = await _showConfirmation(
      title: 'Move to Pending',
      message:
      'Move ${application.workerName} back to pending? '
          'If the worker was accepted, their reserved '
          'position will become available again.',
      action: 'Move to Pending',
      color: _amber,
    );

    if (confirmed) {
      await _performAction(
        application,
            () => _applicationService.markPending(
          application: application,
        ),
        'Application moved to pending.',
      );
    }
  }

  // ============================================================
  // CONFIRMATION DIALOG
  // ============================================================

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String action,
    required Color color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(21),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: _subtext,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    false,
                  ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _subtext,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                    dialogContext,
                    true,
                  ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor:
                color == _coral
                    ? _text
                    : _bg,
                elevation: 0,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(11),
                ),
              ),
              child: Text(action),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // ============================================================
  // FIREBASE ACTION HANDLER
  // ============================================================

  Future<void> _performAction(
      ApplicationModel application,
      Future<void> Function() action,
      String successMessage,
      ) async {
    if (_busyApplications.contains(
      application.id,
    )) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _busyApplications.add(application.id);
    });

    try {
      await action();

      if (!mounted) return;

      _showSuccess(successMessage);
    } catch (e) {
      if (!mounted) return;

      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busyApplications.remove(
            application.id,
          );
        });
      }
    }
  }

  // ============================================================
  // SUCCESS / ERROR MESSAGES
  // ============================================================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        const Color(0xFF17695D),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String error) {
    final cleanError =
    error.replaceFirst(
      'Exception: ',
      '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanError),
        backgroundColor:
        const Color(0xFFB83F4D),
        behavior:
        SnackBarBehavior.floating,
        duration:
        const Duration(seconds: 5),
      ),
    );
  }

  // ============================================================
  // EMPTY / ERROR STATE
  // ============================================================

  Widget _messageState(
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
              textAlign:
              TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign:
              TextAlign.center,
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
}
