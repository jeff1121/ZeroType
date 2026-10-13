import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_type/core/di/injection.dart';
import 'package:zero_type/core/services/antigravity_auth_source.dart';
import 'package:zero_type/core/services/official_model_catalog_service.dart';
import 'package:zero_type/core/services/proxy_model_catalog_service.dart';
import 'package:zero_type/features/model_config/data/repositories/model_config_repository_impl.dart';
import 'package:zero_type/features/model_config/domain/entities/ai_provider.dart';
import 'package:zero_type/features/model_config/domain/entities/speech_connection.dart';
import 'package:zero_type/features/model_config/presentation/controllers/model_config_controller.dart';
import 'package:zero_type/features/model_config/presentation/pages/model_config_page.dart';

// 2026-10-13 遠端目錄的去識別化最小回放；同名模型仍有各自的 ID。
const Map<String, Object> _repeatedNames = {
  'models': {
    'gemini-2.5-flash': {'displayName': 'Gemini 3.5 Flash Lite'},
    'gemini-2.5-flash-thinking': {'displayName': 'Gemini 3.5 Flash Lite'},
    'gemini-2.5-flash-lite': {'displayName': 'Gemini 3.5 Flash Lite'},
    'gemini-3.1-flash-lite': {'displayName': 'Gemini 3.5 Flash Lite'},
    'gemini-3.5-flash-lite': {'displayName': 'Gemini 3.5 Flash Lite'},
  },
};

class _PageAuth extends AntigravityAuthSource {
  _PageAuth() : super(dio: Dio());

