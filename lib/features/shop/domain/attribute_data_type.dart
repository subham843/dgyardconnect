/// Supabase attribute_data_type enum values (Postgres).
abstract final class AttributeDataType {
  static const text = 'text';
  static const longText = 'long_text';
  static const number = 'number';
  static const boolean = 'bool';
  static const select = 'select';
  static const multiSelect = 'multi_select';
  static const date = 'date';

  static const all = [text, longText, number, boolean, select, multiSelect, date];

  static const labels = <String, String>{
    text: 'Text',
    longText: 'Long Text',
    number: 'Number',
    boolean: 'Boolean',
    select: 'Select (Single Choice)',
    multiSelect: 'Multi Select',
    date: 'Date',
  };

  static bool hasOptions(String type) => type == select || type == multiSelect;

  static String labelFor(String type) => labels[type] ?? type;
}
