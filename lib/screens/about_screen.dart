import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = 'Version ${info.version} (build ${info.buildNumber})';
      });
    } catch (_) {
      // The version line is omitted when the platform channel is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy & Architecture',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 0. Hero App Branding Header
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/icon/app_logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Open Hearables',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (_versionLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _versionLabel!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Open Source Audio Control',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // 1. Privacy Banner (Tonal Container)
            Container(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons.security_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Offline & Private',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Zero cloud login, zero telemetry tokens (CleverTap/Meta), and zero internet permissions. All audio processing runs locally on your device.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Feature Comparison Surface
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feature Comparison',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildComparisonItem(
                    context,
                    title: 'Binary Footprint',
                    openValue: '13.3 MB (split APK, zero bloat)',
                    proprietaryValue: '144 MB commercial app',
                  ),
                  Divider(color: colorScheme.outlineVariant, height: 16),
                  _buildComparisonItem(
                    context,
                    title: 'System Equalizer (DSP)',
                    openValue: 'Universal Android Session 0 (Works on 311 Plus)',
                    proprietaryValue: 'Artificial software whitelist block',
                  ),
                  Divider(color: colorScheme.outlineVariant, height: 16),
                  _buildComparisonItem(
                    context,
                    title: 'Authentication',
                    openValue: 'Zero login (Instant offline launch)',
                    proprietaryValue: 'Mandatory phone OTP & cloud sync',
                  ),
                  Divider(color: colorScheme.outlineVariant, height: 16),
                  _buildComparisonItem(
                    context,
                    title: 'Permissions',
                    openValue: 'Only Bluetooth & Audio DSP',
                    proprietaryValue: 'READ_CALL_LOG, Contacts, Location, etc.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Technical Specifications Container
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Technical Architecture',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '• Protocol: Clean-room JieLi RCSP (0xFE, 0xDC, 0xBA) low-latency frames\n'
                    '• Audio DSP: Native android.media.audiofx.Equalizer Session 0\n'
                    '• Telemetry: Completely severed; no background pings\n'
                    '• Battery: Vendor BLE beacons (0x05D6 / 0x0642) with GATT (0x180F) fallback\n'
                    '• Platform: Android only (API 26+)\n'
                    '• License: MIT Open-Source (Community Edition)',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(
    BuildContext context, {
    required String title,
    required String openValue,
    required String proprietaryValue,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, color: colorScheme.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                openValue,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cancel_outlined, color: colorScheme.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                proprietaryValue,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
