import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class AllReportsScreen extends StatefulWidget {
  const AllReportsScreen({super.key});

  @override
  State<AllReportsScreen> createState() => _AllReportsScreenState();
}

class _AllReportsScreenState extends State<AllReportsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _workers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 1. 获取所有报告
      final reportResponse = await Supabase.instance.client
          .from('reports')
          .select()
          .order('created_at', ascending: false);

      // 2. 获取所有 Worker 列表
      final workerResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .ilike('role', 'worker');

      setState(() {
        _reports = List<Map<String, dynamic>>.from(reportResponse);
        _workers = List<Map<String, dynamic>>.from(workerResponse);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reports: $e')),
        );
      }
    }
  }

  // 指派 Worker 弹窗
  void _showAssignWorkerDialog(Map<String, dynamic> report) {
    String? selectedWorkerId = report['assigned_worker_id']?.toString();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131B2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Assign Worker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report: ${report['title'] ?? 'Untitled'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1B263B),
                    value: selectedWorkerId,
                    hint: const Text('Select a Worker', style: TextStyle(color: Colors.white54)),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                    ),
                    items: _workers.map((worker) {
                      return DropdownMenuItem<String>(
                        value: worker['id'].toString(),
                        child: Text(worker['full_name'] ?? 'Worker', style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedWorkerId = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: selectedWorkerId == null
                      ? null
                      : () async {
                    try {
                      await Supabase.instance.client
                          .from('reports')
                          .update({
                        'assigned_worker_id': selectedWorkerId,
                        'status': 'in_progress', // 指派后自动切换状态
                      })
                          .eq('id', report['id']);

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Worker assigned successfully!')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to assign worker: $e')),
                      );
                    }
                  },
                  child: const Text('Assign', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 过滤不同分类的数据列表
    final unassignedReports = _reports.where((r) => r['assigned_worker_id'] == null && r['status'] != 'completed').toList();
    final inProgressReports = _reports.where((r) => r['assigned_worker_id'] != null && r['status'] != 'completed').toList();
    final completedReports = _reports.where((r) => r['status'] == 'completed').toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('All System Reports'),
          backgroundColor: AppColors.surface,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Unassigned (${unassignedReports.length})'),
              Tab(text: 'In Progress (${inProgressReports.length})'),
              Tab(text: 'Completed (${completedReports.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
          children: [
            _buildReportList(unassignedReports, showAssignButton: true),
            _buildReportList(inProgressReports, showAssignButton: true),
            _buildReportList(completedReports, showAssignButton: false),
          ],
        ),
      ),
    );
  }

  // 渲染单条 List 布局的组件
  Widget _buildReportList(List<Map<String, dynamic>> reports, {required bool showAssignButton}) {
    if (reports.isEmpty) {
      return const Center(
        child: Text('No reports in this tab.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = reports[index];
        final String status = (report['status'] ?? 'pending').toString();
        final bool isCompleted = status.toLowerCase() == 'completed';

        // 匹配已指派的 Worker 名字
        final assignedWorker = _workers.firstWhere(
              (w) => w['id'].toString() == report['assigned_worker_id']?.toString(),
          orElse: () => {},
        );
        final String workerName = assignedWorker['full_name'] ?? 'Unassigned';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      report['title'] ?? 'Untitled Report',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: isCompleted ? Colors.greenAccent : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                report['address'] ?? report['description'] ?? 'No location specified',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 14, color: Colors.tealAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Worker: $workerName',
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  if (showAssignButton)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.white),
                      label: Text(
                        report['assigned_worker_id'] == null ? 'Assign' : 'Reassign',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      onPressed: () => _showAssignWorkerDialog(report),
                    ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}