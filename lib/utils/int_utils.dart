/// Parses a dynamic value to a positive integer (> 0), or returns null.
///
/// Accepts [num] and parseable [String] values.
int? readPositiveInt(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final asInt = value.toInt();
    return asInt > 0 ? asInt : null;
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}
