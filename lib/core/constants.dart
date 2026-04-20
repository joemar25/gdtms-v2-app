// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:fsi_courier_app/core/models/delivery_status.dart';

/// Single source of truth for all asset paths used in the app.
/// Update this class (and assets/mar.md) when adding or renaming assets.
abstract final class AppAssets {
  // ── Images ───────────────────────────────────────────────────────────────
  static const String logo = 'assets/logo.png';
  static const String icon = 'assets/favicon-32x32.png';

  // ── Animations ───────────────────────────────────────────────────────────
  static const String animHourGlass = 'assets/anim/hour-glass.json';
  static const String animSuccess = 'assets/anim/successfully-done.json';
  static const String animEmpty = 'assets/anim/empty.json';

  // ── Legal ────────────────────────────────────────────────────────────────
  static const String legalTerms = 'assets/legal/terms.md';
  static const String legalPrivacy = 'assets/legal/privacy.md';
}

const int kDashboardPerPage = 5;
const int kDeliveriesPerPage = 5;
const int kCompletedPerPage = 5;
const int kDispatchesPerPage = 5;

const int kCompactDashboardPerPage = 15;
const int kCompactDeliveriesPerPage = 15;
const int kCompactCompletedPerPage = 15;
const int kCompactDispatchesPerPage = 15;

const int kMaxDeliveryImages = 10;
const int kMaxNoteLength = 500;
const int kMaxReasonLength = 500;
const int kMaxRecipientLength = 255;
const int kMaxRelationshipLength = 100;
const int kMaxPlacementTypeLength = 100;

/// Statuses the courier can submit via the update form.
/// Derived from [DeliveryStatus] — do not hardcode strings here.
final List<String> kUpdateStatuses = [
  DeliveryStatus.delivered.toApiString(),
  DeliveryStatus.failedDelivery.toApiString(),
  DeliveryStatus.osa.toApiString(),
];

/// Full set of delivery statuses known to the app.
/// Derived from [DeliveryStatus] — do not hardcode strings here.
final List<String> kAllDeliveryStatuses = [
  DeliveryStatus.pending.toApiString(),
  DeliveryStatus.delivered.toApiString(),
  DeliveryStatus.failedDelivery.toApiString(),
  DeliveryStatus.osa.toApiString(),
];

/// Pre-defined photo types for delivered POD capture.
/// Exactly two slots: one for the package (POD) and one for the courier selfie.
const List<String> kPodDeliveredTypes = ['POD', 'SELFIE'];

// ─────────────────────────────────────────────────────────────────────────────
// REASON CONFIGURATION
//
// Each [ReasonConfig] entry describes one non-delivery reason and how the UI
// should behave when it is selected:
//
//   requiresAccordingTo  – show the "According to" (informant) field
//   remarksPresets       – chip presets shown above the free-text remarks field
//                          ([] → no chips; every known reason has its own list)
//
// RULES:
//   • [kReasonConfigs] is the single source of truth — do not hardcode reason
//     strings anywhere else in the codebase.
//   • [kReasons] is derived from [kReasonConfigs] — do not maintain separately.
//   • Every reason has its own dedicated [remarksPresets] list defined below.
//   • [kNonDeliveredNotePresets] has been retired; there is no shared fallback.
// ─────────────────────────────────────────────────────────────────────────────

/// Configuration for a single non-delivery reason.
class ReasonConfig {
  const ReasonConfig({
    this.requiresAccordingTo = false,
    this.remarksPresets = const [],
  });

  /// Whether the "According to (name of informant)" field should be shown.
  final bool requiresAccordingTo;

  /// Chip presets for the remarks field.
  /// Empty list → no chips shown.
  final List<String> remarksPresets;
}

// ─────────────────────────────────────────────────────────────────────────────
// REASON-SPECIFIC REMARKS PRESETS
// ─────────────────────────────────────────────────────────────────────────────

const List<String> kRemarksCompanyMovedOut = [
  'According to guard, company has moved out',
  'According to neighbor, company has relocated',
  'According to building admin, unit is vacant',
  'Office/unit is empty',
  'No forwarding address left',
];

const List<String> kRemarksDeceased = [
  'According to family member, recipient is deceased',
  'According to neighbor, recipient has passed away',
  'According to guard, recipient is deceased',
];

const List<String> kRemarksHardToDeliver = [
  'According to resident, area is hard to access',
  'Road is flooded / impassable',
  'No vehicle access to the area',
  'Address is in a gated community, no entry allowed',
  'Location is too far from main road',
];

const List<String> kRemarksInsufficientAddress = [
  'No House Number',
  'No Barangay/Purok Number',
  'No Street Name',
  'No Block and Lot Number',
  'No Phase Number',
  'No Subdivision Name',
  'No Company Name',
  'No Unit Number',
  'No City/Municipality Name',
];

const List<String> kRemarksMovedOut = [
  'Resident has moved out',
  'No forwarding address left',
  'Mailbox is empty / abandoned',
];

