import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_type/core/services/official_model_catalog_service.dart';

void main() {
  late OfficialModelCatalogService catalog;

  setUp(() {
    catalog = OfficialModelCatalogService(dio: Dio());
  });

  test('Gemini 目錄只保留 generateContent，並去掉嵌入／圖片／TTS', () {
    final models = catalog.parseGeminiModels({
      'models': [
        {
          'name': 'models/gemini-2.5-flash',
          'displayName': 'Gemini 2.5 Flash',
          'supportedGenerationMethods': ['generateContent', 'countTokens'],
        },
        {
          'name': 'models/gemini-embedding-001',
          'displayName': 'Gemini Embedding',
          'supportedGenerationMethods': ['embedContent'],
        },
        {
          'name': 'models/imagen-4.0-generate',
          'displayName': 'Imagen 4',
          'supportedGenerationMethods': ['predict'],
        },
        {
          'name': 'models/gemini-2.5-flash-preview-tts',
          'displayName': 'Gemini 2.5 Flash TTS',
          'supportedGenerationMethods': ['generateContent'],
        },
        {
          'name': 'models/gemini-3-flash-preview',
          'displayName': 'Gemini 3 Flash Preview',
          'supportedGenerationMethods': ['generateContent'],
        },
      ],
    });

    expect(models.map((m) => m.id).toList(), [
      'gemini-2.5-flash',
      'gemini-3-flash-preview',
    ]);
    expect(models.first.name, 'Gemini 2.5 Flash');
  });

  test('OpenAI 目錄只保留轉寫相關模型', () {
    final models = catalog.parseOpenAiModels({
      'data': [
        {'id': 'gpt-4o'},
        {'id': 'gpt-4o-transcribe'},
        {'id': 'whisper-1'},
        {'id': 'dall-e-3'},
        {'id': 'gpt-4o-mini-transcribe'},
      ],
    });

    expect(models.map((m) => m.id).toList(), [
      'gpt-4o-transcribe',
      'whisper-1',
      'gpt-4o-mini-transcribe',
    ]);
  });
}
