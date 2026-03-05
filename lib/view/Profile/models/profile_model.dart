class Profile {
  final String name;
  final String mobileNumber;
  final String branch;
  final String address;

  Profile({
    required this.name,
    required this.mobileNumber,
    required this.branch,
    required this.address,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      name: json['name'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      branch: json['branch'] ?? '',
      address: json['address'] ?? '',
    );
  }
}
