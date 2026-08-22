import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.read(supabaseClientProvider),
  );
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.read(supabaseClientProvider);

  return supabase.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final supabase = ref.read(supabaseClientProvider);

  return supabase.auth.currentUser;
});