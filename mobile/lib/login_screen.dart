import 'package:flutter/material.dart';
import 'api_service.dart';
import 'scan_screen.dart';

class LoginScreen extends StatefulWidget {
  final ApiService api;

  const LoginScreen({super.key, required this.api});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showServerConfig = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = ApiService.baseUrl;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter username and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Update server URL if changed
    ApiService.setBaseUrl(_serverUrlController.text.trim());

    final result = await widget.api.login(username, password);

    if (!mounted) return;

    if (result['status'] == 'success') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ScanScreen(api: widget.api),
        ),
      );
    } else {
      setState(() {
        _loading = false;
        _error = result['message'] ?? 'Login failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3F3D94)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.nfc_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'NFC Event Manager',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage event distribution',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // Login Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 24),

                          // Error message
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Login button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Server config toggle
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showServerConfig = !_showServerConfig),
                    icon: Icon(
                      _showServerConfig
                          ? Icons.settings
                          : Icons.settings_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _showServerConfig
                          ? 'Hide Server Config'
                          : 'Server Config',
                    ),
                  ),

                  if (_showServerConfig)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _serverUrlController,
                          decoration: InputDecoration(
                            labelText: 'Server URL',
                            hintText: 'http://10.0.2.2:8000/api',
                            prefixIcon: const Icon(Icons.dns_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
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
