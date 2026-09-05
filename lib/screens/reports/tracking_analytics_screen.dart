import 'package:flutter/material.dart';

import '../../models/infrastructure_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import 'report_detail_screen.dart';

// ================================================================
// TRACKING ANALYTICS SCREEN
//
// Module:
// Report Tracking & Management
//
// Purpose:
// - Analyse the logged-in citizen's reports
// - Show report status distribution
// - Show completion progress
// - Show priority distribution
// - Show department assignment information
// - Generate simple tracking insights
// - Show recently submitted reports
//
// No new database table is required.
// ================================================================

class TrackingAnalyticsScreen extends StatefulWidget {
  const TrackingAnalyticsScreen({
    super.key,
  });

  @override
  State<TrackingAnalyticsScreen> createState() =>
      _TrackingAnalyticsScreenState();
}

class _TrackingAnalyticsScreenState
    extends State<TrackingAnalyticsScreen> {
  // ============================================================
  // SERVICE
  // ============================================================

  final ReportService reportService =
  ReportService();

  // ============================================================
  // DATA
  // ============================================================

  List<InfrastructureReport> reports =
  <InfrastructureReport>[];

  bool loading = true;

  String? errorMessage;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadAnalytics();
  }

  // ============================================================
  // LOAD REPORTS
  // ============================================================

  Future<void> _loadAnalytics() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final List<InfrastructureReport>
      result =
      await reportService.getMyReports();

      if (!mounted) {
        return;
      }

      setState(() {
        reports = result;
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
  // STATUS HELPERS
  // ============================================================

  String _normalizeStatus(
      String status,
      ) {
    return status
        .trim()
        .toLowerCase()
        .replaceAll(
      ' ',
      '_',
    );
  }

  String _statusLabel(
      String status,
      ) {
    switch (_normalizeStatus(status)) {
      case 'pending':
        return 'Pending';

      case 'verified':
        return 'Verified';

      case 'in_progress':
        return 'In Progress';

      case 'completed':
        return 'Completed';

      case 'rejected':
        return 'Rejected';

      default:
        return status;
    }
  }

  Color _statusColor(
      String status,
      ) {
    switch (_normalizeStatus(status)) {
      case 'pending':
        return AppColors.warning;

      case 'completed':
        return AppColors.success;

      case 'rejected':
        return AppColors.danger;

      case 'verified':
      case 'in_progress':
      default:
        return AppColors.primary;
    }
  }

  // ============================================================
  // ANALYTICS COUNTS
  // ============================================================

  int _countStatus(
      String wantedStatus,
      ) {
    return reports.where(
          (
          InfrastructureReport report,
          ) {
        return _normalizeStatus(
          report.status,
        ) ==
            wantedStatus;
      },
    ).length;
  }

  int get pendingCount =>
      _countStatus(
        'pending',
      );

  int get verifiedCount =>
      _countStatus(
        'verified',
      );

  int get inProgressCount =>
      _countStatus(
        'in_progress',
      );

  int get completedCount =>
      _countStatus(
        'completed',
      );

  int get rejectedCount =>
      _countStatus(
        'rejected',
      );

  int get activeCount =>
      pendingCount +
          verifiedCount +
          inProgressCount;

  // ============================================================
  // PROGRESS ANALYTICS
  // ============================================================

  double get averageProgress {
    if (reports.isEmpty) {
      return 0;
    }

    final int totalProgress =
    reports.fold<int>(
      0,
          (
          int total,
          InfrastructureReport report,
          ) {
        return total +
            report.progressPercentage;
      },
    );

    return totalProgress /
        reports.length;
  }

  double get completionRate {
    if (reports.isEmpty) {
      return 0;
    }

    return completedCount /
        reports.length;
  }

  // ============================================================
  // ASSIGNMENT ANALYTICS
  // ============================================================

  int get assignedCount {
    return reports.where(
          (
          InfrastructureReport report,
          ) {
        final String department =
            report.assignedDepartment
                ?.trim() ??
                '';

        return department.isNotEmpty;
      },
    ).length;
  }

  int get unassignedCount =>
      reports.length -
          assignedCount;

  double get assignmentRate {
    if (reports.isEmpty) {
      return 0;
    }

    return assignedCount /
        reports.length;
  }

  // ============================================================
  // PRIORITY ANALYTICS
  // ============================================================

  int _countPriority(
      String wantedPriority,
      ) {
    return reports.where(
          (
          InfrastructureReport report,
          ) {
        return report.priority
            .trim()
            .toLowerCase() ==
            wantedPriority;
      },
    ).length;
  }

  int get criticalCount =>
      _countPriority(
        'critical',
      );

  int get highCount =>
      _countPriority(
        'high',
      );

  int get mediumCount =>
      _countPriority(
        'medium',
      );

  int get lowCount =>
      _countPriority(
        'low',
      );

  // ============================================================
  // PRIORITY COLOR
  // ============================================================

  Color _priorityColor(
      String priority,
      ) {
    switch (
    priority.trim().toLowerCase()) {
      case 'critical':
        return AppColors.danger;

      case 'high':
        return AppColors.warning;

      case 'medium':
        return AppColors.primary;

      case 'low':
      default:
        return AppColors.success;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

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

  // ============================================================
  // RECENT REPORTS
  // ============================================================

  List<InfrastructureReport>
  get recentReports {
    final List<InfrastructureReport>
    result =
    List<InfrastructureReport>.from(
      reports,
    );

    result.sort(
          (
          InfrastructureReport a,
          InfrastructureReport b,
          ) {
        return b.createdAt.compareTo(
          a.createdAt,
        );
      },
    );

    return result.take(5).toList();
  }

  // ============================================================
  // OPEN REPORT
  // ============================================================

  Future<void> _openReport(
      InfrastructureReport report,
      ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder:
            (
            BuildContext context,
            ) {
          return ReportDetailScreen(
            reportId: report.id,
          );
        },
      ),
    );
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

        title:
        const Text(
          'Tracking Analytics',

          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
            'Refresh',

            onPressed:
            _loadAnalytics,

            icon:
            const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body:
      _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

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

    if (reports.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh:
      _loadAnalytics,

      child:
      ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        padding:
        const EdgeInsets.all(
          18,
        ),

        children: [
          // ======================================================
          // HEADER
          // ======================================================

          const Text(
            'My Report Performance',

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
            'Monitor the progress, status and maintenance performance of your submitted infrastructure reports.',

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
          // MAIN STATISTICS
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
              _AnalyticsStatCard(
                title:
                'TOTAL REPORTS',

                value:
                '${reports.length}',

                subtitle:
                'Reports submitted',

                icon:
                Icons.description_outlined,

                color:
                AppColors.primary,
              ),

              _AnalyticsStatCard(
                title:
                'ACTIVE',

                value:
                '$activeCount',

                subtitle:
                'Currently tracked',

                icon:
                Icons.track_changes_rounded,

                color:
                AppColors.warning,
              ),

              _AnalyticsStatCard(
                title:
                'COMPLETED',

                value:
                '$completedCount',

                subtitle:
                '${(completionRate * 100).round()}% completion rate',

                icon:
                Icons.task_alt_rounded,

                color:
                AppColors.success,
              ),

              _AnalyticsStatCard(
                title:
                'AVG. PROGRESS',

                value:
                '${averageProgress.round()}%',

                subtitle:
                'Across all reports',

                icon:
                Icons.analytics_outlined,

                color:
                AppColors.primary,
              ),
            ],
          ),

          const SizedBox(
            height:
            24,
          ),

          // ======================================================
          // STATUS OVERVIEW
          // ======================================================

          _SectionHeader(
            icon:
            Icons.timeline_rounded,

            title:
            'Report Progress Overview',

            subtitle:
            'Current distribution by workflow status',
          ),

          const SizedBox(
            height:
            12,
          ),

          _AnalyticsPanel(
            child:
            Column(
              children: [
                _DistributionRow(
                  label:
                  'Pending',

                  count:
                  pendingCount,

                  total:
                  reports.length,

                  color:
                  AppColors.warning,
                ),

                const SizedBox(
                  height:
                  14,
                ),

                _DistributionRow(
                  label:
                  'Verified',

                  count:
                  verifiedCount,

                  total:
                  reports.length,

                  color:
                  AppColors.primary,
                ),

                const SizedBox(
                  height:
                  14,
                ),

                _DistributionRow(
                  label:
                  'In Progress',

                  count:
                  inProgressCount,

                  total:
                  reports.length,

                  color:
                  AppColors.primary,
                ),

                const SizedBox(
                  height:
                  14,
                ),

                _DistributionRow(
                  label:
                  'Completed',

                  count:
                  completedCount,

                  total:
                  reports.length,

                  color:
                  AppColors.success,
                ),

                const SizedBox(
                  height:
                  14,
                ),

                _DistributionRow(
                  label:
                  'Rejected',

                  count:
                  rejectedCount,

                  total:
                  reports.length,

                  color:
                  AppColors.danger,
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            24,
          ),

          // ======================================================
          // TRACKING INSIGHTS
          // ======================================================

          _SectionHeader(
            icon:
            Icons.auto_graph_rounded,

            title:
            'Tracking Insights',

            subtitle:
            'Automatically generated from your reports',
          ),

          const SizedBox(
            height:
            12,
          ),

          _AnalyticsPanel(
            child:
            Column(
              children: [
                _InsightRow(
                  icon:
                  Icons.speed_rounded,

                  title:
                  'Average progress',

                  value:
                  '${averageProgress.round()}%',

                  description:
                  'Average maintenance progress across your reports.',
                ),

                const Divider(
                  color:
                  AppColors.border,

                  height:
                  28,
                ),

                _InsightRow(
                  icon:
                  Icons.engineering_outlined,

                  title:
                  'Under maintenance',

                  value:
                  '$inProgressCount',

                  description:
                  'Reports currently being worked on.',
                ),

                const Divider(
                  color:
                  AppColors.border,

                  height:
                  28,
                ),

                _InsightRow(
                  icon:
                  Icons.fact_check_outlined,

                  title:
                  'Waiting verification',

                  value:
                  '$pendingCount',

                  description:
                  'Reports that have not yet been verified.',
                ),

                const Divider(
                  color:
                  AppColors.border,

                  height:
                  28,
                ),

                _InsightRow(
                  icon:
                  Icons.apartment_rounded,

                  title:
                  'Without department',

                  value:
                  '$unassignedCount',

                  description:
                  'Reports that are not currently assigned to a department.',
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            24,
          ),

          // ======================================================
          // DEPARTMENT ASSIGNMENT
          // ======================================================

          _SectionHeader(
            icon:
            Icons.account_tree_outlined,

            title:
            'Department Assignment',

            subtitle:
            'Assignment coverage for your reports',
          ),

          const SizedBox(
            height:
            12,
          ),

          _AnalyticsPanel(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    const Text(
                      'Assignment Rate',

                      style:
                      TextStyle(
                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    Text(
                      '${(assignmentRate * 100).round()}%',

                      style:
                      const TextStyle(
                        color:
                        AppColors.primary,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  10,
                ),

                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),

                  child:
                  LinearProgressIndicator(
                    value:
                    assignmentRate,

                    minHeight:
                    8,

                    backgroundColor:
                    AppColors.border,

                    color:
                    AppColors.primary,
                  ),
                ),

                const SizedBox(
                  height:
                  15,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                      _SmallCountBox(
                        label:
                        'ASSIGNED',

                        value:
                        '$assignedCount',

                        icon:
                        Icons.check_circle_outline_rounded,
                      ),
                    ),

                    const SizedBox(
                      width:
                      10,
                    ),

                    Expanded(
                      child:
                      _SmallCountBox(
                        label:
                        'UNASSIGNED',

                        value:
                        '$unassignedCount',

                        icon:
                        Icons.pending_actions_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            24,
          ),

          // ======================================================
          // PRIORITY DISTRIBUTION
          // ======================================================

          _SectionHeader(
            icon:
            Icons.flag_outlined,

            title:
            'Priority Breakdown',

            subtitle:
            'Distribution based on report urgency',
          ),

          const SizedBox(
            height:
            12,
          ),

          _AnalyticsPanel(
            child:
            Column(
              children: [
                _DistributionRow(
                  label:
                  'Critical',

                  count:
                  criticalCount,

                  total:
                  reports.length,

                  color:
                  _priorityColor(
                    'critical',
                  ),
                ),

                const SizedBox(
                  height:
                  14,
                ),

                _DistributionRow(
                  label:
                  'High',

                  count:
                  highCount,

                  total:
                  reports.length,

                  color:
                  _priorityColor(
                    'high',
                  ),
                ),

                const SizedBox(
                  height:
                  14,
                ),

                _DistributionRow(
                  label:
                  'Medium',

                  count:
                  mediumCount,

                  total:
                  reports.length,

                  color:
                  _priorityColor(
                    'medium',
                  ),
                ),

                const SizedBox(
                  height:
                  14,
                ),

                _DistributionRow(
                  label:
                  'Low',

                  count:
                  lowCount,

                  total:
                  reports.length,

                  color:
                  _priorityColor(
                    'low',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            24,
          ),

          // ======================================================
          // RECENT REPORTS
          // ======================================================

          _SectionHeader(
            icon:
            Icons.history_rounded,

            title:
            'Recent Reports',

            subtitle:
            'Latest reports and current tracking status',
          ),

          const SizedBox(
            height:
            12,
          ),

          ...recentReports.map(
                (
                InfrastructureReport report,
                ) {
              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom:
                  10,
                ),

                child:
                _RecentReportCard(
                  report:
                  report,

                  statusLabel:
                  _statusLabel(
                    report.status,
                  ),

                  statusColor:
                  _statusColor(
                    report.status,
                  ),

                  formattedDate:
                  _formatDate(
                    report.createdAt,
                  ),

                  onTap:
                      () {
                    _openReport(
                      report,
                    );
                  },
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
              Icons.error_outline_rounded,

              size:
              48,

              color:
              AppColors.danger,
            ),

            const SizedBox(
              height:
              12,
            ),

            const Text(
              'Unable to load analytics',

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
              _loadAnalytics,

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
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh:
      _loadAnalytics,

      child:
      ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        children: const [
          SizedBox(
            height:
            170,
          ),

          Icon(
            Icons.analytics_outlined,

            size:
            58,

            color:
            AppColors.textSecondary,
          ),

          SizedBox(
            height:
            14,
          ),

          Text(
            'No analytics available',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(
              fontSize:
              18,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          SizedBox(
            height:
            7,
          ),

          Padding(
            padding:
            EdgeInsets.symmetric(
              horizontal:
              35,
            ),

            child:
            Text(
              'Your tracking analytics will appear here after you submit infrastructure reports.',

              textAlign:
              TextAlign.center,

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
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ANALYTICS STAT CARD
// ================================================================

class _AnalyticsStatCard
    extends StatelessWidget {
  final String title;

  final String value;

  final String subtitle;

  final IconData icon;

  final Color color;

  const _AnalyticsStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
                title,

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
            subtitle,

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
// ANALYTICS PANEL
// ================================================================

class _AnalyticsPanel
    extends StatelessWidget {
  final Widget child;

  const _AnalyticsPanel({
    required this.child,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.all(
        16,
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
      child,
    );
  }
}

// ================================================================
// SECTION HEADER
// ================================================================

class _SectionHeader
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Container(
          width:
          36,

          height:
          36,

          decoration:
          BoxDecoration(
            color:
            AppColors.primary
                .withOpacity(
              0.10,
            ),

            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),

          child:
          Icon(
            icon,

            color:
            AppColors.primary,

            size:
            19,
          ),
        ),

        const SizedBox(
          width:
          10,
        ),

        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style:
                const TextStyle(
                  fontSize:
                  15,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                2,
              ),

              Text(
                subtitle,

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
        ),
      ],
    );
  }
}

// ================================================================
// DISTRIBUTION ROW
// ================================================================

class _DistributionRow
    extends StatelessWidget {
  final String label;

  final int count;

  final int total;

  final Color color;

  const _DistributionRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final double percentage =
    total <= 0
        ? 0
        : count /
        total;

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width:
              85,

              child:
              Text(
                label,

                style:
                const TextStyle(
                  fontSize:
                  11,

                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),

            Expanded(
              child:
              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  20,
                ),

                child:
                LinearProgressIndicator(
                  value:
                  percentage,

                  minHeight:
                  7,

                  backgroundColor:
                  AppColors.border,

                  color:
                  color,
                ),
              ),
            ),

            const SizedBox(
              width:
              10,
            ),

            SizedBox(
              width:
              25,

              child:
              Text(
                '$count',

                textAlign:
                TextAlign.right,

                style:
                TextStyle(
                  color:
                  color,

                  fontWeight:
                  FontWeight.bold,

                  fontSize:
                  11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ================================================================
// INSIGHT ROW
// ================================================================

class _InsightRow
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String value;

  final String description;

  const _InsightRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Container(
          width:
          36,

          height:
          36,

          decoration:
          BoxDecoration(
            color:
            AppColors.primary
                .withOpacity(
              0.10,
            ),

            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),

          child:
          Icon(
            icon,

            color:
            AppColors.primary,

            size:
            18,
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

                style:
                const TextStyle(
                  fontSize:
                  11,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                3,
              ),

              Text(
                description,

                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,

                  fontSize:
                  9,

                  height:
                  1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width:
          10,
        ),

        Text(
          value,

          style:
          const TextStyle(
            color:
            AppColors.primary,

            fontSize:
            17,

            fontWeight:
            FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SMALL COUNT BOX
// ================================================================

class _SmallCountBox
    extends StatelessWidget {
  final String label;

  final String value;

  final IconData icon;

  const _SmallCountBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        11,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.background,

        borderRadius:
        BorderRadius.circular(
          12,
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
          Icon(
            icon,

            color:
            AppColors.primary,

            size:
            17,
          ),

          const SizedBox(
            width:
            8,
          ),

          Expanded(
            child:
            Column(
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
                  2,
                ),

                Text(
                  value,

                  style:
                  const TextStyle(
                    fontSize:
                    15,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// RECENT REPORT CARD
// ================================================================

class _RecentReportCard
    extends StatelessWidget {
  final InfrastructureReport report;

  final String statusLabel;

  final Color statusColor;

  final String formattedDate;

  final VoidCallback onTap;

  const _RecentReportCard({
    required this.report,
    required this.statusLabel,
    required this.statusColor,
    required this.formattedDate,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Material(
      color:
      Colors.transparent,

      child:
      InkWell(
        onTap:
        onTap,

        borderRadius:
        BorderRadius.circular(
          15,
        ),

        child:
        Container(
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
              15,
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
              Container(
                width:
                42,

                height:
                42,

                decoration:
                BoxDecoration(
                  color:
                  statusColor
                      .withOpacity(
                    0.10,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                Icon(
                  Icons
                      .construction_rounded,

                  color:
                  statusColor,

                  size:
                  20,
                ),
              ),

              const SizedBox(
                width:
                12,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      report.title,

                      maxLines:
                      1,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      4,
                    ),

                    Text(
                      report.referenceNumber,

                      style:
                      const TextStyle(
                        color:
                        AppColors.primary,

                        fontSize:
                        9,
                      ),
                    ),

                    const SizedBox(
                      height:
                      5,
                    ),

                    Row(
                      children: [
                        Text(
                          formattedDate,

                          style:
                          const TextStyle(
                            color:
                            AppColors.textSecondary,

                            fontSize:
                            9,
                          ),
                        ),

                        const SizedBox(
                          width:
                          8,
                        ),

                        Text(
                          '${report.progressPercentage}% progress',

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
                  ],
                ),
              ),

              const SizedBox(
                width:
                8,
              ),

              Column(
                crossAxisAlignment:
                CrossAxisAlignment.end,

                children: [
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
                      statusColor
                          .withOpacity(
                        0.10,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),

                    child:
                    Text(
                      statusLabel,

                      style:
                      TextStyle(
                        color:
                        statusColor,

                        fontSize:
                        8,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  const Icon(
                    Icons
                        .chevron_right_rounded,

                    color:
                    AppColors.textSecondary,

                    size:
                    18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}