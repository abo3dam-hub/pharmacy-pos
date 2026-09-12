/// Composes an item's Arabic + English name for display: `'عربي (English)'`
/// when both exist, otherwise falls back to whichever single name is present
/// (the English name is preferred when forced). Plain Dart so UI, domain and
/// data layers share the exact same rule.
String bilingualName(String arabic, String english) {
  final ar = arabic.trim();
  final en = english.trim();
  if (ar.isEmpty && en.isEmpty) return '';
  if (ar.isEmpty) return en;
  if (en.isEmpty) return ar;
  return '$ar ($en)';
}