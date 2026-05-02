import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WalletTransaction {
  final String id;
  final String type; // 'credit' | 'debit'
  final double amount;
  final String description;
  final String status;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'debit',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class WalletSummary {
  final double balance;
  final String currency;
  final List<WalletTransaction> transactions;

  const WalletSummary({
    required this.balance,
    required this.currency,
    required this.transactions,
  });
}

class WalletRepository extends ChangeNotifier {
  WalletSummary? _summary;
  bool _isLoading = false;
  String? _error;

  WalletSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get balance => _summary?.balance ?? 0.0;

  Future<void> fetchWalletSummary(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('https://www.sparkmind.in/petsathi/api/v1/wallet-summary'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == true) {
          final walletData = data['data']['wallet'] as Map<String, dynamic>;
          final txList = (data['data']['transactions'] as List?) ?? [];

          _summary = WalletSummary(
            balance: double.tryParse(
                walletData['balance']?.toString() ?? '0') ??
                0.0,
            currency: walletData['currency']?.toString() ?? 'INR',
            transactions: txList
                .map((t) =>
                WalletTransaction.fromJson(t as Map<String, dynamic>))
                .toList(),
          );
          _error = null;
        } else {
          _error = data['message']?.toString() ?? 'Failed to load wallet';
        }
      } else {
        _error = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Network error. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }
}