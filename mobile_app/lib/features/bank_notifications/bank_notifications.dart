import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/format/money.dart';

/// A bank app's notification, waiting to become a transaction. Its text can
/// name an account: never log it.
class BankNotification {
  final String id;

  /// Whose rules read the text: 'moey', 'activobank' (the statement parsers'
  /// ids), 'mbway', or 'other' for any other app.
  final String bank;

  /// The app's name, as the phone shows it.
  final String? appName;

  /// The app that sent it.
  final String? package;
  final String title;
  final String text;
  final DateTime postedAt;

  const BankNotification({
    required this.id,
    required this.bank,
    this.appName,
    this.package,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  factory BankNotification.fromMap(Map<Object?, Object?> map) => BankNotification(
    id: map['id']! as String,
    bank: map['bank']! as String,
    appName: map['appName'] as String?,
    package: map['package'] as String?,
    title: map['title']! as String,
    text: map['text']! as String,
    postedAt: DateTime.fromMillisecondsSinceEpoch((map['postedAt']! as num).toInt()),
  );

  String get bankName =>
      appName ??
      switch (bank) {
        'moey' => 'Moey',
        'activobank' => 'ActivoBank',
        'mbway' => 'MB WAY',
        _ => 'App',
      };
}

/// What a notification says. Either can be missing: the pop-up asks for it.
typedef ParsedBankNotification = ({int? amountCents, bool? income});

final _amount = RegExp(r'(\d[\d.\s]*(?:,\d{1,2})?)\s*(?:€|eur(?:os?)?\b)', caseSensitive: false);

/// Each bank's words for money in and out. "Recebeu uma transferencia no
/// valor de 0,01 euros", "Enviou 0,01 EUR", "Acabaste de receber 0,01€".
const _words = <String, ({List<String> income, List<String> spending})>{
  'activobank': (income: ['recebeu', 'recebida'], spending: ['enviou', 'enviada']),
  'moey': (income: ['receber', 'recebeste'], spending: ['enviaste', 'enviou', 'pagaste']),
};

/// Reads [BankNotification]'s text by the rules of the bank that sent it.
ParsedBankNotification parseBankNotification(String bank, String title, String text) {
  final all = '$title $text';
  final match = _amount.firstMatch(all);
  final amount = match == null ? null : parseAmountInput(match.group(1)!);
  final words = _words[bank];
  final lower = all.toLowerCase();
  final bool? income = words == null
      ? null
      : words.income.any(lower.contains)
      ? true
      : words.spending.any(lower.contains)
      ? false
      : null;
  return (amountCents: amount, income: income);
}

/// The Android side (BankNotifications.kt). Elsewhere there's nothing to
/// listen to, and every call answers as if none had arrived.
class BankNotificationsChannel {
  BankNotificationsChannel() {
    if (_supported) _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('bank_notifications');
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  final _opened = StreamController<String>.broadcast();

  /// The id of a notification of ours tapped while the app is running.
  Stream<String> get opened => _opened.stream;

  Future<void> _onCall(MethodCall call) async {
    if (call.method == 'opened') _opened.add(call.arguments as String);
  }

  bool get available => _supported;

  /// Apps on the phone, to choose from: name by package.
  Future<List<({String package, String label})>> installedApps() async {
    if (!_supported) return const [];
    final items = await _channel.invokeListMethod<Map<Object?, Object?>>('installedApps') ?? const [];
    return [for (final i in items) (package: i['package']! as String, label: i['label']! as String)];
  }

  Future<Set<String>> trackedApps() async {
    if (!_supported) return const {};
    return (await _channel.invokeListMethod<String>('trackedApps') ?? const <String>[]).toSet();
  }

  Future<void> setTrackedApps(Set<String> packages) async {
    if (_supported) await _channel.invokeMethod<void>('setTrackedApps', packages.toList());
  }

  Future<List<BankNotification>> list() async {
    if (!_supported) return const [];
    final items = await _channel.invokeListMethod<Map<Object?, Object?>>('list') ?? const [];
    return items.map(BankNotification.fromMap).toList();
  }

  Future<void> remove(String id) async {
    if (_supported) await _channel.invokeMethod<void>('remove', id);
  }

  /// The id of the notification that started the app, once.
  Future<String?> takeOpened() async => _supported ? _channel.invokeMethod<String>('takeOpened') : null;

  Future<bool> isEnabled() async => _supported && (await _channel.invokeMethod<bool>('isEnabled') ?? false);

  Future<void> openSettings() async {
    if (_supported) await _channel.invokeMethod<void>('openSettings');
  }

  Future<void> requestPostPermission() async {
    if (_supported) await _channel.invokeMethod<void>('requestPost');
  }
}
