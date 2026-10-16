import '../entities/discount_settings.dart';
import '../repositories/discount_settings_repository.dart';

class GetDiscountSettings {
  GetDiscountSettings(this._repository);

  final DiscountSettingsRepository _repository;

  Future<DiscountSettings?> call() {
    return _repository.getSettings();
  }
}
