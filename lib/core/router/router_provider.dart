import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_router.dart';

part 'router_provider.g.dart';

@Riverpod(keepAlive: true)
AppRouter appRouter(Ref ref) {
  return AppRouter();
}
