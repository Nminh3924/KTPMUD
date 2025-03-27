import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import 'admin_home_screen.dart';
import 'engineer_home_screen.dart';
import 'caretaker_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _focusNodeId = FocusNode();
  final _focusNodePassword = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..forward(from: 0.0);
    _focusNodeId.addListener(() => setState(() {}));
    _focusNodePassword.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _focusNodeId.dispose();
    _focusNodePassword.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _idController.text.trim();
    final password = _passwordController.text.trim();

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final isLoggedIn = await authProvider.login(id, password);

      if (!isLoggedIn) {
        _showLoginError(authProvider.loginFailureReason, id);
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        final nextScreen = {
          'admin': const AdminHomeScreen(),
          'engineer': const EngineerHomeScreen(),
          'caretaker': const CaretakerHomeScreen(),
        }[authProvider.userRole] ?? const LoginScreen();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => nextScreen),
        );
      }
    } catch (e) {
      _showSnackBar('Lỗi đăng nhập: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLoginError(LoginFailureReason? reason, String id) {
    final messages = {
      LoginFailureReason.notFound: 'Không tìm thấy người dùng với ID: $id',
      LoginFailureReason.wrongPassword: 'Mật khẩu không đúng!',
      LoginFailureReason.error: 'Đăng nhập thất bại!',
    };
    _showSnackBar(messages[reason] ?? 'Lỗi không xác định!', Colors.red);
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            color: const Color.fromARGB(255, 243, 245, 190),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 1200,
                  height: 720,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 110, 103, 78),
                                Color.fromARGB(255, 110, 103, 78)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.blueGrey,
                                  blurRadius: 20,
                                  offset: Offset(-5, 5),
                                  spreadRadius: 2)
                            ],
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                          ),
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 50),
                                const _LogoWidget(),
                                const SizedBox(height: 20),
                                const _TitleWidget(text: 'Login'),
                                const SizedBox(height: 25),
                                _IdField(
                                  controller: _idController,
                                  focusNode: _focusNodeId,
                                  onSubmitted: (_) => _focusNodePassword.requestFocus(),
                                ),
                                const SizedBox(height: 15),
                                _PasswordField(
                                  controller: _passwordController,
                                  focusNode: _focusNodePassword,
                                  obscureText: _obscurePassword,
                                  onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                                  onSubmitted: (_) => _handleLogin(),
                                ),
                                const SizedBox(height: 25),
                                _LoginButton(
                                  isLoading: _isLoading,
                                  onPressed: _handleLogin,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 255, 255, 238),
                                Color.fromARGB(255, 253, 255, 183)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.blueGrey,
                                  blurRadius: 20,
                                  offset: Offset(-5, 5),
                                  spreadRadius: 2)
                            ],
                            borderRadius: BorderRadius.only(
                                topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                          ),
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: _WelcomeText(),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: _SubtitleText(),
                              ),
                              Flexible(
                                child: AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (_, __) => Transform.translate(
                                    offset: Offset(0, 10 * (1 - _animationController.value)),
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Image.asset('assets/nen.png', height: 500, fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                backgroundColor: Colors.black54,
              ),
            ),
        ],
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/logo.png', height: 200);
  }
}

class _TitleWidget extends StatelessWidget {
  final String text;
  const _TitleWidget({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dancingScript(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class _WelcomeText extends StatelessWidget {
  const _WelcomeText();

  @override
  Widget build(BuildContext context) {
    final animationController = context.findAncestorStateOfType<_LoginScreenState>()!._animationController;
    return AnimatedBuilder(
      animation: animationController,
      builder: (_, __) => Transform.scale(
        scale: 1 + 0.05 * animationController.value,
        child: Column(
          children: [
            Text(
              'Welcome to',
              style: GoogleFonts.dancingScript(
                fontSize: 70,
                color: const Color.fromARGB(255, 65, 14, 10),
                height: 1.0,
              ),
            ),
            Text(
              'HTAM 158176',
              style: GoogleFonts.dancingScript(
                fontSize: 75,
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 65, 14, 10),
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText();

  @override
  Widget build(BuildContext context) {
    final animationController = context.findAncestorStateOfType<_LoginScreenState>()!._animationController;
    return AnimatedBuilder(
      animation: animationController,
      builder: (_, __) => Transform.scale(
        scale: 1 + 0.03 * animationController.value,
        child: Text(
          'Quản lý trồng trọt',
          style: GoogleFonts.dancingScript(
            fontSize: 30,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _IdField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmitted;

  const _IdField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'ID',
        labelStyle: TextStyle(color: Colors.white),
        border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        errorStyle: TextStyle(color: Colors.red),
        errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Vui lòng nhập ID!';
        if (value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) return 'ID không được chứa ký tự đặc biệt!';
        return null;
      },
      onFieldSubmitted: onSubmitted,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final Function(String) onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.obscureText,
    required this.onToggleObscure,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: const TextStyle(color: Colors.white),
        border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        errorStyle: const TextStyle(color: Colors.red),
        errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        focusedErrorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.white),
          onPressed: onToggleObscure,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu!';
        return null;
      },
      onFieldSubmitted: onSubmitted,
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 198, 40, 40),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Text('Login', style: TextStyle(color: Colors.white, fontSize: 25)),
      ),
    );
  }
}