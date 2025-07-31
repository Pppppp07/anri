// lib/pages/login_page.dart

import 'package:anri/home_page.dart';
import 'package:anri/services/firebase_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anri/config/api_config.dart';

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
  bool _rememberMe = true;

  // [PERBAIKAN 1] Controller untuk animasi Text-Reveal
  late AnimationController _textAnimationController;
  late Animation<double> _textAnimation;
  
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode = FocusNode();

    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500), // Sedikit diperlambat
    )..repeat(); // [PERBAIKAN 2] Cukup repeat, tanpa reverse

    // Animasi akan bernilai dari -1.0 hingga 2.0 untuk loop yang mulus
    _textAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _textAnimationController, curve: Curves.linear),
    );

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
    _textAnimationController.dispose();
    _fadeAnimationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // SEMUA LOGIKA LOGIN ANDA TETAP SAMA
  void _loadCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? username = prefs.getString('user_username');
    final bool rememberMe = prefs.getBool('rememberMe') ?? true;

    if (rememberMe && username != null) {
      setState(() {
        _usernameController.text = username;
        _rememberMe = rememberMe;
      });
    }
  }

  Future<void> _saveCredentials({
    required Map<String, dynamic> userData,
    required String token,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('user_id', userData['id']);
    await prefs.setString('user_name', userData['name']);
    await prefs.setString('user_email', userData['email']);
    await prefs.setString('auth_token', token);
    await prefs.setBool('rememberMe', _rememberMe);

    if (_rememberMe) {
      await prefs.setString('user_username', userData['username']);
    } else {
      await prefs.remove('user_username');
    }
  }

  // --- FUNGSI INI TELAH DIPERBARUI ---
  Future<void> _handleLogin() async {
    HapticFeedback.lightImpact();

    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final url = Uri.parse('${ApiConfig.baseUrl}/login.php');

      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: json.encode({
                'username': _usernameController.text,
                'password': _passwordController.text,
              }),
            )
            .timeout(const Duration(seconds: 15)); // Timeout sedikit diperpanjang

        if (!mounted) return;

        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['success']) {
          final userData = responseData['user_data'] as Map<String, dynamic>;
          final String currentUserName = userData['name'];
          final String? authToken = responseData['token'];

          if (authToken != null) {
            await _saveCredentials(userData: userData, token: authToken);
            
            if (mounted) {
              // Inisialisasi notifikasi setelah kredensial disimpan
              await context.read<FirebaseApi>().initNotifications();
            }
            
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    currentUserName: currentUserName,
                    authToken: authToken,
                  ),
                ),
              );
            }
          } else {
            setState(() {
              _errorMessage = 'Login gagal: Server tidak memberikan token.';
            });
          }
        } else {
          setState(() {
            _errorMessage =
                responseData['message'] ?? 'Username atau password salah.';
          });
        }
      } catch (e, stackTrace) {
        // --- INI PERUBAHAN PALING PENTING ---
        // Kita akan menampilkan error yang sebenarnya ke layar.
        debugPrint('Login Error: $e');
        debugPrint('Stack trace: $stackTrace');
        setState(() {
          _errorMessage = 'Terjadi Error Internal: ${e.toString()}';
        });
        // ------------------------------------

      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final loginPageDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: isDarkMode
            ? [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.background
              ]
            : [
                Colors.white,
                const Color(0xFFE0F2F7),
                const Color(0xFFBBDEFB),
                Colors.blueAccent
              ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: loginPageDecoration,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(height: 60),
                          Hero(
                            tag: 'anriLogo',
                            child: Image.asset(
                              'assets/images/anri_logo.png',
                              width: 150,
                              height: 150,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // [PERBAIKAN 3] Logika ShaderMask untuk loop yang mulus
                          AnimatedBuilder(
                            animation: _textAnimation,
                            builder: (context, child) {
                              return ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  // Nilai animasi sekarang berjalan dari -1.0 hingga 2.0
                                  final slidePosition = _textAnimation.value;
                                  const highlightWidth = 0.2; // Lebar "cahaya"

                                  return LinearGradient(
                                    colors: const [
                                      Colors.blue,
                                      Colors.lightBlueAccent,
                                      Colors.white,
                                      Colors.lightBlueAccent,
                                      Colors.blue,
                                    ],
                                    // 'stops' bergerak bersama nilai animasi
                                    stops: [
                                      slidePosition - (highlightWidth * 2),
                                      slidePosition - highlightWidth,
                                      slidePosition,
                                      slidePosition + highlightWidth,
                                      slidePosition + (highlightWidth * 2),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ).createShader(bounds);
                                },
                                child: child,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Helpdesk',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                          // Sisa dari Form Anda tetap sama
                           TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_passwordFocusNode),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              hintText: 'Masukkan username Anda',
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              prefixIcon: const Icon(Icons.person),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: !_isPasswordVisible,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Masukkan password Anda',
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible,
                                ),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _rememberMe = !_rememberMe;
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (bool? newValue) {
                                        setState(() {
                                          _rememberMe = newValue!;
                                        });
                                      },
                                      checkColor: Theme.of(context).colorScheme.onPrimary,
                                      fillColor: MaterialStateProperty.resolveWith<Color>(
                                        (Set<MaterialState> states) {
                                          if (states.contains(MaterialState.selected)) {
                                            return Theme.of(context).colorScheme.primary;
                                          }
                                          if(isDarkMode) {
                                            return Colors.white70;
                                          }
                                          return Theme.of(context).unselectedWidgetColor;
                                        },
                                      ),
                                    ),
                                    Text(
                                      'Ingat Saya',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
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