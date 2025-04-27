import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart' as xml;
import 'package:flutter/foundation.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heart Rate Analyzer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HeartRateAnalyzer(),
    );
  }
}

class HeartRateAnalyzer extends StatefulWidget {
  @override
  _HeartRateAnalyzerState createState() => _HeartRateAnalyzerState();
}

class _HeartRateAnalyzerState extends State<HeartRateAnalyzer> {
  List<Map<String, dynamic>> monthlyMaxes = [];
  Map<String, dynamic>? overallMax;
  bool isLoading = false;

  // Hàm xử lý file XML trong isolate
  static Future<Map<String, dynamic>> processXmlFile(String filePath) async {
    final file = File(filePath);
    final xmlString = await file.readAsString();
    final document = xml.XmlDocument.parse(xmlString);

    // Map lưu dữ liệu nhịp tim theo tháng
    final monthlyData = <String, List<Map<String, dynamic>>>{};

    // Duyệt qua các phần tử <Record>
    for (final record in document.findAllElements('Record')) {
      final startDateStr = record.getAttribute('startDate');
      if (startDateStr != null) {
        final startDate = DateTime.parse(startDateStr);
        final monthKey =
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
        final dateStr = startDate.toIso8601String().split('T')[0];

        // Duyệt qua các phần tử <InstantaneousBeatsPerMinute>
        for (final bpmElem in record.findAllElements(
          'InstantaneousBeatsPerMinute',
        )) {
          final time = bpmElem.getAttribute('time');
          final bpm = int.parse(bpmElem.getAttribute('bpm') ?? '0');
          monthlyData.putIfAbsent(monthKey, () => []).add({
            'date': dateStr,
            'time': time,
            'bpm': bpm,
          });
        }
      }
    }

    // Tìm BPM cao nhất mỗi tháng và tổng thể
    final monthlyMaxes = <Map<String, dynamic>>[];
    Map<String, dynamic>? overallMax;

    for (var month in monthlyData.keys) {
      var entries = monthlyData[month]!;
      if (entries.isNotEmpty) {
        var maxEntry = entries.fold(
          entries.first,
          (max, e) => e['bpm'] > max['bpm'] ? e : max,
        );
        monthlyMaxes.add({
          'month': month,
          'date': maxEntry['date'],
          'time': maxEntry['time'],
          'bpm': maxEntry['bpm'],
        });
        if (overallMax == null || maxEntry['bpm'] > overallMax['bpm']) {
          overallMax = maxEntry;
        }
      }
    }

    return {'monthlyMaxes': monthlyMaxes, 'overallMax': overallMax};
  }

  // Hàm nhập file XML
  Future<void> importFile() async {
    setState(() {
      isLoading = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final data = await compute(processXmlFile, filePath);
        setState(() {
          monthlyMaxes = List<Map<String, dynamic>>.from(data['monthlyMaxes']);
          overallMax = data['overallMax'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xử lý file: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Heart Rate Analyzer')),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (overallMax != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Max BPM Tổng: ${overallMax!['bpm']} vào ngày ${overallMax!['date']} lúc ${overallMax!['time']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Expanded(
                    child:
                        monthlyMaxes.isEmpty
                            ? Center(
                              child: Text(
                                'Chưa có dữ liệu. Vui lòng nhập file XML.',
                              ),
                            )
                            : ListView.builder(
                              itemCount: monthlyMaxes.length,
                              itemBuilder: (context, index) {
                                var entry = monthlyMaxes[index];
                                return ListTile(
                                  title: Text('Tháng: ${entry['month']}'),
                                  subtitle: Text(
                                    'Max BPM: ${entry['bpm']} vào ngày ${entry['date']} lúc ${entry['time']}',
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: importFile,
        tooltip: 'Nhập file XML',
        child: Icon(Icons.file_upload),
      ),
    );
  }
}
