enum SourceType {
  local,
  remote,

  /// Files reached through a WebDAV share instead of the Subsonic API.
  ///
  /// Appended last on purpose: `intEnum<SourceType>()` persists the *index*,
  /// so inserting a value in the middle would silently reinterpret every
  /// row already stored in the `songs` table.
  webdav,
}
