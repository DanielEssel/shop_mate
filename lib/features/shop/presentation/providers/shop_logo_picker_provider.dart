import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the platform image picker and returns the chosen file, or null when
/// the user cancels. Uses the photo library on Android/iOS and the native
/// file dialog on Windows (via image_picker's file_selector backend).
///
/// The image is returned untouched (no resizing or re-encoding), so PNG
/// transparency is preserved; size and format are validated afterwards.
typedef ShopLogoPicker = Future<XFile?> Function();

final shopLogoPickerProvider = Provider<ShopLogoPicker>((ref) {
  return () => ImagePicker().pickImage(source: ImageSource.gallery);
});
