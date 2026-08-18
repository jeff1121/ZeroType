import 'package:auto_route/auto_route.dart';
import 'package:zero_type/features/model_config/presentation/pages/model_config_page.dart';
import 'package:zero_type/features/dictionary/presentation/pages/dictionary_page.dart';
import 'package:zero_type/features/history/presentation/pages/history_page.dart';
import 'package:zero_type/features/prompt/presentation/pages/prompt_page.dart';
import 'package:zero_type/features/settings/presentation/pages/settings_page.dart';
import 'package:zero_type/features/testing/presentation/pages/testing_page.dart';
import 'package:zero_type/shared/widgets/main_shell.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: MainShellRoute.page,
      initial: true,
      children: [
        AutoRoute(page: ModelConfigRoute.page), // index 0
        AutoRoute(page: PromptRoute.page), // index 1
        AutoRoute(page: DictionaryRoute.page), // index 2
        AutoRoute(page: HistoryRoute.page), // index 3
        AutoRoute(page: SettingsRoute.page), // index 4
        AutoRoute(page: TestingRoute.page),
      ],
    ),
  ];
}
