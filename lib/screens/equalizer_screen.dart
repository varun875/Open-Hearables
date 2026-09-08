import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/equalizer_service.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eq = context.watch<EqualizerService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('10-Band Equalizer'),
        actions: [
          Row(
            children: [
              Text(
                eq.isEnabled ? 'ON' : 'OFF',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Switch(
                value: eq.isEnabled,
                onChanged: (val) => eq.setEnabled(val),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Opacity(
        opacity: eq.isEnabled ? 1.0 : 0.4,
        child: AbsorbPointer(
          absorbing: !eq.isEnabled,
          child: Column(
            children: [
              // Presets Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: EqualizerService.presets.keys.map((p) {
                      final isSelected = eq.currentPreset == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(p),
                          selected: isSelected,
                          onSelected: (_) => eq.applyPreset(p),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Bass Boost Rotary/Slider Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.speaker, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        const Text(
                          'Bass Boost',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Expanded(
                          child: Slider(
                            value: eq.bassBoost,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) => eq.setBassBoost(v),
                          ),
                        ),
                        Text(
                          '${(eq.bassBoost * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 10-Band Sliders Grid / View
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(eq.bands.length, (i) {
                      final band = eq.bands[i];
                      return _buildBandSlider(context, eq, band, i);
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBandSlider(
    BuildContext context,
    EqualizerService eq,
    dynamic band,
    int index,
  ) {
    return Column(
      children: [
        Text(
          '${band.levelDb > 0 ? "+" : ""}${band.levelDb.toStringAsFixed(1)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: band.levelDb != 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: band.levelDb,
                min: -12.0,
                max: 12.0,
                onChanged: (val) => eq.setBandLevel(index, val),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          band.formattedFreq,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
