import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zero_type/features/dictionary/data/repositories/dictionary_repository_impl.dart';
import 'package:zero_type/features/dictionary/domain/repositories/dictionary_repository.dart';

part 'dictionary_controller.g.dart';

@riverpod
DictionaryRepository dictionaryRepository(Ref ref) =>
    DictionaryRepositoryImpl();

@riverpod
class DictionaryController extends _$DictionaryController {
  @override
  Future<List<String>> build() async {
    final repo = ref.watch(dictionaryRepositoryProvider);
    return repo.loadWords();
  }

  Future<void> addWord(String word) async {
    final repo = ref.read(dictionaryRepositoryProvider);
    await repo.addWord(word);
    ref.invalidateSelf();
  }

  Future<void> removeWord(String word) async {
    final repo = ref.read(dictionaryRepositoryProvider);
    await repo.removeWord(word);
    ref.invalidateSelf();
  }
}
