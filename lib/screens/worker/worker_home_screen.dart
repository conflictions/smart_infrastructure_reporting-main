import 'package:flutter/material.dart';

import '../../models/infrastructure_report.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import 'worker_manage_report_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToTasks;

  const WorkerHomeScreen({
    super.key,
    required this.onNavigateToTasks,
  });

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final AuthService authService = AuthService();
  final ReportService reportService = ReportService();

  List<InfrastructureReport> tasks = [];
  bool loading = true;
  String workerName = 'Worker';

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      if (mounted) setState(() => loading = true);

      final profile = await authService.getCurrentProfile();
      final String? currentWorkerId = reportService.currentUser?.id;

      List<InfrastructureReport> result = [];
      if (currentWorkerId != null && currentWorkerId.isNotEmpty) {
        // 使用 Worker 专属 API 加载工单
        result = await reportService.getWorkerReports(currentWorkerId);
      } else {
        result = await reportService.getAllReports();
      }

      if (!mounted) return;

      setState(() {
        if (profile != null && profile.fullName.trim().isNotEmpty) {
          workerName = profile.fullName.trim();
        }
        tasks = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  // 接单逻辑
  Future<void> _handleClaimTask(InfrastructureReport report) async {
    final String? currentWorkerId = reportService.currentUser?.id;
    if (currentWorkerId == null) return;

    try {
      await reportService.claimReport(
        reportId: report.id,
        workerId: currentWorkerId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task claimed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        await loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim task: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  String get greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  String get initials {
    final List<String> parts = workerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'W';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  // 统计数值计算
  int get totalCount => tasks.length;
  int get pendingCount =>
      tasks.where((t) => t.status.toLowerCase() == 'pending').length;
  int get activeCount => tasks
      .where((t) =>
  t.status.toLowerCase() == 'in_progress' ||
      t.status.toLowerCase() == 'verified')
      .length;
  int get completedCount =>
      tasks.where((t) => t.status.toLowerCase() == 'completed').length;

  double get completionRate =>
      totalCount == 0 ? 0.0 : (completedCount / totalCount);

  Color taskStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  String taskStatusText(String status) {
    switch (status.toLowerCase()) {
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

  String categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'road damage':
        return '🛣️';
      case 'street light':
        return '💡';
      case 'drainage':
        return '🌊';
      case 'public facility':
        return '🏗️';
      default:
        return '🛠️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadDashboard,
          child: loading
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 300),
              Center(child: CircularProgressIndicator()),
            ],
          )
              : ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ==========================================
              // 1. HEADER
              // ==========================================
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryDark,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          workerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      tooltip: 'Refresh',
                      onPressed: loadDashboard,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ==========================================
              // 2. WORKER IMPACT BANNER
              // ==========================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF083340),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primaryDark),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 95,
                      height: 95,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 85,
                            height: 85,
                            child: CircularProgressIndicator(
                              value: completionRate,
                              strokeWidth: 8,
                              backgroundColor: AppColors.border,
                              color: AppColors.primary,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(completionRate * 100).toInt()}%',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'DONE',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 7,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 17),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Task Resolution Rate',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Keeping municipal facilities safe',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 13),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _SmallBadge(
                                icon: Icons.assignment_turned_in_outlined,
                                text:
                                '$completedCount / $totalCount Tasks',
                                color: AppColors.success,
                              ),
                              const _SmallBadge(
                                icon: Icons.verified_user_outlined,
                                text: 'Staff Verified',
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ==========================================
              // 3. QUICK ACTIONS
              // ==========================================
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      emoji: '📋',
                      title: 'View Work Tasks',
                      subtitle: '$totalCount total assigned',
                      onTap: widget.onNavigateToTasks,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionCard(
                      emoji: '⚡',
                      title: 'Pending Tasks',
                      subtitle: '$pendingCount need action',
                      onTap: widget.onNavigateToTasks,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ==========================================
              // 4. WORK CONTRIBUTION
              // ==========================================
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Work Summary',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Row(
                      children: [
                        Expanded(
                          child: _ContributionItem(
                            icon: '📋',
                            value: '$totalCount',
                            label: 'Total Tasks',
                          ),
                        ),
                        Container(
                          height: 45,
                          width: 1,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _ContributionItem(
                            icon: '⏳',
                            value: '$activeCount',
                            label: 'In Progress',
                          ),
                        ),
                        Container(
                          height: 45,
                          width: 1,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _ContributionItem(
                            icon: '✅',
                            value: '$completedCount',
                            label: 'Completed',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatistic(
                            title: 'Pending',
                            value: pendingCount,
                            color: AppColors.warning,
                          ),
                        ),
                        Expanded(
                          child: _MiniStatistic(
                            title: 'Active',
                            value: activeCount,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: _MiniStatistic(
                            title: 'Completed',
                            value: completedCount,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ==========================================
              // 5. RECENT ASSIGNED TASKS
              // ==========================================
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Assigned Tasks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToTasks,
                    child: const Text(
                      'See all →',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),

              if (tasks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 35),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 40,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No assigned tasks',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'You have cleared all maintenance tasks.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...tasks.take(4).map((report) {
                  final bool isUnassigned =
                      report.assignedWorkerId == null ||
                          report.assignedWorkerId!.isEmpty;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecentTaskCard(
                      report: report,
                      icon: categoryIcon(report.category),
                      statusText: taskStatusText(report.status),
                      statusColor: taskStatusColor(report.status),
                      isUnassigned: isUnassigned,
                      onClaim: () => _handleClaimTask(report),
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkerManageReportScreen(
                              report: report,
                            ),
                          ),
                        );
                        if (changed == true) {
                          await loadDashboard();
                        }
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// HELPER COMPONENTS
// =================================================================

class _QuickActionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.primaryDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContributionItem extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _ContributionItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 8,
          ),
        ),
      ],
    );
  }
}

class _MiniStatistic extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _MiniStatistic({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 8,
          ),
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SmallBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTaskCard extends StatelessWidget {
  final InfrastructureReport report;
  final String icon;
  final String statusText;
  final Color statusColor;
  final bool isUnassigned;
  final VoidCallback onClaim;
  final VoidCallback onTap;

  const _RecentTaskCard({
    required this.report,
    required this.icon,
    required this.statusText,
    required this.statusColor,
    required this.isUnassigned,
    required this.onClaim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 ${report.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isUnassigned)
                ElevatedButton(
                  onPressed: onClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Claim',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

}