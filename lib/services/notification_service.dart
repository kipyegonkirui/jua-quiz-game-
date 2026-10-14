import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../config/app_config.dart';

class NotificationService {
  static Future<void> initialize() async {
    OneSignal.initialize(AppConfig.oneSignalAppId);
    // Shows the OS push permission prompt. Fine for a v1; consider replacing
    // with an in-app "enable reminders?" moment later so you control timing.
    await OneSignal.Notifications.requestPermission(true);
  }

  /// Call right after sign-in/sign-up so you can target this device by
  /// Supabase user id from OneSignal (e.g. for the "your streak is at risk"
  /// push). Call [logout] on sign-out so the device stops being tied to them.
  static Future<void> login(String supabaseUserId) => OneSignal.login(supabaseUserId);

  static Future<void> logout() => OneSignal.logout();
}
