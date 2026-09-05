import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/infrastructure_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

class WorkerManageReportScreen extends StatefulWidget {
  final InfrastructureReport report;

  const WorkerManageReportScreen({
    super.key,
    required this.report,
  });

  @override
  State<WorkerManageReportScreen> createState() =>
      _WorkerManageReportScreenState();
}

class _WorkerManageReportScreenState extends State<WorkerManageReportScreen> {
  final ReportService reportService = ReportService();
  final ImagePicker _picker = ImagePicker();

  late String selectedStatus;
  late int progress;
  String? selectedDepartment;
  DateTime? estimatedCompletion;

  File? afterImageFile;
  bool saving = false;

  final List<String> statuses = [
    'pending',
    'verified',
    'in_progress',
    'completed',
    'rejected',
  ];

  final List<String> departments = [
    'Jabatan Kerja Raya',
    'TNB / DBKL',
    'DBKL',
    'Dewan Bandaraya KL',
    'Local Authority',
  ];

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.report.status;
    progress = widget.report.progressPercentage;
    selectedDepartment = widget.report.assignedDepartment;
    estimatedCompletion = widget.report.estimatedCompletion;
  }

  String statusLabel(String status) {
    switch (status) {
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

  void applyRecommendedProgress(String status) {
    setState(() {
      selectedStatus = status;

      switch (status) {
        case 'pending':
          progress = 10;
          break;
        case 'verified':
          progress = 30;
          break;
        case 'in_progress':
          progress = progress < 30 ? 30 : progress;
          break;
        case 'completed':
          progress = 100;
          break;
        case 'rejected':
          progress = 0;
          break;
      }
    });
  }

  void updateSliderProgress(int value) {
    setState(() {
      progress = value;
      if (progress == 100) {
        selectedStatus = 'completed';
      } else if (progress > 0 && selectedStatus == 'completed') {
        selectedStatus = 'in_progress';
      } else if (progress > 0 && selectedStatus == 'pending') {
        selectedStatus = 'in_progress';
      }
    });
  }

  Future<void> pickAfterImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          afterImageFile = File(picked.path);
        });
      }
    } catch (e) {
      showMessage('Failed to pick image: $e');
    }
  }

  Future<void> selectDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: estimatedCompletion ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (result == null) return;
    setState(() => estimatedCompletion = result);
  }

  Future<void> save() async {
    // 1. 部门分配校验
    if (selectedStatus == 'in_progress' && selectedDepartment == null) {
      showMessage('Please assign a department.');
      return;
    }

    // 2. 如果选择了施工后照片，但进度未达到 100% 或状态不是 Completed
    if (afterImageFile != null && (progress < 100 || selectedStatus != 'completed')) {
      showMessage('Completion photos can only be uploaded when progress is 100% (Completed).');
      return;
    }

    // 3. 强制规则：标记 Completed 时，必须提供施工后照片凭据
    if (selectedStatus == 'completed' && afterImageFile == null) {
      showMessage('Please upload an after-repair photo to mark as completed.');
      return;
    }

    setState(() => saving = true);

    try {
      // 1. 上传施工后图片（如果有选择）
      if (afterImageFile != null) {
        await reportService.uploadAfterRepairImage(
          reportId: widget.report.id,
          imageFile: afterImageFile!,
        );
      }

      // 2. 更新工作流状态
      await reportService.updateReportWorkflow(
        reportId: widget.report.id,
        status: selectedStatus,
        progressPercentage: progress,
        assignedDepartment: selectedDepartment,
        estimatedCompletion: estimatedCompletion,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: saving ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Manage Report',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.report.referenceNumber,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 工单卡片
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.report.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.report.description,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '📍 ${widget.report.address}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'STATUS',
                      style: TextStyle(
                        color: Color(0xFFA9C7EF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      dropdownColor: AppColors.surface,
                      decoration: _inputDecoration(),
                      items: statuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(statusLabel(status)),
                        );
                      }).toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                        if (value != null) {
                          applyRecommendedProgress(value);
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'ASSIGNED DEPARTMENT',
                      style: TextStyle(
                        color: Color(0xFFA9C7EF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      dropdownColor: AppColors.surface,
                      decoration: _inputDecoration(hint: 'Choose department'),
                      items: departments.map((department) {
                        return DropdownMenuItem(
                          value: department,
                          child: Text(department),
                        );
                      }).toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                        setState(() {
                          selectedDepartment = value;
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        const Text(
                          'PROGRESS',
                          style: TextStyle(
                            color: Color(0xFFA9C7EF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$progress%',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    Slider(
                      value: progress.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: AppColors.primary,
                      onChanged: saving
                          ? null
                          : (value) => updateSliderProgress(value.round()),
                    ),

                    const SizedBox(height: 15),

                    // 施工后现场照片上传组件
                    const Text(
                      'AFTER-REPAIR PHOTO (REQUIRED FOR COMPLETED)',
                      style: TextStyle(
                        color: Color(0xFFA9C7EF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    InkWell(
                      onTap: saving
                          ? null
                          : () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('Take Photo'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    pickAfterImage(ImageSource.camera);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('Choose from Gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    pickAfterImage(ImageSource.gallery);
                                  },
                                ),
                                if (afterImageFile != null)
                                  ListTile(
                                    leading: const Icon(Icons.delete, color: Colors.red),
                                    title: const Text(
                                      'Remove Photo',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      setState(() {
                                        afterImageFile = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: afterImageFile != null
                            ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(
                                afterImageFile!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: saving
                                    ? null
                                    : () {
                                  setState(() {
                                    afterImageFile = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54, // ✅ 使用内置的 black54 (54% 透明度)
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.primary,
                              size: 30,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Upload Proof of Repair',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'ESTIMATED COMPLETION',
                      style: TextStyle(
                        color: Color(0xFFA9C7EF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    InkWell(
                      onTap: saving ? null : selectDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(formatDate(estimatedCompletion)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                  ),
                  onPressed: saving ? null : save,
                  child: saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Update'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}