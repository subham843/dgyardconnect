import 'models/text_assist_models.dart';
import 'platform_edge_client.dart';

class PlatformTextAssistService {
  Future<TextAssistResponse> run({
    required TextAssistAction action,
    required String text,
    TextAssistLanguage language = TextAssistLanguage.auto,
    TextAssistContext? context,
  }) async {
    final lang = switch (language) {
      TextAssistLanguage.en => 'en',
      TextAssistLanguage.hi => 'hi',
      TextAssistLanguage.auto => 'auto',
    };
    final json = await PlatformEdgeClient.post('platform-text-assist', {
      'action': action.apiValue,
      'text': text,
      'language': lang,
      if (context != null) 'context': context.toJson(),
    });
    return TextAssistResponse.fromJson(json);
  }
}
