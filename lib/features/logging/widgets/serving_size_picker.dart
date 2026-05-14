import 'package:flutter/material.dart';

const _commonUnits = [
  'g', 'ml', 'fl oz', 'oz', 'cups', 'tbsp', 'tsp',
  'slices', 'pieces', 'bars', 'servings',
];

class ServingSizePicker extends StatefulWidget {
  final double quantity;
  final String unit;
  final double? servingSizeGrams;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<String> onUnitChanged;

  const ServingSizePicker({
    super.key,
    required this.quantity,
    required this.unit,
    this.servingSizeGrams,
    required this.onQuantityChanged,
    required this.onUnitChanged,
  });

  @override
  State<ServingSizePicker> createState() => _ServingSizePickerState();
}

class _ServingSizePickerState extends State<ServingSizePicker> {
  late TextEditingController _qtyController;
  String? _customUnit;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.quantity == widget.quantity.roundToDouble()
          ? widget.quantity.toInt().toString()
          : widget.quantity.toStringAsFixed(1),
    );
  }

  @override
  void didUpdateWidget(ServingSizePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity) {
      _qtyController.text = widget.quantity == widget.quantity.roundToDouble()
          ? widget.quantity.toInt().toString()
          : widget.quantity.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  String get _effectiveUnit => _customUnit ?? widget.unit;

  bool get _unitIsCommon => _commonUnits.contains(_effectiveUnit);

  void _onQtyChanged(String value) {
    final qty = double.tryParse(value);
    if (qty != null && qty > 0) {
      widget.onQuantityChanged(qty);
    }
  }

  Future<void> _openCustomUnitDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom unit'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Unit name',
            hintText: 'e.g. portions, packets',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _customUnit = result);
      widget.onUnitChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUnit = _effectiveUnit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: TextField(
                controller: _qtyController,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onQtyChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _unitIsCommon ? displayUnit : null,
                    isDense: true,
                    hint: Text(displayUnit),
                    onChanged: (v) {
                      if (v == '__custom__') {
                        _openCustomUnitDialog();
                      } else if (v != null) {
                        setState(() => _customUnit = null);
                        widget.onUnitChanged(v);
                      }
                    },
                    items: [
                      ..._commonUnits.map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u),
                          )),
                      const DropdownMenuItem(
                        value: '__custom__',
                        child: Text('Custom\u2026'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
