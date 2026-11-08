import 'dart:html' as html;

Future<void> openLearningResource(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) return;
  html.window.location.assign(uri.toString());
}
