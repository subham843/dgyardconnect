import 'package:flutter_test/flutter_test.dart';

import 'package:dgyardconnect/features/calculator/domain/calculator_engine.dart';
import 'package:dgyardconnect/features/calculator/domain/calculator_models.dart';

void main() {
  test('formula rule computes bnc_qty', () async {
    final engine = CalculatorEngine();
    final rules = [
      CalculatorRule(
        id: '1',
        templateId: 't',
        ruleType: 'formula',
        name: 'BNC',
        priority: 10,
        condition: {'all': [{'var': 'camera_qty', 'op': 'gte', 'value': 1}]},
        action: {'type': 'formula', 'output_key': 'bnc_qty', 'expression': 'camera_qty * 2'},
        isActive: true,
      ),
    ];
    final result = await engine.evaluate(
      questions: const [],
      rules: rules,
      answers: {'camera_qty': 4},
    );
    expect(result.formulas.length, 1);
    expect(result.formulas.first.key, 'bnc_qty');
    expect(result.formulas.first.value, 8);
  });

  test('condition blocks rule when not met', () async {
    final engine = CalculatorEngine();
    final rules = [
      CalculatorRule(
        id: '1',
        templateId: 't',
        ruleType: 'formula',
        name: 'BNC',
        priority: 10,
        condition: {'all': [{'var': 'camera_qty', 'op': 'gte', 'value': 10}]},
        action: {'type': 'formula', 'output_key': 'bnc_qty', 'expression': 'camera_qty * 2'},
        isActive: true,
      ),
    ];
    final result = await engine.evaluate(
      questions: const [],
      rules: rules,
      answers: {'camera_qty': 2},
    );
    expect(result.formulas, isEmpty);
  });
}
