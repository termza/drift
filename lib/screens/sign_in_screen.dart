import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

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
      setState(() => _error = 'Server URL, email, and password are required');
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
      // Sync service rebuilds because auth notified — kick off reconcile.
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
          ? 'Sign-up failed. Email may already be registered or the password is too short.'
          : 'Wrong email or password.';
    }
    return 'Something went wrong. ($s)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.cloud_sync_rounded,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _signUp ? 'Create account' : 'Sign in',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect to your sync server to keep playback progress '
                    'in sync between iOS and Windows.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  _Label('Server URL'),
                  TextField(
                    controller: _serverCtl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'https://sync.example.com',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Label('Email'),
                  TextField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration:
                        const InputDecoration(hintText: 'you@example.com'),
                  ),
                  const SizedBox(height: 16),
                  _Label('Password'),
                  TextField(
                    controller: _passCtl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(hintText: '••••••••'),
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFF1A0F05),
                            ),
                          )
                        : Text(_signUp ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          letterSpacing: 0.4,
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

