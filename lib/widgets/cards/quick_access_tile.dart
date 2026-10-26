import 'package:flutter/material.dart';
import 'package:musly/widgets/common/album_artwork.dart';

class QuickAccessTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Widget? customArtwork;
  final VoidCallback onTap;
  final VoidCallback? onPlayPressed;

  const QuickAccessTile({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.customArtwork,
    required this.onTap,
    this.onPlayPressed,
  });

  @override
  State<QuickAccessTile> createState() => _QuickAccessTileState();
}

class _QuickAccessTileState extends State<QuickAccessTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark
                ? (_isHovered
                    ? const Color(0xFF141417)
                    : const Color(0xFF0C0C0E))
                : (_isHovered
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
              width: 0.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(6)),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: widget.customArtwork ??
                      AlbumArtwork(
                        coverArt: widget.imageUrl,
                        size: 56,
                        borderRadius: 0,
                      ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: widget.subtitle != null && widget.subtitle!.isNotEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF8E8E93)
                                    : const Color(0xFF6B7280),
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              if (_isHovered && widget.onPlayPressed != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: ThemeData.estimateBrightnessForColor(
                                    Theme.of(context).colorScheme.primary) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        size: 22,
                      ),
                      onPressed: widget.onPlayPressed,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