  @override
  String? get catalogIdentity => 'fake-page-account';

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<AntigravityAuthData?> getAuthData() async =>
      (accessToken: 'test-page-token', projectId: 'test-page-project');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Dio dio;
  late SharedPreferences preferences;
  late ModelConfigRepositoryImpl repository;
  int requests = 0;
  bool rejectRequests = false;
  bool holdRequests = false;
  Object payload = _repeatedNames;
  final List<({RequestOptions options, RequestInterceptorHandler handler})>
  heldRequests = [];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = ModelConfigRepositoryImpl(prefs: preferences);
    await repository.saveSelectedSpeechProviderId('gemini');
    await repository.saveOfficialCredentialMethod(
      'gemini',
      CredentialMethod.antigravityOauth,
    );
    requests = 0;
    rejectRequests = false;
    holdRequests = false;
    heldRequests.clear();
    payload = _repeatedNames;
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          if (holdRequests) {
            heldRequests.add((options: options, handler: handler));
            return;
          }
          if (rejectRequests) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: payload),
          );
        },
      ),
    );
    getIt.registerSingleton<SharedPreferences>(preferences);
    getIt.registerSingleton<AntigravityAuthSource>(_PageAuth());
    getIt.registerSingleton<OfficialModelCatalogService>(
      OfficialModelCatalogService(dio: dio),
    );
    getIt.registerSingleton<ProxyModelCatalogService>(
      ProxyModelCatalogService(dio: dio),
    );
  });

  tearDown(() async {
    dio.close(force: true);
    await getIt.reset();
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1000, 1100),
    TargetPlatform platform = TargetPlatform.macOS,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providersConfigProvider.overrideWith(
            (ref) async => const ProvidersConfig(
              speechRecognition: [
                AiProvider(
                  id: 'gemini',
                  name: 'Google Gemini',
                  models: [
                    AiModel(id: 'bundled-gemini', name: 'Bundled Gemini'),
                  ],
                ),
                AiProvider(
                  id: 'openai',
                  name: 'OpenAI',
                  models: [AiModel(id: 'whisper-1', name: 'Whisper')],
                ),
                AiProvider(
                  id: 'azure',
                  name: 'Azure OpenAI',
                  models: [AiModel(id: 'whisper', name: 'Whisper')],
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: const ModelConfigPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  DropdownButton<String> dropdown(WidgetTester tester) =>
      tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('speech-model-dropdown')),
      );

  Future<void> reload(WidgetTester tester) async {
    final Finder button = find.byTooltip('更新模型目錄');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('同名五個模型只顯示完整 ID，儲存原 ID 且不重查目錄', (tester) async {
    await mount(tester);
    expect(requests, 1);
    final List<String?> ids = dropdown(
      tester,
    ).items!.map((item) => item.value).toList();
    expect(ids.toSet().length, 5);
    expect(ids, [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.5-flash-thinking',
      'gemini-3.1-flash-lite',
      'gemini-3.5-flash-lite',
    ]);
    await tester.tap(find.byKey(const ValueKey('speech-model-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('gemini-2.5-flash'), findsWidgets);
    expect(find.text('gemini-3.1-flash-lite'), findsWidgets);
    expect(
      find.text('Gemini 3.5 Flash Lite', skipOffstage: false),
      findsNothing,
    );
    expect(find.byTooltip(RegExp('Gemini 3.5 Flash Lite')), findsNothing);
    final Finder choice = find.text('gemini-3.1-flash-lite').last;
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(
      await repository.getSelectedSpeechModelId(
        'gemini',
        SpeechChannel.official,
      ),
      'gemini-3.1-flash-lite',
    );
    expect(dropdown(tester).value, 'gemini-3.1-flash-lite');
    expect(requests, 1);
  });

  testWidgets('依完整 ID 排序，選單與排除清單及 tooltip 均不顯示 API 名稱', (tester) async {
    payload = {
      'models': {
        'z-model': {'displayName': 'API fake A'},
        'a-model': {'displayName': 'API fake Z'},
        'z-unsupported': {
          'displayName': 'API fake B',
          'supportedMimeTypes': {'image/png': true},
        },
        'a-unsupported': {
          'displayName': 'API fake Y',
          'supportedMimeTypes': {'image/png': true},
        },
      },
    };
    await mount(tester);
    expect(dropdown(tester).items!.map((item) => item.value), [
      'a-model',
      'z-model',
    ]);
    await tester.tap(find.byKey(const ValueKey('speech-model-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('a-model'), findsWidgets);
    expect(find.text('z-model'), findsWidgets);
    expect(find.textContaining('API fake', skipOffstage: false), findsNothing);
    expect(find.byTooltip(RegExp('API fake')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('a-unsupported'), findsOneWidget);
    expect(find.text('z-unsupported'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('a-unsupported')).dy,
      lessThan(tester.getTopLeft(find.text('z-unsupported')).dy),
    );
    expect(find.textContaining('API fake', skipOffstage: false), findsNothing);
    expect(find.byTooltip(RegExp('API fake')), findsNothing);
  });

  testWidgets('reload 失敗保留遠端清單並明示快取，不能宣稱成功', (tester) async {
    await mount(tester);
    rejectRequests = true;
    await reload(tester);
    expect(requests, 3);
    expect(dropdown(tester).items, hasLength(5));
    expect(find.textContaining('已重新取得模型目錄'), findsNothing);
    expect(find.textContaining('已更新模型目錄'), findsNothing);
    expect(find.textContaining('更新失敗'), findsWidgets);
    expect(find.textContaining('清單來源：上次成功取得的目錄'), findsOneWidget);
    expect(find.textContaining('最後成功：'), findsOneWidget);
  });

  testWidgets('首次查詢失敗使用內建清單，reload 仍回報失敗', (tester) async {
    rejectRequests = true;
    await mount(tester);
    expect(dropdown(tester).items, isNotEmpty);
    expect(
      dropdown(tester).items!.map((item) => item.value),
      contains(OfficialModelCatalogService.antigravityModels.first.id),
    );
    await reload(tester);
    expect(find.textContaining('更新失敗'), findsWidgets);
    expect(find.textContaining('已更新模型目錄'), findsNothing);
    expect(find.textContaining('清單來源：內建目錄'), findsOneWidget);
  });

  testWidgets('能力未確認可選，不支援音訊的新模型被排除', (tester) async {
    payload = {
      'models': {
        'supported': {
          'displayName': 'Supported',
          'supportedMimeTypes': {'audio/mp4': true},
        },
        'unknown': {'displayName': 'Unknown'},
        'unsupported': {
          'displayName': 'Unsupported',
          'supportedMimeTypes': {'audio/mpeg': true},
        },
      },
    };
    await mount(tester);
    expect(dropdown(tester).items!.map((item) => item.value), [
      'supported',
      'unknown',
    ]);
    expect(dropdown(tester).items!.every((item) => item.enabled), isTrue);
    expect(find.textContaining('1 個模型不支援目前錄音格式'), findsOneWidget);
    expect(find.textContaining('1 個模型的轉寫能力未驗證'), findsOneWidget);
  });

  testWidgets('已選的不支援模型保留原 ID 並警示，不能再次選取', (tester) async {
    await repository.saveSelectedSpeechModelId(
      'gemini',
      SpeechChannel.official,
      'unsupported',
    );
    payload = {
      'models': {
        'unsupported': {
          'displayName': 'Old model',
          'supportedMimeTypes': {'image/png': true},
        },
      },
    };
    await mount(tester);
    expect(dropdown(tester).value, 'unsupported');
    expect(dropdown(tester).items!.single.enabled, isFalse);
    expect(find.textContaining('目前選取的模型不支援轉寫'), findsOneWidget);
    expect(find.text('此目錄沒有支援目前錄音格式的模型。'), findsOneWidget);
    expect(
      await repository.getSelectedSpeechModelId(
        'gemini',
        SpeechChannel.official,
      ),
      'unsupported',
    );
  });

  testWidgets('消失的選取只補一筆，重現後移除舊選取標記', (tester) async {
    await repository.saveSelectedSpeechModelId(
      'gemini',
      SpeechChannel.official,
      'saved-custom-model',
    );
    await mount(tester);
    for (int iteration = 0; iteration < 2; iteration++) {
      await reload(tester);
      expect(dropdown(tester).items, hasLength(6));
      expect(dropdown(tester).value, 'saved-custom-model');
    }
    expect(find.text('上次選取的模型未列於目前目錄，已保留原設定。'), findsOneWidget);
    payload = {
      'models': {
        'saved-custom-model': {'displayName': 'Returned'},
      },
    };
    await reload(tester);
    expect(dropdown(tester).items, hasLength(1));
    expect(dropdown(tester).value, 'saved-custom-model');
    expect(find.text('上次選取的模型未列於目前目錄，已保留原設定。'), findsNothing);
  });

  testWidgets('更新期間保留清單並停用 reload，連點只發出一次請求', (tester) async {
    await mount(tester);
    holdRequests = true;
    final Finder refreshButton = find.byKey(
      const ValueKey('reload-model-catalog'),
    );
    await tester.tap(refreshButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(dropdown(tester).items, hasLength(5));
    expect(tester.widget<IconButton>(refreshButton).onPressed, isNull);
    await tester.tap(refreshButton);
    await tester.pump();
    expect(requests, 2);
    expect(heldRequests, hasLength(1));
    final held = heldRequests.single;
    held.handler.resolve(
      Response(
        requestOptions: held.options,
        statusCode: 200,
        data: _repeatedNames,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(refreshButton).onPressed, isNotNull);
    expect(dropdown(tester).items, hasLength(5));
  });

  testWidgets('切換 Provider 後舊 reload 回應不得蓋清單或彈出通知', (tester) async {
    await mount(tester);
    holdRequests = true;
    await tester.tap(find.byTooltip('更新模型目錄'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(heldRequests, hasLength(1));
    holdRequests = false;
    await tester.tap(find.widgetWithText(ChoiceChip, 'OpenAI'));
    await tester.pumpAndSettle();
    expect(dropdown(tester).items!.single.value, 'whisper-1');
    final held = heldRequests.single;
    held.handler.resolve(
      Response(
        requestOptions: held.options,
        statusCode: 200,
        data: _repeatedNames,
      ),
    );
    await tester.pumpAndSettle();
    expect(dropdown(tester).items!.single.value, 'whisper-1');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('尚無成功快取時，再次更新仍保留目前內建清單', (tester) async {
    rejectRequests = true;
    await mount(tester);
    final List<String?> previousIds = dropdown(
      tester,
    ).items!.map((item) => item.value).toList();
    expect(previousIds, isNotEmpty);
    rejectRequests = false;
    holdRequests = true;
    await tester.tap(find.byTooltip('更新模型目錄'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final held = heldRequests.single;
    final List<String?> loadingIds = dropdown(
      tester,
    ).items!.map((item) => item.value).toList();
    held.handler.resolve(
      Response(
        requestOptions: held.options,
        statusCode: 200,
        data: _repeatedNames,
      ),
    );
    await tester.pumpAndSettle();
    expect(loadingIds, previousIds);
    expect(dropdown(tester).items, hasLength(5));
  });

  testWidgets('遠端合法空目錄與全數不支援清楚區別，不偷偷套內建', (tester) async {
    payload = {'models': <String, Object>{}};
    await mount(tester);
    expect(dropdown(tester).items, isEmpty);
    expect(find.textContaining('清單來源：遠端目錄'), findsOneWidget);
    expect(find.text('此目錄沒有支援目前錄音格式的模型。'), findsNothing);
    payload = {
      'models': {
        'image-only': {
          'supportedMimeTypes': {'image/png': true},
        },
      },
    };
    await reload(tester);
    expect(dropdown(tester).items, isEmpty);
    expect(find.text('此目錄沒有支援目前錄音格式的模型。'), findsOneWidget);
  });

  for (final bool removed in [false, true]) {
    testWidgets('已開啟的選單不能新增選取${removed ? '已移除' : '已改為不支援'}的模型', (tester) async {
      payload = {
        'models': {
          'candidate-a': {'displayName': 'Candidate A'},
          'candidate-b': {'displayName': 'Candidate B'},
        },
      };
      await repository.saveSelectedSpeechModelId(
        'gemini',
        SpeechChannel.official,
        'candidate-b',
      );
      await mount(tester);
      holdRequests = true;
      await tester.tap(find.byTooltip('更新模型目錄'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('speech-model-dropdown')));
      await tester.pump(const Duration(milliseconds: 500));
      final held = heldRequests.single;
      held.handler.resolve(
        Response(
          requestOptions: held.options,
          statusCode: 200,
          data: {
            'models': {
              if (!removed)
                'candidate-a': {
                  'displayName': 'Candidate A',
                  'supportedMimeTypes': {'image/png': true},
                },
              'candidate-b': {'displayName': 'Candidate B'},
            },
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('candidate-a').last);
      await tester.pumpAndSettle();
      expect(
        await repository.getSelectedSpeechModelId(
          'gemini',
          SpeechChannel.official,
        ),
        'candidate-b',
      );
      expect(dropdown(tester).value, 'candidate-b');
      // reload 的通知先出現，重選提示接在後面。
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('模型目錄已變更，請重新選擇模型。'), findsOneWidget);
    });
  }

  testWidgets('Proxy 自訂別名保留、仍可選且記錄原始 ID', (tester) async {
    await repository.saveSpeechChannel('gemini', SpeechChannel.proxy);
    await repository.saveProxyRoot('gemini', 'https://proxy.example.test');
    await repository.saveSpeechApiKey(
      'gemini',
      SpeechChannel.proxy,
      'proxy-test-key',
    );
    payload = {
      'data': [
        {'id': 'custom-speech-alias', 'name': 'Custom speech'},
      ],
    };
    await mount(tester);
    expect(dropdown(tester).items!.single.value, 'custom-speech-alias');
    await tester.tap(find.byKey(const ValueKey('speech-model-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('custom-speech-alias').last);
    await tester.pumpAndSettle();
    expect(
      await repository.getSelectedSpeechModelId('gemini', SpeechChannel.proxy),
      'custom-speech-alias',
    );
    expect(requests, 1);
  });

  testWidgets('Azure 內建與自訂部署名稱仍可切換並儲存', (tester) async {
    await repository.saveSelectedSpeechProviderId('azure');
    await mount(tester, size: const Size(1000, 1500));
    final Finder manual = find.text('我的部署名稱不在清單中？手動指定自訂部署名稱...');
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    final Finder input = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText?.startsWith('輸入 Azure') == true,
    );
    await tester.enterText(input, 'production-whisper');
    await tester.tap(find.widgetWithText(ElevatedButton, '儲存').last);
    await tester.pumpAndSettle();
    expect(
      await repository.getSelectedSpeechModelId(
        'azure',
        SpeechChannel.official,
      ),
      'production-whisper',
    );
    await tester.tap(find.text('切換回從清單選擇部署'));
    await tester.pumpAndSettle();
    expect(dropdown(tester).value, 'production-whisper');
    expect(requests, 0);
  });

  for (final TargetPlatform platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets('$platform 的 700×500 選單支援長 ID、鍵盤選取與 Escape', (tester) async {
      final String longName = List.filled(12, 'A long model title').join(' ');
      payload = {
        'models': {
          'first-model-with-a-long-but-distinct-id': {'displayName': longName},
          'second-model-with-a-long-but-distinct-id': {'displayName': 'Second'},
        },
      };
      await repository.saveSelectedSpeechModelId(
        'gemini',
        SpeechChannel.official,
        'first-model-with-a-long-but-distinct-id',
      );
      await mount(tester, size: const Size(700, 500), platform: platform);
      final Finder field = find.byKey(const ValueKey('speech-model-dropdown'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(dropdown(tester).menuMaxHeight, lessThanOrEqualTo(300));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        dropdown(tester).value,
        'second-model-with-a-long-but-distinct-id',
      );
      expect(requests, 1);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.text('second-model-with-a-long-but-distinct-id').hitTestable(),
        findsOneWidget,
      );
      expect(find.text(longName, skipOffstage: false), findsNothing);
      expect(find.text('Second', skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
