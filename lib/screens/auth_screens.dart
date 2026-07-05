import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/common/gradient_button.dart';
import '../widgets/common/glowing_grid_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMsg;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppTheme.durSlow,
    )..forward();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      await context.read<AuthService>().signInWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = 'Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      await context.read<AuthService>().signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToSignUp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  void _goToForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowingGridBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.gap20),
                child: FadeTransition(
                  opacity: _anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(_anim),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            _buildLogo(),
                            const SizedBox(height: AppTheme.gap32),
                            _buildCard(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return ShaderMask(
      shaderCallback: (b) => AppTheme.titleGradient.createShader(b),
      child: const Text(
        'وطني چکه',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 5,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome Back',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Sign in to save your match history',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.gap24),

          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.accentRed.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppTheme.accentRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: AppTheme.accentRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.gap16),
          ],

          TextFormField(
            controller: _emailCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            keyboardType: TextInputType.emailAddress,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: _inputDec('Email address', Icons.email_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
              if (!re.hasMatch(v.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.gap14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textInputAction: TextInputAction.done,
            decoration: _inputDec(
              'Password',
              _obscure ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _goToForgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.gap8),
          GradientButton(
            label: _isLoading ? 'Signing in...' : 'Sign In',
            icon: Icons.login_rounded,
            onPressed: _isLoading ? null : _signInWithEmail,
            expand: true,
          ),
          const SizedBox(height: AppTheme.gap14),

          _DividerRow(),
          const SizedBox(height: AppTheme.gap14),

          _GoogleSignInButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            isLoading: _isLoading,
          ),
          const SizedBox(height: AppTheme.gap20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              TextButton(
                onPressed: _isLoading ? null : _goToSignUp,
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: AppTheme.bgPanel,
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.accentBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMsg;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppTheme.durSlow,
    )..forward();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      await context.read<AuthService>().signUpWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _errorMsg = _friendlyMessage(e.code));
    } catch (e) {
      setState(() => _errorMsg = 'Sign up failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      await context.read<AuthService>().signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (e) {
      setState(() => _errorMsg = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Sign up failed. Please try again.';
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowingGridBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.gap20),
                child: FadeTransition(
                  opacity: _anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(_anim),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildHeader(),
                            const SizedBox(height: AppTheme.gap28),
                            _buildCard(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ShaderMask(
      shaderCallback: (b) => AppTheme.titleGradient.createShader(b),
      child: const Text(
        'Create Account',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 4,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.accentRed.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppTheme.accentRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: AppTheme.accentRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.gap16),
          ],

          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textInputAction: TextInputAction.next,
            decoration: _fieldDec('Display Name', Icons.person_outline_rounded),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter a display name';
              if (v.trim().length < 2) return 'Name is too short';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.gap14),
          TextFormField(
            controller: _emailCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            keyboardType: TextInputType.emailAddress,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: _fieldDec('Email address', Icons.email_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
              if (!re.hasMatch(v.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.gap14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textInputAction: TextInputAction.next,
            decoration: _fieldDecWithToggle(
              'Password',
              Icons.lock_outline_rounded,
              _obscure,
              () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 6) return 'Must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.gap14),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textInputAction: TextInputAction.done,
            decoration: _fieldDecWithToggle(
              'Confirm Password',
              Icons.lock_outline_rounded,
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.gap20),
          GradientButton(
            label: _isLoading ? 'Creating account...' : 'Sign Up',
            icon: Icons.person_add_rounded,
            onPressed: _isLoading ? null : _signUp,
            expand: true,
          ),
          const SizedBox(height: AppTheme.gap14),
          _DividerRow(),
          const SizedBox(height: AppTheme.gap14),
          _GoogleSignInButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            isLoading: _isLoading,
          ),
          const SizedBox(height: AppTheme.gap20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              TextButton(
                onPressed: _isLoading ? null : _goToLogin,
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: AppTheme.bgPanel,
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.accentBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  InputDecoration _fieldDecWithToggle(
      String hint, IconData icon, bool obscure, VoidCallback onToggle) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: AppTheme.bgPanel,
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppTheme.textMuted,
          size: 20,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.accentBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _successMsg;
  String? _errorMsg;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppTheme.durSlow,
    )..forward();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; _successMsg = null; });
    try {
      await context.read<AuthService>().sendPasswordResetEmail(_emailCtrl.text);
      if (mounted) {
        setState(() => _successMsg = 'Password reset email sent. Check your inbox.');
      }
    } on AuthException catch (e) {
      setState(() => _errorMsg = _friendly(e.code));
    } catch (e) {
      setState(() => _errorMsg = 'Could not send reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendly(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Could not send reset email. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPanel,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlowingGridBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.gap20),
                child: FadeTransition(
                  opacity: _anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(_anim),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            const Icon(Icons.lock_reset_rounded,
                                size: 56, color: AppTheme.accentBlue),
                            const SizedBox(height: 20),
                            const Text(
                              'Forgot your password?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your email and we will send you a link to reset your password.',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppTheme.gap24),

                            if (_successMsg != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(
                                    color:
                                        AppTheme.accentGreen.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppTheme.accentGreen, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _successMsg!,
                                        style: const TextStyle(
                                          color: AppTheme.accentGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.gap16),
                            ],

                            if (_errorMsg != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.accentRed.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(
                                    color:
                                        AppTheme.accentRed.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: AppTheme.accentRed, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMsg!,
                                        style: const TextStyle(
                                          color: AppTheme.accentRed,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.gap16),
                            ],

                            TextFormField(
                              controller: _emailCtrl,
                              style:
                                  const TextStyle(color: Colors.white, fontSize: 15),
                              keyboardType: TextInputType.emailAddress,
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: _fieldDec('Email address',
                                  Icons.email_outlined),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter your email';
                                }
                                final re =
                                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                if (!re.hasMatch(v.trim())) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppTheme.gap20),
                            GradientButton(
                              label: _isLoading
                                  ? 'Sending...'
                                  : 'Send Reset Link',
                              icon: Icons.send_rounded,
                              onPressed: _isLoading ? null : _reset,
                              expand: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: AppTheme.bgPanel,
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.accentBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _DividerRow extends StatelessWidget {
  const _DividerRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.borderStrong)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppTheme.textFaint,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.borderStrong)),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  const _GoogleSignInButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: AppTheme.durFast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.bgPanel,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.borderStrong),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.textMuted,
                ),
              )
            else
              _GoogleIcon(),
            const SizedBox(width: 12),
            Text(
              isLoading ? 'Please wait...' : 'Continue with Google',
              style: TextStyle(
                color: isLoading ? AppTheme.textMuted : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
      width: 22,
      height: 22,
      errorBuilder: (c, o, s) {
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(),
          child: const Icon(Icons.public_rounded, size: 20, color: Colors.white),
        );
      },
    );
  }
}
