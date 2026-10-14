import 'package:flutter/material.dart';

import 'jua_dialog.dart';

/// How the player pays for a hint.
enum HintSource { video, coins }

/// "Hint" dialog: "Watch a video" (free) or "Use Hint -N coins". Returns the
/// choice, or null if closed. Options that aren't possible right now are
/// greyed out with the reason, so it's clear what's going on.
Future<HintSource?> pickHintSource(
  BuildContext context, {
  required bool videoAvailable, // free video hints left this round
  required bool videoReady, // a video is loaded and can play now
  required int coins,
  required int price,
}) {
  final canVideo = videoAvailable && videoReady;
  final canCoins = coins >= price;
  final videoNote = !videoAvailable
      ? 'No free hints left this round.'
      : (videoReady ? 'Watching a video is free.' : 'Video loading...');
  final coinNote = canCoins
      ? 'You have $coins coins.'
      : 'You have $coins coins. Win more in competitions!';

  return showJuaDialogRoute<HintSource>(
    context,
    label: 'Hint',
    builder: (c) => JuaDialogCard(
      title: 'Hint',
      message: 'Need a little help? Use a hint to get closer to the correct answer.\n$videoNote $coinNote',
      art: JuaDialogArt.bulb,
      artHeight: 104,
      tone: JuaDialogTone.green,
      onClose: () => Navigator.of(c).pop(),
      buttons: [
        JuaDialogButton(
          label: 'Watch a video',
          icon: Icons.play_circle_outline_rounded,
          style: JuaDialogButtonStyle.green,
          onPressed: canVideo ? () => Navigator.of(c).pop(HintSource.video) : null,
        ),
        JuaDialogButton(
          label: 'Use Hint',
          icon: Icons.lightbulb_rounded,
          style: JuaDialogButtonStyle.gold,
          trailing: JuaPricePill(amount: price),
          onPressed: canCoins ? () => Navigator.of(c).pop(HintSource.coins) : null,
        ),
      ],
    ),
  );
}
