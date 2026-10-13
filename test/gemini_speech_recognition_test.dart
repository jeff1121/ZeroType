import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_type/core/services/gemini_transcription_response.dart';
import 'package:zero_type/core/services/speech_recognition_service.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';

import 'support/catalog_test_adapter.dart';

void main() {
  late Directory temporaryDirectory;
  late File audio;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'zerotype-gemini-speech-',
    );
    audio = File('${temporaryDirectory.path}/synthetic.m4a');
    // 假傳輸只檢查服務送出與回應解析，不包含真人錄音或實際音訊解碼。
    await audio.writeAsBytes(const [0, 0, 0, 24, 102, 116, 121, 112]);
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  Future<TranscriptionResult> replay(
    _GeminiRoute route,
    Map<String, dynamic> response,
  ) async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      CatalogReply.json(
        route == _GeminiRoute.antigravity ? {'response': response} : response,
      ),
    ]);
    final SpeechRecognitionService service = SpeechRecognitionService(
      dio: Dio()..httpClientAdapter = adapter,
    );
    final TranscriptionResult result = await service.transcribe(
      audioFilePath: audio.path,
      provider: 'gemini',
      model: 'gemini-3.5-flash-lite',
      prompt: '請逐字轉寫音訊內容。',
      channel: route == _GeminiRoute.proxy
          ? SpeechChannel.proxy
          : SpeechChannel.official,
      isAntigravity: route == _GeminiRoute.antigravity,
      apiKey: route == _GeminiRoute.antigravity ? null : 'synthetic-key',
      accessToken: route == _GeminiRoute.antigravity ? 'synthetic-token' : null,
      antigravityProjectId: 'synthetic-project',
      proxyRoot: 'https://proxy.invalid',
    );
    expect(adapter.requests, hasLength(1));
    return result;
  }

  test('Antigravity 成功回應首個 part 為空時仍取得後續轉寫文字', () async {
    final CatalogTestAdapter adapter = CatalogTestAdapter([
      const CatalogReply.json({
        'response': {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': ''},
                  {'text': '這是一段測試轉寫。'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
        },
      }),
    ]);
    final SpeechRecognitionService service = SpeechRecognitionService(
      dio: Dio()..httpClientAdapter = adapter,
    );

    final TranscriptionResult result = await service.transcribe(
      audioFilePath: audio.path,
      provider: 'gemini',
      model: 'gemini-3.5-flash-lite',
      prompt: '請逐字轉寫音訊內容。',
      channel: SpeechChannel.official,
      isAntigravity: true,
      accessToken: 'synthetic-token',
      antigravityProjectId: 'synthetic-project',
    );

    expect(adapter.requests, hasLength(1));
    expect(result.text, '這是一段測試轉寫。');
  });

  for (final _GeminiRoute route in _GeminiRoute.values) {
    group(route.name, () {
      test('略過前置空 thought，保留帶簽章的可見文字與 token 用量', () async {
        final TranscriptionResult result = await replay(
          route,
          _response([
            {'thought': true, 'text': ''},
            {'thoughtSignature': 'synthetic-signature', 'text': '可見的轉寫文字'},
          ]),
        );
        expect(result.text, '可見的轉寫文字');
        expect(result.inputTokens, 17);
        expect(result.outputTokens, 8);
      });

      test('推理文字不混入後續可見轉寫', () async {
        final TranscriptionResult result = await replay(
          route,
          _response([
            {'thought': true, 'text': '不得貼上的推理內容'},
            {'text': '應貼上的轉寫'},
          ]),
        );
        expect(result.text, '應貼上的轉寫');
      });

      test('略過非文字與非 String part，仍讀取後續文字', () async {
        final TranscriptionResult result = await replay(
          route,
          _response([
            {
              'inlineData': {'mimeType': 'image/png', 'data': 'synthetic'},
            },
            {'text': 42},
            {'text': '後續文字'},
          ]),
        );
        expect(result.text, '後續文字');
      });

      test('合併同一 candidate 所有文字，保留片段間空白', () async {
        final TranscriptionResult result = await replay(
          route,
          _response([
            {'text': '  Hello '},
            {'text': 'world'},
            {'text': '!  '},
          ]),
        );
        expect(result.text, 'Hello world!');
      });

      test('只取第一個 candidate，不串接另一候選內容', () async {
        final Map<String, dynamic> response = _response([
          {'text': '第一個候選'},
        ]);
        (response['candidates'] as List).add({
          'content': {
            'parts': [
              {'text': '另一個候選'},
            ],
          },
          'finishReason': 'STOP',
        });
        expect((await replay(route, response)).text, '第一個候選');
      });

      test('只有 thought 時拋出明確錯誤，不回傳推理文字', () async {
        await expectLater(
          replay(
            route,
            _response([
              {'thought': true, 'text': '不得回傳或記錄的推理內容'},
            ]),
          ),
          throwsA(
            isA<Exception>().having(
              (Exception error) => error.toString(),
              '安全錯誤訊息',
              allOf(contains('未提供可見轉寫文字'), isNot(contains('推理內容'))),
            ),
          ),
        );
      });

      test('正常空文字保留空結果，交由既有空音訊流程處理', () async {
        final TranscriptionResult result = await replay(
          route,
          _response([
            {'text': ' '},
            {'text': ''},
          ]),
        );
        expect(result.text, isEmpty);
      });

      test('MAX_TOKENS 不當成完整成功轉寫', () async {
        await expectLater(
          replay(
            route,
            _response([
              {'text': '不可當成完整結果的片段'},
            ], finishReason: 'MAX_TOKENS'),
          ),
          throwsA(
            isA<Exception>().having(
              (Exception error) => error.toString(),
              '安全錯誤訊息',
              allOf(contains('輸出長度上限'), isNot(contains('完整結果的片段'))),
            ),
          ),
        );
      });

      test('被封鎖的回應不回傳上游內容', () async {
        await expectLater(
          replay(
            route,
            _response([
              {'text': '不得外洩的上游內容'},
            ], finishReason: 'SAFETY'),
          ),
          throwsA(
            isA<Exception>().having(
              (Exception error) => error.toString(),
              '安全錯誤訊息',
              allOf(contains('封鎖'), isNot(contains('上游內容'))),
            ),
          ),
        );
      });
    });
  }

  test('promptFeedback 封鎖且無 candidate 時回傳安全明確錯誤', () async {
    await expectLater(
      replay(_GeminiRoute.antigravity, {
        'promptFeedback': {
          'blockReason': 'SAFETY',
          'blockReasonMessage': '不得回傳的原始說明',
        },
      }),
      throwsA(
        isA<Exception>().having(
          (Exception error) => error.toString(),
          '安全錯誤訊息',
          allOf(contains('封鎖'), isNot(contains('原始說明'))),
        ),
      ),
    );
  });

  test('缺少 candidate 時安全報錯', () async {
    await expectLater(
      replay(_GeminiRoute.antigravity, {
        'usageMetadata': {'promptTokenCount': 17},
      }),
      throwsA(
        isA<Exception>().having(
          (Exception error) => error.toString(),
          '安全錯誤訊息',
          contains('候選回應'),
        ),
      ),
    );
  });

  test('Proxy 省略 optional finishReason 時仍接受有效文字', () async {
    final Map<String, dynamic> response = _response([
      {'text': 'Proxy 轉寫'},
    ]);
    (response['candidates'] as List).first.remove('finishReason');
    expect((await replay(_GeminiRoute.proxy, response)).text, 'Proxy 轉寫');
  });

  for (final String finishReason in [
    'FINISH_REASON_UNSPECIFIED',
    'LANGUAGE',
    'OTHER',
    'UNKNOWN_FUTURE_REASON',
  ]) {
    test('明確未完成原因 $finishReason 不回傳片段或原始原因', () async {
      await expectLater(
        replay(
          _GeminiRoute.antigravity,
          _response([
            {'text': '不得貼上的未完成片段'},
          ], finishReason: finishReason),
        ),
        throwsA(
          isA<GeminiTranscriptionException>()
              .having(
                (GeminiTranscriptionException error) => error.kind,
                '分類',
                GeminiTranscriptionFailure.incomplete,
              )
              .having(
                (GeminiTranscriptionException error) => error.toString(),
                '固定錯誤訊息',
                allOf(isNot(contains(finishReason)), isNot(contains('未完成片段'))),
              ),
        ),
      );
    });
  }

  test('成功日誌不包含轉寫、推理或 thoughtSignature', () async {
    final List<String> messages = [];
    final DebugPrintCallback originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() {
      debugPrint = originalDebugPrint;
    });
    final TranscriptionResult result = await replay(
      _GeminiRoute.antigravity,
      _response([
        {'thought': true, 'text': 'private-thought'},
        {'thoughtSignature': 'private-signature', 'text': 'private-transcript'},
      ]),
    );
    expect(result.text, 'private-transcript');
    expect(messages.join('\n'), isNot(contains('private-')));
    expect(messages.join('\n'), contains('in=17 out=8'));
  });

  test('沒有任何可見 String 文字的回應不是普通空音訊', () async {
    for (final List<Map<String, dynamic>> parts in [
      <Map<String, dynamic>>[
        {
          'inlineData': {'data': 'synthetic'},
        },
      ],
      <Map<String, dynamic>>[
        {'text': 42},
      ],
    ]) {
      await expectLater(
        replay(_GeminiRoute.antigravity, _response(parts)),
        throwsA(
          isA<GeminiTranscriptionException>().having(
            (GeminiTranscriptionException error) => error.kind,
            '沒有可讀內容',
            GeminiTranscriptionFailure.missingContent,
          ),
        ),
      );
    }
  });
}

enum _GeminiRoute { apiKey, proxy, antigravity }

Map<String, dynamic> _response(
  List<Map<String, dynamic>> parts, {
  String finishReason = 'STOP',
}) => {
  'candidates': [
    {
      'content': {'parts': parts},
      'finishReason': finishReason,
    },
  ],
  'usageMetadata': {'promptTokenCount': 17, 'candidatesTokenCount': 8},
};
