import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/infrastructure_report.dart';
import '../../services/community_update_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';

import 'add_community_update_screen.dart';

class CommunityUpdatesScreen
    extends StatefulWidget {
  final String reportId;

  const CommunityUpdatesScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<CommunityUpdatesScreen>
  createState() =>
      _CommunityUpdatesScreenState();
}

class _CommunityUpdatesScreenState
    extends State<CommunityUpdatesScreen> {
  final CommunityUpdateService updateService =
  CommunityUpdateService();

  final ReportService reportService =
  ReportService();

  InfrastructureReport? report;

  List<CommunityUpdate> updates =
  [];

  CommunityConditionSummary condition =
  const CommunityConditionSummary(
    stillExistsCount:
    0,
    looksFixedCount:
    0,
    myFeedback:
    null,
  );

  bool loading = true;

  bool updatingCondition = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();

    _load();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _load({
    bool showLoading = true,
  }) async {
    if (showLoading &&
        mounted) {
      setState(() {
        loading =
        true;

        errorMessage =
        null;
      });
    }

    try {
      final InfrastructureReport? loadedReport =
      await reportService
          .getSharedReportById(
        widget.reportId,
      );

      if (loadedReport == null) {
        throw Exception(
          'Report not found.',
        );
      }

      final List<CommunityUpdate>
      loadedUpdates =
      await updateService.getUpdates(
        widget.reportId,
      );

      final CommunityConditionSummary
      loadedCondition =
      await updateService
          .getConditionSummary(
        widget.reportId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        report =
            loadedReport;

        updates =
            loadedUpdates;

        condition =
            loadedCondition;

        loading =
        false;

        errorMessage =
        null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading =
        false;

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
  // ADD UPDATE
  // ============================================================

  Future<void> _addUpdate() async {
    final bool? added =
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder:
            (_) =>
            AddCommunityUpdateScreen(
              reportId:
              widget.reportId,
            ),
      ),
    );

    if (added == true) {
      await _load(
        showLoading:
        false,
      );

      _message(
        'Community update added.',
      );
    }
  }

  // ============================================================
  // CONDITION
  // ============================================================

  Future<void> _setCondition(
      String feedback,
      ) async {
    if (updatingCondition) {
      return;
    }

    setState(() {
      updatingCondition =
      true;
    });

    try {
      await updateService
          .setConditionFeedback(
        reportId:
        widget.reportId,
        feedback:
        feedback,
      );

      final CommunityConditionSummary
      latest =
      await updateService
          .getConditionSummary(
        widget.reportId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        condition =
            latest;
      });
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
          updatingCondition =
          false;
        });
      }
    }
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
          'Community Updates',
        ),

        actions: [
          IconButton(
            tooltip:
            'Refresh',

            onPressed:
                () => _load(),

            icon:
            const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      floatingActionButton:
      loading ||
          errorMessage != null
          ? null
          : FloatingActionButton.extended(
        onPressed:
        _addUpdate,

        icon:
        const Icon(
          Icons.add_a_photo_outlined,
        ),

        label:
        const Text(
          'Add Update',
        ),
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
                45,
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
                14,
              ),

              FilledButton(
                onPressed:
                _load,

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

    final InfrastructureReport current =
    report!;

    return RefreshIndicator(
      onRefresh:
          () => _load(
        showLoading:
        false,
      ),

      child:
      ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        padding:
        const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          100,
        ),

        children: [
          // ======================================================
          // REPORT HEADER
          // ======================================================

          Container(
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
                Text(
                  current.title,

                  style:
                  const TextStyle(
                    fontSize:
                    16,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                  4,
                ),

                Text(
                  current.referenceNumber,

                  style:
                  const TextStyle(
                    color:
                    AppColors.primary,

                    fontSize:
                    10,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                  8,
                ),

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
                        current.address,

                        style:
                        const TextStyle(
                          color:
                          AppColors.textSecondary,

                          fontSize:
                          9,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            16,
          ),

          // ======================================================
          // CONDITION
          // ======================================================

          Container(
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
                const Text(
                  'Current Condition',

                  style:
                  TextStyle(
                    fontSize:
                    14,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                  5,
                ),

                const Text(
                  'Have you recently seen this issue?',

                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,

                    fontSize:
                    9,
                  ),
                ),

                const SizedBox(
                  height:
                  14,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                      _ConditionCount(
                        icon:
                        Icons
                            .report_problem_outlined,

                        title:
                        'Still Exists',

                        value:
                        condition
                            .stillExistsCount,

                        color:
                        AppColors.danger,
                      ),
                    ),

                    const SizedBox(
                      width:
                      10,
                    ),

                    Expanded(
                      child:
                      _ConditionCount(
                        icon:
                        Icons
                            .check_circle_outline,

                        title:
                        'Looks Fixed',

                        value:
                        condition
                            .looksFixedCount,

                        color:
                        AppColors.success,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                  12,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                      condition.myFeedback ==
                          'still_exists'
                          ? FilledButton.icon(
                        onPressed:
                        updatingCondition
                            ? null
                            : () =>
                            _setCondition(
                              'still_exists',
                            ),

                        icon:
                        const Icon(
                          Icons
                              .report_problem,
                        ),

                        label:
                        const Text(
                          'Still Exists',
                        ),
                      )
                          : OutlinedButton.icon(
                        onPressed:
                        updatingCondition
                            ? null
                            : () =>
                            _setCondition(
                              'still_exists',
                            ),

                        icon:
                        const Icon(
                          Icons
                              .report_problem_outlined,
                        ),

                        label:
                        const Text(
                          'Still Exists',
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                      8,
                    ),

                    Expanded(
                      child:
                      condition.myFeedback ==
                          'looks_fixed'
                          ? FilledButton.icon(
                        onPressed:
                        updatingCondition
                            ? null
                            : () =>
                            _setCondition(
                              'looks_fixed',
                            ),

                        icon:
                        const Icon(
                          Icons
                              .check_circle,
                        ),

                        label:
                        const Text(
                          'Looks Fixed',
                        ),
                      )
                          : OutlinedButton.icon(
                        onPressed:
                        updatingCondition
                            ? null
                            : () =>
                            _setCondition(
                              'looks_fixed',
                            ),

                        icon:
                        const Icon(
                          Icons
                              .check_circle_outline,
                        ),

                        label:
                        const Text(
                          'Looks Fixed',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            22,
          ),

          Row(
            children: [
              const Text(
                'Latest Updates',

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
                '${updates.length} update'
                    '${updates.length == 1 ? '' : 's'}',

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

          if (updates.isEmpty)
            _buildEmpty()
          else
            ...updates.map(
              _buildUpdateCard,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // UPDATE CARD
  // ============================================================

  Widget _buildUpdateCard(
      CommunityUpdate update,
      ) {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom:
        13,
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

      clipBehavior:
      Clip.antiAlias,

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Padding(
            padding:
            const EdgeInsets.all(
              13,
            ),

            child:
            Row(
              children: [
                Container(
                  width:
                  34,

                  height:
                  34,

                  decoration:
                  BoxDecoration(
                    color:
                    AppColors.primary
                        .withValues(
                      alpha:
                      0.10,
                    ),

                    shape:
                    BoxShape.circle,
                  ),

                  child:
                  const Icon(
                    Icons.person_outline,

                    color:
                    AppColors.primary,

                    size:
                    18,
                  ),
                ),

                const SizedBox(
                  width:
                  9,
                ),

                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        update.isMine
                            ? 'You'
                            : 'Community Member',

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
                        2,
                      ),

                      Text(
                        _formatDateTime(
                          update.createdAt,
                        ),

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
                ),

                Icon(
                  update.isImage
                      ? Icons.photo_outlined
                      : Icons.videocam_outlined,

                  color:
                  AppColors.primary,

                  size:
                  18,
                ),
              ],
            ),
          ),

          if (update.isImage)
            GestureDetector(
              onTap:
                  () =>
                  _openImage(
                    update.signedUrl,
                  ),

              child:
              Image.network(
                update.signedUrl,

                width:
                double.infinity,

                height:
                220,

                fit:
                BoxFit.cover,

                loadingBuilder:
                    (
                    context,
                    child,
                    progress,
                    ) {
                  if (progress == null) {
                    return child;
                  }

                  return const SizedBox(
                    height:
                    220,

                    child:
                    Center(
                      child:
                      CircularProgressIndicator(),
                    ),
                  );
                },

                errorBuilder:
                    (
                    context,
                    error,
                    stackTrace,
                    ) {
                  return const SizedBox(
                    height:
                    160,

                    child:
                    Center(
                      child:
                      Icon(
                        Icons
                            .broken_image_outlined,

                        color:
                        AppColors.textSecondary,

                        size:
                        40,
                      ),
                    ),
                  );
                },
              ),
            ),

          if (update.isVideo)
            InkWell(
              onTap:
                  () =>
                  _openVideo(
                    update.signedUrl,
                  ),

              child:
              Container(
                height:
                170,

                width:
                double.infinity,

                color:
                Colors.black,

                child:
                const Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,

                  children: [
                    Icon(
                      Icons
                          .play_circle_fill_rounded,

                      color:
                      Colors.white,

                      size:
                      55,
                    ),

                    SizedBox(
                      height:
                      7,
                    ),

                    Text(
                      'Play video update',

                      style:
                      TextStyle(
                        color:
                        Colors.white,

                        fontSize:
                        10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (update.note != null &&
              update.note!
                  .trim()
                  .isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.all(
                13,
              ),

              child:
              Text(
                update.note!,

                style:
                const TextStyle(
                  fontSize:
                  11,

                  height:
                  1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  void _openImage(
      String url,
      ) {
    showDialog(
      context:
      context,

      builder:
          (_) =>
          Dialog(
            backgroundColor:
            Colors.black,

            child:
            InteractiveViewer(
              minScale:
              0.8,

              maxScale:
              5,

              child:
              Image.network(
                url,

                fit:
                BoxFit.contain,
              ),
            ),
          ),
    );
  }

  // ============================================================
  // VIDEO
  // ============================================================

  void _openVideo(
      String url,
      ) {
    showDialog(
      context:
      context,

      builder:
          (_) =>
          _CommunityVideoDialog(
            url:
            url,
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
        vertical:
        35,

        horizontal:
        20,
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
        children: [
          const Icon(
            Icons
                .forum_outlined,

            color:
            AppColors.textSecondary,

            size:
            42,
          ),

          const SizedBox(
            height:
            10,
          ),

          const Text(
            'No community updates yet',

            style:
            TextStyle(
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          const Text(
            'Be the first citizen to provide updated evidence.',

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

          const SizedBox(
            height:
            14,
          ),

          OutlinedButton.icon(
            onPressed:
            _addUpdate,

            icon:
            const Icon(
              Icons.add_a_photo_outlined,
            ),

            label:
            const Text(
              'Add Update',
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(
      DateTime value,
      ) {
    final DateTime date =
    value.toLocal();

    final String minute =
    date.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '${date.day}/'
        '${date.month}/'
        '${date.year} '
        '${date.hour}:'
        '$minute';
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
// CONDITION COUNT
// ================================================================

class _ConditionCount
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final int value;
  final Color color;

  const _ConditionCount({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
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
        color.withValues(
          alpha:
          0.08,
        ),

        borderRadius:
        BorderRadius.circular(
          12,
        ),
      ),

      child:
      Row(
        children: [
          Icon(
            icon,

            color:
            color,

            size:
            18,
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
                  '$value',

                  style:
                  TextStyle(
                    color:
                    color,

                    fontSize:
                    16,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                Text(
                  title,

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
          ),
        ],
      ),
    );
  }
}

// ================================================================
// VIDEO DIALOG
// ================================================================

class _CommunityVideoDialog
    extends StatefulWidget {
  final String url;

  const _CommunityVideoDialog({
    required this.url,
  });

  @override
  State<_CommunityVideoDialog>
  createState() =>
      _CommunityVideoDialogState();
}

class _CommunityVideoDialogState
    extends State<_CommunityVideoDialog> {
  late final VideoPlayerController controller;

  bool ready = false;

  @override
  void initState() {
    super.initState();

    controller =
        VideoPlayerController.networkUrl(
          Uri.parse(
            widget.url,
          ),
        );

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await controller.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        ready =
        true;
      });

      await controller.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          ready =
          false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Dialog(
      backgroundColor:
      Colors.black,

      child:
      AspectRatio(
        aspectRatio:
        ready &&
            controller
                .value
                .aspectRatio >
                0
            ? controller
            .value
            .aspectRatio
            : 16 / 9,

        child:
        ready
            ? Stack(
          alignment:
          Alignment.center,

          children: [
            VideoPlayer(
              controller,
            ),

            IconButton(
              onPressed:
                  () {
                setState(() {
                  if (controller
                      .value
                      .isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },

              icon:
              Icon(
                controller
                    .value
                    .isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,

                color:
                Colors.white,

                size:
                55,
              ),
            ),
          ],
        )
            : const Center(
          child:
          CircularProgressIndicator(),
        ),
      ),
    );
  }
}