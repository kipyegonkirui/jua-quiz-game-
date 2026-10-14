import 'package:flutter/material.dart';

/// An Odd One Out item is either plain text/emoji or a picture.
///
/// Pictures are stored in the existing item_a..item_d text columns as
///   img:<file name without .png>|<accessible label>
/// e.g.  img:fruits_apple|Apple
/// The file lives in assets/odd_one_out/. Because the value is still just
/// text, the database, RPCs and answer checking need no changes.
class OddItemRef {
  static const _prefix = 'img:';
  static const _folder = 'assets/odd_one_out/';

  final String raw;
  final String? asset;
  final String label;

  const OddItemRef._(this.raw, this.asset, this.label);

  factory OddItemRef.parse(String raw) {
    if (!raw.startsWith(_prefix)) return OddItemRef._(raw, null, raw);
    final body = raw.substring(_prefix.length);
    final bar = body.indexOf('|');
    final file = (bar < 0 ? body : body.substring(0, bar)).trim();
    final label = (bar < 0 ? file : body.substring(bar + 1)).trim();
    return OddItemRef._(raw, '$_folder$file.png', label);
  }

  bool get isImage => asset != null;

  static bool anyImage(Iterable<String> items) => items.any((i) => i.startsWith(_prefix));
}

/// Draws an item: the picture when it is an image item, otherwise the text.
class OddItemView extends StatelessWidget {
  final String item;
  final TextStyle textStyle;
  final double imageSize;
  final int maxLines;
  final TextAlign textAlign;

  const OddItemView({
    super.key,
    required this.item,
    required this.textStyle,
    this.imageSize = 84,
    this.maxLines = 3,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final ref = OddItemRef.parse(item);
    if (!ref.isImage) {
      return Text(
        item,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }
    return Semantics(
      label: ref.label,
      image: true,
      child: Image.asset(
        ref.asset!,
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => Text(
          ref.label,
          textAlign: textAlign,
          style: textStyle.copyWith(fontSize: 16),
        ),
      ),
    );
  }
}
