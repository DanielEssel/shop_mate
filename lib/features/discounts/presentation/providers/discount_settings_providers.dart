import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/discount_settings_remote_datasource.dart';
import '../../data/repositories/discount_settings_repository_impl.dart';
import '../../domain/entities/discount_release_gate.dart';
import '../../domain/entities/discount_settings.dart';
import '../../domain/repositories/discount_settings_repository.dart';
import '../../domain/usecases/get_discount_settings.dart';
import '../../domain/usecases/save_discount_settings.dart';

final discountSettingsRepositoryProvider = Provider<DiscountSettingsRepository>(
  (ref) {
    return DiscountSettingsRepositoryImpl(
      DiscountSettingsRemoteDataSource(ref.read(supabaseClientProvider)),
    );
  },
);

/// Whether this build may save discount settings; see
/// [DiscountReleaseGate]. A provider so tests can open it.
final discountWritesEnabledProvider = Provider<bool>((ref) {
  return DiscountReleaseGate.writesEnabled;
});

final getDiscountSettingsProvider = Provider<GetDiscountSettings>((ref) {
  return GetDiscountSettings(ref.read(discountSettingsRepositoryProvider));
});

final saveDiscountSettingsProvider = Provider<SaveDiscountSettings>((ref) {
  return SaveDiscountSettings(
    ref.read(discountSettingsRepositoryProvider),
    writesEnabled: ref.watch(discountWritesEnabledProvider),
  );
});

/// The shop's saved discount configuration (null when there is none).
/// Scoped to the signed-in account like every other session-scoped
/// provider.
final discountSettingsProvider = FutureProvider.autoDispose<DiscountSettings?>((
  ref,
) {
  ref.watch(currentUserIdProvider);
  return ref.read(getDiscountSettingsProvider).call();
});
