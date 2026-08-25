import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/subsonic/subsonic_client.dart';
import 'package:whisplayer/data/subsonic/subsonic_models.dart';
import 'package:whisplayer/domain/entities/remote_server.dart';
import 'package:whisplayer/domain/repositories/remote_server_repository.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

class RemoteServersPage extends ConsumerWidget {
  const RemoteServersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(remoteServerRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.remoteServersEntry)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<RemoteServer>>(
        stream: repo.watchServers(),
        builder: (context, snapshot) {
          final servers = snapshot.data ?? const <RemoteServer>[];
          if (servers.isEmpty) {
            return Center(child: Text(l10n.noServerYet));
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
                      tooltip: l10n.tooltipDelete,
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteServerTitle(server.name)),
        content: Text(l10n.deleteServerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await repo.removeServer(server.id);
    }
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
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
          title: Text(l10n.addServerTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      InputDecoration(labelText: l10n.fieldName),
                ),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: l10n.fieldAddress,
                    hintText: l10n.fieldAddressHint,
                  ),
                  keyboardType: TextInputType.url,
                ),
                TextField(
                  controller: userController,
                  decoration:
                      InputDecoration(labelText: l10n.fieldUsername),
                ),
                TextField(
                  controller: passwordController,
                  decoration:
                      InputDecoration(labelText: l10n.fieldPassword),
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
                        context,
                        ref,
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
                        hint = ok
                            ? null
                            : _loopbackHint(l10n, urlController.text);
                      });
                    },
              child: testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.testConnection),
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
                        setState(() => feedback = l10n.fillAllFields);
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
                          SnackBar(
                            content: Text(l10n.loopbackSnackBar),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                      Navigator.pop(dialogContext);
                    },
              child: Text(l10n.saveAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<(bool, String)> _testConnection(
    BuildContext context,
    WidgetRef ref,
    String rawUrl,
    String username,
    String password,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (rawUrl.trim().isEmpty ||
        username.trim().isEmpty ||
        password.isEmpty) {
      return (false, l10n.fillAllFieldsFull);
    }
    final String normalized;
    try {
      normalized = SubsonicClient.normalizeBaseUrl(rawUrl);
    } on FormatException catch (e) {
      return (false, e.message);
    }
    if (_isLoopback(normalized)) {
      return (false, l10n.loopbackTest);
    }
    try {
      final client = SubsonicClient(
        baseUrl: normalized,
        username: username.trim(),
        password: password,
      );
      await client.ping();
      return (true, l10n.testOk(normalized));
    } on SubsonicException catch (e) {
      return (false, l10n.serverErrorMsg(e.message));
    } on Exception catch (_) {
      return (false, l10n.cannotConnectMsg(normalized));
    }
  }

  static bool _isLoopback(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1';
  }

  static String? _loopbackHint(AppLocalizations l10n, String url) {
    if (!_isLoopback(url)) {
      return null;
    }
    return l10n.loopbackHint;
  }
}
