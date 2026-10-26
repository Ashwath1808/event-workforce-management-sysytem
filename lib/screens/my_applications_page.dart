
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/application_service.dart';

// ============================================================
// CREWSYNC — PROFESSIONAL MY APPLICATIONS DESIGN
// MIDNIGHT NAVY • CORAL • TEAL
// ============================================================

const Color _bg = Color(0xFF0B1220);
const Color _card = Color(0xFF19263B);
const Color _stroke = Color(0xFF2B3D54);
const Color _coral = Color(0xFFF06449);
const Color _coralBright = Color(0xFFFF7857);
const Color _teal = Color(0xFF35D1AC);
const Color _text = Color(0xFFF7F9FC);
const Color _subtext = Color(0xFFA7B7CD);

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() =>
      _MyApplicationsPageState();
}

class _MyApplicationsPageState
    extends State<MyApplicationsPage> {
  final ApplicationService _applicationService =
  ApplicationService();

  final TextEditingController _searchController =
  TextEditingController();

  String _selectedStatus = 'All';

  static const List<String> _statuses = [
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
  // DATA HELPERS — EXISTING LOGIC PRESERVED
  // ============================================================

  String _value(
      Map<String, dynamic> data,
      String key, [
        String fallback = '',
      ]) {
    final value = data[key];

    if (value == null) return fallback;

    final text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  String _status(Map<String, dynamic> data) {
    return _value(
      data,
      'status',
      'pending',
    ).toLowerCase();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return _teal;

      case 'rejected':
        return const Color(0xFFFF8D96);

      case 'pending':
        return const Color(0xFFFFC178);

      default:
        return _subtext;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_outline_rounded;

      case 'rejected':
        return Icons.cancel_outlined;

      case 'pending':
        return Icons.hourglass_top_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'accepted':
        return 'Congratulations! Your application was accepted.';

      case 'rejected':
        return 'This application was not selected.';

      case 'pending':
        return 'Your application is waiting for organizer review.';

      default:
        return 'Check your application status.';
    }
  }

  // ============================================================
  // FILTER APPLICATIONS
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _filterApplications(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
      documents,
      ) {
    final query =
    _searchController.text.trim().toLowerCase();

    return documents.where((document) {
      final data = document.data();

      final title = _value(
        data,
        'jobTitle',
        'Job',
      ).toLowerCase();

      final location = _value(
        data,
        'location',
      ).toLowerCase();

      final date = _value(
        data,
        'date',
      ).toLowerCase();

      final status = _status(data);

      final matchesSearch = query.isEmpty ||
          title.contains(query) ||
          location.contains(query) ||
          date.contains(query);

      final matchesStatus = _selectedStatus == 'All' ||
          status == _selectedStatus.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
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
              _buildHeader(),

              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _applicationService
                      .getMyApplications(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildMessage(
                        icon: Icons.cloud_off_rounded,
                        title: 'Unable to load applications',
                        subtitle:
                        snapshot.error.toString(),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _coral,
                        ),
                      );
                    }

                    final documents = snapshot.data!.docs;

                    final total = documents.length;

                    final pending =
                        documents.where((document) {
                          return _status(document.data()) ==
                              'pending';
                        }).length;

                    final accepted =
                        documents.where((document) {
                          return _status(document.data()) ==
                              'accepted';
                        }).length;

                    final rejected =
                        documents.where((document) {
                          return _status(document.data()) ==
                              'rejected';
                        }).length;

                    final filtered =
                    _filterApplications(documents);

                    return Column(
                      children: [
                        _buildOverview(
                          total: total,
                          pending: pending,
                          accepted: accepted,
                          rejected: rejected,
                        ),

                        _buildSearchBar(),

                        _buildFilterBar(),

                        const SizedBox(height: 12),

                        Expanded(
                          child: filtered.isEmpty
                              ? _buildMessage(
                            icon: Icons
                                .assignment_outlined,
                            title: documents.isEmpty
                                ? 'No applications yet'
                                : 'No matching applications',
                            subtitle: documents.isEmpty
                                ? 'Jobs you apply for will appear here.'
                                : 'Try another keyword or status filter.',
                          )
                              : ListView.separated(
                            padding:
                            const EdgeInsets
                                .fromLTRB(
                              18,
                              4,
                              18,
                              30,
                            ),
                            physics:
                            const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder:
                                (_, __) =>
                            const SizedBox(
                              height: 14,
                            ),
                            itemBuilder:
                                (context, index) {
                              return _buildApplicationCard(
                                filtered[index],
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
  // SEAMLESS HEADER — SAME FLOW AS MANAGE JOBS
  // ============================================================

  Widget _buildHeader() {
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
            onPressed: () {
              Navigator.maybePop(context);
            },
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
                  'My Applications',
                  style: TextStyle(
                    color: _text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Track your job applications',
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
              borderRadius:
              BorderRadius.circular(14),
              border: Border.all(
                color: _coral.withOpacity(0.18),
              ),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: _coralBright,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPLICATION OVERVIEW
  // ============================================================

  Widget _buildOverview({
    required int total,
    required int pending,
    required int accepted,
    required int rejected,
  }) {
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
              _overviewItem(
                label: 'Total',
                value: '$total',
                icon: Icons.layers_outlined,
                color: _text,
              ),

              _overviewItem(
                label: 'Pending',
                value: '$pending',
                icon: Icons.schedule_rounded,
                color: const Color(0xFFFFC178),
              ),

              _overviewItem(
                label: 'Accepted',
                value: '$accepted',
                icon: Icons.verified_outlined,
                color: _teal,
              ),

              _overviewItem(
                label: 'Rejected',
                value: '$rejected',
                icon: Icons.cancel_outlined,
                color: _coralBright,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius:
              BorderRadius.circular(13),
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
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
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
          hintText: 'Search your applications...',
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
            borderRadius:
            BorderRadius.circular(16),
            borderSide:
            const BorderSide(color: _stroke),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(16),
            borderSide:
            const BorderSide(color: _stroke),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(16),
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
  // STATUS FILTER BAR
  // ============================================================

  Widget _buildFilterBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
        ),
        itemCount: _statuses.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 9),
        itemBuilder: (context, index) {
          return _buildFilterChip(
            _statuses[index],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    final selected = _selectedStatus == status;

    return ChoiceChip(
      label: Text(status),
      selected: selected,
      showCheckmark: false,

      onSelected: (_) {
        setState(() {
          _selectedStatus = status;
        });
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
  }

  // ============================================================
  // APPLICATION CARD
  // ============================================================

  Widget _buildApplicationCard(
      QueryDocumentSnapshot<Map<String, dynamic>>
      document,
      ) {
    final data = document.data();

    final title = _value(
      data,
      'jobTitle',
      'Job',
    );

    final date = _value(
      data,
      'date',
      'Date not provided',
    );

    final location = _value(
      data,
      'location',
      'Location not provided',
    );

    final status = _status(data);
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius:
        BorderRadius.circular(22),
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
                      title,
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

                    const Text(
                      'Job Application',
                      style: TextStyle(
                        color: _subtext,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 7),

              _buildStatusBadge(status),
            ],
          ),

          const SizedBox(height: 19),

          _buildInfoRow(
            Icons.calendar_month_outlined,
            date,
          ),

          const SizedBox(height: 10),

          _buildInfoRow(
            Icons.location_on_outlined,
            location,
          ),

          const SizedBox(height: 18),

          const Divider(
            color: _stroke,
            height: 1,
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
              statusColor.withOpacity(0.08),
              borderRadius:
              BorderRadius.circular(13),
              border: Border.all(
                color:
                statusColor.withOpacity(0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Icon(
                  _statusIcon(status),
                  color: statusColor,
                  size: 20,
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Text(
                    _statusMessage(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPLICATION INFORMATION ROW
  // ============================================================

  Widget _buildInfoRow(
      IconData icon,
      String value,
      ) {
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
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _subtext,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);

    final label = status.isEmpty
        ? 'UNKNOWN'
        : status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY / ERROR STATE
  // ============================================================

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
}
