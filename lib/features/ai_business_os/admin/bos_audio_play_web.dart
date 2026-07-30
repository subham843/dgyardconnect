import 'dart:convert';
import 'dart:html' as html;

void playBase64Audio(String base64Audio, {String contentType = 'audio/wav'}) {
  final bytes = base64Decode(base64Audio);
  final blob = html.Blob([bytes], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final audio = html.AudioElement()
    ..src = url
    ..autoplay = true;
  audio.play();
  audio.onEnded.listen((_) => html.Url.revokeObjectUrl(url));
}

void playAudioUrl(String url) {
  final audio = html.AudioElement()
    ..src = url
    ..autoplay = true
    ..controls = false;
  audio.play();
}
