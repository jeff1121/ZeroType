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

  test('Antigravity 目錄解析 API 回應並過濾內部模型', () {
    final models = catalog.parseAntigravityModels({
      'models': {
        'gemini-3.1-flash-lite': {'displayName': 'Gemini 3.1 Flash Lite'},
        'gemini-3.6-flash-high': {'displayName': 'Gemini 3.6 Flash (High)'},
        'tab_flash_lite_preview': {'displayName': 'Tab Internal'},
        'chat_20706': {'displayName': 'Chat Internal'},
        'gemini-3-flash': {'displayName': ''},
      },
    });

    expect(models.map((m) => m.id).toList(), [
      'gemini-3.1-flash-lite',
      'gemini-3.6-flash-high',
      'gemini-3-flash',
    ]);
    expect(models[0].name, 'Gemini 3.1 Flash Lite');
    expect(models[1].name, 'Gemini 3.6 Flash (High)');
    expect(models[2].name, 'gemini-3-flash');
  });

  test('Antigravity 目錄非預期資料回傳空清單', () {
    expect(catalog.parseAntigravityModels(null), isEmpty);
    expect(catalog.parseAntigravityModels('invalid'), isEmpty);
    expect(catalog.parseAntigravityModels({'models': null}), isEmpty);
  });
}
