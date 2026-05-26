import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/artwork.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final TextEditingController _serverCtl;
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverCtl = TextEditingController(
      text: ref.read(authRepositoryProvider).serverUrl,
    );
  }

  @override
  void dispose() {
    _serverCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authRepositoryProvider);
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    final server = _serverCtl.text.trim();

    if (email.isEmpty || pass.isEmpty || server.isEmpty) {
      setState(() => _error = 'Server, email, and password are required');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await auth.setServerUrl(server);
      if (_signUp) {
        await auth.signUp(email: email, password: pass);
      } else {
        await auth.signIn(email, pass);
      }
      if (!mounted) return;
      unawaited(ref.read(syncServiceProvider).reconcile());
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(Object e) {
    final s = e.toString();
    if (s.contains('Failed host lookup') ||
        s.contains('SocketException') ||
        s.contains('Connection refused')) {
      return 'Could not reach the server. Check the URL.';
    }
    if (s.contains('400') || s.contains('Failed to authenticate')) {
      return _signUp
          ? 'Sign-up failed. Email may already be registered.'
          : 'Wrong email or password.';
    }
    return 'Something went wrong.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: InkResponse(
                radius: 22,
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.fillTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.xxxl,
                  Insets.gutter,
                  Insets.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: BrandMark(size: 72, glow: true),
                      ),
                      const SizedBox(height: Insets.xl),
                      Text(
                        _signUp ? 'Create account' : 'Sign in',
                        style: theme.textTheme.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        'Connect to your sync server to keep playback '
                        'in sync across devices.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: Insets.xl),
                      _Field(
                        label: 'Server URL',
                        controller: _serverCtl,
                        hint: 'https://sync.example.com',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: Insets.md),
                      _Field(
                        label: 'Email',
                        controller: _emailCtl,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: Insets.md),
                      _Field(
                        label: 'Password',
                        controller: _passCtl,
                        hint: '••••••••',
                        obscure: true,
                        onSubmitted: (_) => _busy ? null : _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Insets.md),
                        Container(
                          padding: const EdgeInsets.all(Insets.sm + 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(Radii.sm),
                          ),
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: Insets.xl),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.accentInk,
                                ),
                              )
                            : Text(
                                _signUp
                                    ? 'Create account'
                                    : 'Sign in',
                              ),
                      ),
                      const SizedBox(height: Insets.sm),
                      Center(
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _signUp = !_signUp;
                                    _error = null;
                                  }),
                          child: Text(
                            _signUp
                                ? 'Have an account? Sign in'
                                : 'New here? Create an account',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          autocorrect: false,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
