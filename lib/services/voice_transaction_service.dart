import 'package:supabase_flutter/supabase_flutter.dart';

/// Result returned by the `parse-transaction` Supabase Edge Function.
///
/// Field semantics mirror the JSON schema documented in the function source.
class ParsedTransaction {
  final String type; // "income" | "expense"
  final int amount; // rupiah, integer
  final int categoryId;
  final String categoryName;
  final String? categoryEmoji;
  final String account; // "Tunai" | "Transfer" | "E-Wallet"
  final String sourceOrPayee;
  final String notes;
  final String date; // YYYY-MM-DD
  final String confidence; // "high" | "medium" | "low"
  final String reasoning;
  final String transcript; // shared across siblings parsed from same utterance

  const ParsedTransaction({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.account,
    required this.sourceOrPayee,
    required this.notes,
    required this.date,
    required this.confidence,
    required this.reasoning,
    required this.transcript,
  });

  factory ParsedTransaction.fromJson(
    Map<String, dynamic> j, {
    String transcript = '',
  }) {
    return ParsedTransaction(
      type: j['type'] as String? ?? 'expense',
      amount: (j['amount'] as num?)?.toInt() ?? 0,
      categoryId: (j['category_id'] as num?)?.toInt() ?? 0,
      categoryName: j['category_name'] as String? ?? '',
      categoryEmoji: j['category_emoji'] as String?,
      account: j['account'] as String? ?? 'Tunai',
      sourceOrPayee: j['source_or_payee'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      date: j['date'] as String? ?? '',
      confidence: j['confidence'] as String? ?? 'medium',
      reasoning: j['reasoning'] as String? ?? '',
      transcript: (j['transcript'] as String?) ?? transcript,
    );
  }

  Map<String, dynamic> toInsertPayload() {
    return {
      'date': date,
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'source_or_payee': sourceOrPayee,
      'account': account,
      'notes': notes,
    };
  }
}

class VoiceParseException implements Exception {
  final String message;
  final String? code;
  VoiceParseException(this.message, {this.code});

  @override
  String toString() => 'VoiceParseException($code): $message';
}

/// Calls the Supabase Edge Function `parse-transaction` with the user's
/// transcript and returns a [ParsedTransaction] draft.
///
/// The function uses the caller's Supabase JWT so RLS scopes category
/// lookups to the current user.
class VoiceTransactionService {
  static final VoiceTransactionService _instance =
      VoiceTransactionService._internal();
  factory VoiceTransactionService() => _instance;
  VoiceTransactionService._internal();

  static const String _functionName = 'parse-transaction';
  static const int maxTransactions = 3;

  /// Calls the edge function and returns 1..[maxTransactions] drafts parsed
  /// from a single utterance. Always returns at least one element on success.
  Future<List<ParsedTransaction>> parse(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw VoiceParseException(
        'Ucapanmu tidak terdengar. Coba lagi.',
        code: 'empty_transcript',
      );
    }

    final client = Supabase.instance.client;

    try {
      final res = await client.functions.invoke(
        _functionName,
        body: {'transcript': trimmed},
      );

      // Supabase functions-js returns FunctionResponse with `data` and `status`.
      if (res.status >= 200 && res.status < 300 && res.data is Map) {
        final data = (res.data as Map).cast<String, dynamic>();
        final sharedTranscript = (data['transcript'] as String?) ?? trimmed;

        // New shape: { transactions: [...], transcript }
        final list = data['transactions'];
        if (list is List) {
          final parsed = list
              .whereType<Map>()
              .map(
                (m) => ParsedTransaction.fromJson(
                  m.cast<String, dynamic>(),
                  transcript: sharedTranscript,
                ),
              )
              .take(maxTransactions)
              .toList();
          if (parsed.isEmpty) {
            throw VoiceParseException(
              'Tidak ada transaksi yang terbaca.',
              code: 'no_transactions_parsed',
            );
          }
          return parsed;
        }

        // Backward-compat: single transaction object at the top level.
        if (data['amount'] != null) {
          return [
            ParsedTransaction.fromJson(data, transcript: sharedTranscript),
          ];
        }

        throw VoiceParseException(
          'Format respons tidak dikenal.',
          code: 'unknown_response_shape',
        );
      }

      // Try to extract error message from response body.
      String? errorMsg;
      String? errorCode;
      if (res.data is Map) {
        final m = (res.data as Map).cast<String, dynamic>();
        errorCode = m['error'] as String?;
        errorMsg = m['detail'] as String? ?? m['error'] as String?;
      }
      throw VoiceParseException(
        errorMsg ?? 'Gagal memproses ucapan (status ${res.status}).',
        code: errorCode,
      );
    } on FunctionException catch (e) {
      throw VoiceParseException(
        'Gagal memanggil parser: ${e.details ?? e.toString()}',
        code: 'function_exception',
      );
    } on VoiceParseException {
      rethrow;
    } catch (e) {
      throw VoiceParseException(
        'Tidak terhubung ke server: $e',
        code: 'network',
      );
    }
  }
}
