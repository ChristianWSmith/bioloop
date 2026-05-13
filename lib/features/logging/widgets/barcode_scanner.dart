import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/api/open_food_facts_client.dart';
import '../../../core/api/models/food_result.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final OpenFoodFactsClient apiClient;

  const BarcodeScannerScreen({super.key, required this.apiClient});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _loading = false;
  bool? _notFound;

  void _onDetect(BarcodeCapture capture) {
    if (_loading || _notFound != null) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (barcode == null || barcode.isEmpty) return;

    setState(() => _loading = true);

    widget.apiClient.getByBarcode(barcode).then((result) {
      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop<FoodResult>(result);
      } else {
        setState(() {
          _loading = false;
          _notFound = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      error.errorCode.message,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              );
            },
            placeholderBuilder: (context) => const ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_notFound == true)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Unknown barcode',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text('No food found for this barcode'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              Navigator.of(context).pop<Object?>('manual'),
                          label: const Text('Enter manually'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _notFound = null;
                              _loading = false;
                            });
                          },
                          child: const Text('Scan again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
