import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whisplayer/core/providers/repository_providers.dart';
import 'package:whisplayer/data/webdav/webdav_client.dart';
import 'package:whisplayer/domain/entities/webdav_server.dart';
import 'package:whisplayer/domain/repositories/webdav_server_repository.dart';
import 'package:whisplayer/features/settings/presentation/webdav_scan_sheet.dart';
import 'package:whisplayer/l10n/app_localizations.dart';

/// Manages the saved WebDAV music sources.
///
/// A WebDAV source replaces the Subsonic cloud branch: the app reads the
/// share directly, so covers, sidecar lyrics and folder structure all come
/// from the file system rather than from a server-side index.
class WebDavServersPage extends ConsumerWidget {
  const WebDavServersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(webDavServerRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.webdavEntry)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<WebDavServer>>(
        stream: repo.watchServers(),
        builder: (context, snapshot) {
          final servers = snapshot.data ?? const <WebDavServer>[];
          if (servers.isEmpty) {
            return Center(child: Text(l10n.webdavNoServerYet));
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
                    leading: const Icon(Icons.cloud_outlined),
                    title: Text(server.name),
                    subtitle: Text(
                      '${server.baseUrl} · ${server.username}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: l10n.startScanAction,
                          onPressed: () => _openScan(context, server),
                        ),
                        IconButton(
                          icon: const Icon(Icons.restart_alt_rounded),
                          tooltip: l10n.clearAndRescanAction,
                          onPressed: () =>
                              _confirmClearAndRescan(context, server),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.tooltipDelete,
                          onPressed: () =>
                              _confirmDelete(context, repo, server),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openScan(
    BuildContext context,
    WebDavServer server, {
    bool clearFirst = false,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WebDavScanSheet(server: server, clearFirst: clearFirst),
    );
  }

  /// Confirms before wiping, because the delete cannot be undone without
  /// re-downloading the whole share.
  Future<void> _confirmClearAndRescan(
    BuildContext context,
    WebDavServer server,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearAndRescanTitle),
        content: Text(l10n.clearAndRescanBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.clearAndRescanAction),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      await _openScan(context, server, clearFirst: true);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WebDavServerRepository repo,
    WebDavServer server,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteWebdavTitle(server.name)),
        content: Text(l10n.deleteWebdavBody),
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
    // Pre-filled so the "name is required" rule cannot silently block a save
    // that the user believes they completed.
    final nameController = TextEditingController(text: 'WebDAV');
    final urlController = TextEditingController();
    final userController = TextEditingController(text: 'whisplayer');
    final tokenController = TextEditingController();
    final rootController = TextEditingController(text: '/');
    var testing = false;
    var saving = false;
    String? feedback;
    var feedbackOk = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addWebdavTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l10n.fieldName),
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
                  controller: tokenController,
                  decoration: InputDecoration(
                    labelText: l10n.fieldToken,
                    hintText: l10n.fieldTokenHint,
                  ),
                  obscureText: true,
                ),
                TextField(
                  controller: rootController,
                  decoration:
                      InputDecoration(labelText: l10n.fieldRootPath),
                ),
                if (feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      feedback!,
                      style: TextStyle(
                        color: feedbackOk
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
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
                      });
                      final (ok, message) = await _testConnection(
                        context,
                        urlController.text,
                        userController.text,
                        tokenController.text,
                      );
                      if (!dialogContext.mounted) {
                        return;
                      }
                      setState(() {
                        testing = false;
                        feedbackOk = ok;
                        feedback = message;
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
                          tokenController.text.isEmpty) {
                        setState(() => feedback = l10n.fillAllFields);
                        return;
                      }
                      try {
                        WebDavClient.normalizeBaseUrl(url);
                      } on FormatException catch (e) {
                        setState(() => feedback = e.message);
                        return;
                      }
                      setState(() => saving = true);
                      await ref
                          .read(webDavServerRepositoryProvider)
                          .addServer(
                            name: name,
                            baseUrl: url,
                            username: user,
                            token: tokenController.text,
                            rootPath: rootController.text.trim().isEmpty
                                ? '/'
                                : rootController.text.trim(),
                          );
                      if (!dialogContext.mounted) {
                        return;
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

  /// Returns whether the connection worked, plus a message to display.
  Future<(bool, String)> _testConnection(
    BuildContext context,
    String rawUrl,
    String username,
    String token,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (rawUrl.trim().isEmpty ||
        username.trim().isEmpty ||
        token.isEmpty) {
      return (false, l10n.fillAllFields);
    }
    final String normalized;
    try {
      normalized = WebDavClient.normalizeBaseUrl(rawUrl);
    } on FormatException catch (e) {
      return (false, e.message);
    }
    final client = WebDavClient(
      baseUrl: normalized,
      username: username.trim(),
      token: token,
    );
    try {
      await client.ping();
      return (true, l10n.testOk(normalized));
    } on WebDavAuthException catch (_) {
      return (false, l10n.serverErrorMsg('401 Unauthorized'));
    } on Exception catch (_) {
      return (false, l10n.cannotConnectMsg(normalized));
    } finally {
      client.close();
    }
  }
}
