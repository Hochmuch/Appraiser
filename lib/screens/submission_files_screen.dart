import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' as highlight;

import '../models/models.dart';
import '../services/api_client.dart';

class _FolderNode {
  final String name;
  final String path;
  final Map<String, _FolderNode> folders = {};
  final List<String> files = [];

  _FolderNode({required this.name, required this.path});
}

class SubmissionFilesScreen extends StatefulWidget {
  final ApiClient apiClient;
  final int submissionId;
  final VoidCallback onBack;

  const SubmissionFilesScreen({
    super.key,
    required this.apiClient,
    required this.submissionId,
    required this.onBack,
  });

  @override
  State<SubmissionFilesScreen> createState() => _SubmissionFilesScreenState();
}

class _SubmissionFilesScreenState extends State<SubmissionFilesScreen> {
  List<GitHubRepoFile>? _files;
  Map<String, GitHubRepoFile> _filesByPath = {};
  Map<String, List<ReviewFinding>> _findingsByFile = {};
  final Map<String, List<InlineSpan>> _highlightedLinesCache = {};
  _FolderNode? _root;
  String? _selectedPath;
  final Set<String> _expandedDirs = {};
  final Set<int> _expandedFindings = {}; 
  final ScrollController _codeScrollController = ScrollController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await widget.apiClient.getSubmissionFiles(
        widget.submissionId,
      );
      files.sort(
        (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
      );
      final root = _buildTree(files);
      final filesByPath = {for (final f in files) f.path: f};

      
      Map<String, List<ReviewFinding>> findingsByFile = {};
      try {
        final submission = await widget.apiClient.getSubmissionResults(
          widget.submissionId,
        );
        for (final f in submission.findings) {
          findingsByFile.putIfAbsent(f.filePath, () => []).add(f);
        }
      } catch (_) {}

      setState(() {
        _files = files;
        _root = root;
        _filesByPath = filesByPath;
        _findingsByFile = findingsByFile;
        _highlightedLinesCache.clear();
        _expandedDirs
          ..clear()
          ..add('');
        for (final dir in root.folders.keys) {
          _expandedDirs.add(dir);
        }
        _selectedPath = files.isNotEmpty ? files.first.path : null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Файлы проекта'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Ошибка: $_error', textAlign: TextAlign.center),
            ),
            FilledButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final files = _files ?? [];
    if (files.isEmpty) return const Center(child: Text('Файлы не найдены'));

    final root = _root;
    if (root == null)
      return const Center(child: Text('Ошибка построения дерева файлов'));

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return Row(
              children: [
                SizedBox(width: 330, child: _buildTreePane(root)),
                const VerticalDivider(width: 1),
                Expanded(child: _buildFilePane()),
              ],
            );
          }

