import 'dart:async';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/database/isar_service.dart';
import '../../core/models/expense.dart';
import '../../core/repositories/expense_repository.dart';
import '../parser/transaction_parser.dart';

class SmsIngestionService {
  SmsIngestionService({
    required ExpenseRepository repository,
    required TransactionParser parser,
    Telephony? telephony,
  })  : _repository = repository,
        _parser = parser,
        _telephony = telephony ?? Telephony.instance;

  static const MethodChannel _receiverChannel = MethodChannel('spendly/sms_receiver');

  final ExpenseRepository _repository;
  final TransactionParser _parser;
  final Telephony _telephony;

  bool _isRunning = false;

  Future<bool> requestSmsPermissions() async {
    try {
      final result = await _telephony.requestPhoneAndSmsPermissions;
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> start() async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;

    _receiverChannel.setMethodCallHandler((call) async {
      if (call.method != 'onSmsReceived') {
        return;
      }

      final args = Map<String, dynamic>.from(call.arguments as Map<dynamic, dynamic>);
      final String sender = (args['sender'] as String?) ?? '';
      final String body = (args['body'] as String?) ?? '';
      final int timestampMs = (args['timestampMs'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
      await _ingestRawSms(
        sender: sender,
        body: body,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      );
    });

    _telephony.listenIncomingSms(
      onNewMessage: _handleForegroundMessage,
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  Future<int> ingestHistoricalInbox({int maxMessages = 3000}) async {
    final smsList = await _telephony.getInboxSms(
      columns: const [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    int ingested = 0;
    final takeCount = smsList.length > maxMessages ? maxMessages : smsList.length;
    for (var i = 0; i < takeCount; i++) {
      final message = smsList[i];
      final didSave = await _ingestRawSms(
        sender: message.address ?? '',
        body: message.body ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(message.date ?? DateTime.now().millisecondsSinceEpoch),
      );
      if (didSave) {
        ingested++;
      }
    }

    return ingested;
  }

  Future<void> _handleForegroundMessage(SmsMessage message) async {
    await _ingestRawSms(
      sender: message.address ?? '',
      body: message.body ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(message.date ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  Future<bool> _ingestRawSms({
    required String sender,
    required String body,
    required DateTime timestamp,
  }) async {
    if (body.trim().isEmpty) {
      return false;
    }

    final parsed = _parser.parse(
      sender: sender,
      body: body,
      timestamp: timestamp,
    );

    if (parsed == null) {
      return false;
    }

    final String dedupeKey = _buildDedupeKey(
      amount: parsed.amount,
      sender: parsed.sender,
      timestamp: parsed.timestamp,
      merchant: parsed.merchant,
    );

    final exists = await _repository.existsByDedupeKey(dedupeKey);
    if (exists) {
      return false;
    }

    final expense = Expense()
      ..timestamp = parsed.timestamp
      ..amount = parsed.amount
      ..merchant = parsed.merchant ?? _fallbackMerchant(sender)
      ..sender = parsed.sender
      ..upiId = parsed.upiId
      ..cardLastFour = parsed.cardLastFour
      ..bankName = parsed.bankName
      ..transactionType = parsed.transactionType
      ..source = ExpenseSource.sms
      ..rawSms = body
      ..createdAt = DateTime.now()
      ..dedupeKey = dedupeKey;

    await _repository.saveExpense(expense);
    return true;
  }

  String _buildDedupeKey({
    required double amount,
    required String sender,
    required DateTime timestamp,
    required String? merchant,
  }) {
    final roundedTimeWindow = timestamp.millisecondsSinceEpoch ~/ 60000;
    return '${amount.toStringAsFixed(2)}|${sender.toUpperCase()}|${merchant?.toUpperCase() ?? 'UNKNOWN'}|$roundedTimeWindow';
  }

  String _fallbackMerchant(String sender) {
    if (sender.trim().isEmpty) {
      return 'Unknown merchant';
    }
    return sender.toUpperCase();
  }
}

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  final body = message.body ?? '';
  if (body.trim().isEmpty) {
    return;
  }

  final sender = message.address ?? '';
  final timestampMs = message.date ?? DateTime.now().millisecondsSinceEpoch;
  final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final parser = TransactionParser();
  final parsed = parser.parse(
    sender: sender,
    body: body,
    timestamp: timestamp,
  );

  if (parsed == null || parsed.transactionType != TransactionType.debit) {
    return;
  }

  final isar = await openSpendlyIsar();
  final repo = ExpenseRepository(isar);
  final dedupeWindow = timestamp.millisecondsSinceEpoch ~/ 60000;
  final dedupeKey =
      '${parsed.amount.toStringAsFixed(2)}|${parsed.sender.toUpperCase()}|${(parsed.merchant ?? sender).toUpperCase()}|$dedupeWindow';

  if (await repo.existsByDedupeKey(dedupeKey)) {
    return;
  }

  final expense = Expense()
    ..timestamp = parsed.timestamp
    ..amount = parsed.amount
    ..merchant = parsed.merchant ?? (sender.isEmpty ? 'Unknown merchant' : sender.toUpperCase())
    ..sender = parsed.sender
    ..upiId = parsed.upiId
    ..cardLastFour = parsed.cardLastFour
    ..bankName = parsed.bankName
    ..transactionType = parsed.transactionType
    ..source = ExpenseSource.sms
    ..rawSms = body
    ..createdAt = DateTime.now()
    ..dedupeKey = dedupeKey;

  await repo.saveExpense(expense);

  debugPrint('Spendly background SMS persisted from $sender');
}
