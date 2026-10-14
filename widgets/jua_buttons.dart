import 'package:flutter/material.dart';

enum JuaButtonVariant { action, primary, secondary }

class JuaGlossyButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final JuaButtonVariant variant;

  const JuaGlossyButton({
    Key? key,
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.variant,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
