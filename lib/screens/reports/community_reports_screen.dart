import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/infrastructure_report.dart';
import '../../services/community_priority_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

import 'community_updates_screen.dart';
import 'report_detail_screen.dart';

import '../../models/malaysia_open_data.dart';
import '../../services/malaysia_open_data_service.dart';

// ================================================================
// COMMUNITY REPORTS
//
// Allows citizens to:
// - browse reports submitted by the community
// - search reports
// - filter by category / status / priority
// - sort by newest / community activity / supports / distance
// - identify their own reports
// - support another report
// - open Community Updates
// - open full report details
//
// No worker-side functionality is changed.
// ================================================================

class CommunityReportsScreen
    extends StatefulWidget {
  const CommunityReportsScreen({
    super.key,
  });

  @override
  State<CommunityReportsScreen>
  createState() =>
      _CommunityReportsScreenState();
}

class _CommunityReportsScreenState
    extends State<CommunityReportsScreen> {
  final CommunityPriorityService
  priorityService =
  CommunityPriorityService();

  final ReportService reportService =
  ReportService();

  final MalaysiaOpenDataService
  openDataService =
  MalaysiaOpenDataService();

  final TextEditingController
  searchController =
  TextEditingController();

  // ============================================================
  // DATA
  // ============================================================

  List<CommunityPriorityReport> reports =
  [];

  final Set<String> myReportIds =
  {};

  final Set<String> busyReportIds =
  {};

  MalaysiaOpenDataSummary?
  governmentData;

  bool loadingGovernmentData =
  true;

  // ============================================================
  // STATE
  // ============================================================

  bool loading = true;

  String? errorMessage;

  Position? currentPosition;

  bool loadingLocation = false;

  // ============================================================
  // FILTERS
  // ============================================================

  String selectedCategory = 'All';

  String selectedStatus = 'All';

  String selectedPriority = 'All';

  String selectedSort = 'Newest';

  final List<String> categories = [
    'All',
    'Road Damage',
    'Street Light',
    'Drainage',
    'Public Facility',
    'Other',
  ];

  final List<String> statuses = [
    'All',
    'Pending',
    'Verified',
    'In Progress',
    'Completed',
  ];

  final List<String> priorities = [
    'All',
    'Critical',
    'High',
    'Medium',
    'Low',
  ];

  final List<String> sortOptions = [
    'Newest',
    'Community Priority',
    'Most Supported',
    'Most Updates',
    'Nearest',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    searchController.addListener(
      _refreshSearch,
    );

    _loadReports();
    _loadGovernmentData();
  }

// ============================================================
// LOAD GOVERNMENT OPEN DATA
// ============================================================

  Future<void> _loadGovernmentData() async {
    try {
      final MalaysiaOpenDataSummary result =
      await openDataService
          .getPublicTransportSummary();

      if (!mounted) {
        return;
      }

      setState(() {
        governmentData = result;
        loadingGovernmentData = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingGovernmentData = false;
      });

      // Community Reports should continue working
      // even if data.gov.my is temporarily unavailable.
    }
  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }

  void _refreshSearch() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // LOAD REPORTS
  // ============================================================

  Future<void> _loadReports({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      // ----------------------------------------------------------
      // LOAD ALL COMMUNITY REPORTS + COMMUNITY METRICS
      // ----------------------------------------------------------

      final List<CommunityPriorityReport>
      communityReports =
      await priorityService
          .getPriorityReports();

      // ----------------------------------------------------------
      // LOAD MY OWN REPORTS
      //
      // Used only to show "My Report".
      // ----------------------------------------------------------

      final List<InfrastructureReport>
      myReports =
      await reportService.getMyReports();

      if (!mounted) {
        return;
      }

      setState(() {
        reports =
            communityReports;

        myReportIds
          ..clear()
          ..addAll(
            myReports.map(
                  (
                  InfrastructureReport report,
                  ) =>
              report.id,
            ),
          );

        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;

        errorMessage =
            _cleanError(
              e,
            );
      });
    }
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> _enableLocation() async {
    if (loadingLocation) {
      return;
    }

    setState(() {
      loadingLocation = true;
    });

    try {
      final bool serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Please enable location services first.',
        );
      }

      LocationPermission permission =
      await Geolocator
          .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator
            .requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission
                  .deniedForever) {
        throw Exception(
          'Location permission is required to sort nearby reports.',
        );
      }

      final Position position =
      await Geolocator
          .getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        currentPosition =
            position;

        selectedSort =
        'Nearest';
      });

      _message(
        'Nearby reports are now sorted by distance.',
      );
    } catch (e) {
      _message(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loadingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // FILTERED REPORTS
  // ============================================================

  List<CommunityPriorityReport>
  get visibleReports {
    final String search =
    searchController.text
        .trim()
        .toLowerCase();

    List<CommunityPriorityReport> result =
    reports.where(
          (
          CommunityPriorityReport item,
          ) {
        final InfrastructureReport report =
            item.report;

        // --------------------------------------------------------
        // SEARCH
        // --------------------------------------------------------

        final bool matchesSearch =
            search.isEmpty ||
                report.title
                    .toLowerCase()
                    .contains(
                  search,
                ) ||
                report.referenceNumber
                    .toLowerCase()
                    .contains(
                  search,
                ) ||
                report.address
                    .toLowerCase()
                    .contains(
                  search,
                ) ||
                report.category
                    .toLowerCase()
                    .contains(
                  search,
                );

        if (!matchesSearch) {
          return false;
        }

        // --------------------------------------------------------
        // CATEGORY
        // --------------------------------------------------------

        if (selectedCategory != 'All' &&
            report.category
                .trim()
                .toLowerCase() !=
                selectedCategory
                    .trim()
                    .toLowerCase()) {
          return false;
        }

        // --------------------------------------------------------
        // PRIORITY
        // --------------------------------------------------------

        if (selectedPriority != 'All' &&
            report.priority
                .trim()
                .toLowerCase() !=
                selectedPriority
                    .trim()
                    .toLowerCase()) {
          return false;
        }

        // --------------------------------------------------------
        // STATUS
        // --------------------------------------------------------

        if (selectedStatus != 'All') {
          final String wanted =
          _normalizeStatus(
            selectedStatus,
          );

          final String actual =
          _normalizeStatus(
            report.status,
          );

          if (actual != wanted) {
            return false;
          }
        }

        return true;
      },
    ).toList();

    // ============================================================
    // SORT
    // ============================================================

    switch (selectedSort) {
      case 'Community Priority':
        result.sort(
              (
              CommunityPriorityReport a,
              CommunityPriorityReport b,
              ) =>
              b.score.compareTo(
                a.score,
              ),
        );

        break;

      case 'Most Supported':
        result.sort(
              (
              CommunityPriorityReport a,
              CommunityPriorityReport b,
              ) =>
              b.supportCount
                  .compareTo(
                a.supportCount,
              ),
        );

        break;

      case 'Most Updates':
        result.sort(
              (
              CommunityPriorityReport a,
              CommunityPriorityReport b,
              ) =>
              b.contributionCount
                  .compareTo(
                a.contributionCount,
              ),
        );

        break;

      case 'Nearest':
        final Position? position =
            currentPosition;

        if (position != null) {
          result.sort(
                (
                CommunityPriorityReport a,
                CommunityPriorityReport b,
                ) {
              final double? distanceA =
              _distanceKm(
                a.report,
              );

              final double? distanceB =
              _distanceKm(
                b.report,
              );

              if (distanceA == null &&
                  distanceB == null) {
                return 0;
              }

              if (distanceA == null) {
                return 1;
              }

              if (distanceB == null) {
                return -1;
              }

              return distanceA.compareTo(
                distanceB,
              );
            },
          );
        }

        break;

      case 'Newest':
      default:
        result.sort(
              (
              CommunityPriorityReport a,
              CommunityPriorityReport b,
              ) =>
              b.report.createdAt
                  .compareTo(
                a.report.createdAt,
              ),
        );

        break;
    }

    return result;
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double? _distanceKm(
      InfrastructureReport report,
      ) {
    final Position? position =
        currentPosition;

    if (position == null ||
        report.latitude == null ||
        report.longitude == null) {
      return null;
    }

    final double meters =
    Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      report.latitude!,
      report.longitude!,
    );

    return meters / 1000;
  }

  // ============================================================
  // SUPPORT
  // ============================================================

  Future<void> _toggleSupport(
      CommunityPriorityReport item,
      ) async {
    if (busyReportIds.contains(
      item.report.id,
    )) {
      return;
    }

    setState(() {
      busyReportIds.add(
        item.report.id,
      );
    });

    try {
      final bool supported =
      await priorityService
          .toggleSupport(
        item.report.id,
      );

      await _loadReports(
        showLoading: false,
      );

      _message(
        supported
            ? 'You supported this report.'
            : 'Support removed.',
      );
    } catch (e) {
      _message(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          busyReportIds.remove(
            item.report.id,
          );
        });
      }
    }
  }

  // ============================================================
  // OPEN DETAILS
  // ============================================================

  Future<void> _openDetails(
      CommunityPriorityReport item,
      ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder:
            (_) =>
            ReportDetailScreen(
              reportId:
              item.report.id,
            ),
      ),
    );

    await _loadReports(
      showLoading: false,
    );
  }

  // ============================================================
  // OPEN COMMUNITY UPDATES
  // ============================================================

  Future<void> _openUpdates(
      CommunityPriorityReport item,
      ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder:
            (_) =>
            CommunityUpdatesScreen(
              reportId:
              item.report.id,
            ),
      ),
    );

    await _loadReports(
      showLoading: false,
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
          'Community Reports',

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
                () => _loadReports(),

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
          () => _loadReports(
        showLoading: false,
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
          // ======================================================
          // PAGE INTRODUCTION
          // ======================================================

          const Text(
            'Explore reported issues',

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
            'Check existing infrastructure reports before creating a duplicate. '
                'You can support reports, verify their current condition and add updated evidence.',

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
            18,
          ),

          // =====================================
          // GOVERNMENT OPEN DATA
          // =====================================

          if (loadingGovernmentData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                14,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),

                  SizedBox(
                    width: 10,
                  ),

                  Text(
                    'Loading Malaysia Open Data...',
                    style: TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            )
          else if (governmentData != null)
            _buildGovernmentDataCard(),

          if (loadingGovernmentData ||
              governmentData != null)
            const SizedBox(
              height: 16,
            ),

          // =====================================
          // NEAR ME
          // =====================================

          // ======================================================
          // NEAR ME
          // ======================================================

          SizedBox(
            width:
            double.infinity,

            child:
            OutlinedButton.icon(
              onPressed:
              loadingLocation
                  ? null
                  : _enableLocation,

              icon:
              loadingLocation
                  ? const SizedBox(
                width:
                17,

                height:
                17,

                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                ),
              )
                  : Icon(
                currentPosition ==
                    null
                    ? Icons
                    .my_location_outlined
                    : Icons
                    .location_on,

                color:
                AppColors.primary,
              ),

              label:
              Text(
                currentPosition == null
                    ? 'Show Reports Near Me'
                    : 'Location Enabled • Sort by Distance',
              ),
            ),
          ),

          const SizedBox(
            height:
            14,
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
              'Search report, location or reference...',

              prefixIcon:
              const Icon(
                Icons.search_rounded,
              ),

              suffixIcon:
              searchController
                  .text
                  .isEmpty
                  ? null
                  : IconButton(
                onPressed:
                searchController
                    .clear,

                icon:
                const Icon(
                  Icons.clear_rounded,
                ),
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

                borderSide:
                const BorderSide(
                  color:
                  AppColors.border,
                ),
              ),

              enabledBorder:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  14,
                ),

                borderSide:
                const BorderSide(
                  color:
                  AppColors.border,
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
            14,
          ),

          // ======================================================
          // CATEGORY CHIPS
          // ======================================================

          const Text(
            'Category',

            style:
            TextStyle(
              fontSize:
              11,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            8,
          ),

          SizedBox(
            height:
            38,

            child:
            ListView.separated(
              scrollDirection:
              Axis.horizontal,

              itemCount:
              categories.length,

              separatorBuilder:
                  (_, __) =>
              const SizedBox(
                width:
                7,
              ),

              itemBuilder:
                  (
                  BuildContext context,
                  int index,
                  ) {
                final String category =
                categories[index];

                return ChoiceChip(
                  label:
                  Text(
                    category,
                  ),

                  selected:
                  selectedCategory ==
                      category,

                  onSelected:
                      (_) {
                    setState(() {
                      selectedCategory =
                          category;
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(
            height:
            14,
          ),

          // ======================================================
          // STATUS + PRIORITY
          // ======================================================

          Row(
            children: [
              Expanded(
                child:
                _DropdownFilter(
                  label:
                  'Status',

                  value:
                  selectedStatus,

                  values:
                  statuses,

                  onChanged:
                      (
                      String value,
                      ) {
                    setState(() {
                      selectedStatus =
                          value;
                    });
                  },
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                _DropdownFilter(
                  label:
                  'Priority',

                  value:
                  selectedPriority,

                  values:
                  priorities,

                  onChanged:
                      (
                      String value,
                      ) {
                    setState(() {
                      selectedPriority =
                          value;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            10,
          ),

          // ======================================================
          // SORT
          // ======================================================

          _DropdownFilter(
            label:
            'Sort',

            value:
            selectedSort,

            values:
            sortOptions,

            onChanged:
                (
                String value,
                ) async {
              if (value == 'Nearest' &&
                  currentPosition == null) {
                await _enableLocation();

                return;
              }

              setState(() {
                selectedSort =
                    value;
              });
            },
          ),

          const SizedBox(
            height:
            22,
          ),

          // ======================================================
          // RESULTS HEADER
          // ======================================================

          Row(
            children: [
              const Text(
                'Community Reports',

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
                '${visibleReports.length} found',

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

          // ======================================================
          // REPORT LIST
          // ======================================================

          if (visibleReports.isEmpty)
            _buildEmpty()
          else
            ...visibleReports.map(
              _buildReportCard,
            ),

          const SizedBox(
            height:
            25,
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
    final InfrastructureReport report =
        item.report;

    final bool isMine =
    myReportIds.contains(
      report.id,
    );

    final bool busy =
    busyReportIds.contains(
      report.id,
    );

    final double? distance =
    _distanceKm(
      report,
    );

    return Container(
      margin:
      const EdgeInsets.only(
        bottom:
        13,
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
          AppColors.border,
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Container(
                width:
                43,

                height:
                43,

                decoration:
                BoxDecoration(
                  color:
                  _categoryColor(
                    report.category,
                  ).withValues(
                    alpha:
                    0.10,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                Icon(
                  _categoryIcon(
                    report.category,
                  ),

                  color:
                  _categoryColor(
                    report.category,
                  ),

                  size:
                  22,
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
                      report.title,

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
                      report.referenceNumber,

                      style:
                      const TextStyle(
                        color:
                        AppColors.primary,

                        fontSize:
                        9,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              if (isMine)
                Container(
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
                    AppColors.primary
                        .withValues(
                      alpha:
                      0.10,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),

                  child:
                  const Text(
                    'MY REPORT',

                    style:
                    TextStyle(
                      color:
                      AppColors.primary,

                      fontSize:
                      7,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(
            height:
            12,
          ),

          // ======================================================
          // LOCATION
          // ======================================================

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,

                color:
                AppColors.textSecondary,

                size:
                15,
              ),

              const SizedBox(
                width:
                5,
              ),

              Expanded(
                child:
                Text(
                  report.address,

                  maxLines:
                  2,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,

                    fontSize:
                    9,

                    height:
                    1.3,
                  ),
                ),
              ),

              if (distance != null) ...[
                const SizedBox(
                  width:
                  7,
                ),

                Text(
                  '${distance.toStringAsFixed(1)} km',

                  style:
                  const TextStyle(
                    color:
                    AppColors.primary,

                    fontSize:
                    9,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(
            height:
            11,
          ),

          // ======================================================
          // TAGS
          // ======================================================

          Wrap(
            spacing:
            6,

            runSpacing:
            6,

            children: [
              _Tag(
                text:
                report.category,

                color:
                AppColors.primary,
              ),

              _Tag(
                text:
                report.priority
                    .toUpperCase(),

                color:
                _priorityColor(
                  report.priority,
                ),
              ),

              _Tag(
                text:
                _displayStatus(
                  report.status,
                ).toUpperCase(),

                color:
                _statusColor(
                  report.status,
                ),
              ),

              if (item.trending)
                const _Tag(
                  text:
                  'TRENDING',

                  color:
                  AppColors.warning,
                ),

              if (item.stillExistsSignal)
                const _Tag(
                  text:
                  'STILL EXISTS',

                  color:
                  AppColors.danger,
                ),
            ],
          ),

          const SizedBox(
            height:
            14,
          ),

          // ======================================================
          // COMMUNITY ACTIVITY
          // ======================================================

          Container(
            padding:
            const EdgeInsets.symmetric(
              vertical:
              10,

              horizontal:
              8,
            ),

            decoration:
            BoxDecoration(
              color:
              AppColors.background,

              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),

            child:
            Row(
              children: [
                Expanded(
                  child:
                  _CommunityMetric(
                    icon:
                    Icons
                        .thumb_up_alt_outlined,

                    value:
                    item.supportCount,

                    label:
                    'Supports',
                  ),
                ),

                Container(
                  width:
                  1,

                  height:
                  28,

                  color:
                  AppColors.border,
                ),

                Expanded(
                  child:
                  _CommunityMetric(
                    icon:
                    Icons
                        .forum_outlined,

                    value:
                    item.contributionCount,

                    label:
                    'Updates',
                  ),
                ),

                Container(
                  width:
                  1,

                  height:
                  28,

                  color:
                  AppColors.border,
                ),

                Expanded(
                  child:
                  _CommunityMetric(
                    icon:
                    Icons
                        .report_problem_outlined,

                    value:
                    item.stillExistsCount,

                    label:
                    'Still Exists',
                  ),
                ),

                Container(
                  width:
                  1,

                  height:
                  28,

                  color:
                  AppColors.border,
                ),

                Expanded(
                  child:
                  _CommunityMetric(
                    icon:
                    Icons
                        .check_circle_outline,

                    value:
                    item.looksFixedCount,

                    label:
                    'Looks Fixed',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            13,
          ),

          // ======================================================
          // PROGRESS
          // ======================================================

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
                '${report.progressPercentage}%',

                style:
                const TextStyle(
                  color:
                  AppColors.primary,

                  fontSize:
                  9,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            5,
          ),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              20,
            ),

            child:
            LinearProgressIndicator(
              value:
              (report.progressPercentage /
                  100)
                  .clamp(
                0.0,
                1.0,
              )
                  .toDouble(),

              minHeight:
              5,

              backgroundColor:
              AppColors.border,

              color:
              _statusColor(
                report.status,
              ),
            ),
          ),

          const SizedBox(
            height:
            14,
          ),

          // ======================================================
          // ACTIONS
          // ======================================================

          if (busy)
            const Center(
              child:
              SizedBox(
                width:
                22,

                height:
                22,

                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                ),
              ),
            )
          else
            Row(
              children: [
                // ------------------------------------------------
                // SUPPORT
                // ------------------------------------------------

                Expanded(
                  child:
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
                      15,
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
                      Icons
                          .thumb_up_alt_outlined,
                      size:
                      15,
                    ),

                    label:
                    const Text(
                      'Support',
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  7,
                ),

                // ------------------------------------------------
                // COMMUNITY UPDATES
                // ------------------------------------------------

                Expanded(
                  child:
                  OutlinedButton.icon(
                    onPressed:
                        () =>
                        _openUpdates(
                          item,
                        ),

                    icon:
                    const Icon(
                      Icons
                          .forum_outlined,

                      size:
                      15,
                    ),

                    label:
                    const Text(
                      'Updates',
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(
            height:
            4,
          ),

          SizedBox(
            width:
            double.infinity,

            child:
            TextButton.icon(
              onPressed:
                  () =>
                  _openDetails(
                    item,
                  ),

              icon:
              const Icon(
                Icons
                    .visibility_outlined,

                size:
                16,
              ),

              label:
              const Text(
                'View Full Report',
              ),
            ),
          ),
        ],
      ),
    );
  }



  // ============================================================
// GOVERNMENT OPEN DATA CARD
// ============================================================

  Widget _buildGovernmentDataCard() {
    final MalaysiaOpenDataSummary data =
    governmentData!;

    final latest =
        data.latest;

    final double? change =
        data.dailyChangePercentage;

    final bool increasing =
        change != null && change >= 0;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(
        15,
      ),

      decoration: BoxDecoration(
        color: AppColors.surface,

        borderRadius: BorderRadius.circular(
          15,
        ),

        border: Border.all(
          color: AppColors.primary,
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // =====================================
          // HEADER
          // =====================================

          Row(
            children: [
              Container(
                width: 40,
                height: 40,

                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(
                    alpha: 0.10,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child: const Icon(
                  Icons.account_balance_outlined,

                  color: AppColors.primary,

                  size: 21,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Malaysia Open Data',

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height: 2,
                    ),

                    Text(
                      'Official public transport data',

                      style: TextStyle(
                        color:
                        AppColors.textSecondary,

                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),

                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(
                    alpha: 0.10,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                ),

                child: const Text(
                  'GOV DATA',

                  style: TextStyle(
                    color: AppColors.primary,

                    fontSize: 7,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          // =====================================
          // LATEST DATE
          // =====================================

          Text(
            'Latest available data • '
                '${openDataService.formatDate(latest.date)}',

            style: const TextStyle(
              color: AppColors.textSecondary,

              fontSize: 8,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          // =====================================
          // TOTAL PUBLIC TRANSPORT TRIPS
          // =====================================

          Text(
            openDataService.formatNumber(
              latest.totalTrips,
            ),

            style: const TextStyle(
              color: AppColors.primary,

              fontSize: 25,

              fontWeight: FontWeight.bold,
            ),
          ),

          const Text(
            'public transport trips',

            style: TextStyle(
              color: AppColors.textSecondary,

              fontSize: 8,
            ),
          ),

          if (change != null) ...[
            const SizedBox(
              height: 6,
            ),

            Row(
              children: [
                Icon(
                  increasing
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,

                  size: 15,

                  color: increasing
                      ? AppColors.success
                      : AppColors.warning,
                ),

                const SizedBox(
                  width: 4,
                ),

                Text(
                  '${change >= 0 ? '+' : ''}'
                      '${change.toStringAsFixed(1)}% '
                      'vs previous available day',

                  style: TextStyle(
                    color: increasing
                        ? AppColors.success
                        : AppColors.warning,

                    fontSize: 8,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(
            height: 14,
          ),

          // =====================================
          // BUS / RAIL
          // =====================================

          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                  const EdgeInsets.all(
                    10,
                  ),

                  decoration: BoxDecoration(
                    color: AppColors.background,

                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),

                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .directions_bus_outlined,

                        color:
                        AppColors.primary,

                        size: 18,
                      ),

                      const SizedBox(
                        width: 7,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            Text(
                              openDataService
                                  .formatNumber(
                                latest.busTotal,
                              ),

                              style:
                              const TextStyle(
                                fontSize: 11,

                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            const Text(
                              'Bus Trips',

                              style:
                              TextStyle(
                                color: AppColors
                                    .textSecondary,

                                fontSize: 7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: Container(
                  padding:
                  const EdgeInsets.all(
                    10,
                  ),

                  decoration: BoxDecoration(
                    color: AppColors.background,

                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),

                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons.train_outlined,

                        color:
                        AppColors.primary,

                        size: 18,
                      ),

                      const SizedBox(
                        width: 7,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            Text(
                              openDataService
                                  .formatNumber(
                                latest.railTotal,
                              ),

                              style:
                              const TextStyle(
                                fontSize: 11,

                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            const Text(
                              'Rail Trips',

                              style:
                              TextStyle(
                                color: AppColors
                                    .textSecondary,

                                fontSize: 7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          // =====================================
          // EXPLANATION
          // =====================================

          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(
              10,
            ),

            decoration: BoxDecoration(
              color: AppColors.background,

              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),

            child: const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.info_outline,

                  color: AppColors.primary,

                  size: 16,
                ),

                SizedBox(
                  width: 7,
                ),

                Expanded(
                  child: Text(
                    'Public transport usage provides additional context when reviewing infrastructure issues that may affect mobility and transport access.',

                    style: TextStyle(
                      color:
                      AppColors.textSecondary,

                      fontSize: 8.5,

                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Source: data.gov.my • Values represent trips, not unique passengers.',

            style: TextStyle(
              color: AppColors.textSecondary,

              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }
  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return Container(
      width:
      double.infinity,

      padding:
      const EdgeInsets.symmetric(
        horizontal:
        20,

        vertical:
        38,
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
            Icons
                .travel_explore_outlined,

            color:
            AppColors.textSecondary,

            size:
            45,
          ),

          SizedBox(
            height:
            11,
          ),

          Text(
            'No matching reports',

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
            'Try changing your search or filters.',

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
              'Unable to load community reports',

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
                10,
              ),
            ),

            const SizedBox(
              height:
              16,
            ),

            FilledButton.icon(
              onPressed:
                  () => _loadReports(),

              icon:
              const Icon(
                Icons.refresh,
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
  // DISPLAY HELPERS
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

  String _displayStatus(
      String status,
      ) {
    switch (_normalizeStatus(
      status,
    )) {
      case 'verified':
        return 'Verified';

      case 'in_progress':
        return 'In Progress';

      case 'completed':
        return 'Completed';

      case 'rejected':
        return 'Rejected';

      case 'pending':
      default:
        return 'Pending';
    }
  }

  Color _statusColor(
      String status,
      ) {
    switch (_normalizeStatus(
      status,
    )) {
      case 'completed':
        return AppColors.success;

      case 'rejected':
        return AppColors.danger;

      case 'pending':
        return AppColors.warning;

      case 'verified':
      case 'in_progress':
      default:
        return AppColors.primary;
    }
  }

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

  IconData _categoryIcon(
      String category,
      ) {
    switch (
    category.trim().toLowerCase()) {
      case 'road damage':
        return Icons
            .add_road_outlined;

      case 'street light':
        return Icons
            .lightbulb_outline;

      case 'drainage':
        return Icons
            .water_drop_outlined;

      case 'public facility':
        return Icons
            .apartment_outlined;

      default:
        return Icons
            .report_problem_outlined;
    }
  }

  Color _categoryColor(
      String category,
      ) {
    switch (
    category.trim().toLowerCase()) {
      case 'road damage':
        return AppColors.danger;

      case 'street light':
        return AppColors.warning;

      case 'drainage':
        return AppColors.primary;

      case 'public facility':
        return AppColors.success;

      default:
        return AppColors.primary;
    }
  }

  String _cleanError(
      Object error,
      ) {
    return error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    )
        .trim();
  }

  void _message(
      String message,
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
          message,
        ),
      ),
    );
  }
}

// ================================================================
// DROPDOWN FILTER
// ================================================================

class _DropdownFilter
    extends StatelessWidget {
  final String label;

  final String value;

  final List<String> values;

  final ValueChanged<String> onChanged;

  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        11,
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
          value,

          isExpanded:
          true,

          items:
          values.map(
                (
                String item,
                ) {
              return DropdownMenuItem<String>(
                value:
                item,

                child:
                Text(
                  '$label: $item',

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    fontSize:
                    10,
                  ),
                ),
              );
            },
          ).toList(),

          onChanged:
              (
              String? newValue,
              ) {
            if (newValue != null) {
              onChanged(
                newValue,
              );
            }
          },
        ),
      ),
    );
  }
}

// ================================================================
// COMMUNITY METRIC
// ================================================================

class _CommunityMetric
    extends StatelessWidget {
  final IconData icon;

  final int value;

  final String label;

  const _CommunityMetric({
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

          color:
          AppColors.primary,

          size:
          15,
        ),

        const SizedBox(
          height:
          3,
        ),

        Text(
          '$value',

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
          2,
        ),

        Text(
          label,

          maxLines:
          1,

          overflow:
          TextOverflow.ellipsis,

          style:
          const TextStyle(
            color:
            AppColors.textSecondary,

            fontSize:
            6.5,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// TAG
// ================================================================

class _Tag
    extends StatelessWidget {
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
        color.withValues(
          alpha:
          0.10,
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