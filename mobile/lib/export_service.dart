import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for exporting participant and distribution data to CSV/XLSX.
class ExportService {
  /// Generate a timestamped filename.
  static String _filename(String ext) {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'BreachGate_Export_$ts.$ext';
  }

  // ─── CSV Export ──────────────────────────────────

  /// Export participant data to a CSV file and share it.
  static Future<void> exportToCsv(List<Map<String, dynamic>> participants) async {
    final rows = <List<dynamic>>[];

    // Header
    rows.add([
      'UID', 'Name', 'College', 'Team', 'Registration', 'Breakfast',
      'Lunch', 'Snacks', 'Dinner', 'Midnight Snacks',
    ]);

    // Data rows
    for (final p in participants) {
      rows.add([
        p['uid'] ?? '',
        p['name'] ?? '',
        p['college'] ?? '',
        p['team_name'] ?? 'Solo',
        p['registration_goodies'] == true ? 'YES' : 'NO',
        p['breakfast'] == true ? 'YES' : 'NO',
        p['lunch'] == true ? 'YES' : 'NO',
        p['snacks'] == true ? 'YES' : 'NO',
        p['dinner'] == true ? 'YES' : 'NO',
        p['midnight_snacks'] == true ? 'YES' : 'NO',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final path = await _writeToFile(_filename('csv'), csvString);
    await _shareFile(path, 'Breach Gate CSV Export');
  }

  // ─── XLSX Export ─────────────────────────────────

  /// Export participant data to a multi-sheet XLSX file and share it.
  static Future<void> exportToExcel(List<Map<String, dynamic>> participants) async {
    final excel = Excel.createExcel();

    // ── Sheet 1: Participants ──
    final pSheet = excel['Participants'];
    pSheet.appendRow([
      TextCellValue('UID'),
      TextCellValue('Name'),
      TextCellValue('College'),
      TextCellValue('Team'),
    ]);
    for (final p in participants) {
      pSheet.appendRow([
        TextCellValue(p['uid'] ?? ''),
        TextCellValue(p['name'] ?? ''),
        TextCellValue(p['college'] ?? ''),
        TextCellValue(p['team_name'] ?? 'Solo'),
      ]);
    }

    // ── Sheet 2: Distribution Status ──
    final dSheet = excel['Distribution Status'];
    dSheet.appendRow([
      TextCellValue('UID'),
      TextCellValue('Name'),
      TextCellValue('Reg'),
      TextCellValue('Breakfast'),
      TextCellValue('Lunch'),
      TextCellValue('Snacks'),
      TextCellValue('Dinner'),
      TextCellValue('Midnight'),
    ]);
    for (final p in participants) {
      dSheet.appendRow([
        TextCellValue(p['uid'] ?? ''),
        TextCellValue(p['name'] ?? ''),
        TextCellValue(p['registration_goodies'] == true ? '✓' : ''),
        TextCellValue(p['breakfast'] == true ? '✓' : ''),
        TextCellValue(p['lunch'] == true ? '✓' : ''),
        TextCellValue(p['snacks'] == true ? '✓' : ''),
        TextCellValue(p['dinner'] == true ? '✓' : ''),
        TextCellValue(p['midnight_snacks'] == true ? '✓' : ''),
      ]);
    }

    // ── Sheet 3: Team Summary ──
    final tSheet = excel['Team Summary'];
    tSheet.appendRow([
      TextCellValue('Team'),
      TextCellValue('Members'),
      TextCellValue('Items Collected'),
      TextCellValue('Total Items'),
      TextCellValue('Completion %'),
    ]);

    // Group by team
    final teamMap = <String, List<Map<String, dynamic>>>{};
    for (final p in participants) {
      final team = (p['team_name'] ?? 'Solo') as String;
      teamMap.putIfAbsent(team, () => []).add(p);
    }
    for (final entry in teamMap.entries) {
      final members = entry.value;
      int collected = 0;
      final total = members.length * 6;
      for (final m in members) {
        collected += _countCollected(m);
      }
      final pct = total > 0 ? (collected / total * 100).toStringAsFixed(1) : '0.0';
      tSheet.appendRow([
        TextCellValue(entry.key),
        IntCellValue(members.length),
        IntCellValue(collected),
        IntCellValue(total),
        TextCellValue('$pct%'),
      ]);
    }

    // Remove default "Sheet1" that Excel creates
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to generate Excel file');

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/${_filename('xlsx')}';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await _shareFile(filePath, 'Breach Gate Excel Export');
  }

  // ─── Helpers ──────────────────────────────────────

  static int _countCollected(Map<String, dynamic> m) {
    int c = 0;
    if (m['registration_goodies'] == true) c++;
    if (m['breakfast'] == true) c++;
    if (m['lunch'] == true) c++;
    if (m['snacks'] == true) c++;
    if (m['dinner'] == true) c++;
    if (m['midnight_snacks'] == true) c++;
    return c;
  }

  static Future<String> _writeToFile(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    await File(path).writeAsString(content);
    return path;
  }

  static Future<void> _shareFile(String path, String subject) async {
    await Share.shareXFiles(
      [XFile(path)],
      subject: subject,
    );
  }
}
