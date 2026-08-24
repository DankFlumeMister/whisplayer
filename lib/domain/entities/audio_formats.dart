abstract final class AudioFormats {
  static const Set<String> supportedExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
    '.ape',
    '.aiff',
    '.aif',
  };

  static bool isSupported(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) {
      return false;
    }
    return supportedExtensions.contains(path.substring(dot).toLowerCase());
  }
}
