import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../agent_debug_log.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim();
    final pwLen = _password.text.length;
    // #region agent log
    await agentDebugLog(
      hypothesisId: 'D',
      location: 'register_screen.dart:signUp:start',
      message: 'sign_up_attempt',
      data: {
        'emailDomain': email.contains('@') ? email.split('@').last : 'invalid',
        'passwordLen': pwLen,
      },
    );
    // #endregion
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _password.text,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );
      // #region agent log
      await agentDebugLog(
        hypothesisId: 'B',
        location: 'register_screen.dart:signUp:response',
        message: 'sign_up_response',
        data: {
          'hasSession': res.session != null,
          'userIdPresent': res.user?.id.isNotEmpty ?? false,
        },
      );
      // #endregion
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check your email to confirm your account if required by your project.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      // #region agent log
      await agentDebugLog(
        hypothesisId: 'D',
        location: 'register_screen.dart:signUp:AuthException',
        message: 'sign_up_auth_exception',
        data: {
          'msg': e.message,
          'statusCode': e.statusCode,
          'code': e.code,
        },
      );
      // #endregion
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e, st) {
      // #region agent log
      await agentDebugLog(
        hypothesisId: 'C',
        location: 'register_screen.dart:signUp:catch',
        message: 'sign_up_other_error',
        data: {
          'type': e.runtimeType.toString(),
          'err': e.toString(),
          'stackLen': st.toString().length,
        },
      );
      // #endregion
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Choose a password';
                        }
                        if (v.length < 6) {
                          return 'At least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v != _password.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _signUp,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
