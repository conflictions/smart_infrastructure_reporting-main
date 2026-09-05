import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

// ================================================================
// COMMUNITY UPDATE MODEL
// ================================================================

class CommunityUpdate {
  final String id;
  final String reportId;
  final String contributorId;

  final String evidenceType;
  final String storagePath;

  final String? originalFileName;
  final String? mimeType;
  final int? fileSizeBytes;

  final String? note;

  final DateTime createdAt;

  final String signedUrl;

  final bool isMine;

  const CommunityUpdate({
    required this.id,
    required this.reportId,
    required this.contributorId,
    required this.evidenceType,
    required this.storagePath,
    required this.originalFileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.note,
    required this.createdAt,
    required this.signedUrl,
    required this.isMine,
  });

  bool get isImage =>
      evidenceType == 'image';

  bool get isVideo =>
      evidenceType == 'video';
}

// ================================================================
// CONDITION SUMMARY
// ================================================================

class CommunityConditionSummary {
  final int stillExistsCount;
  final int looksFixedCount;

  final String? myFeedback;

  const CommunityConditionSummary({
    required this.stillExistsCount,
    required this.looksFixedCount,
    required this.myFeedback,
  });
}

// ================================================================
// INTERNAL FEEDBACK RECORD
// ================================================================

class _FeedbackRecord {
  final String feedback;
  final DateTime timestamp;

  const _FeedbackRecord({
    required this.feedback,
    required this.timestamp,
  });
}

// ================================================================
// COMMUNITY UPDATE SERVICE
// ================================================================

