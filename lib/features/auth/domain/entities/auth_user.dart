import 'package:flutter/foundation.dart';

/// The signed-in account, reduced to what ShopMate uses.
@immutable
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) {
    return other is AuthUser && other.id == id && other.email == email;
  }

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'AuthUser($id)';
}
