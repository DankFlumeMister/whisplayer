class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.songCount,
    required this.albumCount,
  });

  final int id;
  final String name;
  final int songCount;
  final int albumCount;
}
