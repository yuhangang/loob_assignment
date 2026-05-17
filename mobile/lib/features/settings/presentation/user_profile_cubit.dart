import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/di/injection.dart';
import '../data/models/user_profile_model.dart';
import '../data/repositories/user_profile_repository.dart';

// ── State ────────────────────────────────────────────────────────────────────

abstract class UserProfileState extends Equatable {
  const UserProfileState();

  @override
  List<Object?> get props => [];
}

class UserProfileInitial extends UserProfileState {
  const UserProfileInitial();
}

class UserProfileLoading extends UserProfileState {
  const UserProfileLoading();
}

class UserProfileLoaded extends UserProfileState {
  final UserProfileModel profile;

  const UserProfileLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class UserProfileError extends UserProfileState {
  final String message;

  const UserProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class UserProfileCubit extends Cubit<UserProfileState> {
  final UserProfileRepository _repository;

  UserProfileCubit({UserProfileRepository? repository})
      : _repository = repository ?? sl<UserProfileRepository>(),
        super(const UserProfileInitial());

  Future<void> loadProfile() async {
    emit(const UserProfileLoading());
    try {
      final profile = await _repository.getProfile();
      emit(UserProfileLoaded(profile));
    } catch (e) {
      emit(UserProfileError(e.toString()));
    }
  }

  Future<void> updatePreferredLanguage(String languageCode) async {
    final backendLanguage = switch (languageCode) {
      'ms' => 'ms-MY',
      'th' => 'th-TH',
      _ => 'en-US',
    };
    try {
      final updatedProfile = await _repository.updateProfile(
        preferredLanguage: backendLanguage,
      );
      emit(UserProfileLoaded(updatedProfile));
    } catch (e) {
      emit(UserProfileError(e.toString()));
    }
  }
}
