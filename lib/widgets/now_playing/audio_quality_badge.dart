import 'package:flutter/material.dart';
import '../../models/song.dart';
import '../../services/audio_quality_manager.dart';

/// Painter vectoriel pur pour les ondes sonores (Style Apple Music / Tidal).
/// Zéro emoji, rendu géométrique net et anti-aliasé.
class AudioWaveformVectorPainter extends CustomPainter {
  final Color color;
  final bool isAnimated;

  AudioWaveformVectorPainter({
    required this.color,
    this.isAnimated = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    // 4 barres vectorielles proportionnées
    final barWidth = size.width / 7.0;
    final heights = [0.45, 0.95, 0.65, 0.85];

    for (int i = 0; i < heights.length; i++) {
      final x = (i * 2.0) * barWidth + (barWidth / 2.0);
      final barH = size.height * heights[i];
      final top = (size.height - barH) / 2.0;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth * 0.85, barH),
        Radius.circular(barWidth / 2.0),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioWaveformVectorPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isAnimated != isAnimated;
  }
}

/// Pastille d'indication de la qualité audio en temps réel.
/// Reprend l'esthétique exacte des badges Apple Music / Tidal (Pill, verre dépoli, micro-bordure 0.5px).
class AudioQualityBadge extends StatefulWidget {
  final Song? song;
  final bool isSmall;

  const AudioQualityBadge({
    super.key,
    required this.song,
    this.isSmall = false,
  });

  @override
  State<AudioQualityBadge> createState() => _AudioQualityBadgeState();
}

class _AudioQualityBadgeState extends State<AudioQualityBadge> {
  AudioQualityDetails? _details;

  @override
  void initState() {
    super.initState();
    _loadQuality();
    AudioQualityManager().addListener(_onManagerUpdate);
  }

  @override
  void didUpdateWidget(covariant AudioQualityBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id) {
      _loadQuality();
    }
  }

  @override
  void dispose() {
    AudioQualityManager().removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) _loadQuality();
  }

  Future<void> _loadQuality() async {
    final s = widget.song;
    if (s == null) {
      if (mounted) setState(() => _details = null);
      return;
    }
    final q = await AudioQualityManager().getSongQuality(s);
    if (mounted) {
      setState(() => _details = q);
    }
  }

  void _showQualityModal(BuildContext context, AudioQualityDetails details) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                        width: 0.5,
                      ),
                    ),
                    child: CustomPaint(
                      painter: AudioWaveformVectorPainter(
                        color: details.isHighQuality
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          details.label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    _buildSpecRow('Format du flux', details.format.name.toUpperCase()),
                    const Divider(color: Colors.white10, height: 16),
                    _buildSpecRow('Fréquence d\'échantillonnage', details.sampleRate),
                    const Divider(color: Colors.white10, height: 16),
                    _buildSpecRow('Débit binaire', details.bitRate),
                    const Divider(color: Colors.white10, height: 16),
                    _buildSpecRow('Source serveur', 'CJ Stream Direct Resolver'),
                    const Divider(color: Colors.white10, height: 16),
                    _buildSpecRow('Moteur de rendu', 'ExoPlayer (AndroidX Media3)'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.song == null) return const SizedBox.shrink();
    final d = _details ??
        AudioQualityDetails.fromFormat(AudioCodecFormat.opus,
            reportedBitrate: widget.song?.bitRate);

    final accentColor = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: 'Qualité audio: ${d.label}',
      button: true,
      child: GestureDetector(
        onTap: () => _showQualityModal(context, d),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: d.isHighQuality
                  ? accentColor.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(11, 9),
                painter: AudioWaveformVectorPainter(
                  color: d.isHighQuality ? accentColor : Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                d.badgeText,
                style: TextStyle(
                  fontSize: widget.isSmall ? 9.5 : 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
