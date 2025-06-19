import 'package:anri/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert'; // <-- IMPORT BARU untuk JSON
import 'dart:math' as math;
import 'package:http/http.dart' as http; // <-- IMPORT BARU untuk HTTP
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final FocusNode _passwordFocusNode;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = false;

  late AnimationController _auroraController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode = FocusNode();

    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeIn,
    );
    
    _loadCredentials();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _fadeAnimationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _loadCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? username = prefs.getString('username');
    final bool rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe && username != null) {
      setState(() {
        _usernameController.text = username;
        _rememberMe = rememberMe;
      });
    }
  }

  void _saveOrClearCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', _usernameController.text);
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('username');
      await prefs.remove('rememberMe');
    }
  }

  // ===== FUNGSI HANDLE LOGIN YANG BARU =====
  void _handleLogin() async {
    HapticFeedback.lightImpact();
    
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // GANTI DENGAN URL API ANDA YANG SEBENARNYA
      final url = Uri.parse('http://localhost:8080/anri_helpdesk_api/login.php');

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: json.encode({
            'username': _usernameController.text,
            'password': _passwordController.text,
          }),
        ).timeout(const Duration(seconds: 10)); // Timeout setelah 10 detik

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);

          if (responseData['success']) {
            _saveOrClearCredentials();
            
            if(mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            }
          } else {
            setState(() {
              _errorMessage = responseData['message'] ?? 'Username atau password salah.';
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Gagal terhubung ke server (Error: ${response.statusCode})';
          });
        }
      } catch (e) {
        // Menangani error timeout atau tidak ada koneksi internet
        setState(() {
          _errorMessage = 'Tidak dapat terhubung. Periksa koneksi internet Anda.';
        });
      } finally {
        if(mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  // ===== AKHIR FUNGSI HANDLE LOGIN BARU =====

  @override
  Widget build(BuildContext context) {
    // Method build() tidak ada perubahan, sama seperti sebelumnya
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Color(0xFFE0F2F7),
                Color(0xFFBBDEFB),
                Colors.blueAccent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.4, 0.7, 1.0],
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(height: 60),
                          Hero(
                            tag: 'anriLogo',
                            child: Image.asset(
                              'assets/images/anri_logo.png',
                              width: 200,
                              height: 200,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedBuilder(
                            animation: _auroraController,
                            builder: (context, child) {
                              final double value = _auroraController.value;
                              final Alignment begin = Alignment(math.sin(value * 2 * math.pi * 1.2), math.cos(value * 2 * math.pi));
                              final Alignment end = Alignment(math.cos(value * 2 * math.pi), math.sin(value * 2 * math.pi * 1.5));
                              return ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [Colors.blue.shade300, Colors.blue.shade700, Colors.lightBlueAccent],
                                  begin: begin, end: end,
                                ).createShader(bounds),
                                child: const Text('Helpdesk',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                          TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                            decoration: const InputDecoration(
                              labelText: 'Username / NIP',
                              hintText: 'Enter your Username or NIP',
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              prefixIcon: Icon(Icons.person),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Username or NIP cannot be empty';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your Password',
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onFieldSubmitted: (_) => _handleLogin(),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Password cannot be empty';
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (bool? newValue) => setState(() => _rememberMe = newValue!),
                                    activeColor: Colors.blue.shade700,
                                  ),
                                  const Text('Remember Me', style: TextStyle(color: Colors.blueGrey)),
                                ],
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Forgot Password?', style: TextStyle(color: Colors.blue)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 8,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('LOGIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}