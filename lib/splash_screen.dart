// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/database/cleanup_service.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/core/services/push_notification_service.dart';
import 'package:fsi_courier_app/core/services/runtime_environment_service.dart';
import 'package:fsi_courier_app/core/services/version_check_service.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/settings/dashboard_feel_provider.dart';
import 'package:fsi_courier_app/core/settings/debug_ui_provider.dart';
import 'package:fsi_courier_app/core/sync/workmanager_setup.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/auth/widgets/auth_illustration.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'firebase_options.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Fast path: auth + settings check gates navigation.
    _initAndNavigate();
    // Deferred heavy init (Firebase, DB, FCM, Sentry) — fire-and-forget
    // after the first frame so the splash renders instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDeferredInit();
    });
    // Remove the native splash once the first frame is rendered.
    // This creates a seamless handoff from native to Flutter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  Future<void> _initAndNavigate() async {
    await _initialize();
    if (!mounted) return;
    // Brief minimum delay so splash animations have time to play.
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final auth = ref.read(authProvider);
    context.go(auth.isAuthenticated ? '/dashboard' : '/login');
  }

  /// Heavy initialisation deferred to after the first frame so the splash
  /// renders instantly without jank. All errors are swallowed — the app
  /// proceeds with defaults if something fails.
  Future<void> _runDeferredInit() async {
    // Fire all independent heavy init in parallel.
    await Future.wait([
      AppVersionService.init(),
      _initFirebase(),
      AppDatabase.getInstance(),
      BackgroundSyncSetup.init(),
      RuntimeEnvironmentService.instance.init(),
    ], eagerError: false);

    // Release + persisted developer mode: re-sync tools after prefs load.
    if (mounted) {
      ref.read(debugToolsProvider.notifier).syncFromRuntime();
    }

    // Firebase-dependent steps.
    if (mounted) {
      await _initFcmToken();
      PushNotificationService.initBackgroundHandler();
    }

    // Sentry — only when DSN is provided.
    if (mounted && sentryDsn.isNotEmpty) {
      await SentryFlutter.init((options) {
        options.dsn = sentryDsn;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.tracesSampleRate = kReleaseMode ? 0.2 : 0.0;
        options.attachScreenshot = false;
        options.sendDefaultPii = false;
      });
    }
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    } catch (_) {
      // Non-Firebase errors are swallowed — app proceeds without Firebase.
    }
  }

  Future<void> _initFcmToken() async {
    try {
      final earlyToken = await FirebaseMessaging.instance.getToken();
      if (earlyToken != null) {
        final authStorage = AuthStorage();
        await authStorage.setPendingFcmToken(earlyToken);
        debugPrint('[SPLASH] Early FCM token persisted: $earlyToken');
      }
    } catch (e) {
      debugPrint('[SPLASH] Failed to fetch/persist early FCM token: $e');
    }
  }

  Future<void> _initialize() async {
    try {
      // Developer mode must load before debug-tools gate (release + dev path).
      await RuntimeEnvironmentService.instance.init();
      await ref.read(authProvider.notifier).initialize();
      final settings = ref.read(appSettingsProvider);
      final compactMode = await settings.getCompactMode();
      final dashboardFeel = await settings.getDashboardFeel();
      final debugUiVisible = await settings.getDebugUiVisible();
      if (mounted) {
        ref.read(debugToolsProvider.notifier).syncFromRuntime();
        ref.read(compactModeProvider.notifier).setValue(compactMode);
        ref.read(dashboardFeelProvider.notifier).setValue(dashboardFeel);
        ref.read(debugUiProvider.notifier).setValue(debugUiVisible);
      }
      // ignore: discarded_futures
      CleanupService.instance.runIfNeeded(ref.read(appSettingsProvider));
      // Check for forced app updates (best-effort; failures are logged).
      if (mounted) {
        await VersionCheckService(ref.read(apiClientProvider))
            .check(context)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => debugPrint('[SPLASH] Version check timed out'),
            );
      }
    } catch (_) {
      // Keep defaults on error — app proceeds to login.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? DSColors.white : DSColors.labelPrimary;
    final muted = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: DSColors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? DSColors.scaffoldDark
            : const Color(0xFFEAF6EC),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Quieter than login — brand present, not competing with gate UX.
          const DsBrandBackdrop(intensity: DsBackdropIntensity.quiet),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxHeight < 600;
                final logoSize = isSmallScreen ? 96.0 : 112.0;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DSSpacing.lg,
                        vertical: DSSpacing.xl,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Brand mark — softer motion than login (no pulse).
                          AuthLogoMark(
                                size: logoSize,
                                assetPath: AppAssets.fsiIcon,
                                pulse: false,
                              )
                              .animate()
                              .fadeIn(duration: DSAnimations.dNormal)
                              .scale(
                                begin: const Offset(0.72, 0.72),
                                end: const Offset(1, 1),
                                duration: DSAnimations.dHero,
                                curve: Curves.easeOutBack,
                              ),

                          isSmallScreen ? DSSpacing.hLg : DSSpacing.hXl,

                          Text(
                                'splash.title'.tr(),
                                style: DSTypography.display(color: textColor)
                                    .copyWith(
                                      fontSize: isSmallScreen
                                          ? DSTypography.sizeXl * 1.35
                                          : DSTypography.sizeHero,
                                      letterSpacing:
                                          DSTypography.lsExtraLoose *
                                          (isSmallScreen ? 2.5 : 4),
                                    ),
                              )
                              .animate()
                              .fadeIn(
                                delay: 280.ms,
                                duration: DSAnimations.dSlow,
                              )
                              .slideY(
                                begin: 0.18,
                                end: 0,
                                delay: 280.ms,
                                duration: DSAnimations.dSlow,
                                curve: Curves.easeOutCubic,
                              ),

                          DSSpacing.hSm,

                          Text(
                                'splash.tagline'.tr(),
                                textAlign: TextAlign.center,
                                style: DSTypography.label(
                                  color: muted,
                                ).copyWith(letterSpacing: DSTypography.lsWide),
                              )
                              .animate()
                              .fadeIn(
                                delay: 420.ms,
                                duration: DSAnimations.dNormal,
                              )
                              .slideY(
                                begin: 0.12,
                                end: 0,
                                delay: 420.ms,
                                duration: DSAnimations.dNormal,
                              ),

                          isSmallScreen ? DSSpacing.hLg : DSSpacing.hXl,
                          if (!isSmallScreen) DSSpacing.hMd,

                          // Feature chips — glass cards matching auth form.
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DSSpacing.sm,
                            ),
                            child: Wrap(
                              spacing: DSSpacing.sm,
                              runSpacing: DSSpacing.sm,
                              alignment: WrapAlignment.center,
                              children: [
                                _SplashChip(
                                      icon: LucideIcons.truck,
                                      label: 'splash.feature.accept'.tr(),
                                    )
                                    .animate()
                                    .fadeIn(
                                      delay:
                                          DSAnimations.stagger(
                                            1,
                                            step: DSAnimations.staggerCoarse,
                                          ) +
                                          500.ms,
                                      duration: DSAnimations.dNormal,
                                    )
                                    .scale(
                                      begin: const Offset(0.88, 0.88),
                                      end: const Offset(1, 1),
                                      delay:
                                          DSAnimations.stagger(
                                            1,
                                            step: DSAnimations.staggerCoarse,
                                          ) +
                                          500.ms,
                                      duration: DSAnimations.dNormal,
                                      curve: Curves.easeOutBack,
                                    ),
                                _SplashChip(
                                      icon: LucideIcons.package,
                                      label: 'splash.feature.deliver'.tr(),
                                    )
                                    .animate()
                                    .fadeIn(
                                      delay:
                                          DSAnimations.stagger(
                                            2,
                                            step: DSAnimations.staggerCoarse,
                                          ) +
                                          500.ms,
                                      duration: DSAnimations.dNormal,
                                    )
                                    .scale(
                                      begin: const Offset(0.88, 0.88),
                                      end: const Offset(1, 1),
                                      delay:
                                          DSAnimations.stagger(
                                            2,
                                            step: DSAnimations.staggerCoarse,
                                          ) +
                                          500.ms,
                                      duration: DSAnimations.dNormal,
                                      curve: Curves.easeOutBack,
                                    ),
                                _SplashChip(
                                      icon: LucideIcons.wallet,
                                      label: 'splash.feature.payout'.tr(),
                                    )
                                    .animate()
                                    .fadeIn(
                                      delay:
                                          DSAnimations.stagger(
                                            3,
                                            step: DSAnimations.staggerCoarse,
                                          ) +
                                          500.ms,
                                      duration: DSAnimations.dNormal,
                                    )
                                    .scale(
                                      begin: const Offset(0.88, 0.88),
                                      end: const Offset(1, 1),
                                      delay:
                                          DSAnimations.stagger(
                                            3,
                                            step: DSAnimations.staggerCoarse,
                                          ) +
                                          500.ms,
                                      duration: DSAnimations.dNormal,
                                      curve: Curves.easeOutBack,
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer — loader + brand
          Positioned(
            left: 0,
            right: 0,
            bottom: DSSpacing.xl,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SpinKitThreeBounce(
                        color: DSColors.primary,
                        size: DSIconSize.md,
                      )
                      .animate()
                      .fadeIn(delay: 900.ms, duration: DSAnimations.dNormal)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                        delay: 900.ms,
                        duration: DSAnimations.dNormal,
                      ),
                  DSSpacing.hMd,
                  Text(
                    'splash.footer_brand'.tr(),
                    style: DSTypography.caption(color: muted).copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: DSTypography.lsWide,
                    ),
                  ).animate().fadeIn(
                    delay: 1050.ms,
                    duration: DSAnimations.dNormal,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass feature chip — same surface language as auth form cards.
class _SplashChip extends StatelessWidget {
  const _SplashChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(
        vertical: DSSpacing.md,
        horizontal: DSSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? DSColors.cardElevatedDark.withValues(alpha: 0.90)
            : DSColors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(DSStyles.radius2XL),
        border: Border.all(
          color: isDark
              ? DSColors.white.withValues(alpha: 0.10)
              : DSColors.primary.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: DSColors.primary.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: DSColors.primary.withValues(alpha: DSStyles.alphaSubtle),
              borderRadius: DSStyles.pillRadius,
            ),
            child: Icon(icon, color: DSColors.primary, size: DSIconSize.md),
          ),
          DSSpacing.hSm,
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                DSTypography.label(
                  color: isDark ? DSColors.white : DSColors.labelPrimary,
                ).copyWith(
                  fontSize: DSTypography.sizeXs,
                  fontWeight: FontWeight.w600,
                  letterSpacing: DSTypography.lsWide,
                ),
          ),
        ],
      ),
    );
  }
}
