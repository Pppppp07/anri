import 'package:anri/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
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
    final String? username = prefs.getString('user_username');
    final bool rememberMe = prefs.getBool('rememberMe') ?? true;

    if (rememberMe && username != null) {
      setState(() {
        _usernameController.text = username;
        _rememberMe = rememberMe;
      });
    }
  }

  // --- FUNGSI INI DIRAPIKAN UNTUK MENJADI SATU-SATUNYA SUMBER PENYIMPANAN ---
  Future<void> _saveCredentials({
    required Map<String, dynamic> userData,
    required String token,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('user_id', userData['id']);
    await prefs.setString('user_name', userData['name']);
    await prefs.setString('user_username', userData['username']);
    await prefs.setString('user_email', userData['email']);
    await prefs.setString('auth_token', token); // Simpan token otentikasi
    await prefs.setBool('rememberMe', _rememberMe);
  }

  Future<void> _clearCredentials() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void _handleLogin() async {
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
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);

          if (responseData['success']) {
            // --- PERUBAHAN UTAMA DI SINI ---
            final userData = responseData['user_data'] as Map<String, dynamic>;
            final String currentUserName = userData['name'];
            final String? authToken = responseData['token'];

            if (authToken != null) {
              // Jika login sukses dan dapat token, simpan kredensial
              if (_rememberMe) {
                await _saveCredentials(userData: userData, token: authToken);
              } else {
                await _clearCredentials();
              }

              if (mounted) {
                // Navigasi ke HomePage dengan membawa nama dan token
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
              // Handle jika API sukses tapi tidak mengirim token
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
        } else {
          setState(() {
            _errorMessage =
                'Gagal terhubung ke server (Error: ${response.statusCode})';
          });
        }
      } catch (e) {
        debugPrint('Login Error: $e');
        setState(() {
          _errorMessage =
              'Tidak dapat terhubung. Periksa koneksi atau hubungi admin.';
        });
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
    // Seluruh UI (build method) tidak ada perubahan sama sekali
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
                          AnimatedBuilder(
                            animation: _auroraController,
                            builder: (context, child) {
                              final double value = _auroraController.value;
                              final Alignment begin = Alignment(
                                math.sin(value * 2 * math.pi * 1.2),
                                math.cos(value * 2 * math.pi),
                              );
                              final Alignment end = Alignment(
                                math.cos(value * 2 * math.pi),
                                math.sin(value * 2 * math.pi * 1.5),
                              );
                              return ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Colors.blue.shade300,
                                    Colors.blue.shade700,
                                    Colors.lightBlueAccent,
                                  ],
                                  begin: begin,
                                  end: end,
                                ).createShader(bounds),
                                child: const Text(
                                  'Helpdesk',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                          TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(
                              context,
                            ).requestFocus(_passwordFocusNode),
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              hintText: 'Enter your Username',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              prefixIcon: Icon(Icons.person),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username or cannot be empty';
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
                              hintText: 'Enter your Password',
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                  () =>
                                      _isPasswordVisible = !_isPasswordVisible,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password cannot be empty';
                              }
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
                                    onChanged: (bool? newValue) =>
                                        setState(() => _rememberMe = newValue!),
                                    activeColor: Colors.blue.shade700,
                                  ),
                                  const Text(
                                    'Remember Me',
                                    style: TextStyle(color: Colors.blueGrey),
                                  ),
                                ],
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
                                  color: Colors.red,
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
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
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
