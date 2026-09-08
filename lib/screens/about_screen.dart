import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Open Hearables'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Card
          Card(
            color: Colors.green.withAlpha(25),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shield, color: Colors.green, size: 36),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Offline & Private',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Zero analytics, zero tracking tokens (CleverTap/Meta), zero cloud login. No telemetry leaves your phone.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Features List Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How It Beats boAt Hearables',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildComparisonRow(
                    'App Footprint',
                    '<5 MB clean Flutter APK',
                    '144 MB bloatware',
                  ),
                  const Divider(),
                  _buildComparisonRow(
                    'Equalizer (EQ)',
                    'Universal System DSP (Works on 311 Plus)',
                    'Software whitelist locked',
                  ),
                  const Divider(),
                  _buildComparisonRow(
                    'Login Required',
                    'Zero login (Instant local launch)',
                    'Forced OTP & cloud login',
                  ),
                  const Divider(),
                  _buildComparisonRow(
                    'Permissions',
                    'Only Bluetooth & Audio DSP',
                    'READ_CALL_LOG, Contacts, etc.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Technical Specs
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Technical Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Protocol: Clean JieLi RCSP (0xBA, 0xDC) frame implementation\n'
                    '• DSP Engine: Android AudioEffect Session 0 Pipeline\n'
                    '• Battery: Bluetooth SIG GATT Service (0x180F)\n'
                    '• License: Open Source (Clean-room implementation)',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String feature, String openVal, String boatVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feature, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(openVal, style: const TextStyle(fontSize: 13, color: Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.cancel, color: Colors.redAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(boatVal, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
