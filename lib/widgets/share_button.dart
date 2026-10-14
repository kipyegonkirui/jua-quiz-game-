import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// Opens WhatsApp with a ready-made message. If WhatsApp can't be opened the
/// text is copied instead, so the player can paste it anywhere.
Future<void> shareToWhatsApp(BuildContext context, String text) async {
  final full = AppConfig.shareUrl.isEmpty ? text : '$text\n${AppConfig.shareUrl}';
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(full)}');
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (opened || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: full));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open WhatsApp. Message copied, paste it anywhere.')),
  );
}

class WhatsAppShareButton extends StatelessWidget {
  final String text;
  final bool onDark;
  const WhatsAppShareButton({super.key, required this.text, this.onDark = true});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => shareToWhatsApp(context, text),
      style: TextButton.styleFrom(foregroundColor: onDark ? Colors.white : const Color(0xFF1B8F4B)),
      icon: const Icon(Icons.share_rounded, size: 18),
      label: const Text('Share on WhatsApp', style: TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
