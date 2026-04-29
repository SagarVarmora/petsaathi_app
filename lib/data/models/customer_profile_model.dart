// ─── Customer Profile Model ───────────────────────────────────────────────────
// Matches Laravel CustomerController showProfile / updateProfile response

class CustomerProfile {
  final int id;
  final int userId;
  final String name;
  final String? email;
  final String mobile;
  final String? address;
  final String? profileImage;   // filename stored on server
  final String? profileImageUrl; // full URL (set by API on updateProfile)
  final List<BankAccount> bankAccounts;

  const CustomerProfile({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    required this.mobile,
    this.address,
    this.profileImage,
    this.profileImageUrl,
    this.bankAccounts = const [],
  });

  // ── Derived ────────────────────────────────────────────────────────────────
  BankAccount? get primaryBank =>
      bankAccounts.where((b) => b.isPrimary).isNotEmpty
          ? bankAccounts.firstWhere((b) => b.isPrimary)
          : bankAccounts.isNotEmpty
          ? bankAccounts.first
          : null;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ── JSON ───────────────────────────────────────────────────────────────────
  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    final banks = (json['bank_accounts'] as List<dynamic>? ?? [])
        .map((b) => BankAccount.fromJson(b as Map<String, dynamic>))
        .toList();

    return CustomerProfile(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      mobile: json['mobile'] as String? ?? '',
      address: json['address'] as String?,
      profileImage: json['profile_image'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      bankAccounts: banks,
    );
  }

  CustomerProfile copyWith({
    String? name,
    String? email,
    String? mobile,
    String? address,
    String? profileImage,
    String? profileImageUrl,
    List<BankAccount>? bankAccounts,
  }) {
    return CustomerProfile(
      id: id,
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      profileImage: profileImage ?? this.profileImage,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bankAccounts: bankAccounts ?? this.bankAccounts,
    );
  }
}

// ─── Bank Account Model ───────────────────────────────────────────────────────
class BankAccount {
  final int id;
  final int customerId;
  final String? bankName;
  final String? accountNo;
  final String? ifscCode;
  final String? upiId;
  final String? holderName;
  final bool isPrimary;

  const BankAccount({
    required this.id,
    required this.customerId,
    this.bankName,
    this.accountNo,
    this.ifscCode,
    this.upiId,
    this.holderName,
    this.isPrimary = false,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as int? ?? 0,
      customerId: json['customer_id'] as int? ?? 0,
      bankName: json['bank_name'] as String?,
      accountNo: json['account_no'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      upiId: json['upi_id'] as String?,
      holderName: json['holder_name'] as String?,
      isPrimary: (json['is_primary'] == 1 || json['is_primary'] == true),
    );
  }

  bool get hasDetails =>
      (bankName?.isNotEmpty ?? false) ||
          (accountNo?.isNotEmpty ?? false) ||
          (ifscCode?.isNotEmpty ?? false) ||
          (upiId?.isNotEmpty ?? false);
}