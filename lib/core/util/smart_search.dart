import 'package:drift/drift.dart';

/// Arabic-aware search normalization used by the inventory + POS catalogs.
///
/// Arabic has several variants that are interchangeable for everyday typing:
/// the alef families (أ/إ/آ/ٱ → ا), yeh/tā marbuta (ى/ئ → ي, ة → ه) and
/// vocalisation marks (tashkeel). Comparing against the raw column is fragile,
/// so the same transliteration is applied in Dart (to the query) and in SQL
/// (to the column via a chain of `replace()` calls), and only then is `LIKE`
/// evaluated. ASCII is folded to lower case on the SQLite side (`LIKE`). All
/// other fields are already lower-case model text.
class SmartSearch {
  const SmartSearch._();

  /// Pairs of (from → to) applied in order on both the query (Dart) and the
  /// column (SQL). Order matters: tashkeel/tatweel are removed first so the
  /// letter mappings below operate on clean text.
  static const List<(String, String)> _charMap = [
    // Shape removal: alef families keep the plain alef.
    ('أ', 'ا'),
    ('إ', 'ا'),
    ('آ', 'ا'),
    ('ٱ', 'ا'),
    // Yeh variants and tā marbuta.
    ('ى', 'ي'),
    ('ئ', 'ي'),
    ('ة', 'ه'),
    ('ؤ', 'و'),
  ];

  static const String _tashkeel =
      '\u064B\u064C\u064D\u064E\u064F\u0650\u0651\u0652\u0653\u0670\u0640';

  /// Normalizes Arabic search text: strips vocalisation + tatweel and folds
  /// the common letter variants, then lower-cases for ASCII input.
  static String normalize(String input) {
    final stripped = StringBuffer();
    for (final rune in input.runes) {
      if (!_tashkeel.contains(String.fromCharCode(rune))) {
        stripped.writeCharCode(rune);
      }
    }
    var value = stripped.toString().toLowerCase();
    for (final (from, to) in _charMap) {
      value = value.replaceAll(from, to);
    }
    return value;
  }

  /// Escapes a query into a SQLite `LIKE` pattern matching the normalized
  /// value anywhere (leading/trailing `%`). Wildcards in the input are
  /// escaped so a user typing `%` looks for a literal percent sign.
  static String likePattern(String query) {
    final normalized = normalize(query);
    final escaped = normalized
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  /// Same transliteration as [normalize] but as a SQL `replace(...)` chain so
  /// it can be applied to a column inside a `WHERE` clause.
  static Expression<String> normalizeExpr(Expression<String> column) {
    var expr = column;
    for (final (from, to) in _charMap) {
      expr = FunctionCallExpression<String>(
          'replace', [expr, Constant<String>(from), Constant<String>(to)]);
    }
    return expr;
  }
}