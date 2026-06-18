import 'package:flutter/widgets.dart';
import 'api.dart';
import 'asset_images.dart';

/// Returns the best image source for a given remote URL:
///  - the BUNDLED asset if we shipped one (instant, offline, no server needed)
///  - otherwise the network image (routed through the backend proxy on web)
///
/// Bundling is preferred for store builds (iOS/Android) so the app never shows
/// blank images when the network or backend is slow/unreachable. Drop-in usage:
///   Image(image: appImg(url), width: .., height: .., fit: .., errorBuilder: ..)
ImageProvider appImg(String url) {
  final key = url.split('?').first; // map is keyed without the resize query
  final asset = kAssetForUrl[key];
  if (asset != null) return AssetImage(asset);
  return NetworkImage(Api.img(url));
}
