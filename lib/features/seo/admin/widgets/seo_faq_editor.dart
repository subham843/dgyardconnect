import 'package:flutter/material.dart';

import '../../domain/seo_service.dart';

/// Reusable FAQ Q&A editor for SEO cities and services.
class SeoFaqEditor extends StatefulWidget {
  const SeoFaqEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.templateHint,
  });

  final List<SeoFaqItem> items;
  final ValueChanged<List<SeoFaqItem>> onChanged;
  final String? templateHint;

  @override
  State<SeoFaqEditor> createState() => _SeoFaqEditorState();
}

class _SeoFaqEditorState extends State<SeoFaqEditor> {
  late List<SeoFaqItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List<SeoFaqItem>.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant SeoFaqEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _items = List<SeoFaqItem>.from(widget.items);
    }
  }

  void _notify() => widget.onChanged(List<SeoFaqItem>.from(_items));

  void _add() {
    setState(() => _items.add(const SeoFaqItem(question: '', answer: '')));
    _notify();
  }

  void _remove(int index) {
    setState(() => _items.removeAt(index));
    _notify();
  }

  void _update(int index, {String? question, String? answer}) {
    final item = _items[index];
    _items[index] = SeoFaqItem(
      question: question ?? item.question,
      answer: answer ?? item.answer,
    );
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.templateHint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.templateHint!, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (var i = 0; i < _items.length; i++) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('FAQ ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _remove(i),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: _items[i].question,
                    decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder()),
                    onChanged: (v) => _update(i, question: v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _items[i].answer,
                    decoration: const InputDecoration(labelText: 'Answer', border: OutlineInputBorder()),
                    maxLines: 3,
                    onChanged: (v) => _update(i, answer: v),
                  ),
                ],
              ),
            ),
          ),
        ],
        OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add FAQ')),
      ],
    );
  }
}
