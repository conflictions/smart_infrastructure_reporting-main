import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';
import 'report_detail_screen.dart';

class ReportSlaScreen extends StatefulWidget {
  const ReportSlaScreen({
    super.key,
  });

  @override
  State<ReportSlaScreen> createState() =>
      _ReportSlaScreenState();
}

class _ReportSlaScreenState
    extends State<ReportSlaScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  List<Map<String, dynamic>> reports =
  <Map<String, dynamic>>[];

  bool loading = true;
  String? errorMessage;

  String selectedFilter = 'All';

  final List<String> filters = <String>[
    'All',
    'Overdue',
    'Due Soon',
    'On Schedule',
    'Completed',
    'No Deadline',
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // ============================================================
  // LOAD CITIZEN REPORTS
  // ============================================================

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final User? user =
          supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'You must be logged in.',
        );
      }

      final List<dynamic> response =
      await supabase
          .from('reports')
          .select(
        '''
                id,
                reference_number,
                title,
                category,
                priority,
                status,
                progress_percentage,
                assigned_department,
                estimated_completion,
                created_at
                ''',
      )
          .eq(
        'citizen_id',
        user.id,
      )
          .order(
        'created_at',
        ascending: false,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        reports = response
            .map(
              (dynamic item) =>
          Map<String, dynamic>.from(
            item as Map,
          ),
        )
            .toList();

        loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;

        errorMessage = e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        )
            .trim();
      });
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _normalizeStatus(
      dynamic value,
      ) {
    return value
        ?.toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_') ??
        '';
  }

  bool _isCompleted(
      Map<String, dynamic> report,
      ) {
    return _normalizeStatus(
      report['status'],
    ) ==
        'completed';
  }

  bool _isRejected(
      Map<String, dynamic> report,
      ) {
    return _normalizeStatus(
      report['status'],
    ) ==
        'rejected';
  }

  // ============================================================
  // ESTIMATED COMPLETION
  // ============================================================

  DateTime? _estimatedDate(
      Map<String, dynamic> report,
      ) {
    final dynamic raw =
    report['estimated_completion'];

    if (raw == null) {
      return null;
    }

    final String value =
    raw.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  DateTime _dateOnly(
      DateTime date,
      ) {
    final DateTime local =
    date.toLocal();

    return DateTime(
      local.year,
      local.month,
      local.day,
    );
  }

  int? _daysRemaining(
      Map<String, dynamic> report,
      ) {
    final DateTime? estimated =
    _estimatedDate(report);

    if (estimated == null) {
      return null;
    }

    final DateTime today =
    _dateOnly(
      DateTime.now(),
    );

    final DateTime target =
    _dateOnly(
      estimated,
    );

    return target
        .difference(today)
        .inDays;
  }

  // ============================================================
  // SLA CLASSIFICATION
  // ============================================================

  String _slaStatus(
      Map<String, dynamic> report,
      ) {
    if (_isCompleted(report)) {
      return 'Completed';
    }

    if (_isRejected(report)) {
      return 'Closed';
    }

    final int? days =
    _daysRemaining(report);

    if (days == null) {
      return 'No Deadline';
    }

    if (days < 0) {
      return 'Overdue';
    }

    if (days <= 3) {
      return 'Due Soon';
    }

    return 'On Schedule';
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int _countSla(
      String status,
      ) {
    return reports.where(
          (
          Map<String, dynamic> report,
          ) {
        return _slaStatus(report) ==
            status;
      },
    ).length;
  }

  int get overdueCount =>
      _countSla('Overdue');

  int get dueSoonCount =>
      _countSla('Due Soon');

  int get onScheduleCount =>
      _countSla('On Schedule');

  int get completedCount =>
      _countSla('Completed');

  int get noDeadlineCount =>
      _countSla('No Deadline');

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>>
  get filteredReports {
    List<Map<String, dynamic>> result =
    List<Map<String, dynamic>>.from(
      reports,
    );

    if (selectedFilter != 'All') {
      result = result.where(
            (
            Map<String, dynamic> report,
            ) {
          return _slaStatus(report) ==
              selectedFilter;
        },
      ).toList();
    }

    // Sort most urgent first.
    result.sort(
          (
          Map<String, dynamic> a,
          Map<String, dynamic> b,
          ) {
        return _slaWeight(a).compareTo(
          _slaWeight(b),
        );
      },
    );

    return result;
  }

  int _slaWeight(
      Map<String, dynamic> report,
      ) {
    switch (_slaStatus(report)) {
      case 'Overdue':
        return 0;

      case 'Due Soon':
        return 1;

      case 'On Schedule':
        return 2;

      case 'No Deadline':
        return 3;

      case 'Completed':
        return 4;

      case 'Closed':
      default:
        return 5;
    }
  }

  // ============================================================
  // DISPLAY HELPERS
  // ============================================================

  Color _slaColor(
      String status,
      ) {
    switch (status) {
      case 'Overdue':
        return AppColors.danger;

      case 'Due Soon':
        return AppColors.warning;

      case 'Completed':
        return AppColors.success;

      case 'On Schedule':
        return AppColors.primary;

      case 'No Deadline':
      case 'Closed':
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _slaIcon(
      String status,
      ) {
    switch (status) {
      case 'Overdue':
        return Icons.warning_amber_rounded;

      case 'Due Soon':
        return Icons.schedule_rounded;

      case 'On Schedule':
        return Icons.event_available_rounded;

      case 'Completed':
        return Icons.task_alt_rounded;

      case 'No Deadline':
        return Icons.event_busy_outlined;

      case 'Closed':
      default:
        return Icons.block_outlined;
    }
  }

  String _deadlineMessage(
      Map<String, dynamic> report,
      ) {
    final String status =
    _slaStatus(report);

    final int? days =
    _daysRemaining(report);

    if (status == 'Completed') {
      return 'Maintenance completed';
    }

    if (status == 'Closed') {
      return 'Report closed';
    }

    if (days == null) {
      return 'Estimated completion has not been set';
    }

    if (days < 0) {
      final int overdue =
      days.abs();

      return '$overdue day'
          '${overdue == 1 ? '' : 's'} overdue';
    }

    if (days == 0) {
      return 'Due today';
    }

    if (days == 1) {
      return '1 day remaining';
    }

    return '$days days remaining';
  }

  String _formatDate(
      DateTime date,
      ) {
    const List<String> months =
    <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final DateTime local =
    date.toLocal();

    return '${local.day} '
        '${months[local.month - 1]} '
        '${local.year}';
  }

  String _priorityText(
      dynamic priority,
      ) {
    final String value =
        priority
            ?.toString()
            .trim() ??
            '';

    if (value.isEmpty) {
      return 'Unknown';
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1).toLowerCase()}';
  }

  // ============================================================
  // OPEN REPORT
  // ============================================================

  Future<void> _openReport(
      Map<String, dynamic> report,
      ) async {
    final String id =
        report['id']
            ?.toString()
            .trim() ??
            '';

    if (id.isEmpty) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder:
            (
            BuildContext context,
            ) {
          return ReportDetailScreen(
            reportId: id,
          );
        },
      ),
    );

    await _loadReports();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      appBar: AppBar(
        backgroundColor:
        AppColors.surface,

        title: const Text(
          'Maintenance SLA Monitor',
          style: TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',

            onPressed:
            _loadReports,

            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body:
      _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return _buildError();
    }

    return RefreshIndicator(
      onRefresh:
      _loadReports,

      child:
      ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        padding:
        const EdgeInsets.all(
          18,
        ),

        children: [
          const Text(
            'Deadline Monitoring',

            style:
            TextStyle(
              fontSize:
              22,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          const Text(
            'Track estimated maintenance completion dates and identify reports that may require attention.',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              11,

              height:
              1.45,
            ),
          ),

          const SizedBox(
            height:
            20,
          ),

          // ======================================================
          // SUMMARY CARDS
          // ======================================================

          GridView.count(
            crossAxisCount:
            2,

            shrinkWrap:
            true,

            physics:
            const NeverScrollableScrollPhysics(),

            mainAxisSpacing:
            12,

            crossAxisSpacing:
            12,

            childAspectRatio:
            1.55,

            children: [
              _SlaSummaryCard(
                label:
                'OVERDUE',

                value:
                '$overdueCount',

                description:
                'Past expected date',

                icon:
                Icons.warning_amber_rounded,

                color:
                AppColors.danger,
              ),

              _SlaSummaryCard(
                label:
                'DUE SOON',

                value:
                '$dueSoonCount',

                description:
                'Within 3 days',

                icon:
                Icons.schedule_rounded,

                color:
                AppColors.warning,
              ),

              _SlaSummaryCard(
                label:
                'ON SCHEDULE',

                value:
                '$onScheduleCount',

                description:
                'More than 3 days',

                icon:
                Icons.event_available_rounded,

                color:
                AppColors.primary,
              ),

              _SlaSummaryCard(
                label:
                'COMPLETED',

                value:
                '$completedCount',

                description:
                'Maintenance finished',

                icon:
                Icons.task_alt_rounded,

                color:
                AppColors.success,
              ),
            ],
          ),

          if (noDeadlineCount > 0) ...[
            const SizedBox(
              height:
              14,
            ),

            Container(
              padding:
              const EdgeInsets.all(
                13,
              ),

              decoration:
              BoxDecoration(
                color:
                AppColors.surface,

                borderRadius:
                BorderRadius.circular(
                  14,
                ),

                border:
                Border.all(
                  color:
                  AppColors.border,
                ),
              ),

              child:
              Row(
                children: [
                  const Icon(
                    Icons.event_busy_outlined,

                    color:
                    AppColors.textSecondary,
                  ),

                  const SizedBox(
                    width:
                    10,
                  ),

                  Expanded(
                    child:
                    Text(
                      '$noDeadlineCount report'
                          '${noDeadlineCount == 1 ? '' : 's'} '
                          'currently have no estimated completion date.',

                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,

                        fontSize:
                        10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(
            height:
            24,
          ),

          // ======================================================
          // FILTER
          // ======================================================

          const Text(
            'Maintenance Schedule',

            style:
            TextStyle(
              fontSize:
              16,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            10,
          ),

          SizedBox(
            height:
            39,

            child:
            ListView.separated(
              scrollDirection:
              Axis.horizontal,

              itemCount:
              filters.length,

              separatorBuilder:
                  (
                  BuildContext context,
                  int index,
                  ) {
                return const SizedBox(
                  width:
                  8,
                );
              },

              itemBuilder:
                  (
                  BuildContext context,
                  int index,
                  ) {
                final String filter =
                filters[index];

                final bool selected =
                    selectedFilter ==
                        filter;

                return ChoiceChip(
                  label:
                  Text(
                    filter,
                  ),

                  selected:
                  selected,

                  onSelected:
                      (_) {
                    setState(() {
                      selectedFilter =
                          filter;
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(
            height:
            16,
          ),

          if (filteredReports.isEmpty)
            _buildNoResults()
          else
            ...filteredReports.map(
                  (
                  Map<String, dynamic>
                  report,
                  ) {
                return Padding(
                  padding:
                  const EdgeInsets.only(
                    bottom:
                    11,
                  ),

                  child:
                  _buildReportCard(
                    report,
                  ),
                );
              },
            ),

          const SizedBox(
            height:
            20,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REPORT CARD
  // ============================================================

  Widget _buildReportCard(
      Map<String, dynamic> report,
      ) {
    final String sla =
    _slaStatus(report);

    final Color color =
    _slaColor(sla);

    final DateTime? estimated =
    _estimatedDate(report);

    final String title =
        report['title']
            ?.toString()
            .trim() ??
            'Infrastructure Report';

    final String reference =
        report['reference_number']
            ?.toString()
            .trim() ??
            '';

    final String category =
        report['category']
            ?.toString()
            .trim() ??
            'Unknown';

    final String department =
        report['assigned_department']
            ?.toString()
            .trim() ??
            '';

    final int progress =
        int.tryParse(
          report['progress_percentage']
              ?.toString() ??
              '',
        ) ??
            0;

    return Material(
      color:
      Colors.transparent,

      child:
      InkWell(
        onTap:
            () {
          _openReport(report);
        },

        borderRadius:
        BorderRadius.circular(
          16,
        ),

        child:
        Container(
          padding:
          const EdgeInsets.all(
            15,
          ),

          decoration:
          BoxDecoration(
            color:
            AppColors.surface,

            borderRadius:
            BorderRadius.circular(
              16,
            ),

            border:
            Border.all(
              color:
              sla == 'Overdue'
                  ? color.withOpacity(
                0.70,
              )
                  : AppColors.border,
            ),
          ),

          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Container(
                    width:
                    42,

                    height:
                    42,

                    decoration:
                    BoxDecoration(
                      color:
                      color.withOpacity(
                        0.12,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),

                    child:
                    Icon(
                      _slaIcon(
                        sla,
                      ),

                      color:
                      color,

                      size:
                      21,
                    ),
                  ),

                  const SizedBox(
                    width:
                    11,
                  ),

                  Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          title,

                          maxLines:
                          1,

                          overflow:
                          TextOverflow.ellipsis,

                          style:
                          const TextStyle(
                            fontSize:
                            13,

                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height:
                          3,
                        ),

                        Text(
                          reference,

                          style:
                          const TextStyle(
                            color:
                            AppColors.primary,

                            fontSize:
                            9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width:
                    8,
                  ),

                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal:
                      8,

                      vertical:
                      5,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      color.withOpacity(
                        0.12,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),

                    child:
                    Text(
                      sla,

                      style:
                      TextStyle(
                        color:
                        color,

                        fontSize:
                        8,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                14,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    _SlaInfoItem(
                      label:
                      'CATEGORY',

                      value:
                      category,
                    ),
                  ),

                  Expanded(
                    child:
                    _SlaInfoItem(
                      label:
                      'PRIORITY',

                      value:
                      _priorityText(
                        report['priority'],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                12,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                    _SlaInfoItem(
                      label:
                      'EXPECTED',

                      value:
                      estimated ==
                          null
                          ? 'Not set'
                          : _formatDate(
                        estimated,
                      ),
                    ),
                  ),

                  Expanded(
                    child:
                    _SlaInfoItem(
                      label:
                      'DEPARTMENT',

                      value:
                      department.isEmpty
                          ? 'Not assigned'
                          : department,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                13,
              ),

              Container(
                width:
                double.infinity,

                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  11,

                  vertical:
                  9,
                ),

                decoration:
                BoxDecoration(
                  color:
                  color.withOpacity(
                    0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child:
                Row(
                  children: [
                    Icon(
                      _slaIcon(
                        sla,
                      ),

                      color:
                      color,

                      size:
                      16,
                    ),

                    const SizedBox(
                      width:
                      7,
                    ),

                    Expanded(
                      child:
                      Text(
                        _deadlineMessage(
                          report,
                        ),

                        style:
                        TextStyle(
                          color:
                          color,

                          fontSize:
                          10,

                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                13,
              ),

              Row(
                children: [
                  const Text(
                    'Progress',

                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,

                      fontSize:
                      9,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    '$progress%',

                    style:
                    const TextStyle(
                      color:
                      AppColors.primary,

                      fontSize:
                      10,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                6,
              ),

              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  20,
                ),

                child:
                LinearProgressIndicator(
                  value:
                  (progress /
                      100)
                      .clamp(
                    0.0,
                    1.0,
                  )
                      .toDouble(),

                  minHeight:
                  6,

                  backgroundColor:
                  AppColors.border,

                  color:
                  color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),

        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            const Icon(
              Icons
                  .error_outline_rounded,

              color:
              AppColors.danger,

              size:
              48,
            ),

            const SizedBox(
              height:
              12,
            ),

            const Text(
              'Unable to load SLA data',

              style:
              TextStyle(
                fontSize:
                17,

                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
              7,
            ),

            Text(
              errorMessage ??
                  'Something went wrong.',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                AppColors.textSecondary,

                fontSize:
                11,
              ),
            ),

            const SizedBox(
              height:
              16,
            ),

            FilledButton.icon(
              onPressed:
              _loadReports,

              icon:
              const Icon(
                Icons.refresh_rounded,
              ),

              label:
              const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NO RESULTS
  // ============================================================

  Widget _buildNoResults() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.symmetric(
        vertical:
        35,

        horizontal:
        20,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.surface,

        borderRadius:
        BorderRadius.circular(
          16,
        ),

        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),

      child:
      const Column(
        children: [
          Icon(
            Icons.event_note_outlined,

            size:
            42,

            color:
            AppColors.textSecondary,
          ),

          SizedBox(
            height:
            10,
          ),

          Text(
            'No reports found',

            style:
            TextStyle(
              fontWeight:
              FontWeight.bold,
            ),
          ),

          SizedBox(
            height:
            5,
          ),

          Text(
            'There are no reports matching this SLA category.',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              10,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SUMMARY CARD
// ================================================================

class _SlaSummaryCard
    extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  const _SlaSummaryCard({
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.surface,

        borderRadius:
        BorderRadius.circular(
          16,
        ),

        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,

        children: [
          Row(
            children: [
              Container(
                width:
                31,

                height:
                31,

                decoration:
                BoxDecoration(
                  color:
                  color.withOpacity(
                    0.12,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    9,
                  ),
                ),

                child:
                Icon(
                  icon,

                  color:
                  color,

                  size:
                  17,
                ),
              ),

              const Spacer(),

              Text(
                label,

                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,

                  fontSize:
                  8,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          Text(
            value,

            style:
            const TextStyle(
              fontSize:
              24,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          Text(
            description,

            maxLines:
            1,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              9,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO ITEM
// ================================================================

class _SlaInfoItem
    extends StatelessWidget {
  final String label;
  final String value;

  const _SlaInfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Text(
          label,

          style:
          const TextStyle(
            color:
            AppColors.textSecondary,

            fontSize:
            8,
          ),
        ),

        const SizedBox(
          height:
          4,
        ),

        Text(
          value,

          maxLines:
          1,

          overflow:
          TextOverflow.ellipsis,

          style:
          const TextStyle(
            fontSize:
            11,

            fontWeight:
            FontWeight.bold,
          ),
        ),
      ],
    );
  }
}