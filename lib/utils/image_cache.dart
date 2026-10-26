import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageCacheConfig {
  static void configure() {
    PaintingBinding.instance.imageCache.maximumSize = 350;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 64 << 20; // 64 MB memory ceiling
  }
}

class ImagePreloader {
  static Future<void> preloadImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(url), context);
        } catch (_) {}
      }
    }
  }

  static Future<void> preloadImage(
    BuildContext context,
    String imageUrl,
  ) async {
    if (imageUrl.isEmpty) return;

    try {
      await precacheImage(CachedNetworkImageProvider(imageUrl), context);
    } catch (_) {}
  }
}
