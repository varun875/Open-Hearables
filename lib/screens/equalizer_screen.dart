import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/eq_band.dart';
import '../services/equalizer_service.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

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
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: EqualizerService.presets.keys.map((p) {
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
                  }).toList(),
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
                          onChanged: eq.isEnabled ? (v) => eq.setBassBoost(v) : null,
                        ),
                      ),
                    ),
                    Text(
                      '${(eq.bassBoost * 100).toInt()}%',
                      style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 10-Band Sliders Matrix
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Opacity(
                  opacity: eq.isEnabled ? 1.0 : 0.4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(eq.bands.length, (i) {
                      final band = eq.bands[i];
                      return _buildBandSlider(context, eq, band, i);
                    }),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Semantics(
      label: '${band.formattedFreq} frequency band',
      value: '${band.levelDb.toStringAsFixed(1)} dB',
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
          // Vertical Slider with min 48dp touch target width
          Expanded(
            child: SizedBox(
              width: 32, // Touch target column
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: band.levelDb,
                    min: -12.0,
                    max: 12.0,
                    onChanged: eq.isEnabled ? (val) => eq.setBandLevel(index, val) : null,
                  ),
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
    );
  }
}
