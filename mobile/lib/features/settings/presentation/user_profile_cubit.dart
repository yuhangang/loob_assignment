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
  final WalletHistoryModel walletHistory;
  final LoyaltyHistoryModel loyaltyHistory;
  final bool isTopUpSubmitting;

  const UserProfileLoaded(
    this.profile, {
    required this.walletHistory,
    required this.loyaltyHistory,
    this.isTopUpSubmitting = false,
  });

  @override
  List<Object?> get props => [
    profile,
    walletHistory,
    loyaltyHistory,
    isTopUpSubmitting,
  ];
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
      final walletHistory = await _repository.getWalletHistory();
      final loyaltyHistory = await _repository.getLoyaltyHistory();
      emit(
        UserProfileLoaded(
          profile,
          walletHistory: walletHistory,
          loyaltyHistory: loyaltyHistory,
        ),
      );
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
      final walletHistory = await _repository.getWalletHistory();
      final loyaltyHistory = await _repository.getLoyaltyHistory();
      emit(
        UserProfileLoaded(
          updatedProfile,
          walletHistory: walletHistory,
          loyaltyHistory: loyaltyHistory,
        ),
      );
    } catch (e) {
      emit(UserProfileError(e.toString()));
    }
  }

  Future<void> topUpWallet(int amount) async {
    final currentState = state;
    if (currentState is! UserProfileLoaded) return;

    emit(
      UserProfileLoaded(
        currentState.profile,
        walletHistory: currentState.walletHistory,
        loyaltyHistory: currentState.loyaltyHistory,
        isTopUpSubmitting: true,
      ),
    );
    try {
      final walletHistory = await _repository.topUpWallet(amount);
      final profile = await _repository.getProfile();
      final loyaltyHistory = await _repository.getLoyaltyHistory();
      emit(
        UserProfileLoaded(
          profile,
          walletHistory: walletHistory,
          loyaltyHistory: loyaltyHistory,
        ),
      );
    } catch (e) {
      emit(UserProfileError(e.toString()));
    }
  }
}
