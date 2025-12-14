import 'dart:convert';

import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'interactive_header.dart';
import 'remote_asset_loader.dart';

class VmaChallengeTable extends StatefulWidget {
  const VmaChallengeTable({super.key, required this.loader});

  final RemoteAssetLoader loader;

  @override
  State<VmaChallengeTable> createState() => _VmaChallengeTableState();
}

class _VmaChallengeTableState extends State<VmaChallengeTable> {
  static const _remoteUrl =
      'https://raw.githubusercontent.com/lougau92/vma-running/refs/heads/main/assets/enjambee_challenge/classement_challenge_enjambee_2025_12_10_2025.csv';
  static const _assetPath =
      'assets/enjambee_challenge/classement_challenge_enjambee_2025_12_10_2025.csv';
  static const double _maxColumnWidth = 130;

  late Future<_ChallengeResult> _future;
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  String? _lastNoticeKey;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  List<List<String>>? _sortedRows;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<_ChallengeResult> _load({bool forceRefresh = false}) async {
    final response = await widget.loader.loadText(
      remoteUrl: _remoteUrl,
      assetPath: _assetPath,
      forceRefresh: forceRefresh,
    );
    final parsed = _parseCsv(response.data);
    return _ChallengeResult(
      headers: parsed.headers,
      rows: parsed.rows,
      noticeKey: _noticeKeyFor(response, forceRefresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => _refresh(forceRefresh: true),
      child: FutureBuilder<_ChallengeResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading challenge: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final result = snapshot.data!;
          _notifyIfNeeded(result.noticeKey);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  strings.challengeTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildTable(result)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTable(_ChallengeResult data) {
    if (data.headers.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final rows = _sortedRows ?? data.rows;
    final divider = Theme.of(context).colorScheme.surfaceDim;
    final columnCount = data.headers.length;

    return Scrollbar(
      thumbVisibility: true,
      controller: _verticalController,
      child: SingleChildScrollView(
        controller: _verticalController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              for (int i = 0; i < columnCount; i++)
                i: const IntrinsicColumnWidth(),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: divider, width: 1)),
                ),
                children: List.generate(
                  columnCount,
                  (i) => _headerCell(
                    title: data.headers[i],
                    columnIndex: i,
                    allRows: data.rows,
                  ),
                ),
              ),
              ...rows.map(
                (row) => TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: divider, width: 1),
                    ),
                  ),
                  children: List.generate(
                    columnCount,
                    (i) => _dataCell(i < row.length ? row[i] : ''),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh({bool forceRefresh = false}) async {
    final next = _load(forceRefresh: forceRefresh);
    setState(() {
      _future = next;
      _lastNoticeKey = null;
      _sortedRows = null;
      _sortColumnIndex = null;
      _sortAscending = true;
    });
    await next;
  }

  _ParsedCsv _parseCsv(String data) {
    final lines = const LineSplitter().convert(data).where((l) => l.isNotEmpty);
    final parsedLines = lines.map((line) => line.split(',')).toList();

    if (parsedLines.isEmpty) return const _ParsedCsv(headers: [], rows: []);

    final headers = parsedLines.first;
    final rows = parsedLines.skip(1).toList();
    return _ParsedCsv(headers: headers, rows: rows);
  }

  void _notifyIfNeeded(String? noticeKey) {
    if (noticeKey == null || noticeKey == _lastNoticeKey || !mounted) return;
    _lastNoticeKey = noticeKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final strings = AppLocalizations.of(context);
      final message = strings[noticeKey];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  String? _noticeKeyFor(RemoteLoadResult result, bool forceRefresh) {
    if (result.origin == RemoteLoadOrigin.cache && forceRefresh) {
      return 'challengeUsedCache';
    }
    if (result.origin == RemoteLoadOrigin.asset) {
      return 'challengeUsedFallback';
    }
    return null;
  }

  void _onSort(int columnIndex, bool ascending, List<List<String>> baseRows) {
    final sorted = baseRows
        .map((row) => List<String>.from(row))
        .toList(growable: false);

    int compare(String a, String b) {
      final aNum = double.tryParse(a);
      final bNum = double.tryParse(b);
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    }

    sorted.sort((a, b) {
      final left = columnIndex < a.length ? a[columnIndex] : '';
      final right = columnIndex < b.length ? b[columnIndex] : '';
      final result = compare(left, right);
      return ascending ? result : -result;
    });

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortedRows = sorted;
    });
  }

  Widget _headerCell({
    required String title,
    required int columnIndex,
    required List<List<String>> allRows,
  }) {
    final isSorted = _sortColumnIndex == columnIndex;
    final nextAscending = isSorted ? !_sortAscending : true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxColumnWidth),
        child: SortableHeader(
          label: title,
          direction: _sortDirectionFor(columnIndex),
          onTap: () => _onSort(columnIndex, nextAscending, allRows),
          compact: true,
        ),
      ),
    );
  }

  Widget _dataCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: _wrapCellText(text),
    );
  }

  Widget _wrapCellText(String text, {bool isHeader = false}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxColumnWidth),
      child: Text(
        text,
        softWrap: true,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.left,
        style: isHeader ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
    );
  }

  SortDirection _sortDirectionFor(int columnIndex) {
    if (_sortColumnIndex != columnIndex) return SortDirection.none;
    return _sortAscending ? SortDirection.ascending : SortDirection.descending;
  }
}

class _ParsedCsv {
  const _ParsedCsv({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

class _ChallengeResult {
  const _ChallengeResult({
    required this.headers,
    required this.rows,
    this.noticeKey,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final String? noticeKey;
}
