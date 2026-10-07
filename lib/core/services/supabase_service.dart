import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseClient client = Supabase.instance.client;
}

/// The single Supabase client initialized in `main.dart`, for providers that
/// receive it as a dependency.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
