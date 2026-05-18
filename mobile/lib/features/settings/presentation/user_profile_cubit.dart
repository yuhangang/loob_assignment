import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/di/injection.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../data/models/user_profile_model.dart';
import '../domain/repositories/user_profile_repository.dart';

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
  final String? errorCode;
  final String? traceId;

  const UserProfileError(this.message, {this.errorCode, this.traceId});

  @override
  List<Object?> get props => [message, errorCode, traceId];
}

// ── Cubit ────────────────────────────────────────────────────────────────────

class UserProfileCubit extends Cubit<UserProfileState> {
  final IUserProfileRepository _repository;

  UserProfileCubit({IUserProfileRepository? repository})
    : _repository = repository ?? sl<IUserProfileRepository>(),
      super(const UserProfileInitial());

  void reset() {
    emit(const UserProfileInitial());
  }

  Future<void> loadProfile() async {
    // If not authenticated, skip remote requests to avoid startup API errors
    if (!sl<AuthService>().isAuthenticated) {
      emit(const UserProfileInitial());
      return;
    }

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
      emit(_errorState(e));
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
      emit(_errorState(e));
    }
  }

  Future<void> updateRegisteredCountry(String countryCode) async {
    try {
      final updatedProfile = await _repository.updateProfile(
        registeredCountryId: countryCode,
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
      emit(_errorState(e));
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
      emit(_errorState(e));
    }
  }

  UserProfileError _errorState(Object error) {
    if (error is ApiException) {
      return UserProfileError(
        _messageFor(error),
        errorCode: error.errorCode,
        traceId: error.traceId,
      );
    }
    return UserProfileError(error.toString());
  }

  String _messageFor(ApiException error) {
    switch (error.errorCode) {
      case 'USR_AUTH_REQUIRED':
      case 'API_UNAUTHORIZED':
        return 'Please sign in again to view your profile.';
      case 'USR_UNSUPPORTED_COUNTRY':
        return 'This country is not supported for your profile yet.';
      case 'USR_INVALID_TOPUP_AMOUNT':
        return 'Enter a valid wallet top-up amount.';
      case 'USR_INVALID_PROFILE_PAYLOAD':
      case 'USR_INVALID_WALLET_TOPUP_PAYLOAD':
        return 'Some profile details could not be saved. Please try again.';
      case 'API_CONNECTION_TIMEOUT':
      case 'API_CONNECTION_ERROR':
        return error.message;
      default:
        return error.message;
    }
  }
}
