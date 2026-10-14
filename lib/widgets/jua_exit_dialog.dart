import 'jua_dialog.dart';
import 'package:flutter/material.dart';

/// Game-styled confirmation for leaving an active round (mascot header,
/// KEEP PLAYING / LEAVE). Returns true when the player chooses to exit.
Future<bool> showJuaExitDialog({
  required BuildContext context,
  required String title,
  required String message,
  String keepPlayingLabel = 'Keep playing',
  String exitLabel = 'Exit',
}) {
  return showJuaConfirm(
    context,
    title: title,
    message: message,
    cancelLabel: keepPlayingLabel,
    confirmLabel: exitLabel,
    tone: JuaDialogTone.blue,
    art: JuaDialogArt.leaveMascot,
    artHeight: 118,
    artAlignment: Alignment.topLeft,
    destructive: true,
  );
}