const List<String> kRemarksNoOneToReceive = [
  'According to neighbor, no one is home',
  'According to guard, resident is out',
  'Called recipient, no answer',
  'Knocked multiple times, no response',
  'Gate or door is locked',
];

const List<String> kRemarksPersonMovedOut = [
  'According to neighbor, person has moved out',
  'According to guard, person no longer lives here',
  'According to landlord, person has vacated',
  'According to family, person has moved out',
  'No forwarding address left',
];

const List<String> kRemarksRefusedToAccept = [
  'According to recipient, item was not ordered',
  'According to recipient, item is damaged',
  'According to recipient, wrong item received',
  'Recipient refused without reason',
  'Recipient is disputing the COD amount',
];

const List<String> kRemarksRequestForRedeliver = [
  'Customer requested reschedule',
  'Customer set a preferred delivery date',
  'Customer requested delivery to a different address',
];

const List<String> kRemarksRiskyArea = [
  'According to resident, area is not safe',
  'According to guard, entry is not allowed',
  'Area flagged as high-risk by operations',
  'No safe place to leave item',
  'Security / guard refused courier entry',
];

const List<String> kRemarksUnknownPerson = [
  'According to resident, person is unknown',
  'According to neighbor, no such person in the area',
  'According to guard, no such person on record',
  'Name does not match any unit/house in the address',
];

const List<String> kRemarksWrongAddress = [
  'According to resident, address does not exist',
  'According to neighbor, no such address in the area',
  'According to guard, address is incorrect',
  'House/unit number does not match',
  'Street name does not exist in the area',
];

const List<String> kRemarksMisrouted = [
  'Package misrouted to wrong area',
  // 'Barcode does not match route assignment',
  // 'Address is outside serviceable area',
  // 'Package belongs to a different courier zone',
  // 'Endorsing to correct area/branch',
];

// ─────────────────────────────────────────────────────────────────────────────
// REASON CONFIGS MAP
// ─────────────────────────────────────────────────────────────────────────────

/// Master reason list with per-reason UI behaviour.
///
/// ⚠️  [kReasons] below is derived from this map — do not maintain both
/// separately.
const Map<String, ReasonConfig> kReasonConfigs = {
  // ── Requires "According to" ───────────────────────────────────────────────
  'Company Moved Out': ReasonConfig(
    requiresAccordingTo: true,
    remarksPresets: kRemarksCompanyMovedOut,
  ),
  'Deceased': ReasonConfig(
    requiresAccordingTo: true,
    remarksPresets: kRemarksDeceased,
  ),
  'Hard to Deliver': ReasonConfig(
    requiresAccordingTo: true,
    remarksPresets: kRemarksHardToDeliver,
  ),
  'No One to Receive': ReasonConfig(
    requiresAccordingTo: true,
    remarksPresets: kRemarksNoOneToReceive,
  ),
  'Person Moved Out': ReasonConfig(
    requiresAccordingTo: true,
    remarksPresets: kRemarksPersonMovedOut,
  ),
  'Refused to Accept': ReasonConfig(
    requiresAccordingTo: true,
    remarksPresets: kRemarksRefusedToAccept,
  ),
  'Risky Area': ReasonConfig(
    requiresAccordingTo: true,
    remarksPresets: kRemarksRiskyArea,
  ),
  'Wrong Address': ReasonConfig(
    requiresAccordingTo: true,
    remarksPresets: kRemarksWrongAddress,
  ),

  // ── No "According to" ─────────────────────────────────────────────────────
  'Insufficient Address': ReasonConfig(
    remarksPresets: kRemarksInsufficientAddress,
  ),
  'Moved Out': ReasonConfig(remarksPresets: kRemarksMovedOut),
  'Request for Redeliver': ReasonConfig(
    remarksPresets: kRemarksRequestForRedeliver,
  ),
  'Unknown Person': ReasonConfig(remarksPresets: kRemarksUnknownPerson),
};

/// Ordered list of reason labels for dropdowns / radio lists.
/// Derived from [kReasonConfigs] — do not hardcode separately.
final List<String> kReasons = kReasonConfigs.keys.toList()..sort();

/// Config for the OSA (Misrouted) status — no reason picker, mailpack photo required.
const ReasonConfig kOsaConfig = ReasonConfig(remarksPresets: kRemarksMisrouted);

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERED NOTE PRESETS
// ─────────────────────────────────────────────────────────────────────────────

/// Quick-select note presets shown as chips for successfully delivered items.
const List<String> kDeliveredNotePresets = [
  'Received by Cardholder/Owner',
  'Package in good condition',
  'Allowed by ch/owner',
  'Received by guard',
  'Received by receptionist',
  'Left at front door',
  'Contacted recipient',
  'Safe drop',
];

