import 'package:url_launcher/url_launcher.dart';

Future<void> openLearningResource(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
