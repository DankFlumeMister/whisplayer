import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/subsonic/subsonic_client.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';

class RemoteServersPage extends ConsumerWidget {
  const RemoteServersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(remoteServerRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('远程音乐服务器')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<RemoteServer>>(
        stream: repo.watchServers(),
        builder: (context, snapshot) {
          final servers = snapshot.data ?? const <RemoteServer>[];
          if (servers.isEmpty) {
            return const Center(
              child: Text('还没有服务器，点右下角添加'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              for (final server in servers)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(server.name),
                    subtitle: Text('${server.baseUrl} · ${server.username}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '删除',
                      onPressed: () =>
                          _confirmDelete(context, ref, repo, server),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RemoteServerRepository repo,
    RemoteServer server,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${server.name}？'),
        content: const Text('将同时删除已保存的密码。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await repo.removeServer(server.id);
    }
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final userController = TextEditingController();
    final passwordController = TextEditingController();
    var testing = false;
    var saving = false;
    String? feedback;
    String? hint;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加服务器'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'http://服务器IP:端口',
                  ),
                  keyboardType: TextInputType.url,
                ),
                TextField(
                  controller: userController,
                  decoration:
                      const InputDecoration(labelText: '用户名'),
                ),
                TextField(
                  controller: passwordController,
                  decoration:
                      const InputDecoration(labelText: '密码'),
                  obscureText: true,
                ),
                if (feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      feedback!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      hint!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: testing || saving
                  ? null
                  : () async {
                      setState(() {
                        testing = true;
                        feedback = null;
                        hint = null;
                      });
                      final (ok, message) = await _testConnection(
                        urlController.text,
                        userController.text,
                        passwordController.text,
                      );
                      if (!dialogContext.mounted) {
                        return;
                      }
                      setState(() {
                        testing = false;
                        feedback = ok ? null : message;
                        hint = ok ? null : _loopbackHint(urlController.text);
                      });
                    },
              child: testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('测试连接'),
            ),
            FilledButton(
              onPressed: testing || saving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final url = urlController.text.trim();
                      final user = userController.text.trim();
                      if (name.isEmpty ||
                          url.isEmpty ||
                          user.isEmpty ||
                          passwordController.text.isEmpty) {
                        setState(() => feedback = '请填写全部字段');
                        return;
                      }
                      try {
                        SubsonicClient.normalizeBaseUrl(url);
                      } on FormatException catch (e) {
                        setState(() => feedback = e.message);
                        return;
                      }
                      setState(() => saving = true);
                      await ref
                          .read(remoteServerRepositoryProvider)
                          .addServer(
                            name: name,
                            baseUrl: url,
                            username: user,
                            password: passwordController.text,
                          );
                      if (!dialogContext.mounted) {
                        return;
                      }
                      if (_isLoopback(url)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '注意：127.0.0.1 指向手机自身，通常应填写电脑的局域网 IP',
                            ),
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                      Navigator.pop(dialogContext);
                    },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<(bool, String)> _testConnection(
    String rawUrl,
    String username,
    String password,
  ) async {
    if (rawUrl.trim().isEmpty ||
        username.trim().isEmpty ||
        password.isEmpty) {
      return (false, '请填写地址、用户名和密码');
    }
    final String normalized;
    try {
      normalized = SubsonicClient.normalizeBaseUrl(rawUrl);
    } on FormatException catch (e) {
      return (false, e.message);
    }
    if (_isLoopback(normalized)) {
      return (
        false,
        '127.0.0.1 / localhost 指向手机自身，无法访问电脑上的服务器；请填写电脑的局域网 IP（ipconfig 查看）',
      );
    }
    try {
      final client = SubsonicClient(
        baseUrl: normalized,
        username: username.trim(),
        password: password,
      );
      await client.ping();
      return (true, '连接成功 ✓ 将使用 $normalized');
    } on SubsonicException catch (e) {
      return (false, '服务器响应错误：${e.message}');
    } on Exception catch (_) {
      return (false, '无法连接到 $normalized（请检查地址与手机网络）');
    }
  }

  static bool _isLoopback(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1';
  }

  static String? _loopbackHint(String url) {
    if (!_isLoopback(url)) {
      return null;
    }
    return '127.0.0.1 指向手机自身，无法访问电脑上的服务器；请填写电脑的局域网 IP';
  }
}
