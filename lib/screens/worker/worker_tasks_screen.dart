import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/infrastructure_report.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import 'worker_manage_report_screen.dart';

enum DistanceFilter { all, km3, km5, km10 }

class WorkerTasksScreen extends StatefulWidget {
  final bool isTab;

  const WorkerTasksScreen({
    super.key,
    this.isTab = true,
  });

  @override
  State<WorkerTasksScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerTasksScreen>
    with SingleTickerProviderStateMixin {
  final ReportService reportService = ReportService();
  final AuthService authService = AuthService();

  late TabController _tabController;
  List<InfrastructureReport> reports = [];
  bool loading = true;

  // 定位与筛选状态
  Position? currentPosition;
  bool loadingLocation = false;
  DistanceFilter selectedFilter = DistanceFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> initData() async {
    await fetchUserLocation();
    await loadReports();
  }

  Future<void> fetchUserLocation() async {
    if (mounted) setState(() => loadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showMessage('GPS service is disabled. Defaulting to time order.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showMessage('Location permission denied. Sorting by creation time.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        showMessage('Location permission permanently denied.');
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() => currentPosition = pos);
      }
    } catch (e) {
      showMessage('Unable to fetch GPS location.');
    } finally {
      if (mounted) setState(() => loadingLocation = false);
    }
  }

