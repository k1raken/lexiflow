import 'package:flutter/foundation.dart';

/// Ensures Firestore ID lists contain strings only.
/// Non-string or empty entries are removed and logged.
List<String> sanitizeIdList(
  dynamic raw, {
  String context = '',
}) {
  if (raw == null) return const <String>[];

  if (raw is! List) {
    if (context.isNotEmpty) {

    }
    return const <String>[];
  }

  final sanitized = <String>[];
  var hadInvalid = false;

  for (final item in raw) {
    if (item is String) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) {
        sanitized.add(trimmed);
      } else {
        hadInvalid = true;
      }
    } else if (item != null) {
      hadInvalid = true;
    }
  }

  if (hadInvalid && context.isNotEmpty) {

  }

  return sanitized;
}
