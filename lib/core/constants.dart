const int kDashboardPerPage = 10;
const int kDeliveriesPerPage = 10;
const int kCompletedPerPage = 10;
const int kDispatchesPerPage = 10;

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

const List<String> kReasons = [
  'Refused',
  'Incorrect Address',
  'Recipient Not Around',
  'Moved Out',
  'Closed / No Business',
  'Insufficient Address',
  'Other',
];

const List<Map<String, String>> kRelationshipOptions = [
  {'value': 'OWNER', 'label': 'Owner'},
  {'value': 'SPOUSE', 'label': 'Spouse'},
  {'value': 'MOTHER', 'label': 'Mother'},
  {'value': 'FATHER', 'label': 'Father'},
  {'value': 'DAUGHTER', 'label': 'Daughter'},
  {'value': 'SON', 'label': 'Son'},
  {'value': 'SISTER', 'label': 'Sister'},
  {'value': 'BROTHER', 'label': 'Brother'},
  {'value': 'MOTHER_IN_LAW', 'label': 'Mother-in-law'},
  {'value': 'FATHER_IN_LAW', 'label': 'Father-in-law'},
  {'value': 'SISTER_IN_LAW', 'label': 'Sister-in-law'},
  {'value': 'BROTHER_IN_LAW', 'label': 'Brother-in-law'},
  {'value': 'SON_IN_LAW', 'label': 'Son-in-law'},
  {'value': 'DAUGHTER_IN_LAW', 'label': 'Daughter-in-law'},
  {'value': 'COUSIN', 'label': 'Cousin'},
  {'value': 'RELATIVE', 'label': 'Relative'},
  {'value': 'NIECE', 'label': 'Niece'},
  {'value': 'NEPHEW', 'label': 'Nephew'},
  {'value': 'UNCLE', 'label': 'Uncle'},
  {'value': 'AUNT', 'label': 'Aunt'},
  {'value': 'HOUSEHELP', 'label': 'Househelp'},
  {'value': 'MAID', 'label': 'Maid'},
  {'value': 'HELPER', 'label': 'Helper'},
  {'value': 'DRIVER', 'label': 'Driver'},
  {'value': 'CARETAKER', 'label': 'Caretaker'},
  {'value': 'SECURITY_GUARD', 'label': 'Security Guard'},
  {'value': 'GUARD', 'label': 'Guard'},
  {'value': 'RECEPTIONIST', 'label': 'Receptionist'},
  {'value': 'TENANT', 'label': 'Tenant'},
  {'value': 'EMPLOYEE', 'label': 'Employee'},
  {'value': 'STAFF', 'label': 'Staff'},
  {'value': 'CO_EMPLOYEE', 'label': 'Co-employee'},
  {'value': 'NEIGHBOR', 'label': 'Neighbor'},
  {'value': 'WIFE', 'label': 'Wife'},
  {'value': 'HUSBAND', 'label': 'Husband'},
  {'value': 'OTHER', 'label': 'Other'},
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
