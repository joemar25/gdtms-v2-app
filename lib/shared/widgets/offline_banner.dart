// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ConnectionStatusBanner  (canonical, self-contained)
// ─────────────────────────────────────────────────────────────────────────────

/// The canonical connection-status notification widget.
///
/// Drop it into any screen/list and it will self-manage visibility:
/// - **Online** (`ConnectionStatus.online`) → renders nothing (zero height).
/// - **No internet** (`ConnectionStatus.networkOffline`) → warning banner with
///   `wifi_off` icon and a "no internet" message.
/// - **Server unavailable** (`ConnectionStatus.apiUnreachable`) → warning banner
///   with `cloud_off` icon and a "server unavailable" message.
///
/// The two failure modes are always shown distinctly so users know whether to
/// check their own connection or wait for the server to recover.
///
/// ### Usage
/// ```dart
/// // Full-page context (e.g. profile, wallet)
/// const ConnectionStatusBanner(),
///
/// // List context — compact single-line variant
/// const ConnectionStatusBanner(isMinimal: true),
///
/// // Custom message for minimal variant only
/// ConnectionStatusBanner(
///   isMinimal: true,
///   customOfflineMessage: 'Showing cached data',
///   customApiMessage: 'Unable to sync — server offline',
/// ),
/// ```
///
/// ### Migration from OfflineBanner
/// Replace every `if (!isOnline) OfflineBanner(...)` block with a single
/// `ConnectionStatusBanner(...)`.  The widget handles its own hide/show logic.
class ConnectionStatusBanner extends ConsumerWidget {
  const ConnectionStatusBanner({
    super.key,
    this.isMinimal = false,
    this.customOfflineMessage,
    this.customApiMessage,
    this.margin,
  });

  /// Shows the compact single-line variant (for list pages, update screens).
  final bool isMinimal;

  /// Overrides the network-offline message. Applies only when [isMinimal] is
  /// true; the full-page variant always shows its canonical copy.
  final String? customOfflineMessage;

  /// Overrides the API-unreachable message. Applies only when [isMinimal] is
  /// true.
  final String? customApiMessage;

  /// Outer margin. Defaults to `bottom: 16` for full-page, `EdgeInsets.zero`
  /// for minimal so the caller controls spacing.
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);

    if (status == ConnectionStatus.online) return const SizedBox.shrink();

    final isApiError = status == ConnectionStatus.apiUnreachable;
    final effectiveMargin =
        margin ??
        (isMinimal ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16));

    if (isMinimal) {
      final message = isApiError
          ? (customApiMessage ?? 'Server unavailable')
          : (customOfflineMessage ?? 'No internet connection');
      return _MinimalBanner(
        message: message,
        isApiError: isApiError,
        margin: effectiveMargin,
      );
    }

    return _StandardBanner(isApiError: isApiError, margin: effectiveMargin);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OfflineBanner  (legacy alias — kept so existing callers still compile)
// ─────────────────────────────────────────────────────────────────────────────

/// Legacy alias for [ConnectionStatusBanner].
///
/// **Deprecated** — prefer [ConnectionStatusBanner] for new code; it requires
/// no `if (!isOnline)` guard and distinguishes network-offline from
/// API-unreachable automatically.
///
/// Existing callers that pass `customMessage` to the minimal variant will
/// continue to work; the message is forwarded as the network-offline copy.
/// For the API-unreachable message add `customApiMessage` via the new widget.
@Deprecated('Use ConnectionStatusBanner instead.')
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({
    super.key,
    this.isMinimal = false,
    this.customMessage,
    this.margin,
  });

  final bool isMinimal;
  final String? customMessage;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConnectionStatusBanner(
      isMinimal: isMinimal,
      customOfflineMessage: customMessage,
      margin: margin,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private internals
// ─────────────────────────────────────────────────────────────────────────────

class _MinimalBanner extends StatelessWidget {
  const _MinimalBanner({
    required this.message,
    required this.isApiError,
    required this.margin,
  });

  final String message;
  final bool isApiError;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: DSSpacing.md),
      decoration: BoxDecoration(
        color: DSColors.warning.withValues(alpha: DSStyles.alphaSubtle),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isApiError ? Icons.cloud_off_rounded : Icons.wifi_off_rounded,
            size: DSIconSize.sm,
            color: DSColors.warning,
          ),
          DSSpacing.wSm,
          Expanded(
            child: Text(
              message,
              style: DSTypography.label(color: DSColors.warning).copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardBanner extends StatelessWidget {
  const _StandardBanner({required this.isApiError, required this.margin});

  final bool isApiError;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final icon = isApiError ? Icons.cloud_off_rounded : Icons.wifi_off_rounded;
    final title = isApiError ? 'Server unavailable' : "You're offline";
    final body = isApiError
        ? 'Your device is connected to the internet, but the server cannot '
              'be reached. Please try again later.'
        : 'Local preferences (theme, compact mode, auto-accept) still work. '
              'Dispatch scanning and data sync require an internet connection.';

    return Container(
      margin: margin,
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: DSColors.warning.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DSColors.warning, size: DSIconSize.lg),
          DSSpacing.wMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DSTypography.label(color: DSColors.warning).copyWith(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                DSSpacing.hXs,
                Text(
                  body,
                  style: DSTypography.body(color: DSColors.warning).copyWith(
                    fontSize: DSTypography.sizeSm,
                    height: DSStyles.heightNormal,
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