// ─────────────────────────────────────────────────────────────────────────────
// RELATIONSHIP & PLACEMENT OPTIONS
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, String>> kRelationshipOptions = [
  {'value': 'AUNT', 'label': 'AUNT'},
  {'value': 'BROTHER', 'label': 'BROTHER'},
  {'value': 'BROTHER-IN-LAW', 'label': 'BROTHER-IN-LAW'},
  {'value': 'CARETAKER', 'label': 'CARETAKER'},
  {'value': 'CO-EMPLOYEE', 'label': 'CO-EMPLOYEE'},
  {'value': 'COUSIN', 'label': 'COUSIN'},
  {'value': 'DAUGHTER', 'label': 'DAUGHTER'},
  {'value': 'DAUGHTER-IN-LAW', 'label': 'DAUGHTER-IN-LAW'},
  // {'value': 'DRIVER', 'label': 'DRIVER'},
  {'value': 'EMPLOYEE', 'label': 'EMPLOYEE'},
  {'value': 'FATHER', 'label': 'FATHER'},
  {'value': 'FATHER-IN-LAW', 'label': 'FATHER-IN-LAW'},
  {'value': 'GUARD', 'label': 'GUARD'},
  {'value': 'HELPER', 'label': 'HELPER'},
  // {'value': 'HOUSEHELP', 'label': 'HOUSEHELP'}, -- not needed and confusing
  {'value': 'LANDLORD_LANDLADY', 'label': 'LANDLORD / LANDLADY'},
  {'value': 'HUSBAND', 'label': 'HUSBAND'},
  {'value': 'MAID', 'label': 'MAID'},
  {'value': 'MOTHER', 'label': 'MOTHER'},
  {'value': 'MOTHER-IN-LAW', 'label': 'MOTHER-IN-LAW'},
  // {'value': 'NEIGHBOR', 'label': 'NEIGHBOR'}, -- has cases that some owners can be attacked by neighbor
  {'value': 'NEPHEW', 'label': 'NEPHEW'},
  {'value': 'NIECE', 'label': 'NIECE'},
  {'value': 'OWNER', 'label': 'OWNER'},
  // {'value': 'RECEPTIONIST', 'label': 'RECEPTIONIST'},
  {'value': 'RELATIVE', 'label': 'RELATIVE'},
  // {'value': 'SECURITY_GUARD', 'label': 'SECURITY GUARD'},
  {'value': 'GUARD', 'label': 'GUARD'},
  {'value': 'SISTER', 'label': 'SISTER'},
  {'value': 'SISTER-IN-LAW', 'label': 'SISTER-IN-LAW'},
  {'value': 'SON', 'label': 'SON'},
  {'value': 'SON-IN-LAW', 'label': 'SON-IN-LAW'},
  // {'value': 'SPOUSE', 'label': 'SPOUSE'},
  // {'value': 'STAFF', 'label': 'STAFF'},
  {'value': 'TENANT', 'label': 'TENANT'},
  {'value': 'UNCLE', 'label': 'UNCLE'},
  {'value': 'WIFE', 'label': 'WIFE'},
  // ── catch-all — always last ──────────────────────────────────────────────
  // {'value': 'OTHERS', 'label': 'OTHERS — Please Specify'},
];

const List<Map<String, String>> kPlacementOptions = [
  {'value': 'RECEIVED', 'label': 'Received'},
  {'value': 'MAILBOX', 'label': 'Mailbox'},
  {'value': 'INSERTED_DOOR', 'label': 'Inserted - Door'},
  {'value': 'INSERTED_WINDOW', 'label': 'Inserted - Window'},
];

// ─────────────────────────────────────────────────────────────────────────────
// MISC
// ─────────────────────────────────────────────────────────────────────────────

const String kDeviceTypeLogin = 'flutter';

/// Number of days that successfully synchronised delivery records are kept in
/// SQLite before the cleanup service removes them.
/// Adjust this value to balance local storage usage against review window.
///
/// mar-note: Unpaid delivered items are visible on the dashboard/list for up
/// to 3 days so the courier can verify and request payout. Once paid, the
/// record switches to the shorter [kPaidDeliveryRetentionDays] window.
const int kLocalDataRetentionDays = 3;

/// Number of days a **paid** delivery record is retained in SQLite after its
/// payout is marked as paid, before the cleanup service permanently deletes it.
///
/// mar-note: SECURITY / ANTI-FRAUD RULE — once a courier's payout is marked
/// paid by the server the associated delivered records are kept for exactly
/// 1 day then permanently deleted from the device.
///
/// The intent is to prevent couriers from manipulating or re-submitting already
/// paid records (e.g. to claim double payout). After the 1-day window:
///   • The record no longer appears on dashboard, delivery list, or search.
///   • Scanning the barcode or opening it via payout/wallet shows nothing —
///     the app treats it as if the delivery never existed locally.
///   • Any attempt to retrieve it (barcode scan, wallet history, payout
///     request) will find no local row; the server is the final source of truth.
///
/// This value intentionally overrides [kLocalDataRetentionDays] for records
/// where [local_deliveries.paid_at] is non-null (≥ 1).
const int kPaidDeliveryRetentionDays = 1;

/// Default number of days to keep synced delivery-update queue entries.
/// Couriers can change this in Profile → Preferences → Sync history.
const int kDefaultSyncRetentionDays = 1;

/// Maximum days a courier can configure for sync-queue history retention.
const int kMaxSyncRetentionDays = 5;
