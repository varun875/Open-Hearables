import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/eq_band.dart';
import '../services/equalizer_service.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  /// Minimum touch target width for a band column. Ten bands exceed a phone's
  /// width at this size, so the matrix scrolls horizontally rather than
  /// shrinking the targets below the accessibility minimum.
  static const double _bandColumnWidth = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final eq = context.watch<EqualizerService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '10-Band Equalizer',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          Row(
            children: [
              Text(
                eq.isEnabled ? 'Active' : 'Bypassed',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: eq.isEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: eq.isEnabled,
                onChanged: (val) => eq.setEnabled(val),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Informational Banner if Bypassed
            if (!eq.isEnabled)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Equalizer DSP is currently bypassed. Switch toggle on to activate audio shaping.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Presets Horizontal Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Built-in Factory Presets
                    ...EqualizerService.presets.keys.map((p) {
                      final isSelected = eq.currentPreset == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(p),
                          selected: isSelected,
                          showCheckmark: isSelected,
                          onSelected: eq.isEnabled ? (_) => eq.applyPreset(p) : null,
                        ),
                      );
                    }),
                    // Manually edited curve
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const Icon(Icons.tune, size: 16),
                        label: const Text(EqualizerService.customPresetName),
                        selected: eq.currentPreset == EqualizerService.customPresetName,
                        showCheckmark: eq.currentPreset == EqualizerService.customPresetName,
                        onSelected: eq.isEnabled
                            ? (_) => eq.applyPreset(EqualizerService.customPresetName)
                            : null,
                      ),
                    ),
                    // User Custom Presets
                    ...eq.customPresets.keys.map((p) {
                      final isSelected = eq.currentPreset == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: const Icon(Icons.tune, size: 16),
                          label: Text(p),
                          selected: isSelected,
                          showCheckmark: isSelected,
                          onSelected: eq.isEnabled ? (_) => eq.applyPreset(p) : null,
                          onDeleted: eq.isEnabled ? () => _confirmDelete(context, eq, p) : null,
                        ),
                      );
                    }),
                    // Save Current Curve Action Chip
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Save Preset'),
                        onPressed: eq.isEnabled ? () => _showSaveDialog(context, eq) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bass Boost Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.speaker,
                        color: colorScheme.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Bass Boost',
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Semantics(
                        label: 'Bass Boost Intensity',
                        value: '${(eq.bassBoost * 100).toInt()}%',
                        child: Slider(
                          value: eq.bassBoost,
                          min: 0.0,
                          max: 1.0,
                          onChanged: eq.isEnabled && eq.bassBoostSupported
                              ? (v) => eq.setBassBoost(v)
                              : null,
                        ),
                      ),
                    ),
                    Text(
                      eq.bassBoostSupported
                          ? '${(eq.bassBoost * 100).toInt()}%'
                          : 'N/A',
                      style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 10-Band Sliders Matrix
            Expanded(
              child: Opacity(
                opacity: eq.isEnabled ? 1.0 : 0.4,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: List.generate(
                      eq.bands.length,
                      (i) => _buildBandSlider(context, eq, eq.bands[i], i),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBandSlider(
    BuildContext context,
    EqualizerService eq,
    EqBand band,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '${band.formattedFreq} frequency band',
      value: '${band.levelDb.toStringAsFixed(1)} dB',
      child: SizedBox(
        width: _bandColumnWidth,
        child: Column(
          children: [
            // Current dB readout
            Text(
              '${band.levelDb > 0 ? "+" : ""}${band.levelDb.toStringAsFixed(1)}',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: band.levelDb != 0
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: band.levelDb.clamp(eq.minLevelDb, eq.maxLevelDb),
                    min: eq.minLevelDb,
                    max: eq.maxLevelDb,
                    onChanged:
                        eq.isEnabled ? (val) => eq.setBandLevel(index, val) : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Frequency Label
            Text(
              band.formattedFreq,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveDialog(BuildContext context, EqualizerService eq) {
    final current = eq.currentPreset;
    final controller = TextEditingController(
      text: current == EqualizerService.customPresetName ||
              eq.customPresets.containsKey(current)
          ? ''
          : current,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Custom Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. My Heavy Bass',
            labelText: 'Preset Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                eq.saveCustomPreset(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, EqualizerService eq, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              eq.deleteCustomPreset(name);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
