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

const List<String> kUpdateStatuses = ['delivered', 'rts', 'osa'];

const List<String> kAllDeliveryStatuses = [
  'pending',
  'delivered',
  'rts',
  'osa',
  'roll-back',
  'lost',
  'undelivered',
];

const List<String> kImageTypes = [
  'package',
  'recipient',
  'location',
  'damage',
  'other',
];

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
  {'value': 'self', 'label': 'Owner'},
  {'value': 'spouse', 'label': 'Spouse'},
  {'value': 'mother', 'label': 'Mother'},
  {'value': 'father', 'label': 'Father'},
  {'value': 'daughter', 'label': 'Daughter'},
  {'value': 'son', 'label': 'Son'},
  {'value': 'sister', 'label': 'Sister'},
  {'value': 'brother', 'label': 'Brother'},
  {'value': 'mother_in_law', 'label': 'Mother-in-law'},
  {'value': 'father_in_law', 'label': 'Father-in-law'},
  {'value': 'sister_in_law', 'label': 'Sister-in-law'},
  {'value': 'brother_in_law', 'label': 'Brother-in-law'},
  {'value': 'son_in_law', 'label': 'Son-in-law'},
  {'value': 'daughter_in_law', 'label': 'Daughter-in-law'},
  {'value': 'cousin', 'label': 'Cousin'},
  {'value': 'relative', 'label': 'Relative'},
  {'value': 'niece', 'label': 'Niece'},
  {'value': 'nephew', 'label': 'Nephew'},
  {'value': 'uncle', 'label': 'Uncle'},
  {'value': 'aunt', 'label': 'Aunt'},
  {'value': 'househelp', 'label': 'Househelp'},
  {'value': 'maid', 'label': 'Maid'},
  {'value': 'helper', 'label': 'Helper'},
  {'value': 'driver', 'label': 'Driver'},
  {'value': 'caretaker', 'label': 'Caretaker'},
  {'value': 'security_guard', 'label': 'Security Guard'},
  {'value': 'guard', 'label': 'Guard'},
  {'value': 'receptionist', 'label': 'Receptionist'},
  {'value': 'tenant', 'label': 'Tenant'},
  {'value': 'employee', 'label': 'Employee'},
  {'value': 'staff', 'label': 'Staff'},
  {'value': 'co_employee', 'label': 'Co-employee'},
  {'value': 'neighbor', 'label': 'Neighbor'},
  {'value': 'wife', 'label': 'Wife'},
  {'value': 'husband', 'label': 'Husband'},
  {'value': 'other', 'label': 'Other'},
];

const List<Map<String, String>> kPlacementOptions = [
  {'value': 'received', 'label': 'Received'},
  {'value': 'mailbox', 'label': 'Mailbox'},
  {'value': 'inserted_door', 'label': 'Inserted - Door'},
  {'value': 'inserted_window', 'label': 'Inserted - Window'},
];

const String kDeviceTypeLogin = 'flutter';
