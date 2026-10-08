/// Deployment settings that differ between environments.
class AppConfig {
  /// Directus (CMS) address, e.g. 'https://cms.yourdomain.co.uk'.
  /// Uploaded images are served from `$cmsBaseUrl/assets/{file id}`.
  /// Leave empty until the CMS is deployed; images are then skipped.
  static const String cmsBaseUrl = String.fromEnvironment(
    'CMS_BASE_URL',
    defaultValue: '',
  );

  /// URL for an image stored as a Directus file id or a full URL.
  /// [width] asks Directus for a resized copy.
  static String? imageUrl(String? ref, {int width = 800}) {
    if (ref == null || ref.trim().isEmpty) return null;
    if (ref.startsWith('http://') || ref.startsWith('https://')) return ref;
    if (cmsBaseUrl.isEmpty) return null;
    return '$cmsBaseUrl/assets/$ref?width=$width&format=webp';
  }
}
