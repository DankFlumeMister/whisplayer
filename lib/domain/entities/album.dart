class Album {
  const Album({
    required this.id,
    required this.title,
    required this.groupKey,
    required this.songCount,
    this.artistId,
    this.artistName,
    this.year,
    this.artworkPath,
  });

  final int id;
  final String title;
  final String groupKey;
  final int? artistId;
  final String? artistName;
  final int? year;
  final String? artworkPath;
  final int songCount;
}
