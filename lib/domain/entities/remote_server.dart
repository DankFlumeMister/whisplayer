class RemoteServer {
  const RemoteServer({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.addedAtMs,
  });

  final int id;
  final String name;
  final String baseUrl;
  final String username;
  final int addedAtMs;
}
