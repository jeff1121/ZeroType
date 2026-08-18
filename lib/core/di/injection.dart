import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/antigravity_auth_source.dart';
import '../services/gemini_oauth_service.dart';
import '../services/official_model_catalog_service.dart';
import '../services/proxy_model_catalog_service.dart';
import '../services/sound_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/hotkey_service.dart';
import '../services/tray_service.dart';
import '../../features/history/domain/repositories/history_repository.dart';
import '../../features/history/data/repositories/history_repository_impl.dart';
import '../../features/model_config/data/repositories/model_config_repository_impl.dart';
import '../../features/model_config/domain/repositories/model_config_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  final dio = Dio();
  getIt.registerSingleton<Dio>(dio);
  final modelConfigRepository = ModelConfigRepositoryImpl(
    prefs: sharedPreferences,
  );
  getIt.registerSingleton<ModelConfigRepository>(modelConfigRepository);
  getIt.registerSingleton<GeminiOauthService>(
    GeminiOauthService(dio: dio, repository: modelConfigRepository),
  );
  getIt.registerSingleton<AntigravityAuthSource>(
    AntigravityAuthSource(dio: dio),
  );
  getIt.registerSingleton<ProxyModelCatalogService>(
    ProxyModelCatalogService(dio: dio),
  );
  getIt.registerSingleton<OfficialModelCatalogService>(
    OfficialModelCatalogService(dio: dio),
  );
  getIt.registerSingleton<SpeechRecognitionService>(
    SpeechRecognitionService(dio: dio),
  );
  getIt.registerSingleton<HotkeyService>(
    HotkeyService(prefs: sharedPreferences),
  );
  getIt.registerSingleton<TrayService>(TrayService());
  getIt.registerSingleton<SoundService>(SoundService(prefs: sharedPreferences));
  getIt.registerSingleton<HistoryRepository>(HistoryRepositoryImpl());
}
