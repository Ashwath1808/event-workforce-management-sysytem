import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'forgot_password.dart';
import 'organizer_home_page.dart';
import 'signup_page.dart';
import 'worker_home_page.dart';

class LoginPage extends StatefulWidget {
  final String role;

  const LoginPage({
    super.key,
    required this.role,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      final user = await AuthService().login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        selectedRole: widget.role,
      );

      if (!mounted) return;

      // ========================================================
      // WORKER LOGIN
      // ========================================================

      if (user.role.toLowerCase() == 'worker') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerHomePage(
              user: user,
            ),
          ),
              (route) => false,
        );
      }

      // ========================================================
      // ORGANIZER LOGIN
      // ========================================================

      else if (user.role.toLowerCase() == 'organizer') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => OrganizerHomePage(
              user: user,
            ),
          ),
              (route) => false,
        );
      }

      // ========================================================
      // UNKNOWN ROLE
      // ========================================================

      else {
        await AuthService().logout();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid account role. Please contact administrator.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final message = e
          .toString()
          .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isWorker =
        widget.role.toLowerCase() == 'worker';

    final String roleName =
    isWorker ? 'Worker' : 'Organizer';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FF),
        elevation: 0,
        scrolledUnderElevation: 0,

        title: Text(
          '$roleName Login',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: true,

        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),

          padding: const EdgeInsets.all(24),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),

              child: Form(
                key: _formKey,

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,

                  children: [
                    const SizedBox(height: 20),

                    // ==================================================
                    // ICON
                    // ==================================================

                    Center(
                      child: Container(
                        width: 90,
                        height: 90,

                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEBFF),
                          borderRadius:
                          BorderRadius.circular(25),
                        ),

                        child: Icon(
                          isWorker
                              ? Icons.engineering_rounded
                              : Icons.manage_accounts_rounded,
                          size: 48,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ==================================================
                    // TITLE
                    // ==================================================

                    Text(
                      'Welcome Back!',
                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Login as $roleName',
                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // ==================================================
                    // EMAIL
                    // ==================================================

                    const Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _emailController,

                      keyboardType:
                      TextInputType.emailAddress,

                      textInputAction:
                      TextInputAction.next,

                      decoration: InputDecoration(
                        hintText:
                        'Enter your email',

                        prefixIcon: const Icon(
                          Icons.email_outlined,
                        ),

                        filled: true,

                        fillColor: Colors.white,

                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide.none,
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide:
                          BorderSide.none,
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide:
                          const BorderSide(
                            color: Color(0xFF4F46E5),
                            width: 1.5,
                          ),
                        ),
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter your email';
                        }

                        final email =
                        value.trim();

                        if (!email.contains('@') ||
                            !email.contains('.')) {
                          return 'Please enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // PASSWORD
                    // ==================================================

                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller:
                      _passwordController,

                      obscureText:
                      _obscurePassword,

                      textInputAction:
                      TextInputAction.done,

                      onFieldSubmitted: (_) {
                        if (!_loading) {
                          _login();
                        }
                      },

                      decoration: InputDecoration(
                        hintText:
                        'Enter your password',

                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),

                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                              !_obscurePassword;
                            });
                          },

                          icon: Icon(
                            _obscurePassword
                                ? Icons
                                .visibility_outlined
                                : Icons
                                .visibility_off_outlined,
                          ),
                        ),

                        filled: true,

                        fillColor: Colors.white,

                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide: BorderSide.none,
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide:
                          BorderSide.none,
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12),

                          borderSide:
                          const BorderSide(
                            color: Color(0xFF4F46E5),
                            width: 1.5,
                          ),
                        ),
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Please enter your password';
                        }

                        return null;
                      },
                    ),

                    // ==================================================
                    // FORGOT PASSWORD
                    // ==================================================

                    Align(
                      alignment:
                      Alignment.centerRight,

                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const ForgotPasswordPage(),
                            ),
                          );
                        },

                        child: const Text(
                          'Forgot Password?',
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ==================================================
                    // LOGIN BUTTON
                    // ==================================================

                    SizedBox(
                      height: 54,
                      width: double.infinity,

                      child: FilledButton(
                        onPressed:
                        _loading ? null : _login,

                        style: FilledButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF4F46E5),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                        ),

                        child: _loading
                            ? const SizedBox(
                          height: 24,
                          width: 24,

                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // SIGN UP
                    // ==================================================

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,

                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),

                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SignupPage(
                                      role: widget.role,
                                    ),
                              ),
                            );
                          },

                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
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