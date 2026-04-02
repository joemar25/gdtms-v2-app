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

const List<String> kUpdateStatuses = ['DELIVERED', 'RTS', 'OSA'];

const List<String> kAllDeliveryStatuses = [
  'PENDING',
  'DELIVERED',
  'FAILED_ATTEMPT',
  'RTS',
  'OSA',
  'ROLL-BACK',
  'LOST',
  'UNDELIVERED',
];

const List<String> kImageTypes = [
  'PACKAGE',
  'RECIPIENT',
  'LOCATION',
  'DAMAGE',
  'OTHER',
];

/// Pre-defined photo types for delivered POD capture.
/// Exactly two slots: one for the package (POD) and one for the courier selfie.
const List<String> kPodDeliveredTypes = ['POD', 'SELFIE'];

/// Reasons for non-delivery (RTS / OSA).
/// Sorted alphabetically; 'Others' is always last to keep it easy to scan.
const List<String> kReasons = [
  'Closed / No Business',
  'Company Moved Out',
  'Deceased',
  'Hard to Deliver',
  'Incomplete Address',
  'Incorrect Address',
  'Insufficient Address',
  'Moved Out',
  'No One to Receive',
  'Out of Scope',
  'Person Moved Out',
  'Recipient Not Around',
  'Refused to Accept',
  'Request to Redeliver',
  'Risky Area',
  'Unknown Address',
  'Unknown Person',
  'Unlocated',
  'Wrong Address',
  // ── catch-all — always last ──────────────────────────────────────────────
  'Others',
];

/// Quick-select note presets shown as chips above the free-text remarks field.
/// Splitted into Delivered (Positive) and RTS/OSA (Negative) remarks.

const List<String> kDeliveredNotePresets = [
  'Received by Cardholder/Owner',
  'Package in good condition',
  'Received by guard',
  'Received by receptionist',
  'Left at front door',
  'Contacted recipient',
  'Safe drop',
];

const List<String> kNonDeliveredNotePresets = [
  'Closed / No Business',
  'Company Moved Out',
  'Deceased',
  'Hard to Deliver',
  'Incomplete Address',
  'Incorrect Address',
  'Insufficient Address',
  'Moved Out',
  'No One to Receive',
  'Out of Scope',
  'Person Moved Out',
  'Recipient Not Around',
  'Refused to Accept',
  'Request to Redeliver',
  'Risky Area',
  'Unknown Address',
  'Unknown Person',
  'Unlocated',
  'Wrong Address',
];

const List<Map<String, String>> kRelationshipOptions = [
  {'value': 'AUNT', 'label': 'AUNT'},
  {'value': 'BROTHER', 'label': 'BROTHER'},
  {'value': 'BROTHER-IN-LAW', 'label': 'BROTHER-IN-LAW'},
  {'value': 'CARETAKER', 'label': 'CARETAKER'},
  {'value': 'CO-EMPLOYEE', 'label': 'CO-EMPLOYEE'},
  {'value': 'COUSIN', 'label': 'COUSIN'},
  {'value': 'DAUGHTER', 'label': 'DAUGHTER'},
  {'value': 'DAUGHTER-IN-LAW', 'label': 'DAUGHTER-IN-LAW'},
  {'value': 'DRIVER', 'label': 'DRIVER'},
  {'value': 'EMPLOYEE', 'label': 'EMPLOYEE'},
  {'value': 'FATHER', 'label': 'FATHER'},
  {'value': 'FATHER-IN-LAW', 'label': 'FATHER-IN-LAW'},
  {'value': 'GUARD', 'label': 'GUARD'},
  {'value': 'HELPER', 'label': 'HELPER'},
  {'value': 'HOUSEHELP', 'label': 'HOUSEHELP'},
  {'value': 'HUSBAND', 'label': 'HUSBAND'},
  {'value': 'MAID', 'label': 'MAID'},
  {'value': 'MOTHER', 'label': 'MOTHER'},
  {'value': 'MOTHER-IN-LAW', 'label': 'MOTHER-IN-LAW'},
  {'value': 'NEIGHBOR', 'label': 'NEIGHBOR'},
  {'value': 'NEPHEW', 'label': 'NEPHEW'},
  {'value': 'NIECE', 'label': 'NIECE'},
  {'value': 'OWNER', 'label': 'OWNER'},
  {'value': 'RECEPTIONIST', 'label': 'RECEPTIONIST'},
  {'value': 'RELATIVE', 'label': 'RELATIVE'},
  {'value': 'SECURITY_GUARD', 'label': 'SECURITY GUARD'},
  {'value': 'SISTER', 'label': 'SISTER'},
  {'value': 'SISTER-IN-LAW', 'label': 'SISTER-IN-LAW'},
  {'value': 'SON', 'label': 'SON'},
  {'value': 'SON-IN-LAW', 'label': 'SON-IN-LAW'},
  {'value': 'SPOUSE', 'label': 'SPOUSE'},
  {'value': 'STAFF', 'label': 'STAFF'},
  {'value': 'TENANT', 'label': 'TENANT'},
  {'value': 'UNCLE', 'label': 'UNCLE'},
  // ── catch-all — always last ──────────────────────────────────────────────
  {'value': 'OTHERS', 'label': 'OTHERS — Please Specify'},
];

const List<Map<String, String>> kPlacementOptions = [
  {'value': 'RECEIVED', 'label': 'Received'},
  {'value': 'MAILBOX', 'label': 'Mailbox'},
  {'value': 'INSERTED_DOOR', 'label': 'Inserted - Door'},
  {'value': 'INSERTED_WINDOW', 'label': 'Inserted - Window'},
];

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
