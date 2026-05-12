import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parsed_transaction.dart';

/// Thrown by [ReceiptOcrService] when receipt parsing fails for any reason.
class ReceiptOcrException implements Exception {
  final String message;
  final String? code;
  ReceiptOcrException(this.message, {this.code});

  @override
  String toString() => 'ReceiptOcrException($code): $message';
}

/// Sends a receipt image to the `parse-receipt` Supabase Edge Function and
/// returns one or more [ParsedTransaction] drafts ready for the preview UI.
///
/// The function uses the caller's Supabase JWT so RLS scopes category lookups
/// to the current user. Images are encoded as base64 client-side; resize +
/// compress before calling so the payload stays well under the function's
/// hard cap.
class ReceiptOcrService {
  static final ReceiptOcrService _instance = ReceiptOcrService._internal();
  factory ReceiptOcrService() => _instance;
  ReceiptOcrService._internal();

  static const String _functionName = 'parse-receipt';
  static const int maxTransactions = 3;

  /// Parses a receipt photo. [bytes] must be the raw image bytes (already
  /// resized/compressed by the caller). [mime] is the MIME type, defaulting
  /// to `image/jpeg` which is what `image_picker` produces.
  Future<({List<ParsedTransaction> drafts, String transcript})> parseImage(
    Uint8List bytes, {
    String mime = 'image/jpeg',
  }) async {
    if (bytes.isEmpty) {
      throw ReceiptOcrException(
        'Foto struk tidak ditemukan.',
        code: 'empty_image',
      );
    }

    final imageBase64 = base64Encode(bytes);
    final client = Supabase.instance.client;

    try {
      final res = await client.functions.invoke(
        _functionName,
        body: {
          'image_base64': imageBase64,
          'mime': mime,
        },
      );

      if (res.status >= 200 && res.status < 300 && res.data is Map) {
        final data = (res.data as Map).cast<String, dynamic>();
        final transcript = (data['transcript'] as String?) ?? '';
        final list = data['transactions'];
        if (list is List) {
          final drafts = list
              .whereType<Map>()
              .map(
                (m) => ParsedTransaction.fromJson(
                  m.cast<String, dynamic>(),
                  transcript: transcript,
                ),
              )
              .take(maxTransactions)
              .toList();
          if (drafts.isEmpty) {
            throw ReceiptOcrException(
              transcript.isNotEmpty
                  ? transcript
                  : 'Struk tidak terbaca. Coba foto ulang dengan pencahayaan yang lebih baik.',
              code: 'no_transactions_parsed',
            );
          }
          return (drafts: drafts, transcript: transcript);
        }
        throw ReceiptOcrException(
          'Format respons tidak dikenal.',
          code: 'unknown_response_shape',
        );
      }

      String? errorMsg;
      String? errorCode;
      if (res.data is Map) {
        final m = (res.data as Map).cast<String, dynamic>();
        errorCode = m['error'] as String?;
        errorMsg = m['detail'] as String? ?? m['error'] as String?;
      }
      throw ReceiptOcrException(
        errorMsg ?? 'Gagal memproses struk (status ${res.status}).',
        code: errorCode,
      );
    } on FunctionException catch (e) {
      throw ReceiptOcrException(
        'Gagal memanggil parser: ${e.details ?? e.toString()}',
        code: 'function_exception',
      );
    } on ReceiptOcrException {
      rethrow;
    } catch (e) {
      throw ReceiptOcrException(
        'Tidak terhubung ke server: $e',
        code: 'network',
      );
    }
  }
}
