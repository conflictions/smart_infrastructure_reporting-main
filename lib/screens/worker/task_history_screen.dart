import 'package:flutter/material.dart';
import '../../models/infrastructure_report.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

class TaskHistoryScreen extends StatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();

  bool _loading = true;
  List<InfrastructureReport> _allTasks = [];

  @override
  void initState() {
    super.initState();
    _fetchTaskHistory();
  }

  Future<void> _fetchTaskHistory() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final reports = await _reportService.getWorkerReports(user.id);
        setState(() {
          _allTasks = reports;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Task History'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _allTasks.isEmpty
          ? const Center(
        child: Text('No historical tasks found.', style: TextStyle(color: AppColors.textSecondary)),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _allTasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = _allTasks[index];
          final bool isCompleted = task.status.toLowerCase() == 'completed' || task.progressPercentage >= 100;

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: Icon(
                isCompleted ? Icons.check_circle : Icons.build_circle_outlined,
                color: isCompleted ? Colors.greenAccent : AppColors.primary,
              ),
              title: Text(
                task.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                task.address,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.status.toUpperCase(),
                  style: TextStyle(
                    color: isCompleted ? Colors.greenAccent : Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}