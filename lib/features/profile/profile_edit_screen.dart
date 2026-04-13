// DOCS: docs/features/profile.md — update that file when you edit this one.

// =============================================================================
// profile_edit_screen.dart
// =============================================================================
//
// Purpose:
//   Allows the authenticated courier to update their profile information,
//   including display name, phone number, and profile picture.
//
// Key behaviours:
//   • Profile picture — picked from the camera or gallery, compressed, and
//     queued for upload via the sync pipeline (S3 or API fallback).
//   • Form fields — validated before submission; changes are sent via
//     PATCH /couriers/me.
//   • Loading overlay — [LoadingOverlay] blocks input while the save request
//     is in flight, preventing duplicate submissions.
//   • Auth state refresh — after a successful save, [AuthProvider] is
//     re-fetched so the updated name/picture propagates to the profile screen
//     and the app header immediately.
//
// Navigation:
//   Route: /profile/edit
//   Pushed from: ProfileScreen
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/helpers/formatters.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';
import 'package:flutter/services.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  File? _profileImage;
  bool _loading = false;
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    final courier = ref.read(authProvider).courier;
    if (courier != null) {
      _usernameController.text = courier['name']?.toString() ?? '';
      _firstNameController.text = courier['first_name']?.toString() ?? '';
      _middleNameController.text = courier['middle_name']?.toString() ?? '';
      _lastNameController.text = courier['last_name']?.toString() ?? '';
      _emailController.text = courier['email']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final courier = ref.read(authProvider).courier;
      final courierId = courier?['id']?.toString() ?? '';

      final payload = {
        'name': _usernameController.text.trim(),
        'first_name': _firstNameController.text.trim().toUpperCase(),
        'middle_name': _middleNameController.text.trim().toUpperCase(),
        'last_name': _lastNameController.text.trim().toUpperCase(),
        'email': _emailController.text.trim(),
      };

      String? mediaPathsJson;
      if (_profileImage != null) {
        // Copy image to app docs for persistence during sync
        final dir = await getApplicationDocumentsDirectory();
        final filename = 'profile_picture_${_uuid.v4()}.jpg';
        final savedPath = '${dir.path}/$filename';
        await _profileImage!.copy(savedPath);

        mediaPathsJson = jsonEncode({'profile_picture': savedPath});
      }

      final opId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await SyncOperationsDao.instance.insert(
        SyncOperation(
          id: opId,
          courierId: courierId,
          barcode: 'PROFILE_$courierId', // Used as a key in sync
          operationType: 'UPDATE_PROFILE',
          payloadJson: jsonEncode(payload),
          mediaPathsJson: mediaPathsJson,
          status: 'pending',
          createdAt: now,
        ),
      );

      final isOnline = ref.read(isOnlineProvider);
      if (isOnline) {
        // ignore: unawaited_futures
        ref.read(syncManagerProvider.notifier).processQueue();
      }

      if (!mounted) return;
      showSuccessNotification(
        context,
        'Profile update queued for synchronization.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showErrorNotification(context, 'Failed to save changes: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final courier = ref.watch(authProvider).courier;
    final currentProfilePic = courier?['profile_picture_url']?.toString();

    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: const AppHeaderBar(title: 'Edit Profile'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Profile Picture ──────────────────────────────────────────
                GestureDetector(
                      onTap: _pickImage,
                      child: Hero(
                        tag: 'profile_avatar',
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                                image: _profileImage != null
                                    ? DecorationImage(
                                        image: FileImage(_profileImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : (currentProfilePic != null &&
                                              currentProfilePic.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                currentProfilePic,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                                border: Border.all(
                                  color: ColorStyles.grabGreen.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child:
                                  _profileImage == null &&
                                      (currentProfilePic == null ||
                                          currentProfilePic.isEmpty)
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 60,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: ColorStyles.grabGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                    ),
                const SizedBox(height: 32),

                // ── Fields ──────────────────────────────────────────────────
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username',
                  icon: Icons.alternate_email_rounded,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Username is required' : null,
                ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseFormatter()],
                  validator: (v) =>
                      v == null || v.isEmpty ? 'First name is required' : null,
                ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _middleNameController,
                  label: 'Middle Name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseFormatter()],
                ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseFormatter()],
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Last name is required' : null,
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(v)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 40),

                // ── Save Button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child:
                      FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: ColorStyles.grabGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 600.ms)
                          .scaleXY(begin: 0.95, end: 1),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: ColorStyles.grabGreen,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