          return Column(
            children: [
              SizedBox(height: 280, child: _buildTreePane(root)),
              const Divider(height: 1),
              Expanded(child: _buildFilePane()),
            ],
          );
        },
      ),
    );
  }

  _FolderNode _buildTree(List<GitHubRepoFile> files) {
    final root = _FolderNode(name: '', path: '');

    for (final file in files) {
      final normalized = file.path.replaceAll('\\', '/');
      final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) continue;

      var current = root;
      for (var i = 0; i < parts.length - 1; i++) {
        final dirName = parts[i];
        final dirPath = current.path.isEmpty
            ? dirName
            : '${current.path}/$dirName';
        current = current.folders.putIfAbsent(
          dirName,
          () => _FolderNode(name: dirName, path: dirPath),
        );
      }

      current.files.add(normalized);
    }

    _sortTree(root);
    return root;
  }

  void _sortTree(_FolderNode node) {
    node.files.sort(
      (a, b) =>
          _fileName(a).toLowerCase().compareTo(_fileName(b).toLowerCase()),
    );
    final sortedEntries = node.folders.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    node.folders
      ..clear()
      ..addEntries(sortedEntries);
    for (final child in node.folders.values) {
      _sortTree(child);
    }
  }

  Widget _buildTreePane(_FolderNode root) {
    return Container(
      color: const Color(0xFF161616),
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Text(
              'ФАЙЛЫ РЕПОЗИТОРИЯ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ..._buildTreeItems(root, depth: 0),
        ],
      ),
    );
  }

  List<Widget> _buildTreeItems(_FolderNode node, {required int depth}) {
    final widgets = <Widget>[];
    const double baseIndent = 8.0;
    const double levelIndent = 14.0;
    const double rowHeight = 26.0;

    for (final folder in node.folders.values) {
      final isExpanded = _expandedDirs.contains(folder.path);
      final leftPad = baseIndent + depth * levelIndent;

      widgets.add(
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedDirs.remove(folder.path);
            } else {
              _expandedDirs.add(folder.path);
            }
          }),
          child: SizedBox(
            height: rowHeight,
            child: Padding(
              padding: EdgeInsets.only(left: leftPad, right: 8),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 16,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    isExpanded
                        ? Icons.folder_open_rounded
                        : Icons.folder_rounded,
                    size: 15,
                    color: const Color(0xFFDCB862),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      folder.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (isExpanded) {
        widgets.addAll(_buildTreeItems(folder, depth: depth + 1));
      }
    }

    for (final path in node.files) {
      final selected = path == _selectedPath;
      final fileFindings = _findingsByFile[path] ?? [];
      final badgeCount = fileFindings.length;
      
      final leftPad = baseIndent + depth * levelIndent + 19.0;

      widgets.add(
        InkWell(
          onTap: () => setState(() => _selectedPath = path),
          child: Container(
            height: rowHeight,
            color: selected ? Colors.white.withOpacity(0.08) : null,
            padding: EdgeInsets.only(left: leftPad, right: 8),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 15,
                  color: selected ? Colors.white70 : Colors.white38,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _fileName(path),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1,
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.75),
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _worstSeverityColor(fileFindings),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildFilePane() {
    final selectedPath = _selectedPath;
    if (selectedPath == null) {
      return const Center(child: Text('Выберите файл в дереве'));
    }

    final file = _filesByPath[selectedPath];
    if (file == null) {
      return const Center(child: Text('Файл не найден'));
    }

    final fileFindings = _findingsByFile[selectedPath] ?? [];
    final lines = file.content.split('\n');
  final highlightedLines = _getHighlightedLines(file.path, file.content);

    
    final Map<int, List<ReviewFinding>> findingsAtLine = {};
    
    final Map<int, String> severityByLine = {};
    for (final f in fileFindings) {
      findingsAtLine.putIfAbsent(f.startLine, () => []).add(f);
      for (var l = f.startLine; l <= f.endLine; l++) {
        final cur = severityByLine[l];
        if (cur == null || _severityRank(f.severity) > _severityRank(cur)) {
          severityByLine[l] = f.severity;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  file.path,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (fileFindings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${fileFindings.length} замечани${fileFindings.length % 10 == 1
                        ? 'е'
                        : fileFindings.length % 10 < 5 && fileFindings.length % 10 != 0
                        ? 'я'
                        : 'й'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _worstSeverityColor(fileFindings),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            child: Scrollbar(
              thumbVisibility: true,
              controller: _codeScrollController,
              child: ListView.builder(
                controller: _codeScrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final lineNum = index + 1; 
                  final line = lines[index];
                  final lineSeverity = severityByLine[lineNum];
                  final Color? bg = lineSeverity != null
                      ? _severityBgColor(lineSeverity)
                      : null;
                  final startingFindings = findingsAtLine[lineNum] ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: bg,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                '$lineNum',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.white38,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText.rich(
                                TextSpan(
                                  children: highlightedLines.length > index
                                      ? [highlightedLines[index]]
                                      : [
                                          TextSpan(
                                            text: line,
                                            style: _codeTextStyle,
                                          ),
                                        ],
                                ),
                                style: _codeTextStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      for (final finding in startingFindings)
                        _buildFindingCard(finding),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFindingCard(ReviewFinding finding) {
    final color = _severityColor(finding.severity);
    final isExpanded = _expandedFindings.contains(finding.id);
    return Container(
      margin: const EdgeInsets.only(left: 48, right: 4, bottom: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: InkWell(
        onTap: () => setState(() {
          if (isExpanded) {
            _expandedFindings.remove(finding.id);
          } else {
            _expandedFindings.add(finding.id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_severityIcon(finding.severity), size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      finding.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.white54,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 6),
                Text(
                  finding.comment,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                if (finding.suggestion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Рекомендация:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          finding.suggestion,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _getHighlightedLines(String path, String content) {
    final cached = _highlightedLinesCache[path];
    if (cached != null) return cached;

    final language = _highlightLanguageForPath(path);
    final lines = content.split('\n');
    final highlighted = lines.map((line) {
      if (line.isEmpty) {
        return const TextSpan(text: '');
      }

      try {
        final result = highlight.highlight.parse(line, language: language);
        return TextSpan(
          style: _codeTextStyle,
          children: _highlightNodesToSpans(result.nodes, _codeTextStyle),
        );
      } catch (_) {
        return TextSpan(text: line, style: _codeTextStyle);
      }
    }).toList(growable: false);

    _highlightedLinesCache[path] = highlighted;
    return highlighted;
  }

  List<InlineSpan> _highlightNodesToSpans(
    List<highlight.Node>? nodes,
    TextStyle inheritedStyle,
  ) {
    if (nodes == null || nodes.isEmpty) {
      return const [TextSpan(text: '')];
    }

    final spans = <InlineSpan>[];
    for (final node in nodes) {
      final nodeStyle = inheritedStyle.merge(
        _styleForHighlightClass(node.className),
      );

      if (node.value != null) {
        spans.add(
          TextSpan(
            text: node.value,
            style: nodeStyle,
          ),
        );
      } else if (node.children != null && node.children!.isNotEmpty) {
        spans.add(
          TextSpan(
            style: nodeStyle,
            children: _highlightNodesToSpans(node.children, nodeStyle),
          ),
        );
      }
    }

    return spans.isEmpty ? const [TextSpan(text: '')] : spans;
  }

  String? _highlightLanguageForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.dart')) return 'dart';
    if (lower.endsWith('.go')) return 'go';
    if (lower.endsWith('.js')) return 'javascript';
    if (lower.endsWith('.ts')) return 'typescript';
    if (lower.endsWith('.json')) return 'json';
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return 'yaml';
    if (lower.endsWith('.java')) return 'java';
    if (lower.endsWith('.kt') || lower.endsWith('.kts')) return 'kotlin';
    if (lower.endsWith('.swift')) return 'swift';
    if (lower.endsWith('.py')) return 'python';
    if (lower.endsWith('.html')) return 'xml';
    if (lower.endsWith('.css')) return 'css';
    if (lower.endsWith('.md')) return 'markdown';
    if (lower.endsWith('.sh')) return 'bash';
    if (lower.endsWith('.sql')) return 'sql';
    if (lower.endsWith('.xml')) return 'xml';
    if (lower.endsWith('.c') || lower.endsWith('.h')) return 'c';
    if (lower.endsWith('.cpp') || lower.endsWith('.cc') || lower.endsWith('.hpp')) {
      return 'cpp';
    }
    return null;
  }

  TextStyle? _styleForHighlightClass(String? className) {
    switch (className) {
      case 'keyword':
      case 'selector-tag':
      case 'built_in':
        return const TextStyle(color: Color(0xFFC792EA));
      case 'string':
      case 'subst':
      case 'title':
      case 'section':
      case 'attribute':
      case 'symbol':
        return const TextStyle(color: Color(0xFFECC48D));
      case 'number':
      case 'literal':
      case 'variable':
      case 'template-variable':
        return const TextStyle(color: Color(0xFFF78C6C));
      case 'comment':
      case 'quote':
        return const TextStyle(color: Color(0xFF5C6370), fontStyle: FontStyle.italic);
      case 'type':
      case 'class':
      case 'title.class_':
        return const TextStyle(color: Color(0xFF82AAFF));
      case 'function':
      case 'title.function_':
        return const TextStyle(color: Color(0xFF80CBC4));
      case 'meta':
      case 'doctag':
        return const TextStyle(color: Color(0xFF89DDFF));
      default:
        return null;
    }
  }

  TextStyle get _codeTextStyle => const TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    color: Colors.white,
    height: 1.5,
  );

  Color _severityColor(String severity) {
    switch (severity) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blueAccent;
    }
  }

  Color _severityBgColor(String severity) {
    switch (severity) {
      case 'error':
        return Colors.red.withOpacity(0.15);
      case 'warning':
        return Colors.orange.withOpacity(0.12);
      default:
        return Colors.blue.withOpacity(0.10);
    }
  }

  int _severityRank(String severity) {
    switch (severity) {
      case 'error':
        return 3;
      case 'warning':
        return 2;
      default:
        return 1;
    }
  }

  Color _worstSeverityColor(List<ReviewFinding> findings) {
    String worst = 'info';
    for (final f in findings) {
      if (_severityRank(f.severity) > _severityRank(worst)) {
        worst = f.severity;
      }
    }
    return _severityColor(worst);
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _fileName(String path) {
    final idx = path.lastIndexOf('/');
    if (idx == -1) return path;
    return path.substring(idx + 1);
  }
}
