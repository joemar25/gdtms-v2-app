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
//   • Online-only — profile updates require an active internet connection.
//     No sync queue is used; all changes are sent immediately via direct API.
//   • Profile picture — picked from gallery, uploaded via POST /me/media
//     (S3 or API fallback), then the returned URL is included in the PATCH.
//   • Form fields — validated before submission; changes are sent via
//     PATCH /me.
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/helpers/formatters.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

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
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

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

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      showErrorNotification(
        context,
        'Profile updates require an internet connection.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final api = ref.read(apiClientProvider);

      final payload = <String, dynamic>{
        'name': _usernameController.text.trim(),
        'first_name': _firstNameController.text.trim().toUpperCase(),
        'middle_name': _middleNameController.text.trim().toUpperCase(),
        'last_name': _lastNameController.text.trim().toUpperCase(),
        'email': _emailController.text.trim(),
      };

      // Upload profile picture first if changed, then include the returned URL.
      if (_profileImage != null) {
        final bytes = await _profileImage!.readAsBytes();
        final uploadResult = await api.uploadMedia<Map<String, dynamic>>(
          '/me/media',
          bytes: bytes,
          filename: 'profile_picture.jpg',
          type: 'profile_picture',
          parser: (d) {
            if (d is Map<String, dynamic>) return d;
            if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
            return <String, dynamic>{};
          },
        );
        if (uploadResult is ApiSuccess<Map<String, dynamic>>) {
          final inner = uploadResult.data['data'];
          final url =
              (inner is Map
                      ? inner['url'] ?? inner['profile_picture_url']
                      : uploadResult.data['url'])
                  ?.toString();
          if (url != null && url.isNotEmpty) {
            payload['profile_picture_url'] = url;
          }
        } else {
          if (!mounted) return;
          showErrorNotification(
            context,
            'Profile picture upload failed. Text changes will still be saved.',
          );
        }
      }

      final result = await api.patch<Map<String, dynamic>>(
        '/me',
        data: payload,
        parser: parseApiMap,
      );

      if (!mounted) return;

      if (result is ApiSuccess<Map<String, dynamic>>) {
        final data = result.data['data'];
        if (data is Map<String, dynamic>) {
          await ref.read(authProvider.notifier).setAuthenticated(courier: data);
        }
        if (!mounted) return;
        showSuccessNotification(context, 'Profile updated successfully.');
        Navigator.pop(context);
      } else {
        final msg = switch (result) {
          ApiValidationError<Map<String, dynamic>>(:final message) =>
            message ?? 'Validation failed.',
          ApiBadRequest<Map<String, dynamic>>(:final message) => message,
          ApiNetworkError<Map<String, dynamic>>(:final message) => message,
          _ => 'Failed to update profile.',
        };
        showErrorNotification(context, msg);
      }
    } catch (e) {
      if (mounted) showErrorNotification(context, 'Failed to save changes: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courier = ref.watch(authProvider).courier;
    final currentProfilePic = courier?['profile_picture_url']?.toString();

    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: const AppHeaderBar(title: 'Edit Profile'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            DSSpacing.xl,
            DSSpacing.xxl,
            DSSpacing.xl,
            DSSpacing.xxxl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Profile Picture ──────────────────────────────────────
                Center(
                  child:
                      GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? DSColors.secondarySurfaceDark
                                        : DSColors.secondarySurfaceLight,
                                    border: Border.all(
                                      color: DSColors.primary.withValues(
                                        alpha: 0.40,
                                      ),
                                      width: 2.5,
                                    ),
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
                                    boxShadow: DSStyles.shadowSoft(context),
                                  ),
                                  child:
                                      _profileImage == null &&
                                          (currentProfilePic == null ||
                                              currentProfilePic.isEmpty)
                                      ? Icon(
                                          Icons.person_rounded,
                                          size: 50,
                                          color: isDark
                                              ? DSColors.labelTertiaryDark
                                              : DSColors.labelTertiary,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(DSSpacing.sm),
                                    decoration: const BoxDecoration(
                                      color: DSColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1, 1),
                          ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap to change photo',
                    style: DSTypography.caption().copyWith(
                      fontSize: DSTypography.sizeSm,
                      color: isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Username ─────────────────────────────────────────────
                _fieldLabel('Username'),
                const SizedBox(height: DSSpacing.sm),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    hintText: 'Your display name',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Username is required' : null,
                ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 16),

                // ── First Name ───────────────────────────────────────────
                _fieldLabel('First Name'),
                const SizedBox(height: DSSpacing.sm),
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseFormatter()],
                  decoration: const InputDecoration(hintText: 'e.g. JUAN'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'First name is required' : null,
                ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 16),

                // ── Middle Name ──────────────────────────────────────────
                _fieldLabel('Middle Name'),
                const SizedBox(height: DSSpacing.sm),
                TextFormField(
                  controller: _middleNameController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseFormatter()],
                  decoration: const InputDecoration(hintText: 'Optional'),
                ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 16),

                // ── Last Name ────────────────────────────────────────────
                _fieldLabel('Last Name'),
                const SizedBox(height: DSSpacing.sm),
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseFormatter()],
                  decoration: const InputDecoration(hintText: 'e.g. DELA CRUZ'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Last name is required' : null,
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                const SizedBox(height: 16),

                // ── Email ────────────────────────────────────────────────
                _fieldLabel('Email'),
                const SizedBox(height: DSSpacing.sm),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                  ),
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
                const SizedBox(height: 32),

                // ── Save Button ──────────────────────────────────────────
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: DSStyles.cardRadius,
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: DSTypography.button().copyWith(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms).scaleXY(begin: 0.95, end: 1),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: DSTypography.label().copyWith(
        fontSize: DSTypography.sizeMd,
        fontWeight: FontWeight.w600,
        color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
      ),
    );
  }
}
