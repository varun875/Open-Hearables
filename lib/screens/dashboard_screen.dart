import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/equalizer_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bt = context.watch<BluetoothService>();
    final eq = context.watch<EqualizerService>();
    final device = bt.deviceState;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Open Hearables',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: bt.isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Scan BLE Beacons & Battery',
            onPressed: () {
              bt.checkConnectedDevices();
              bt.startBeaconScanning();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Hero Device Status Surface
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant, width: 1),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.headphones,
                          size: 28,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  device.isConnected
                                      ? Icons.check_circle_outline
                                      : Icons.link_off,
                                  size: 14,
                                  color: device.isConnected
                                      ? colorScheme.primary
                                      : colorScheme.error,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  device.isConnected
                                      ? 'Connected • Audio & Controls'
                                      : 'Disconnected • Scanning Beacons',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: colorScheme.outlineVariant, height: 1),
                  const SizedBox(height: 20),

                  // Battery Triad (Left / Case / Right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBatteryTonal(
                        context,
                        label: 'Left Earbud',
                        shortLabel: 'Left',
                        percent: device.leftBattery,
                        isCharging: device.isLeftCharging,
                        icon: Icons.earbuds,
                      ),
                      _buildBatteryTonal(
                        context,
                        label: 'Charging Case',
                        shortLabel: 'Case',
                        percent: device.caseBattery,
                        isCharging: device.isCaseCharging,
                        icon: Icons.inventory_2_outlined,
                      ),
                      _buildBatteryTonal(
                        context,
                        label: 'Right Earbud',
                        shortLabel: 'Right',
                        percent: device.rightBattery,
                        isCharging: device.isRightCharging,
                        icon: Icons.earbuds,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Hardware Beast Mode Switch Container
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant, width: 1),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                secondary: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: device.isBeastModeActive
                        ? colorScheme.tertiaryContainer
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.sports_esports,
                    color: device.isBeastModeActive
                        ? colorScheme.onTertiaryContainer
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Beast Mode (Low Latency)',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  device.isBeastModeActive
                      ? 'Hardware buffer reduced (~48ms drop)'
                      : 'Standard music buffer (283ms)',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                value: device.isBeastModeActive,
                onChanged: (_) => bt.toggleBeastMode(),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Sound Profile Tonal Section
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant, width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Sound Profile',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: eq.isEnabled
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          eq.isEnabled ? 'DSP ACTIVE' : 'BYPASSED',
                          style: textTheme.labelSmall?.copyWith(
                            color: eq.isEnabled
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EqualizerService.presets.keys.map((preset) {
                      final isSelected = eq.currentPreset == preset;
                      return FilterChip(
                        label: Text(preset),
                        selected: isSelected,
                        showCheckmark: isSelected,
                        onSelected: (selected) {
                          if (selected) eq.applyPreset(preset);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryTonal(
    BuildContext context, {
    required String label,
    required String shortLabel,
    required int percent,
    required bool isCharging,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final isLow = percent <= 20 && percent >= 0 && !isCharging;
    final progressColor = isCharging
        ? colorScheme.tertiary
        : (isLow ? colorScheme.error : colorScheme.primary);

    return Semantics(
      label: '$label battery level',
      value: '$percent percent${isCharging ? ", charging" : ""}',
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  value: percent >= 0 ? (percent / 100.0) : 0.0,
                  strokeWidth: 4.5,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              Icon(
                isCharging ? Icons.bolt : icon,
                size: 22,
                color: isCharging
                    ? colorScheme.tertiary
                    : (isLow ? colorScheme.error : colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLow) ...[
                Icon(Icons.warning_amber_rounded, size: 12, color: colorScheme.error),
                const SizedBox(width: 2),
              ],
              Text(
                percent >= 0 ? '$percent%' : '--',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLow ? colorScheme.error : colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Text(
            shortLabel,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
