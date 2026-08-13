import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../data/services/license_service.dart';

class LicenseBlockedScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LicenseBlockedScreen({super.key, required this.onUnlocked});

  @override
  State<LicenseBlockedScreen> createState() => _LicenseBlockedScreenState();
}

class _LicenseBlockedScreenState extends State<LicenseBlockedScreen> {
  bool _isChecking = false;

  void _checkAgain() async {
    setState(() => _isChecking = true);
    final isUnlocked = await LicenseService.instance.initializeAndVerify();
    setState(() => _isChecking = false);

    if (isUnlocked) {
      widget.onUnlocked();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ License status is still blocked or unreachable.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = LicenseService.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate blue background
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Main Center Container
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 540),
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // Dark card surface
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Lock Icon & Badge
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade900.withValues(alpha: 0.25),
                        border: Border.all(color: Colors.red.shade600, width: 2),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 48,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'SOFTWARE ACCESS RESTRICTED',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Client ID: ${service.clientId}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Block Message Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF450A0A).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade800.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Status Details:',
                                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            service.blockReason.isNotEmpty
                                ? service.blockReason
                                : 'Your software license has been suspended or payment is pending.',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Contact Agency Details Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade900.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: const [
                          Text(
                            'SUPPORT & RENEWAL CONTACT',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.1),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Wisdom Core Solutions',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text('📞 Phone: 9050524678', style: TextStyle(fontSize: 13, color: Colors.white70)),
                          Text('🌐 Website: wisdomcoresolution.store', style: TextStyle(fontSize: 12, color: Colors.white60)),
                          Text('✉️ Email: wisdomcoresolutions@gmail.com', style: TextStyle(fontSize: 12, color: Colors.white60)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isChecking ? null : _checkAgain,
                            icon: _isChecking
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.refresh, size: 18),
                            label: const Text('Check Online Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
