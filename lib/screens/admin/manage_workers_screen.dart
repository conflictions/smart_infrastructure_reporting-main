import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class ManageWorkersScreen extends StatefulWidget {
  const ManageWorkersScreen({super.key});

  @override
  State<ManageWorkersScreen> createState() => _ManageWorkersScreenState();
}

class _ManageWorkersScreenState extends State<ManageWorkersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _workers = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  // 获取所有 worker 列表
  Future<void> _fetchWorkers() async {
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .ilike('role', 'worker')
          .order('created_at', ascending: false);

      setState(() {
        _workers = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load workers: $e')),
        );
      }
    }
  }

  // 弹出 Create Worker 模态框
  void _showCreateWorkerDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool creating = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF131B2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Create New Worker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creating ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: creating
                      ? null
                      : () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final phone = phoneController.text.trim();
                    final password = passwordController.text.trim();

                    if (email.isEmpty || password.isEmpty || name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in required fields.')),
                      );
                      return;
                    }

                    setDialogState(() => creating = true);

                    try {
                      // 1. 在 Supabase Auth 中创建新用户
                      final authResponse = await Supabase.instance.client.auth.signUp(
                        email: email,
                        password: password,
                        data: {
                          'full_name': name,
                          'phone': phone,
                        },
                      );

                      final newUser = authResponse.user;

                      if (newUser != null) {
                        // 2. 将新用户的 role 在 profiles 表更新为 worker
                        await Supabase.instance.client.from('profiles').upsert({
                          'id': newUser.id,
                          'email': email,
                          'full_name': name,
                          'phone': phone,
                          'role': 'worker',
                        });

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          _fetchWorkers(); // 刷新数据
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Worker created successfully!')),
                          );
                        }
                      }
                    } catch (e) {
                      setDialogState(() => creating = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Create Worker Failed: $e')),
                        );
                      }
                    }
                  },
                  child: creating
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示 Worker 详细信息弹窗
  void _showWorkerDetails(Map<String, dynamic> worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                (worker['full_name'] ?? 'W')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                worker['full_name'] ?? 'Worker Details',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.email_outlined, 'Email', worker['email'] ?? 'N/A'),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.phone_outlined, 'Phone', worker['phone'] ?? 'N/A'),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.badge_outlined, 'Role', (worker['role'] ?? 'worker').toString().toUpperCase()),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.calendar_today_outlined, 'User ID', worker['id'] ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  // 删除 Worker 账号
  Future<void> _deleteWorker(String workerId, String workerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text(
              'Confirm Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            children: [
              const TextSpan(text: 'Are you sure you want to permanently delete worker '),
              TextSpan(
                text: '"$workerName"',
                style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('profiles').delete().eq('id', workerId);
        _fetchWorkers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$workerName has been removed.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete worker: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Workers'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWorkers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _showCreateWorkerDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Worker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _workers.isEmpty
          ? const Center(
        child: Text('No workers found.', style: TextStyle(color: AppColors.textSecondary)),
      )
          : ListView.separated(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
        itemCount: _workers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final worker = _workers[index];
          final String name = worker['full_name'] ?? 'Unnamed Worker';
          final String email = worker['email'] ?? 'No Email';
          final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              onTap: () => _showWorkerDetails(worker),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                email,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteWorker(worker['id'], name),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}