  Future<void> loadReports() async {
    try {
      if (mounted) setState(() => loading = true);

      final String? currentWorkerId = reportService.currentUser?.id;

      List<InfrastructureReport> result = [];
      if (currentWorkerId != null && currentWorkerId.isNotEmpty) {
        result = await reportService.getWorkerReports(currentWorkerId);
      } else {
        result = await reportService.getAllReports();
      }

      if (!mounted) return;

      setState(() {
        reports = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> handleClaimTask(InfrastructureReport report) async {
    final String? currentWorkerId = reportService.currentUser?.id;
    if (currentWorkerId == null) return;

    try {
      await reportService.claimReport(
        reportId: report.id,
        workerId: currentWorkerId,
      );
      if (mounted) {
        showMessage('Task claimed successfully!');
        await loadReports();
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          'Failed to claim task: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  double? _calculateDistance(double? taskLat, double? taskLng) {
    if (currentPosition == null || taskLat == null || taskLng == null) {
      return null;
    }
    double distanceInMeters = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      taskLat,
      taskLng,
    );
    return distanceInMeters / 1000.0;
  }

  List<InfrastructureReport> _processTasks(List<InfrastructureReport> inputTasks) {
    List<InfrastructureReport> filtered = inputTasks.where((task) {
      double? dist = _calculateDistance(task.latitude, task.longitude);
      if (dist == null) return true;

      switch (selectedFilter) {
        case DistanceFilter.km3:
          return dist <= 3.0;
        case DistanceFilter.km5:
          return dist <= 5.0;
        case DistanceFilter.km10:
          return dist <= 10.0;
        case DistanceFilter.all:
        default:
          return true;
      }
    }).toList();

    if (currentPosition != null) {
      filtered.sort((a, b) {
        double distA = _calculateDistance(a.latitude, a.longitude) ?? 999999;
        double distB = _calculateDistance(b.latitude, b.longitude) ?? 999999;
        return distA.compareTo(distB);
      });
    }

    return filtered;
  }

  List<InfrastructureReport> get availableTasks {
    final raw = reports.where((r) =>
    (r.assignedWorkerId == null || r.assignedWorkerId!.isEmpty) &&
        r.status != 'completed' &&
        r.progressPercentage < 100
    ).toList();
    return _processTasks(raw);
  }

  List<InfrastructureReport> get myClaimedTasks {
    final String? currentWorkerId = reportService.currentUser?.id;
    if (currentWorkerId == null) return [];
    final raw = reports.where((r) =>
    r.assignedWorkerId == currentWorkerId &&
        r.status != 'completed' &&
        r.progressPercentage < 100
    ).toList();
    return _processTasks(raw);
  }

  List<InfrastructureReport> get completedTasks {
    final raw = reports.where((r) =>
    r.status == 'completed' || r.progressPercentage >= 100
    ).toList();
    return _processTasks(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
        leading: widget.isTab && !Navigator.canPop(context)
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Worker Tasks'),
        actions: [
          IconButton(
            onPressed: () async {
              await fetchUserLocation();
              await loadReports();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Available (${availableTasks.length})'),
            Tab(text: 'My Claimed (${myClaimedTasks.length})'),
            Tab(text: 'Completed (${completedTasks.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: loading
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : RefreshIndicator(
              onRefresh: () async {
                await fetchUserLocation();
                await loadReports();
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(
                    taskList: availableTasks,
                    emptyText: 'No available tasks in this radius.',
                    isClaimable: true,
                  ),
                  _buildTaskList(
                    taskList: myClaimedTasks,
                    emptyText: 'No active claimed tasks.',
                    isClaimable: false,
                  ),
                  _buildTaskList(
                    taskList: completedTasks,
                    emptyText: 'No completed tasks found.',
                    isClaimable: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('All Distance', DistanceFilter.all),
                  const SizedBox(width: 8),
                  _buildChip('< 3 km', DistanceFilter.km3),
                  const SizedBox(width: 8),
                  _buildChip('< 5 km', DistanceFilter.km5),
                  const SizedBox(width: 8),
                  _buildChip('< 10 km', DistanceFilter.km10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, DistanceFilter filter) {
    final isSelected = selectedFilter == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      onSelected: (selected) {
        if (selected) {
          setState(() => selectedFilter = filter);
        }
      },
    );
  }

  Widget _buildTaskList({
    required List<InfrastructureReport> taskList,
    required String emptyText,
    required bool isClaimable,
  }) {
    if (taskList.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Text(
              emptyText,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: taskList.length,
      itemBuilder: (context, index) {
        final report = taskList[index];
        final double? dist = _calculateDistance(report.latitude, report.longitude);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _WorkerReportCard(
            report: report,
            distanceInKm: dist,
            isUnassigned: isClaimable,
            onClaim: () => handleClaimTask(report),
            onManage: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerManageReportScreen(
                    report: report,
                  ),
                ),
              );

              if (changed == true) {
                await loadReports();
              }
            },
          ),
        );
      },
    );
  }
}

class _WorkerReportCard extends StatelessWidget {
  final InfrastructureReport report;
  final double? distanceInKm;
  final bool isUnassigned;
  final VoidCallback onClaim;
  final VoidCallback onManage;

  const _WorkerReportCard({
    required this.report,
    this.distanceInKm,
    required this.isUnassigned,
    required this.onClaim,
    required this.onManage,
  });

  Color get statusColor {
    switch (report.status) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  String get statusText {
    switch (report.status) {
      case 'verified':
        return 'VERIFIED';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'completed':
        return 'COMPLETED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'PENDING';
    }
  }

  // 快捷一键拉起地图导航
  Future<void> _navigateToSite(BuildContext context) async {
    if (report.latitude == null || report.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid GPS coordinates for this site.')),
      );
      return;
    }

    final double targetLat = report.latitude!;
    final double targetLng = report.longitude!;

    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$targetLat,$targetLng&travelmode=driving',
    );
    final Uri appleMapsUri = Uri.parse(
      'https://maps.apple.com/?daddr=$targetLat,$targetLng',
    );

    final Uri mapUri = Platform.isIOS ? appleMapsUri : googleMapsUri;

    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map application.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching map: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                report.referenceNumber,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                ),
              ),
              if (distanceInKm != null)
                Row(
                  children: [
                    const Icon(Icons.near_me, size: 12, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      '${distanceInKm!.toStringAsFixed(1)} km away',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '📍 ${report.address}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Category: ${report.category}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: report.progressPercentage / 100,
                  minHeight: 5,
                  backgroundColor: AppColors.border,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${report.progressPercentage}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 底部操作按钮区域（一键导航 + 领单/管理）
          Row(
            children: [
              // 导航按钮
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _navigateToSite(context),
                icon: const Icon(Icons.navigation_outlined, size: 16, color: AppColors.primary),
                label: const Text(
                  'Navigate',
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),

              // 主操作按钮（Claim Task 或 Manage Report）
              Expanded(
                child: isUnassigned
                    ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                  ),
                  onPressed: onClaim,
                  icon: const Icon(Icons.handshake_outlined, size: 16),
                  label: const Text('Claim Task', style: TextStyle(fontSize: 12)),
                )
                    : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                  ),
                  onPressed: onManage,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Manage Report', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}