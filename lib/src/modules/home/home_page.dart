import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../bridge/api/documents.dart' as bridge;
import '../../bridge/api/folders.dart' as folder_api;
import '../collecti_module.dart';
import 'document_events.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenModule,
    this.onOpenDocument,
    this.lockedExt,
  });

  final void Function(CollectiModule module) onOpenModule;
  final void Function(CollectiModule module, String path)? onOpenDocument;
  final String? lockedExt;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _docsDir;
  List<bridge.DocumentEntry> _docs = [];
  List<folder_api.FolderEntry> _folders = [];
  Map<String, String> _folderOf = {};
  String? _openFolderId;
  String? _chipFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _chipFilter = widget.lockedExt;
    documentsRevision.addListener(_onDocumentsChanged);
    _init();
  }

  @override
  void dispose() {
    documentsRevision.removeListener(_onDocumentsChanged);
    super.dispose();
  }

  void _onDocumentsChanged() {
    _reload();
  }

  Future<void> _init() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}documents');
    _docsDir = dir.path;
    await _reload();
  }

  Future<void> _reload() async {
    final dir = _docsDir;
    if (dir == null) return;
    final docs = await bridge.listDocuments(dir: dir);
    var folders = <folder_api.FolderEntry>[];
    var folderOf = <String, String>{};
    final ext = widget.lockedExt;
    if (ext != null) {
      folders = await folder_api.listFolders(dir: dir, ext: ext);
      final links = await folder_api.listFolderLinks(dir: dir);
      folderOf = {for (final l in links) l.documentId: l.folderId};
    }
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _folders = folders;
      _folderOf = folderOf;
      if (_openFolderId != null && !folders.any((f) => f.id == _openFolderId)) {
        _openFolderId = null;
      }
    });
  }

  Future<void> _reloadAndNotify() async {
    await _reload();
    documentsRevision.value++;
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  CollectiModule _moduleFor(String ext) {
    return CollectiModule.values.firstWhere(
      (m) => m.extension == ext,
      orElse: () => CollectiModule.write,
    );
  }

  List<bridge.DocumentEntry> get _filtered {
    var docs = _docs;
    if (_chipFilter != null) {
      docs = docs.where((d) => d.ext == _chipFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      docs = docs.where((d) => d.name.toLowerCase().contains(q)).toList();
    }
    return docs;
  }

  String _timeAgo(int unixSeconds) {
    final then = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  void _open(bridge.DocumentEntry doc) {
    final module = _moduleFor(doc.ext);
    final dir = _docsDir;
    if (dir == null || widget.onOpenDocument == null) {
      widget.onOpenModule(module);
      return;
    }
    widget.onOpenDocument!(module, '$dir${Platform.pathSeparator}${doc.id}.${doc.ext}');
  }

  Future<String?> _askName({
    required String title,
    String initial = '',
    required String confirmLabel,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _openCreateDialog() async {
    final nameController = TextEditingController();
    String ext = _chipFilter ?? 'awce';
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('New document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Document name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: ext,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: [
                  for (final m in CollectiModule.values.where(
                    (m) => widget.lockedExt == null || m.extension == widget.lockedExt,
                  ))
                    DropdownMenuItem(value: m.extension, child: Text(m.label)),
                ],
                onChanged: (v) => setDialogState(() => ext = v ?? ext),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    final dir = _docsDir;
    if (created != true || name.isEmpty || dir == null) return;
    await _run(() async {
      final entry = await bridge.createDocumentEntry(dir: dir, name: name, ext: ext);
      final folderId = _openFolderId;
      if (folderId != null && widget.lockedExt != null) {
        await folder_api.moveDocumentToFolder(
          dir: dir,
          documentId: entry.id,
          folderId: folderId,
        );
      }
      await _reloadAndNotify();
      _showMessage('Created "$name"');
    });
  }

  Future<void> _renameDocument(bridge.DocumentEntry doc) async {
    final dir = _docsDir;
    if (dir == null) return;
    final name = await _askName(title: 'Rename', initial: doc.name, confirmLabel: 'Save');
    if (name == null) return;
    await _run(() async {
      await bridge.renameDocumentEntry(dir: dir, id: doc.id, newName: name);
      await _reloadAndNotify();
    });
  }

  Future<void> _togglePin(bridge.DocumentEntry doc) async {
    final dir = _docsDir;
    if (dir == null) return;
    await _run(() async {
      await bridge.togglePinDocument(dir: dir, id: doc.id);
      await _reloadAndNotify();
    });
  }

  Future<void> _deleteDocument(bridge.DocumentEntry doc) async {
    final dir = _docsDir;
    if (dir == null) return;
    final ok = await _confirm(
      title: 'Delete document?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _run(() async {
      await bridge.deleteDocumentEntry(dir: dir, id: doc.id);
      await _reloadAndNotify();
      _showMessage('Deleted "${doc.name}"');
    });
  }

  Future<void> _moveDocument(bridge.DocumentEntry doc) async {
    final dir = _docsDir;
    if (dir == null) return;
    if (_folders.isEmpty) {
      _showMessage('Create a folder first');
      return;
    }
    final current = _folderOf[doc.id] ?? '';
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Move to folder'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('No folder'),
          ),
          for (final f in _folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f.id),
              child: Text(f.name),
            ),
        ],
      ),
    );
    if (choice == null || choice == current) return;
    await _run(() async {
      await folder_api.moveDocumentToFolder(
        dir: dir,
        documentId: doc.id,
        folderId: choice.isEmpty ? null : choice,
      );
      await _reloadAndNotify();
    });
  }

  Future<void> _createFolder() async {
    final dir = _docsDir;
    final ext = widget.lockedExt;
    if (dir == null || ext == null) return;
    final name = await _askName(title: 'New folder', confirmLabel: 'Create');
    if (name == null) return;
    await _run(() async {
      await folder_api.createFolder(dir: dir, name: name, ext: ext);
      await _reloadAndNotify();
    });
  }

  Future<void> _renameFolder(folder_api.FolderEntry folder) async {
    final dir = _docsDir;
    if (dir == null) return;
    final name = await _askName(
      title: 'Rename folder',
      initial: folder.name,
      confirmLabel: 'Save',
    );
    if (name == null) return;
    await _run(() async {
      await folder_api.renameFolder(dir: dir, id: folder.id, newName: name);
      await _reloadAndNotify();
    });
  }

  Future<void> _deleteFolder(folder_api.FolderEntry folder) async {
    final dir = _docsDir;
    if (dir == null) return;
    final ok = await _confirm(
      title: 'Delete folder?',
      message: 'Documents inside will move out of the folder, not be deleted.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _run(() async {
      await folder_api.deleteFolder(dir: dir, id: folder.id);
      await _reloadAndNotify();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = widget.lockedExt != null;
    final searching = _searchQuery.trim().isNotEmpty;
    final inFolder = locked && _openFolderId != null && !searching;
    final base = _filtered;

    final pinned = inFolder ? <bridge.DocumentEntry>[] : base.where((d) => d.pinned).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    List<bridge.DocumentEntry> recent;
    if (!locked || searching) {
      recent = base.toList();
    } else if (_openFolderId != null) {
      recent = base.where((d) => _folderOf[d.id] == _openFolderId).toList();
    } else {
      recent = base.where((d) => !_folderOf.containsKey(d.id)).toList();
    }
    recent.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final featured = _docs.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Stack(
      children: [
        Column(
          children: [
            _buildTopBar(theme),
            if (!locked) _buildChipRow(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                children: [
                  if (!locked) _buildCarousel(theme, featured),
                  if (inFolder) _buildFolderHeader(theme),
                  if (pinned.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Pinned', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    _buildDocGrid(theme, pinned),
                  ],
                  if (locked && !inFolder && !searching) ...[
                    const SizedBox(height: 20),
                    Text('Folders', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    _buildFolderRow(theme),
                  ],
                  const SizedBox(height: 20),
                  if (!inFolder) ...[
                    Text('Recent', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                  ],
                  if (recent.isEmpty)
                    _buildEmptyState(theme, inFolder)
                  else
                    _buildDocGrid(theme, recent),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: FloatingActionButton.large(
            onPressed: _openCreateDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _showMessage('No new notifications'),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _showMessage('Settings are coming soon'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final m in CollectiModule.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(m.label),
                  selected: _chipFilter == m.extension,
                  onSelected: (selected) {
                    setState(() => _chipFilter = selected ? m.extension : null);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderHeader(ThemeData theme) {
    final folder = _folders.where((f) => f.id == _openFolderId).firstOrNull;
    if (folder == null) return const SizedBox.shrink();
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => setState(() => _openFolderId = null),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            folder.name,
            style: theme.textTheme.headlineSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _folderMenu(folder),
      ],
    );
  }

  Widget _folderMenu(folder_api.FolderEntry folder) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        if (action == 'rename') _renameFolder(folder);
        if (action == 'delete') _deleteFolder(folder);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    );
  }

  Widget _buildFolderRow(ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final folder in _folders) _buildFolderTile(theme, folder),
        _buildNewFolderTile(theme),
      ],
    );
  }

  Widget _buildFolderTile(ThemeData theme, folder_api.FolderEntry folder) {
    return SizedBox(
      width: 216,
      height: 56,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _openFolderId = folder.id),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    folder.name,
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _folderMenu(folder),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewFolderTile(ThemeData theme) {
    return SizedBox(
      width: 216,
      height: 56,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _createFolder,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.create_new_folder_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'New folder',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool inFolder) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.note_add_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            inFolder ? 'This folder is empty' : 'No documents yet',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            inFolder ? 'Tap + to create a document here' : 'Tap + to create a new document',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel(ThemeData theme, List<bridge.DocumentEntry> featured) {
    final top5 = featured.take(5).toList();
    if (top5.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          'Create your first document to see it here',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    final palette = [
      const Color(0xFF6750A4),
      const Color(0xFF7D5260),
      const Color(0xFF4A6572),
      const Color(0xFF8C6D46),
      const Color(0xFF5E6A4B),
    ];
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: top5.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final doc = top5[i];
          return GestureDetector(
            onTap: () => _open(doc),
            child: Container(
              width: i == 0 ? 420 : 140,
              decoration: BoxDecoration(
                color: palette[i % palette.length],
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [palette[i % palette.length].withValues(alpha: .85), Colors.transparent],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(14),
              child: Text(
                doc.name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocGrid(ThemeData theme, List<bridge.DocumentEntry> docs) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [for (final doc in docs) _buildDocCard(theme, doc)],
    );
  }

  Widget _buildDocCard(ThemeData theme, bridge.DocumentEntry doc) {
    return SizedBox(
      width: 216,
      child: GestureDetector(
        onTap: () => _open(doc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 216,
                  height: 128,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.image_outlined, size: 40, color: theme.colorScheme.outline),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: PopupMenuButton<String>(
                    icon: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(alpha: .85),
                      child: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    onSelected: (action) {
                      if (action == 'pin') _togglePin(doc);
                      if (action == 'rename') _renameDocument(doc);
                      if (action == 'move') _moveDocument(doc);
                      if (action == 'delete') _deleteDocument(doc);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'pin', child: Text(doc.pinned ? 'Unpin' : 'Pin')),
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      if (widget.lockedExt != null)
                        const PopupMenuItem(value: 'move', child: Text('Move to folder')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(doc.name, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
            Text(
              '${_moduleFor(doc.ext).label} · ${_timeAgo(doc.updatedAt.toInt())}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}