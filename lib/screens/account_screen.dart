import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/jua_dialog.dart';

enum AccountFlowMode { createAccount, logIn }

class AccountScreen extends StatefulWidget {
  final AccountFlowMode mode;

  const AccountScreen({super.key, required this.mode});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _Step { enterEmail, checkEmail }

class _AccountScreenState extends State<AccountScreen> {
  _Step _step = _Step.enterEmail;
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  bool get _isCreate => widget.mode == AccountFlowMode.createAccount;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.instance.authStateChanges.listen((state) {
      final user = state.session?.user;
      if (user == null || user.isAnonymous || _step != _Step.checkEmail) return;
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _sendLink() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isCreate) {
        await SupabaseService.instance.sendCreateAccountLink(email);
      } else {
        await SupabaseService.instance.sendLoginLink(email);
      }
      if (mounted) setState(() => _step = _Step.checkEmail);
    } on AuthException catch (e) {
      setState(() {
        _error = _isCreate
            ? '${e.message}\nIf this email already has an account, use Log in instead.'
            : e.message;
      });
    } catch (_) {
      setState(() => _error = 'Something went wrong. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration() => InputDecoration(
        labelText: 'Email',
        prefixIcon: const Icon(Icons.mail_outline_rounded),
        filled: true,
        fillColor: const Color(0xFFEAF2FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2561C6), width: 2),
        ),
      );

  Widget? _errorBox() {
    if (_error == null) return null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD81E2B), width: 1.5),
      ),
      child: Text(
        _error!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF9E1019), fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enterEmail = _step == _Step.enterEmail;
    final error = _errorBox();

    final card = enterEmail
        ? JuaDialogCard(
            title: _isCreate ? 'Create account' : 'Log in',
            message: _isCreate
                ? 'Your progress is already saved on this device. Create an account only if you want to restore it after reinstalling or use the leaderboard.'
                : 'Enter the email your Jua Quiz account is registered with.',
            art: JuaDialogArt.leaveMascot,
            artHeight: 118,
            artAlignment: Alignment.topLeft,
            tone: _isCreate ? JuaDialogTone.green : JuaDialogTone.blue,
            onClose: () => Navigator.of(context).pop(),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: _fieldDecoration(),
                ),
                if (error != null) ...[const SizedBox(height: 12), error],
              ],
            ),
            buttons: [
              JuaDialogButton(
                label: _loading ? 'Sending…' : 'Send verification link',
                icon: Icons.send_rounded,
                style: JuaDialogButtonStyle.green,
                onPressed: _loading ? null : _sendLink,
              ),
            ],
          )
        : JuaDialogCard(
            title: 'Check your email',
            message:
                'We sent a verification link to ${_emailController.text.trim()}.\n\nOpen the email and tap the verification link. Jua Quiz will return to the app automatically.',
            fallbackIcon: Icons.mark_email_read_rounded,
            tone: JuaDialogTone.blue,
            onClose: () => Navigator.of(context).pop(),
            content: error,
            buttons: [
              JuaDialogButton(
                label: _loading ? 'Sending…' : 'Resend verification link',
                icon: Icons.refresh_rounded,
                style: JuaDialogButtonStyle.blue,
                onPressed: _loading ? null : _sendLink,
              ),
              JuaDialogButton(
                label: 'Use a different email',
                style: JuaDialogButtonStyle.light,
                onPressed: _loading ? null : () => setState(() => _step = _Step.enterEmail),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}
