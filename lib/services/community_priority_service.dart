import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/infrastructure_report.dart';
import 'report_service.dart';

// ================================================================
// COMMUNITY PRIORITY REPORT MODEL
// ================================================================

class CommunityPriorityReport {
  final InfrastructureReport report;

  final int supportCount;
  final int stillExistsCount;
  final int looksFixedCount;

  final int contributionCount;
  final int contributorCount;

  final int participantCount;
  final int recentParticipantCount;

  final DateTime? latestInteractionAt;

  final bool supportedByMe;
  final String? myFeedback;

  final int priorityWeight;
  final int statusAdjustment;
  final int evidenceBonus;

  final int score;
  final bool trending;

  const CommunityPriorityReport({
    required this.report,
    required this.supportCount,
    required this.stillExistsCount,
    required this.looksFixedCount,
    required this.contributionCount,
    required this.contributorCount,
    required this.participantCount,
    required this.recentParticipantCount,
    required this.latestInteractionAt,
    required this.supportedByMe,
    required this.myFeedback,
    required this.priorityWeight,
    required this.statusAdjustment,
    required this.evidenceBonus,
    required this.score,
    required this.trending,
  });

  int get totalInteractions =>
      supportCount +
          stillExistsCount +
          looksFixedCount +
          contributionCount;

  bool get stillExistsSignal =>
      stillExistsCount > 0 &&
          stillExistsCount > looksFixedCount;

  String get attentionLabel {
    if (score >= 70) {
      return 'Critical Attention';
    }

    if (score >= 40) {
      return 'High Attention';
    }

    if (score >= 20) {
      return 'Rising';
    }

    return 'Normal';
  }
}

// ================================================================
// INTERNAL FEEDBACK STATE
// ================================================================

class _LatestFeedback {
  final String feedback;
  final DateTime timestamp;

  const _LatestFeedback({
    required this.feedback,
    required this.timestamp,
  });
}

// ================================================================
// COMMUNITY PRIORITY SERVICE
// ================================================================

