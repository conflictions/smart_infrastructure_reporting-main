import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/community_update_service.dart';
import '../../theme/app_colors.dart';

class AddCommunityUpdateScreen
    extends StatefulWidget {
  final String reportId;

  const AddCommunityUpdateScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<AddCommunityUpdateScreen>
  createState() =>
      _AddCommunityUpdateScreenState();
}

class _AddCommunityUpdateScreenState
    extends State<AddCommunityUpdateScreen> {
  final CommunityUpdateService service =
  CommunityUpdateService();

  final ImagePicker picker =
  ImagePicker();

  final TextEditingController noteController =
  TextEditingController();

  File? selectedFile;

  String? evidenceType;

  bool submitting = false;

  @override
  void dispose() {
    noteController.dispose();

    super.dispose();
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage(
      ImageSource source,
      ) async {
    final XFile? result =
    await picker.pickImage(
      source:
      source,
      imageQuality:
      85,
    );

    if (result == null) {
      return;
    }

    setState(() {
      selectedFile =
          File(
            result.path,
          );

      evidenceType =
      'image';
    });
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo(
      ImageSource source,
      ) async {
    final XFile? result =
    await picker.pickVideo(
      source:
      source,
      maxDuration:
      const Duration(
        minutes:
        2,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      selectedFile =
          File(
            result.path,
          );

      evidenceType =
      'video';
    });
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    final File? file =
        selectedFile;

    final String? type =
        evidenceType;

    if (file == null ||
        type == null) {
      _message(
        'Please add a photo or video.',
      );

      return;
    }

    setState(() {
      submitting =
      true;
    });

    try {
      await service.addUpdate(
        reportId:
        widget.reportId,
        file:
        file,
        evidenceType:
        type,
        note:
        noteController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
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
          submitting =
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
          'Add Community Update',
        ),
      ),

      body:
      ListView(
        padding:
        const EdgeInsets.all(
          18,
        ),

        children: [
          const Text(
            'What has changed?',

            style:
            TextStyle(
              fontSize:
              21,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          const Text(
            'Add current evidence so other citizens can see the latest condition of this issue.',

            style:
            TextStyle(
              color:
              AppColors.textSecondary,

              fontSize:
              11,

              height:
              1.5,
            ),
          ),

          const SizedBox(
            height:
            20,
          ),

          // ======================================================
          // MEDIA ACTIONS
          // ======================================================

          Row(
            children: [
              Expanded(
                child:
                OutlinedButton.icon(
                  onPressed:
                  submitting
                      ? null
                      : () =>
                      _pickImage(
                        ImageSource.camera,
                      ),

                  icon:
                  const Icon(
                    Icons.camera_alt_outlined,
                  ),

                  label:
                  const Text(
                    'Take Photo',
                  ),
                ),
              ),

              const SizedBox(
                width:
                8,
              ),

              Expanded(
                child:
                OutlinedButton.icon(
                  onPressed:
                  submitting
                      ? null
                      : () =>
                      _pickImage(
                        ImageSource.gallery,
                      ),

                  icon:
                  const Icon(
                    Icons.photo_library_outlined,
                  ),

                  label:
                  const Text(
                    'Photo',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            8,
          ),

          SizedBox(
            width:
            double.infinity,

            child:
            OutlinedButton.icon(
              onPressed:
              submitting
                  ? null
                  : () =>
                  _pickVideo(
                    ImageSource.gallery,
                  ),

              icon:
              const Icon(
                Icons.videocam_outlined,
              ),

              label:
              const Text(
                'Choose Video',
              ),
            ),
          ),

          const SizedBox(
            height:
            18,
          ),

          // ======================================================
          // PREVIEW
          // ======================================================

          if (selectedFile != null)
            Container(
              width:
              double.infinity,

              decoration:
              BoxDecoration(
                color:
                AppColors.surface,

                borderRadius:
                BorderRadius.circular(
                  15,
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
              evidenceType ==
                  'image'
                  ? Image.file(
                selectedFile!,

                height:
                210,

                fit:
                BoxFit.cover,
              )
                  : SizedBox(
                height:
                150,

                child:
                Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,

                  children: [
                    const Icon(
                      Icons
                          .play_circle_outline_rounded,

                      color:
                      AppColors.primary,

                      size:
                      55,
                    ),

                    const SizedBox(
                      height:
                      8,
                    ),

                    const Text(
                      'Video selected',

                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (selectedFile != null)
            const SizedBox(
              height:
              18,
            ),

          // ======================================================
          // NOTE
          // ======================================================

          TextField(
            controller:
            noteController,

            minLines:
            4,

            maxLines:
            6,

            maxLength:
            300,

            decoration:
            InputDecoration(
              labelText:
              'Update note',

              hintText:
              'Example: The pothole has become deeper after the rain.',

              alignLabelWithHint:
              true,

              filled:
              true,

              fillColor:
              AppColors.surface,

              border:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
            10,
          ),

          // ======================================================
          // INFO
          // ======================================================

          Container(
            padding:
            const EdgeInsets.all(
              12,
            ),

            decoration:
            BoxDecoration(
              color:
              AppColors.primary.withValues(
                alpha:
                0.08,
              ),

              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),

            child:
            const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Icon(
                  Icons.info_outline,

                  color:
                  AppColors.primary,

                  size:
                  18,
                ),

                SizedBox(
                  width:
                  8,
                ),

                Expanded(
                  child:
                  Text(
                    'Only upload recent evidence related to this infrastructure issue.',

                    style:
                    TextStyle(
                      fontSize:
                      10,

                      height:
                      1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            22,
          ),

          // ======================================================
          // SUBMIT
          // ======================================================

          SizedBox(
            height:
            48,

            child:
            FilledButton.icon(
              onPressed:
              submitting
                  ? null
                  : _submit,

              icon:
              submitting
                  ? const SizedBox(
                width:
                18,

                height:
                18,

                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                ),
              )
                  : const Icon(
                Icons
                    .cloud_upload_outlined,
              ),

              label:
              Text(
                submitting
                    ? 'Uploading...'
                    : 'Submit Update',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _message(
      String message,
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
          message,
        ),
      ),
    );
  }
}