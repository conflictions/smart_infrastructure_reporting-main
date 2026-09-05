import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../models/infrastructure_report.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../worker/task_history_screen.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();

  bool _loading = true;
  int _claimedCount = 0;
  int _completedCount = 0;
  List<InfrastructureReport> _recentTasks = [];
  String _fullName = ''; // 存储 Worker 全名

  @override
  void initState() {
    super.initState();
    _loadWorkerData();
  }

  Future<void> _loadWorkerData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final reports = await _reportService.getWorkerReports(user.id);

        // 1. 获取 profile 对象
        final profile = await _authService.getCurrentProfile();

        setState(() {
          // 2. 从 profile 对象中读取 fullName 属性（使用 dynamic 访问可避免类型报错）
          _fullName = (profile as dynamic)?.fullName?.toString() ?? 'Worker Name';

          _claimedCount = reports.length;
          _completedCount = reports
              .where((r) => r.status == 'completed' || r.progressPercentage >= 100)
              .length;
          _recentTasks = reports.take(2).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }
  // 弹出 Sign Out 确认对话框
  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Sign Out?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: const Text(
            'Are you sure you want to sign out of your SmartCity Worker account?',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.tealAccent, fontSize: 14)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 1. Edit Profile 弹窗（已同步更新至 Supabase）
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _fullName);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131B2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    enabled: !isSaving,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                    ),
                  ),
                  if (isSaving) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: AppColors.primary),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: isSaving
                      ? null
                      : () async {
                    final newName = nameController.text.trim();
                    final user = _authService.currentUser;

                    if (newName.isNotEmpty && user != null) {
                      setDialogState(() => isSaving = true);
                      try {
                        // 直接调用 Supabase 更新 profiles 数据表中的 full_name
                        await Supabase.instance.client
                            .from('profiles')
                            .update({'full_name': newName})
                            .eq('id', user.id);

                        if (mounted) {
                          setState(() => _fullName = newName);
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated in Supabase!')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update Supabase: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

// 2. Security & Password 弹窗（含长度提示 + 二次确认框 + Supabase 同步）
  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131B2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Security & Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    enabled: !isSaving,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      helperText: 'Must be at least 6 characters', // 显式给用户的格式提示
                      helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    enabled: !isSaving,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                    ),
                  ),
                  if (isSaving) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: isSaving
                      ? null
                      : () async {
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword = confirmPasswordController.text.trim();

                    // 1. 基础前端输入校验
                    if (newPassword.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password must be at least 6 characters long.')),
                      );
                      return;
                    }

                    if (newPassword != confirmPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match.')),
                      );
                      return;
                    }

                    // 2. 弹出二次确认框
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (confirmContext) => AlertDialog(
                        backgroundColor: const Color(0xFF131B2E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Confirm Password Change', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        content: const Text('Are you sure you want to update your password?', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmContext, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () => Navigator.pop(confirmContext, true),
                            child: const Text('Yes, Update', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    // 用户点击了 Confirm 按钮才开始提交 Supabase
                    if (confirm == true) {
                      setDialogState(() => isSaving = true);
                      try {
                        // 3. 调用 Supabase API 修改当前账号密码
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPassword),
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated successfully!')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update password: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Update', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

// 3. Help & Support 弹窗
  void _showHelpSupportDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Help & Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SmartCity Operations Hotline:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 4),
              Text('+60 12-345 6789', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('Support Email:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              SizedBox(height: 4),
              Text('support@smartcity.gov.my', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    // 安全防空与首字母提取
    final String name = _fullName.trim().isNotEmpty ? _fullName.trim() : 'Worker Name';
    final String email = user?.email ?? 'worker@gmail.com';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 用户基本信息卡片
            _buildHeaderCard(name, email, initial),
            const SizedBox(height: 16),

            // 2. Performance & Impact 统计卡片
            _buildPerformanceCard(),
            const SizedBox(height: 16),

            // 3. 核心统计小方块
            _buildStatRow(),
            const SizedBox(height: 20),

            // 4. Worker Achievements 勋章区
            const Text(
              'Achievements',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildAchievementsRow(),
            const SizedBox(height: 20),

            // 5. Recent Activity 最近工作记录
            if (_recentTasks.isNotEmpty) ...[
              const Text(
                'Recent Activity',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildRecentActivity(),
              const SizedBox(height: 20),
            ],

            // 6. 菜单列表
            _buildMenuList(),
            const SizedBox(height: 24),

            // 7. 红色 Sign Out 按钮
            _buildSignOutButton(),
            const SizedBox(height: 12),

            // 底部版本信息
            const Center(
              child: Text(
                'Worker Account • SmartCity System 2026',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String name, String email, String initial) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              initial,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTag('Certified Worker', Colors.amber),
                    const SizedBox(width: 6),
                    _buildTag('Field Operations', AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPerformanceCard() {
    double completionRate = _claimedCount == 0 ? 0 : (_completedCount / _claimedCount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: completionRate,
                      strokeWidth: 6,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '${(completionRate * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Task Efficiency Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Completed $_completedCount out of $_claimedCount claimed tasks.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow() {
    return Row(
      children: [
        _buildStatBox('Claimed', '$_claimedCount', Icons.assignment_outlined),
        const SizedBox(width: 10),
        _buildStatBox('Done', '$_completedCount', Icons.check_circle_outline),
        const SizedBox(width: 10),
        _buildStatBox('Rating', '4.9 ★', Icons.star_outline),
      ],
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildBadge('First Task', Icons.handshake, Colors.cyan, true),
          const SizedBox(width: 10),
          _buildBadge('Problem Solver', Icons.build, Colors.orange, _completedCount >= 5),
          const SizedBox(width: 10),
          _buildBadge('Fast Responder', Icons.bolt, Colors.purple, _completedCount >= 10),
        ],
      ),
    );
  }

  Widget _buildBadge(String title, IconData icon, Color color, bool unlocked) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: unlocked ? color.withOpacity(0.6) : AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: unlocked ? color : Colors.grey, size: 28),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: unlocked ? Colors.white : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: _recentTasks.map((task) {
          return ListTile(
            leading: const Icon(Icons.build_circle_outlined, color: AppColors.primary),
            title: Text(task.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(task.address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            trailing: Text(task.status.toUpperCase(), style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // 1. Edit Profile: 弹出编辑姓名对话框（更新后自动刷新 Profile 页面）
          _buildMenuItem(
            Icons.edit_outlined,
            'Edit Profile',
            onTap: _showEditProfileDialog,
          ),
          const Divider(height: 1, color: AppColors.border),

          // 2. Security & Password: 弹出修改密码对话框
          _buildMenuItem(
            Icons.shield_outlined,
            'Security & Password',
            onTap: _showChangePasswordDialog,
          ),
          const Divider(height: 1, color: AppColors.border),
// 3. Task History: 跳转到任务历史页面
          _buildMenuItem(
            Icons.history,
            'Task History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskHistoryScreen()),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.border),

          // 4. Help & Support: 弹出支持与联系方式
          _buildMenuItem(
            Icons.help_outline,
            'Help & Support',
            onTap: _showHelpSupportDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFF5252)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _showSignOutDialog,
        icon: const Icon(Icons.logout, color: Color(0xFFFF5252)),
        label: const Text(
          'Sign Out',
          style: TextStyle(color: Color(0xFFFF5252), fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}