class CommunityPriorityService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final ReportService _reportService =
  ReportService();

  // ============================================================
  // LOAD PRIORITY DATA
  // ============================================================

  Future<List<CommunityPriorityReport>>
  getPriorityReports() async {
    final User? user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      // ----------------------------------------------------------
      // LOAD PUBLIC REPORTS USING YOUR EXISTING SERVICE
      // ----------------------------------------------------------

      final List<InfrastructureReport>
      reports =
      await _reportService.getAllReports();

      if (reports.isEmpty) {
        return [];
      }

      final List<String> reportIds =
      reports
          .map(
            (InfrastructureReport report) =>
        report.id,
      )
          .toList();

      // ----------------------------------------------------------
      // COMMUNITY SUPPORTS
      // ----------------------------------------------------------

      final List<dynamic> supports =
      await _supabase
          .from(
        'community_report_supports',
      )
          .select(
        'report_id, user_id, created_at',
      )
          .inFilter(
        'report_id',
        reportIds,
      );

      // ----------------------------------------------------------
      // COMMUNITY FEEDBACK
      // ----------------------------------------------------------

      final List<dynamic> feedback =
      await _supabase
          .from(
        'community_report_feedback',
      )
          .select(
        '''
                report_id,
                user_id,
                feedback,
                created_at,
                updated_at
                ''',
      )
          .inFilter(
        'report_id',
        reportIds,
      );

      // ----------------------------------------------------------
      // COMMUNITY CONTRIBUTIONS
      // ----------------------------------------------------------

      final List<dynamic> contributions =
      await _supabase
          .from(
        'community_report_contributions',
      )
          .select(
        '''
                report_id,
                contributor_id,
                created_at
                ''',
      )
          .inFilter(
        'report_id',
        reportIds,
      );

      final DateTime recentCutoff =
      DateTime.now()
          .toUtc()
          .subtract(
        const Duration(
          days: 7,
        ),
      );

      // ==========================================================
      // AGGREGATION MAPS
      // ==========================================================

      final Map<String, Set<String>>
      supportUsers =
      {};

      final Map<
          String,
          Map<String, _LatestFeedback>>
      feedbackUsers =
      {};

      final Map<String, int>
      contributionCounts =
      {};

      final Map<String, Set<String>>
      contributorUsers =
      {};

      final Map<String, Set<String>>
      allParticipants =
      {};

      final Map<String, Set<String>>
      recentParticipants =
      {};

      final Map<String, DateTime>
      latestActivity =
      {};

      // ==========================================================
      // PROCESS SUPPORTS
      // ==========================================================

      for (final dynamic raw in supports) {
        if (raw is! Map) {
          continue;
        }

        final Map<String, dynamic> row =
        Map<String, dynamic>.from(
          raw,
        );

        final String reportId =
            row['report_id']
                ?.toString() ??
                '';

        final String userId =
            row['user_id']
                ?.toString() ??
                '';

        if (reportId.isEmpty ||
            userId.isEmpty) {
          continue;
        }

        supportUsers
            .putIfAbsent(
          reportId,
              () => <String>{},
        )
            .add(
          userId,
        );

        allParticipants
            .putIfAbsent(
          reportId,
              () => <String>{},
        )
            .add(
          userId,
        );

        _recordActivity(
          reportId: reportId,
          userId: userId,
          timestamp:
          _parseDate(
            row['created_at'],
          ),
          cutoff:
          recentCutoff,
          recentParticipants:
          recentParticipants,
          latestActivity:
          latestActivity,
        );
      }

      // ==========================================================
      // PROCESS FEEDBACK
      //
      // Only newest feedback from each user counts.
      // ==========================================================

      for (final dynamic raw in feedback) {
        if (raw is! Map) {
          continue;
        }

        final Map<String, dynamic> row =
        Map<String, dynamic>.from(
          raw,
        );

        final String reportId =
            row['report_id']
                ?.toString() ??
                '';

        final String userId =
            row['user_id']
                ?.toString() ??
                '';

        final String value =
            row['feedback']
                ?.toString()
                .toLowerCase() ??
                '';

        if (reportId.isEmpty ||
            userId.isEmpty) {
          continue;
        }

        if (value != 'still_exists' &&
            value != 'looks_fixed') {
          continue;
        }

        final DateTime timestamp =
            _parseDate(
              row['updated_at'],
            ) ??
                _parseDate(
                  row['created_at'],
                ) ??
                DateTime.fromMillisecondsSinceEpoch(
                  0,
                  isUtc: true,
                );

        final Map<String, _LatestFeedback>
        users =
        feedbackUsers.putIfAbsent(
          reportId,
              () => {},
        );

        final _LatestFeedback? old =
        users[userId];

        if (old == null ||
            timestamp.isAfter(
              old.timestamp,
            )) {
          users[userId] =
              _LatestFeedback(
                feedback:
                value,
                timestamp:
                timestamp,
              );
        }

        allParticipants
            .putIfAbsent(
          reportId,
              () => <String>{},
        )
            .add(
          userId,
        );

        _recordActivity(
          reportId:
          reportId,
          userId:
          userId,
          timestamp:
          timestamp,
          cutoff:
          recentCutoff,
          recentParticipants:
          recentParticipants,
          latestActivity:
          latestActivity,
        );
      }

      // ==========================================================
      // PROCESS CONTRIBUTED EVIDENCE
      // ==========================================================

      for (final dynamic raw
      in contributions) {
        if (raw is! Map) {
          continue;
        }

        final Map<String, dynamic> row =
        Map<String, dynamic>.from(
          raw,
        );

        final String reportId =
            row['report_id']
                ?.toString() ??
                '';

        final String userId =
            row['contributor_id']
                ?.toString() ??
                '';

        if (reportId.isEmpty ||
            userId.isEmpty) {
          continue;
        }

        contributionCounts[reportId] =
            (contributionCounts[
            reportId] ??
                0) +
                1;

        contributorUsers
            .putIfAbsent(
          reportId,
              () => <String>{},
        )
            .add(
          userId,
        );

        allParticipants
            .putIfAbsent(
          reportId,
              () => <String>{},
        )
            .add(
          userId,
        );

        _recordActivity(
          reportId:
          reportId,
          userId:
          userId,
          timestamp:
          _parseDate(
            row['created_at'],
          ),
          cutoff:
          recentCutoff,
          recentParticipants:
          recentParticipants,
          latestActivity:
          latestActivity,
        );
      }

      // ==========================================================
      // CREATE ANALYTICS RESULTS
      // ==========================================================

      final List<CommunityPriorityReport>
      result =
      [];

      for (final InfrastructureReport report
      in reports) {
        final String reportId =
            report.id;

        final Set<String> supportsForReport =
            supportUsers[reportId] ??
                {};

        final Map<String, _LatestFeedback>
        feedbackForReport =
            feedbackUsers[reportId] ??
                {};

        int stillExists = 0;
        int looksFixed = 0;

        for (final _LatestFeedback item
        in feedbackForReport.values) {
          if (item.feedback ==
              'still_exists') {
            stillExists++;
          } else if (item.feedback ==
              'looks_fixed') {
            looksFixed++;
          }
        }

        final int evidenceCount =
            contributionCounts[
            reportId] ??
                0;

        final int contributorCount =
            contributorUsers[
            reportId]
                ?.length ??
                0;

        final int participantCount =
            allParticipants[
            reportId]
                ?.length ??
                0;

        final int recentCount =
            recentParticipants[
            reportId]
                ?.length ??
                0;

        final int priorityWeight =
        _priorityWeight(
          report.priority,
        );

        final int evidenceBonus =
        math
            .min(
          evidenceCount,
          5,
        )
            .toInt();

        final int statusAdjustment =
        _statusAdjustment(
          status:
          report.status,
          stillExists:
          stillExists,
          looksFixed:
          looksFixed,
        );

        // ========================================================
        // COMMUNITY PRIORITY SCORE
        //
        // Support               x 2
        // Still exists          x 6
        // Looks fixed           x -2
        // Unique contributors   x 4
        // Evidence bonus        max +5
        // Recent participants   x 3
        // Report priority       up to +20
        // ========================================================

        int rawScore =
            (supportsForReport.length * 2) +
                (stillExists * 6) -
                (looksFixed * 2) +
                (contributorCount * 4) +
                evidenceBonus +
                (recentCount * 3) +
                priorityWeight +
                statusAdjustment;

        // Critical report + repeated unresolved confirmation
        // should be surfaced strongly.
        if (report.priority
            .toLowerCase() ==
            'critical' &&
            stillExists >= 3) {
          rawScore =
              math
                  .max(
                rawScore,
                70,
              )
                  .toInt();
        }

        final int score =
        rawScore
            .clamp(
          0,
          100,
        )
            .toInt();

        // At least 3 recent participants and at least half
        // of all participating citizens were active recently.
        final bool trending =
            recentCount >= 3 &&
                participantCount > 0 &&
                (recentCount /
                    participantCount) >=
                    0.5;

        result.add(
          CommunityPriorityReport(
            report:
            report,
            supportCount:
            supportsForReport.length,
            stillExistsCount:
            stillExists,
            looksFixedCount:
            looksFixed,
            contributionCount:
            evidenceCount,
            contributorCount:
            contributorCount,
            participantCount:
            participantCount,
            recentParticipantCount:
            recentCount,
            latestInteractionAt:
            latestActivity[
            reportId],
            supportedByMe:
            supportsForReport
                .contains(
              user.id,
            ),
            myFeedback:
            feedbackForReport[
            user.id]
                ?.feedback,
            priorityWeight:
            priorityWeight,
            statusAdjustment:
            statusAdjustment,
            evidenceBonus:
            evidenceBonus,
            score:
            score,
            trending:
            trending,
          ),
        );
      }

      result.sort(
            (
            CommunityPriorityReport a,
            CommunityPriorityReport b,
            ) =>
            b.score.compareTo(
              a.score,
            ),
      );

      return result;
    } catch (e) {
      throw Exception(
        'Unable to load community priority data: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // SUPPORT / UNSUPPORT
  // ============================================================

  Future<bool> toggleSupport(
      String reportId,
      ) async {
    final User? user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    try {
      final List<dynamic> existing =
      await _supabase
          .from(
        'community_report_supports',
      )
          .select(
        'id',
      )
          .eq(
        'report_id',
        reportId,
      )
          .eq(
        'user_id',
        user.id,
      );

      if (existing.isNotEmpty) {
        await _supabase
            .from(
          'community_report_supports',
        )
            .delete()
            .eq(
          'report_id',
          reportId,
        )
            .eq(
          'user_id',
          user.id,
        );

        return false;
      }

      await _supabase
          .from(
        'community_report_supports',
      )
          .insert(
        {
          'report_id':
          reportId,
          'user_id':
          user.id,
        },
      );

      return true;
    } catch (e) {
      throw Exception(
        'Unable to update support: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // STILL EXISTS / LOOKS FIXED
  // ============================================================

  Future<void> setFeedback({
    required String reportId,
    required String? feedback,
  }) async {
    final User? user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    if (feedback != null &&
        feedback != 'still_exists' &&
        feedback != 'looks_fixed') {
      throw Exception(
        'Invalid feedback.',
      );
    }

    try {
      final List<dynamic> existing =
      await _supabase
          .from(
        'community_report_feedback',
      )
          .select(
        'id',
      )
          .eq(
        'report_id',
        reportId,
      )
          .eq(
        'user_id',
        user.id,
      );

      // Clear feedback.
      if (feedback == null) {
        if (existing.isNotEmpty) {
          await _supabase
              .from(
            'community_report_feedback',
          )
              .delete()
              .eq(
            'report_id',
            reportId,
          )
              .eq(
            'user_id',
            user.id,
          );
        }

        return;
      }

      // First feedback.
      if (existing.isEmpty) {
        await _supabase
            .from(
          'community_report_feedback',
        )
            .insert(
          {
            'report_id':
            reportId,
            'user_id':
            user.id,
            'feedback':
            feedback,
            'updated_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
          },
        );

        return;
      }

      // Change existing feedback.
      await _supabase
          .from(
        'community_report_feedback',
      )
          .update(
        {
          'feedback':
          feedback,
          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        },
      )
          .eq(
        'report_id',
        reportId,
      )
          .eq(
        'user_id',
        user.id,
      );
    } catch (e) {
      throw Exception(
        'Unable to update feedback: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // SCORE HELPERS
  // ============================================================

  int _priorityWeight(
      String priority,
      ) {
    switch (
    priority.toLowerCase()) {
      case 'critical':
        return 20;

      case 'high':
        return 10;

      case 'medium':
        return 5;

      case 'low':
      default:
        return 0;
    }
  }

  int _statusAdjustment({
    required String status,
    required int stillExists,
    required int looksFixed,
  }) {
    final String value =
    status
        .toLowerCase()
        .replaceAll(
      ' ',
      '_',
    );

    if (value == 'rejected') {
      return -20;
    }

    // A completed issue is reduced only when the community
    // does not indicate that it remains unresolved.
    if (value == 'completed' &&
        stillExists <= looksFixed) {
      return -15;
    }

    return 0;
  }

  // ============================================================
  // ACTIVITY
  // ============================================================

  void _recordActivity({
    required String reportId,
    required String userId,
    required DateTime? timestamp,
    required DateTime cutoff,
    required Map<String, Set<String>>
    recentParticipants,
    required Map<String, DateTime>
    latestActivity,
  }) {
    if (timestamp == null) {
      return;
    }

    final DateTime utc =
    timestamp.toUtc();

    if (!utc.isBefore(
      cutoff,
    )) {
      recentParticipants
          .putIfAbsent(
        reportId,
            () => <String>{},
      )
          .add(
        userId,
      );
    }

    final DateTime? latest =
    latestActivity[
    reportId];

    if (latest == null ||
        utc.isAfter(
          latest,
        )) {
      latestActivity[
      reportId] =
          utc;
    }
  }

  DateTime? _parseDate(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
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
}