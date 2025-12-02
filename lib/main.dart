import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_picker/gallery_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptData {
  final String merchant;
  final double total;
  final String date;

  ReceiptData({
    required this.merchant,
    required this.total,
    required this.date,
  });

  @override
  String toString() {
    return 'merchant: $merchant, total: $total, date: $date';
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Expense Tracker',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const ReceiptScannerScreen(),
    );
  }
}

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  XFile? _pickedFile;
  String _statusMessage = "Welcome! Waiting for image...";
  ReceiptData? _extractedData;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Run the function immediately after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openGalleryAutomatically();
    });
  }

  // --- UI Functions ---

  // Function to open the Image Picker (Gallery)
  Future<void> _openGalleryAutomatically() async {
    setState(() {
      _statusMessage = "Requesting photo library permission...";
    });

    // 1. Check and Request Photos Permission
    final status = await Permission.photos.request();

    if (status.isGranted || status.isLimited) {
      setState(() {
        _statusMessage = "Permission granted. Launching gallery...";
      });

      try {
        final ImagePicker picker = ImagePicker();
        final XFile? file = await picker.pickImage(source: ImageSource.gallery);

        if (file != null) {
          setState(() {
            _pickedFile = file;
            _statusMessage = "Image selected. Starting text recognition...";
            _extractedData = null; // Clear previous data
            _isProcessing = true;
          });
          await _processReceipt(file);
        } else {
          setState(() {
            _statusMessage = "Gallery access cancelled. Tap 'Pick Receipt' to try again.";
          });
        }
      } catch (e) {
        setState(() {
          _statusMessage = "Error picking image: $e";
        });
      }
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _statusMessage = "Permission permanently denied. Please enable in Settings.";
      });
      // Optionally show a dialog and open settings
      openAppSettings();
    } else {
      setState(() {
        _statusMessage = "Permission denied. Tap 'Pick Receipt' to retry.";
      });
    }
  }

  // --- OCR Processing Functions ---

  Future<void> _processReceipt(XFile file) async {
    final textRecognizer = TextRecognizer(script: TextScript.latin);
    final InputImage inputImage = InputImage.fromFilePath(file.path);

    try {
      // 1. Run ML Kit OCR to get raw text
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      setState(() {
        _statusMessage = "Text recognized. Parsing data...";
      });

      // 2. Extract structured data using pattern matching (The hard part!)
      final data = _extractStructuredData(rawText);

      setState(() {
        _extractedData = data;
        _statusMessage = "✅ Extraction Complete!";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "OCR processing failed: $e";
      });
    } finally {
      textRecognizer.close();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // This is the custom logic needed when NOT using an AI/LLM for structured parsing.
  ReceiptData _extractStructuredData(String rawText) {
    // --- Define Regex Patterns ---
    // NOTE: This logic is brittle and only works for simple, consistent receipts.
    // It is provided as an example of the complex parsing required without AI.

    // Regex 1: Find total amount (looks for keywords like TOTAL or AMOUNT followed by a number)
    final totalRegex = RegExp(r'(TOTAL|AMOUNT|BALANCE|SUBTOTAL)[^\d]*(\d+\.\d{2})', caseSensitive: false);
    
    // Regex 2: Find date (common formats like DD/MM/YYYY, YYYY-MM-DD, or DD-MON-YY)
    final dateRegex = RegExp(r'(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})|(\d{4}-\d{2}-\d{2})');

    // Simple heuristic for merchant (just take the first non-blank line)
    final lines = rawText.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    final merchant = lines.isNotEmpty ? lines.first : 'Unknown Merchant';

    // --- Extraction ---
    double total = 0.0;
    String date = 'Unknown Date';

    // Extract Total
    final totalMatch = totalRegex.firstMatch(rawText);
    if (totalMatch != null) {
      // The amount is in the second capturing group
      final totalStr = totalMatch.group(2)?.replaceAll(',', ''); 
      total = double.tryParse(totalStr ?? '0.0') ?? 0.0;
    }

    // Extract Date
    final dateMatch = dateRegex.firstMatch(rawText);
    if (dateMatch != null) {
      date = dateMatch.group(0) ?? 'Unknown Date';
    }

    // --- Return Result ---
    return ReceiptData(merchant: merchant, total: total, date: date);
  }

  // --- UI Widget Tree ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Receipt Scanner'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Status and Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isProcessing ? Colors.blue.shade50 : Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isProcessing ? Colors.blue.shade700 : Colors.indigo.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isProcessing)
                    const LinearProgressIndicator(color: Colors.indigo),
                  if (!_isProcessing)
                    ElevatedButton.icon(
                      onPressed: _openGalleryAutomatically,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text("Pick Receipt from Gallery"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. Image Preview
            Text(
              "Receipt Preview",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              child: _pickedFile == null
                  ? Center(child: Text("No image selected", style: TextStyle(color: Colors.grey.shade600)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_pickedFile!.path),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Text("Error loading image")),
                      ),
                    ),
            ),
            const SizedBox(height: 30),

            // 3. Extracted Data Result
            Text(
              "Extraction Result",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.green.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: _extractedData == null
                  ? Center(child: Text(_isProcessing ? "Processing..." : "Results will appear here."))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildResultRow('Merchant', _extractedData!.merchant, Icons.store),
                        _buildResultRow('Total', "\$${_extractedData!.total.toStringAsFixed(2)}", Icons.monetization_on),
                        _buildResultRow('Date', _extractedData!.date, Icons.calendar_today),
                        const SizedBox(height: 15),
                        // Action button placeholder
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement actual Firestore save operation here
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Simulated: Expense saved to database!')),
                            );
                          },
                          icon: const Icon(Icons.save),
                          label: const Text("Save Expense"),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.indigo, size: 20),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              "$title:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
