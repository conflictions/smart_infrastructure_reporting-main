import 'package:flutter/material.dart';

import '../../services/community_priority_service.dart';
import '../../theme/app_colors.dart';
import 'report_detail_screen.dart';

class CommunityPriorityScreen
    extends StatefulWidget {
  const CommunityPriorityScreen({
    super.key,
  });

  @override
  State<CommunityPriorityScreen>
  createState() =>
      _CommunityPriorityScreenState();
}

class _CommunityPriorityScreenState
    extends State<CommunityPriorityScreen> {
  final CommunityPriorityService service =
  CommunityPriorityService();

  final TextEditingController searchController =
  TextEditingController();

  List<CommunityPriorityReport> reports =
  [];

  final Set<String> busyReports =
  {};

  bool loading = true;

  String? errorMessage;

  String selectedFilter = 'All';

  String selectedSort =
      'Priority Score';

  final List<String> filters = [
    'All',
    'Critical',
    'High Attention',
    'Trending',
    'Still Exists',
  ];

  final List<String> sortOptions = [
    'Priority Score',
    'Most Supported',
    'Recent Activity',
    'Newest',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    searchController.addListener(
      _refresh,
    );

    _loadReports();
  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadReports({
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final result =
      await service
          .getPriorityReports();

      if (!mounted) {
        return;
      }

      setState(() {
        reports = result;
        loading = false;
        errorMessage = null;
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
        );
      });
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<CommunityPriorityReport>
  get visibleReports {
    final String query =
    searchController.text
        .trim()
        .toLowerCase();

    List<CommunityPriorityReport> result =
    reports.where(
          (
          CommunityPriorityReport item,
          ) {
        final bool searchMatch =
            query.isEmpty ||
                item.report.title
                    .toLowerCase()
                    .contains(query) ||
                item.report.referenceNumber
                    .toLowerCase()
                    .contains(query) ||
                item.report.category
                    .toLowerCase()
                    .contains(query) ||
                item.report.address
                    .toLowerCase()
                    .contains(query);

        if (!searchMatch) {
          return false;
        }

        switch (selectedFilter) {
          case 'Critical':
            return item.score >= 70;

          case 'High Attention':
            return item.score >= 40;

          case 'Trending':
            return item.trending;

          case 'Still Exists':
            return item.stillExistsSignal;

          default:
            return true;
        }
      },
    ).toList();

    switch (selectedSort) {
      case 'Most Supported':
        result.sort(
              (a, b) =>
              b.supportCount
                  .compareTo(
                a.supportCount,
              ),
        );
        break;

      case 'Recent Activity':
        result.sort(
              (a, b) {
            final DateTime first =
                a.latestInteractionAt ??
                    DateTime(2000);

            final DateTime second =
                b.latestInteractionAt ??
                    DateTime(2000);

            return second.compareTo(
              first,
            );
          },
        );
        break;

      case 'Newest':
        result.sort(
              (a, b) =>
              b.report.createdAt
                  .compareTo(
                a.report.createdAt,
              ),
        );
        break;

      case 'Priority Score':
      default:
        result.sort(
              (a, b) =>
              b.score.compareTo(
                a.score,
              ),
        );
    }

    return result;
  }

  int get highAttentionCount =>
      reports
          .where(
            (item) =>
        item.score >= 40,
      )
          .length;

  int get trendingCount =>
      reports
          .where(
            (item) =>
        item.trending,
      )
          .length;

  int get stillExistsCount =>
      reports
          .where(
            (item) =>
        item.stillExistsSignal,
      )
          .length;

  // ============================================================
  // SUPPORT
  // ============================================================

  Future<void> _toggleSupport(
      CommunityPriorityReport item,
      ) async {
    if (busyReports.contains(
      item.report.id,
    )) {
      return;
    }

    setState(() {
      busyReports.add(
        item.report.id,
      );
    });

    try {
      final bool supported =
      await service.toggleSupport(
        item.report.id,
      );

      await _loadReports(
        showLoader: false,
      );

      _message(
        supported
            ? 'You supported this report.'
            : 'Support removed.',
      );
    } catch (e) {
      _message(
        e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busyReports.remove(
            item.report.id,
          );
        });
      }
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================

  Future<void> _updateFeedback({
    required CommunityPriorityReport item,
    required String feedback,
  }) async {
    if (busyReports.contains(
      item.report.id,
    )) {
      return;
    }

    final String? value =
    item.myFeedback == feedback
        ? null
        : feedback;

    setState(() {
      busyReports.add(
        item.report.id,
      );
    });

    try {
      await service.setFeedback(
        reportId:
        item.report.id,
        feedback:
        value,
      );

      await _loadReports(
        showLoader: false,
      );

      if (value == null) {
        _message(
          'Feedback removed.',
        );
      } else if (value ==
          'still_exists') {
        _message(
          'Marked as still existing.',
        );
      } else {
        _message(
          'Marked as looking fixed.',
        );
      }
    } catch (e) {
      _message(
        e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busyReports.remove(
            item.report.id,
          );
        });
      }
    }
  }

  // ============================================================
  // VIEW REPORT
  // ============================================================

  Future<void> _openReport(
      CommunityPriorityReport item,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
            ReportDetailScreen(
              reportId:
              item.report.id,
            ),
      ),
    );

    await _loadReports(
      showLoader: false,
    );
  }

  // ============================================================
  // SCORE EXPLANATION
  // ============================================================

  void _showScoreInfo() {
    showModalBottomSheet(
      context:
      context,
      backgroundColor:
      AppColors.surface,
      isScrollControlled:
      true,
      builder:
          (
          BuildContext context,
          ) {
        return SafeArea(
          child:
          Padding(
            padding:
            const EdgeInsets.all(
              20,
            ),
            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: const [
                Text(
                  'Community Priority Score',
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
                  10,
                ),

                Text(
                  'This is a project-defined ranking algorithm. '
                      'It is not an official government priority score.',
                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize:
                    11,
                    height:
                    1.5,
                  ),
                ),

                SizedBox(
                  height:
                  16,
                ),

                Text(
                  'Support × 2\n'
                      'Still Exists × 6\n'
                      'Looks Fixed × -2\n'
                      'Unique Evidence Contributors × 4\n'
                      'Evidence Bonus up to +5\n'
                      'Recent Participants × 3\n'
                      'Medium Priority +5\n'
                      'High Priority +10\n'
                      'Critical Priority +20',
                  style:
                  TextStyle(
                    fontSize:
                    11,
                    height:
                    1.8,
                  ),
                ),

                SizedBox(
                  height:
                  12,
                ),
              ],
            ),
          ),
        );
      },
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

      appBar:
      AppBar(
        backgroundColor:
        AppColors.surface,

        title:
        const Text(
          'Community Priority',

          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
            'How scoring works',

            onPressed:
            _showScoreInfo,

            icon:
            const Icon(
              Icons.info_outline,
            ),
          ),

          IconButton(
            tooltip:
            'Refresh',

            onPressed:
            _loadReports,

            icon:
            const Icon(
              Icons.refresh,
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
                Icons.error_outline,

                color:
                AppColors.danger,

                size:
                48,
              ),

              const SizedBox(
                height:
                12,
              ),

              Text(
                errorMessage!,

                textAlign:
                TextAlign.center,
              ),

              const SizedBox(
                height:
                16,
              ),

              FilledButton(
                onPressed:
                _loadReports,

                child:
                const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          () =>
          _loadReports(
            showLoader:
            false,
          ),

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
            'High-Interaction Report Management',

            style:
            TextStyle(
              fontSize:
              21,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          const Text(
            'Identify reports receiving strong public attention and manage community feedback from one place.',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              11,

              height:
              1.4,
            ),
          ),

          const SizedBox(
            height:
            20,
          ),

          // ======================================================
          // SUMMARY
          // ======================================================

          GridView.count(
            crossAxisCount:
            2,

            shrinkWrap:
            true,

            physics:
            const NeverScrollableScrollPhysics(),

            mainAxisSpacing:
            10,

            crossAxisSpacing:
            10,

            childAspectRatio:
            1.55,

            children: [
              _SummaryCard(
                title:
                'TRACKED',

                value:
                '${reports.length}',

                subtitle:
                'Community reports',

                icon:
                Icons.public,

                color:
                AppColors.primary,
              ),

              _SummaryCard(
                title:
                'HIGH ATTENTION',

                value:
                '$highAttentionCount',

                subtitle:
                'Score 40+',

                icon:
                Icons.priority_high,

                color:
                AppColors.danger,
              ),

              _SummaryCard(
                title:
                'TRENDING',

                value:
                '$trendingCount',

                subtitle:
                'Recent activity',

                icon:
                Icons.trending_up,

                color:
                AppColors.warning,
              ),

              _SummaryCard(
                title:
                'STILL EXISTS',

                value:
                '$stillExistsCount',

                subtitle:
                'Unresolved signal',

                icon:
                Icons.report_problem,

                color:
                AppColors.warning,
              ),
            ],
          ),

          const SizedBox(
            height:
            20,
          ),

          // ======================================================
          // SEARCH
          // ======================================================

          TextField(
            controller:
            searchController,

            decoration:
            InputDecoration(
              hintText:
              'Search report, category or location',

              prefixIcon:
              const Icon(
                Icons.search,
              ),

              filled:
              true,

              fillColor:
              AppColors.surface,

              border:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
            12,
          ),

          // ======================================================
          // FILTER
          // ======================================================

          SizedBox(
            height:
            40,

            child:
            ListView.separated(
              scrollDirection:
              Axis.horizontal,

              itemCount:
              filters.length,

              separatorBuilder:
                  (_, __) =>
              const SizedBox(
                width:
                7,
              ),

              itemBuilder:
                  (
                  context,
                  index,
                  ) {
                final String filter =
                filters[index];

                return ChoiceChip(
                  label:
                  Text(
                    filter,
                  ),

                  selected:
                  selectedFilter ==
                      filter,

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
            12,
          ),

          // ======================================================
          // SORT
          // ======================================================

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              12,
            ),

            decoration:
            BoxDecoration(
              color:
              AppColors.surface,

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
            DropdownButtonHideUnderline(
              child:
              DropdownButton<String>(
                value:
                selectedSort,

                isExpanded:
                true,

                items:
                sortOptions.map(
                      (
                      String option,
                      ) {
                    return DropdownMenuItem(
                      value:
                      option,

                      child:
                      Text(
                        'Sort: $option',
                      ),
                    );
                  },
                ).toList(),

                onChanged:
                    (
                    String? value,
                    ) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedSort =
                        value;
                  });
                },
              ),
            ),
          ),

          const SizedBox(
            height:
            20,
          ),

          Row(
            children: [
              const Text(
                'Community Priority Queue',

                style:
                TextStyle(
                  fontSize:
                  16,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const Spacer(),

              Text(
                '${visibleReports.length} reports',

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

          const SizedBox(
            height:
            12,
          ),

          if (visibleReports.isEmpty)
            const Center(
              child:
              Padding(
                padding:
                EdgeInsets.all(
                  40,
                ),

                child:
                Text(
                  'No matching reports.',
                ),
              ),
            )
          else
            ...visibleReports.map(
              _buildReportCard,
            ),

          const SizedBox(
            height:
            30,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REPORT CARD
  // ============================================================

  Widget _buildReportCard(
      CommunityPriorityReport item,
      ) {
    final Color scoreColor =
    _scoreColor(
      item.score,
    );

    final bool busy =
    busyReports.contains(
      item.report.id,
    );

    return Container(
      margin:
      const EdgeInsets.only(
        bottom:
        12,
      ),

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
          item.score >= 70
              ? scoreColor
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
                52,

                height:
                52,

                decoration:
                BoxDecoration(
                  color:
                  scoreColor
                      .withOpacity(
                    0.12,
                  ),

                  shape:
                  BoxShape.circle,
                ),

                child:
                Center(
                  child:
                  Text(
                    '${item.score}',

                    style:
                    TextStyle(
                      color:
                      scoreColor,

                      fontSize:
                      18,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
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
                      item.report.title,

                      maxLines:
                      2,

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
                      item.report.referenceNumber,

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
                      7,
                    ),

                    Wrap(
                      spacing:
                      6,

                      runSpacing:
                      5,

                      children: [
                        _Tag(
                          text:
                          item.attentionLabel,

                          color:
                          scoreColor,
                        ),

                        if (item.trending)
                          const _Tag(
                            text:
                            'TRENDING',

                            color:
                            AppColors.warning,
                          ),

                        if (item
                            .stillExistsSignal)
                          const _Tag(
                            text:
                            'STILL EXISTS',

                            color:
                            AppColors.danger,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            14,
          ),

          // ======================================================
          // COMMUNITY METRICS
          // ======================================================

          Row(
            children: [
              Expanded(
                child:
                _Metric(
                  icon:
                  Icons.thumb_up_alt_outlined,

                  value:
                  '${item.supportCount}',

                  label:
                  'Supports',
                ),
              ),

              Expanded(
                child:
                _Metric(
                  icon:
                  Icons.report_problem_outlined,

                  value:
                  '${item.stillExistsCount}',

                  label:
                  'Still Exists',
                ),
              ),

              Expanded(
                child:
                _Metric(
                  icon:
                  Icons.check_circle_outline,

                  value:
                  '${item.looksFixedCount}',

                  label:
                  'Looks Fixed',
                ),
              ),

              Expanded(
                child:
                _Metric(
                  icon:
                  Icons.add_photo_alternate_outlined,

                  value:
                  '${item.contributionCount}',

                  label:
                  'Evidence',
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            14,
          ),

          Text(
            '${item.report.priority} Priority • '
                '${_statusText(item.report.status)} • '
                '${item.recentParticipantCount} recent participant'
                '${item.recentParticipantCount == 1 ? '' : 's'}',

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              9,
            ),
          ),

          const SizedBox(
            height:
            10,
          ),

          Row(
            children: [
              const Text(
                'Maintenance Progress',

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
                '${item.report.progressPercentage}%',

                style:
                const TextStyle(
                  color:
                  AppColors.primary,

                  fontWeight:
                  FontWeight.bold,

                  fontSize:
                  10,
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
              10,
            ),

            child:
            LinearProgressIndicator(
              value:
              (item.report
                  .progressPercentage /
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
              AppColors.primary,
            ),
          ),

          const SizedBox(
            height:
            14,
          ),

          // ======================================================
          // COMMUNITY ACTIONS
          // ======================================================

          if (busy)
            const Center(
              child:
              CircularProgressIndicator(),
            )
          else
            Wrap(
              spacing:
              8,

              runSpacing:
              8,

              children: [
                item.supportedByMe
                    ? FilledButton.icon(
                  onPressed:
                      () =>
                      _toggleSupport(
                        item,
                      ),

                  icon:
                  const Icon(
                    Icons.thumb_up,
                    size:
                    16,
                  ),

                  label:
                  const Text(
                    'Supported',
                  ),
                )
                    : OutlinedButton.icon(
                  onPressed:
                      () =>
                      _toggleSupport(
                        item,
                      ),

                  icon:
                  const Icon(
                    Icons.thumb_up_alt_outlined,
                    size:
                    16,
                  ),

                  label:
                  const Text(
                    'Support',
                  ),
                ),

                item.myFeedback ==
                    'still_exists'
                    ? FilledButton.icon(
                  onPressed:
                      () =>
                      _updateFeedback(
                        item:
                        item,

                        feedback:
                        'still_exists',
                      ),

                  icon:
                  const Icon(
                    Icons.report_problem,
                    size:
                    16,
                  ),

                  label:
                  const Text(
                    'Still Exists',
                  ),
                )
                    : OutlinedButton.icon(
                  onPressed:
                      () =>
                      _updateFeedback(
                        item:
                        item,

                        feedback:
                        'still_exists',
                      ),

                  icon:
                  const Icon(
                    Icons.report_problem_outlined,
                    size:
                    16,
                  ),

                  label:
                  const Text(
                    'Still Exists',
                  ),
                ),

                item.myFeedback ==
                    'looks_fixed'
                    ? FilledButton.icon(
                  onPressed:
                      () =>
                      _updateFeedback(
                        item:
                        item,

                        feedback:
                        'looks_fixed',
                      ),

                  icon:
                  const Icon(
                    Icons.check_circle,
                    size:
                    16,
                  ),

                  label:
                  const Text(
                    'Looks Fixed',
                  ),
                )
                    : OutlinedButton.icon(
                  onPressed:
                      () =>
                      _updateFeedback(
                        item:
                        item,

                        feedback:
                        'looks_fixed',
                      ),

                  icon:
                  const Icon(
                    Icons.check_circle_outline,
                    size:
                    16,
                  ),

                  label:
                  const Text(
                    'Looks Fixed',
                  ),
                ),
              ],
            ),

          const SizedBox(
            height:
            8,
          ),

          Align(
            alignment:
            Alignment.centerRight,

            child:
            TextButton.icon(
              onPressed:
                  () =>
                  _openReport(
                    item,
                  ),

              icon:
              const Icon(
                Icons.open_in_new,

                size:
                16,
              ),

              label:
              const Text(
                'View Details',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Color _scoreColor(
      int score,
      ) {
    if (score >= 70) {
      return AppColors.danger;
    }

    if (score >= 40) {
      return AppColors.warning;
    }

    if (score >= 20) {
      return AppColors.primary;
    }

    return AppColors.success;
  }

  String _statusText(
      String status,
      ) {
    switch (
    status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';

      case 'completed':
        return 'Completed';

      case 'verified':
        return 'Verified';

      case 'rejected':
        return 'Rejected';

      default:
        return 'Pending';
    }
  }

  void _message(
      String text,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(
          text,
        ),
      ),
    );
  }
}

// ================================================================
// SUMMARY CARD
// ================================================================

class _SummaryCard
    extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
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
        13,
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
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,

        children: [
          Row(
            children: [
              Icon(
                icon,

                color:
                color,

                size:
                20,
              ),

              const Spacer(),

              Text(
                title,

                style:
                const TextStyle(
                  color:
                  AppColors.textSecondary,

                  fontSize:
                  7,

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
              23,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          Text(
            subtitle,

            style:
            const TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              8,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// METRIC
// ================================================================

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Icon(
          icon,

          size:
          16,

          color:
          AppColors.primary,
        ),

        const SizedBox(
          height:
          4,
        ),

        Text(
          value,

          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,

            fontSize:
            13,
          ),
        ),

        const SizedBox(
          height:
          2,
        ),

        Text(
          label,

          style:
          const TextStyle(
            color:
            AppColors.textSecondary,

            fontSize:
            7,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// TAG
// ================================================================

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({
    required this.text,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        8,

        vertical:
        4,
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
        text,

        style:
        TextStyle(
          color:
          color,

          fontSize:
          7,

          fontWeight:
          FontWeight.bold,
        ),
      ),
    );
  }
}