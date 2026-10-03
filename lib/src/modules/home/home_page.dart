import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../bridge/api/documents.dart' as bridge;
import '../collecti_module.dart';
import 'document_events.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpenModule, this.onOpenDocument, this.lockedExt});

  final void Function(CollectiModule module) onOpenModule;
  final void Function(CollectiModule module, String path)? onOpenDocument;
  final String? lockedExt;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _docsDir;
  List<bridge.DocumentEntry> _docs = [];
  String? _chipFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _chipFilter = widget.lockedExt;
    documentsRevision.addListener(_onDocumentsChanged);
    _init();
  }

  void _onDocumentsChanged() {
    _reload();
  }

  Future<void> _reloadAndNotify() async {
    await _reload();
    documentsRevision.value++;
  }

  @override
  void dispose() {
    documentsRevision.removeListener(_onDocumentsChanged);
    super.dispose();
  }

  Future<void> _init() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}documents');
    _docsDir = dir.path;
    await _reload();
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

  Future<void> _reload() async {
    if (_docsDir == null) return;
    final docs = await bridge.listDocuments(dir: _docsDir!);
    if (!mounted) return;
    setState(() => _docs = docs);
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
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  Future<void> _openCreateDialog() async {
    final nameController = TextEditingController();
    String ext = _chipFilter ?? 'awce';
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Tạo tài liệu mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên tài liệu'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: ext,
                decoration: const InputDecoration(labelText: 'Loại tài liệu'),
                items: [
                  for (final m in CollectiModule.values.where((m) => widget.lockedExt == null || m.extension == widget.lockedExt))
                    DropdownMenuItem(value: m.extension, child: Text(m.label)),
                ],
                onChanged: (v) => setDialogState(() => ext = v ?? ext),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo')),
          ],
        ),
      ),
    );

    if (created == true && nameController.text.trim().isNotEmpty && _docsDir != null) {
      await bridge.createDocumentEntry(
        dir: _docsDir!,
        name: nameController.text.trim(),
        ext: ext,
      );
      await _reloadAndNotify();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo "${nameController.text.trim()}"')),
        );
      }
    }
  }

  Future<void> _openRenameDialog(bridge.DocumentEntry doc) async {
    final controller = TextEditingController(text: doc.name);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Đổi tên'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (renamed == true && controller.text.trim().isNotEmpty && _docsDir != null) {
      await bridge.renameDocumentEntry(dir: _docsDir!, id: doc.id, newName: controller.text.trim());
      await _reloadAndNotify();
    }
  }

  Future<void> _togglePin(bridge.DocumentEntry doc) async {
    if (_docsDir == null) return;
    await bridge.togglePinDocument(dir: _docsDir!, id: doc.id);
    await _reloadAndNotify();
  }

  Future<void> _delete(bridge.DocumentEntry doc) async {
    if (_docsDir == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Xóa tài liệu?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await bridge.deleteDocumentEntry(dir: _docsDir!, id: doc.id);
    await _reloadAndNotify();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${doc.name}"'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final pinned = filtered.where((d) => d.pinned).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recent = filtered.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final featured = _docs.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Stack(
      children: [
        Column(
          children: [
            Padding(
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
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chưa có thông báo mới')),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cài đặt sẽ sớm ra mắt')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.lockedExt == null)
            Padding(
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
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                children: [
                  if (widget.lockedExt == null) _buildCarousel(theme, featured),
                  if (pinned.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Pinned', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    _buildDocGrid(theme, pinned),
                  ],
                  const SizedBox(height: 20),
                  Text('Recent', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  if (recent.isEmpty)
                    _buildEmptyState(theme)
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

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.note_add_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('Chưa có tài liệu nào', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(
            'Bấm nút + để tạo tài liệu mới',
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
          'Tạo tài liệu đầu tiên để thấy ở đây',
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
                      if (action == 'rename') _openRenameDialog(doc);
                      if (action == 'delete') _delete(doc);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'pin', child: Text(doc.pinned ? 'Bỏ ghim' : 'Ghim')),
                      const PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Xóa', style: TextStyle(color: theme.colorScheme.error)),
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