import 'package:flutter/material.dart';
import '../../bridge/api.dart';

const int kVisibleRows = 60;
const int kVisibleCols = 26;
const double kRowHeight = 28;
const double kHeaderWidth = 48;
const double kColWidth = 96;

class TablePage extends StatefulWidget {
  const TablePage({super.key});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  final Map<int, String> _cells = {};
  int? _selectedRow;
  int? _selectedCol;
  final TextEditingController _formulaBarController = TextEditingController();
  final FocusNode _formulaBarFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  int _cellKey(int row, int col) => row * kVisibleCols + col;

  Future<void> _loadSnapshot() async {
    final snapshot = await getSheetSnapshot(sheetIndex: 0);
    setState(() {
      _cells.clear();
      for (final cell in snapshot) {
        _cells[_cellKey(cell.row, cell.col)] = cell.display;
      }
    });
  }

  Future<void> _selectCell(int row, int col) async {
    final input = await getCellInput(sheetIndex: 0, row: row, col: col);
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
      _formulaBarController.text = input;
    });
    _formulaBarFocus.requestFocus();
  }

  Future<void> _commitFormulaBar() async {
    if (_selectedRow == null || _selectedCol == null) return;
    final result = await setCellInput(
      sheetIndex: 0,
      row: _selectedRow!,
      col: _selectedCol!,
      input: _formulaBarController.text,
    );
    setState(() {
      for (final cell in result) {
        _cells[_cellKey(cell.row, cell.col)] = cell.display;
      }
    });
  }

  String _columnLabel(int col) {
    var n = col + 1;
    var label = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      label = String.fromCharCode(65 + rem) + label;
      n = (n - 1) ~/ 26;
    }
    return label;
  }

  @override
  void dispose() {
    _formulaBarController.dispose();
    _formulaBarFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  _selectedRow != null
                      ? '${_columnLabel(_selectedCol!)}${_selectedRow! + 1}'
                      : '',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _formulaBarController,
                  focusNode: _formulaBarFocus,
                  enabled: _selectedRow != null,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _commitFormulaBar(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeaderRow(theme),
                    for (var row = 0; row < kVisibleRows; row++)
                      _buildDataRow(theme, row),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: kHeaderWidth,
          height: kRowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
        ),
        for (var col = 0; col < kVisibleCols; col++)
          Container(
            width: kColWidth,
            height: kRowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(color: theme.dividerColor, width: 0.5),
            ),
            child: Text(_columnLabel(col), style: theme.textTheme.labelMedium),
          ),
      ],
    );
  }

  Widget _buildDataRow(ThemeData theme, int row) {
    return Row(
      children: [
        Container(
          width: kHeaderWidth,
          height: kRowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(color: theme.dividerColor, width: 0.5),
          ),
          child: Text('${row + 1}', style: theme.textTheme.labelMedium),
        ),
        for (var col = 0; col < kVisibleCols; col++) _buildCell(theme, row, col),
      ],
    );
  }

  Widget _buildCell(ThemeData theme, int row, int col) {
    final selected = _selectedRow == row && _selectedCol == col;
    final text = _cells[_cellKey(row, col)] ?? '';
    return GestureDetector(
      onTap: () => _selectCell(row, col),
      child: Container(
        width: kColWidth,
        height: kRowHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : null,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}