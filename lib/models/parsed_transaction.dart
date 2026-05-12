/// Shared draft model returned by AI parsers (voice, OCR, etc.).
///
/// Field semantics mirror the JSON schema documented in the
/// `parse-transaction` and `parse-receipt` Supabase Edge Functions.
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

  /// Free-form context shared across siblings parsed from the same input
  /// (e.g. the original transcript for voice, or a short receipt summary
  /// for OCR). Empty when no shared context is available.
  final String transcript;

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

/// Mutable variant of [ParsedTransaction] used by preview/edit UIs (voice,
/// OCR, etc.) so the user can tweak any field before committing.
class TransactionDraft {
  String type;
  int amount;
  int categoryId;
  String categoryName;
  String? categoryEmoji;
  String account;
  String sourceOrPayee;
  String notes;
  DateTime date;
  final String confidence;
  final String reasoning;

  /// Optional shared context (transcript for voice, short summary for OCR).
  final String transcript;

  TransactionDraft({
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

  factory TransactionDraft.fromParsed(ParsedTransaction p) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(p.date);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return TransactionDraft(
      type: p.type,
      amount: p.amount,
      categoryId: p.categoryId,
      categoryName: p.categoryName,
      categoryEmoji: p.categoryEmoji,
      account: p.account,
      sourceOrPayee: p.sourceOrPayee,
      notes: p.notes,
      date: parsedDate,
      confidence: p.confidence,
      reasoning: p.reasoning,
      transcript: p.transcript,
    );
  }

  Map<String, dynamic> toInsertPayload() {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return {
      'date': dateStr,
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'source_or_payee': sourceOrPayee,
      'account': account,
      'notes': notes,
    };
  }
}