class CommunityUpdateService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  static const String evidenceBucket =
      'report-evidence';

  static const String contributionsTable =
      'community_report_contributions';

  static const String feedbackTable =
      'community_report_feedback';

  // ============================================================
  // CURRENT USER
  // ============================================================

  User get _currentUser {
    final User? user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    return user;
  }

  // ============================================================
  // LOAD COMMUNITY UPDATES
  // ============================================================

  Future<List<CommunityUpdate>>
  getUpdates(
      String reportId,
      ) async {
    final User user =
        _currentUser;

    final String cleanReportId =
    reportId.trim();

    if (cleanReportId.isEmpty) {
      throw Exception(
        'Report ID is required.',
      );
    }

    try {
      final List<dynamic> response =
      await _supabase
          .from(
        contributionsTable,
      )
          .select(
        '''
                id,
                report_id,
                contributor_id,
                evidence_type,
                storage_path,
                original_file_name,
                mime_type,
                file_size_bytes,
                note,
                created_at
                ''',
      )
          .eq(
        'report_id',
        cleanReportId,
      )
          .order(
        'created_at',
        ascending: false,
      );

      final List<CommunityUpdate> result =
      [];

      for (final dynamic raw
      in response) {
        if (raw is! Map) {
          continue;
        }

        final Map<String, dynamic> row =
        Map<String, dynamic>.from(
          raw,
        );

        final String storagePath =
            row['storage_path']
                ?.toString()
                .trim() ??
                '';

        if (storagePath.isEmpty) {
          continue;
        }

        try {
          final String signedUrl =
          await _supabase.storage
              .from(
            evidenceBucket,
          )
              .createSignedUrl(
            storagePath,
            3600,
          );

          final String contributorId =
              row['contributor_id']
                  ?.toString() ??
                  '';

          result.add(
            CommunityUpdate(
              id:
              row['id']
                  ?.toString() ??
                  '',
              reportId:
              row['report_id']
                  ?.toString() ??
                  '',
              contributorId:
              contributorId,
              evidenceType:
              row['evidence_type']
                  ?.toString()
                  .toLowerCase() ??
                  '',
              storagePath:
              storagePath,
              originalFileName:
              row['original_file_name']
                  ?.toString(),
              mimeType:
              row['mime_type']
                  ?.toString(),
              fileSizeBytes:
              int.tryParse(
                row['file_size_bytes']
                    ?.toString() ??
                    '',
              ),
              note:
              row['note']
                  ?.toString(),
              createdAt:
              DateTime.tryParse(
                row['created_at']
                    ?.toString() ??
                    '',
              ) ??
                  DateTime.now(),
              signedUrl:
              signedUrl,
              isMine:
              contributorId ==
                  user.id,
            ),
          );
        } catch (_) {
          // One broken storage item should not
          // prevent the rest of the feed loading.
          continue;
        }
      }

      return result;
    } catch (e) {
      throw Exception(
        'Unable to load community updates: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // ADD COMMUNITY UPDATE
  // ============================================================

  Future<void> addUpdate({
    required String reportId,
    required File file,
    required String evidenceType,
    String? note,
  }) async {
    final User user =
        _currentUser;

    final String cleanReportId =
    reportId.trim();

    if (cleanReportId.isEmpty) {
      throw Exception(
        'Report ID is required.',
      );
    }

    if (evidenceType != 'image' &&
        evidenceType != 'video') {
      throw Exception(
        'Evidence must be an image or video.',
      );
    }

    if (!await file.exists()) {
      throw Exception(
        'Selected file is no longer available.',
      );
    }

    final int fileSize =
    await file.length();

    if (fileSize <= 0) {
      throw Exception(
        'Selected file is empty.',
      );
    }

    final String extension =
    _extension(
      file.path,
    );

    final String contentType =
    _contentType(
      evidenceType:
      evidenceType,
      extension:
      extension,
    );

    final String fileName =
        'community_'
        '${DateTime.now().microsecondsSinceEpoch}'
        '.$extension';

    // Keep the same citizen-first folder structure
    // used by your existing report evidence.
    final String storagePath =
        '${user.id}/'
        '$cleanReportId/'
        '$fileName';

    bool uploaded = false;

    try {
      // ----------------------------------------------------------
      // STORAGE
      // ----------------------------------------------------------

      await _supabase.storage
          .from(
        evidenceBucket,
      )
          .upload(
        storagePath,
        file,
        fileOptions:
        FileOptions(
          upsert:
          false,
          cacheControl:
          '3600',
          contentType:
          contentType,
        ),
      );

      uploaded = true;

      // ----------------------------------------------------------
      // DATABASE
      // ----------------------------------------------------------

      await _supabase
          .from(
        contributionsTable,
      )
          .insert(
        {
          'report_id':
          cleanReportId,
          'contributor_id':
          user.id,
          'evidence_type':
          evidenceType,
          'storage_path':
          storagePath,
          'original_file_name':
          _fileName(
            file.path,
          ),
          'mime_type':
          contentType,
          'file_size_bytes':
          fileSize,
          'note':
          note == null ||
              note.trim().isEmpty
              ? null
              : note.trim(),
        },
      );
    } catch (e) {
      // If DB insert fails after upload,
      // remove the orphaned storage file.
      if (uploaded) {
        try {
          await _supabase.storage
              .from(
            evidenceBucket,
          )
              .remove(
            [
              storagePath,
            ],
          );
        } catch (_) {
          // Best-effort rollback.
        }
      }

      throw Exception(
        'Unable to add community update: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // CONDITION SUMMARY
  // ============================================================

  Future<CommunityConditionSummary>
  getConditionSummary(
      String reportId,
      ) async {
    final User user =
        _currentUser;

    try {
      final List<dynamic> response =
      await _supabase
          .from(
        feedbackTable,
      )
          .select(
        '''
                user_id,
                feedback,
                created_at,
                updated_at
                ''',
      )
          .eq(
        'report_id',
        reportId,
      );

      final Map<String, _FeedbackRecord>
      latestByUser =
      {};

      for (final dynamic raw
      in response) {
        if (raw is! Map) {
          continue;
        }

        final Map<String, dynamic> row =
        Map<String, dynamic>.from(
          raw,
        );

        final String userId =
            row['user_id']
                ?.toString() ??
                '';

        final String feedback =
            row['feedback']
                ?.toString()
                .toLowerCase() ??
                '';

        if (userId.isEmpty) {
          continue;
        }

        final DateTime timestamp =
            DateTime.tryParse(
              row['updated_at']
                  ?.toString() ??
                  '',
            ) ??
                DateTime.tryParse(
                  row['created_at']
                      ?.toString() ??
                      '',
                ) ??
                DateTime.fromMillisecondsSinceEpoch(
                  0,
                );

        final _FeedbackRecord? old =
        latestByUser[userId];

        if (old == null ||
            timestamp.isAfter(
              old.timestamp,
            )) {
          latestByUser[userId] =
              _FeedbackRecord(
                feedback:
                feedback,
                timestamp:
                timestamp,
              );
        }
      }

      int stillExists = 0;
      int looksFixed = 0;

      for (final _FeedbackRecord record
      in latestByUser.values) {
        if (record.feedback ==
            'still_exists') {
          stillExists++;
        }

        if (record.feedback ==
            'looks_fixed') {
          looksFixed++;
        }
      }

      return CommunityConditionSummary(
        stillExistsCount:
        stillExists,
        looksFixedCount:
        looksFixed,
        myFeedback:
        latestByUser[user.id]
            ?.feedback,
      );
    } catch (e) {
      throw Exception(
        'Unable to load condition feedback: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // SET STILL EXISTS / LOOKS FIXED
  // ============================================================

  Future<void> setConditionFeedback({
    required String reportId,
    required String feedback,
  }) async {
    final User user =
        _currentUser;

    if (feedback != 'still_exists' &&
        feedback != 'looks_fixed') {
      throw Exception(
        'Invalid feedback.',
      );
    }

    try {
      final List<dynamic> existing =
      await _supabase
          .from(
        feedbackTable,
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

      // Tap selected option again = clear it.
      final CommunityConditionSummary current =
      await getConditionSummary(
        reportId,
      );

      if (current.myFeedback ==
          feedback) {
        await _supabase
            .from(
          feedbackTable,
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

        return;
      }

      if (existing.isEmpty) {
        await _supabase
            .from(
          feedbackTable,
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
      } else {
        await _supabase
            .from(
          feedbackTable,
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
      }
    } catch (e) {
      throw Exception(
        'Unable to update condition: '
            '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // FILE HELPERS
  // ============================================================

  String _extension(
      String path,
      ) {
    final String fileName =
        path.split('/').last;

    if (!fileName.contains('.')) {
      return 'jpg';
    }

    return fileName
        .split('.')
        .last
        .toLowerCase();
  }

  String _fileName(
      String path,
      ) {
    return path
        .replaceAll(
      '\\',
      '/',
    )
        .split('/')
        .last;
  }

  String _contentType({
    required String evidenceType,
    required String extension,
  }) {
    if (evidenceType == 'image') {
      switch (extension) {
        case 'png':
          return 'image/png';

        case 'webp':
          return 'image/webp';

        case 'heic':
          return 'image/heic';

        case 'jpeg':
        case 'jpg':
        default:
          return 'image/jpeg';
      }
    }

    switch (extension) {
      case 'mov':
        return 'video/quicktime';

      case 'webm':
        return 'video/webm';

      case 'm4v':
        return 'video/x-m4v';

      case 'mp4':
      default:
        return 'video/mp4';
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
}