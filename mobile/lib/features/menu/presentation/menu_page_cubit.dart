import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection.dart';

class MenuPageLocalState {
  final int? selectedStoreId;
  final int? selectedCategoryId;
  final int? pendingStoreChangeWarningStoreId;
  final bool isPickup;
  final bool isProgrammaticScroll;
  final bool isChangingStoreAcrossBrands;
  final Set<int> favouritedIds;
  final Set<String> selectedDietaryTags;

  const MenuPageLocalState({
    this.selectedStoreId,
    this.selectedCategoryId,
    this.pendingStoreChangeWarningStoreId,
    this.isPickup = true,
    this.isProgrammaticScroll = false,
    this.isChangingStoreAcrossBrands = false,
    this.favouritedIds = const {},
    this.selectedDietaryTags = const {},
  });

  MenuPageLocalState copyWith({
    int? Function()? selectedStoreId,
    int? Function()? selectedCategoryId,
    int? Function()? pendingStoreChangeWarningStoreId,
    bool? isPickup,
    bool? isProgrammaticScroll,
    bool? isChangingStoreAcrossBrands,
    Set<int>? favouritedIds,
    Set<String>? selectedDietaryTags,
  }) {
    return MenuPageLocalState(
      selectedStoreId: selectedStoreId != null ? selectedStoreId() : this.selectedStoreId,
      selectedCategoryId: selectedCategoryId != null ? selectedCategoryId() : this.selectedCategoryId,
      pendingStoreChangeWarningStoreId: pendingStoreChangeWarningStoreId != null
          ? pendingStoreChangeWarningStoreId()
          : this.pendingStoreChangeWarningStoreId,
      isPickup: isPickup ?? this.isPickup,
      isProgrammaticScroll: isProgrammaticScroll ?? this.isProgrammaticScroll,
      isChangingStoreAcrossBrands: isChangingStoreAcrossBrands ?? this.isChangingStoreAcrossBrands,
      favouritedIds: favouritedIds ?? this.favouritedIds,
      selectedDietaryTags: selectedDietaryTags ?? this.selectedDietaryTags,
    );
  }
}

class MenuPageCubit extends Cubit<MenuPageLocalState> {
  static const String _dietaryTagsPrefsKey = 'selected_dietary_tags';

  MenuPageCubit() : super(const MenuPageLocalState()) {
    _loadDietaryTags();
  }

  void _loadDietaryTags() {
    try {
      final prefs = sl<SharedPreferences>();
      final tags = prefs.getStringList(_dietaryTagsPrefsKey);
      if (tags != null && tags.isNotEmpty) {
        emit(state.copyWith(selectedDietaryTags: Set<String>.from(tags)));
      }
    } catch (_) {
      // Handle edge cases if SharedPreferences is not yet fully initialized or registered
    }
  }

  void reloadDietaryTags() {
    try {
      final prefs = sl<SharedPreferences>();
      final tags = prefs.getStringList(_dietaryTagsPrefsKey);
      final currentTags = state.selectedDietaryTags;
      final newTags = tags != null ? Set<String>.from(tags) : <String>{};

      if (currentTags.length != newTags.length || !currentTags.containsAll(newTags)) {
        emit(state.copyWith(selectedDietaryTags: newTags));
      }
    } catch (_) {}
  }

  void selectStore(int? storeId) {
    emit(state.copyWith(selectedStoreId: () => storeId));
  }

  void selectCategory(int? categoryId) {
    emit(state.copyWith(selectedCategoryId: () => categoryId));
  }

  void setPendingStoreChange(int? storeId) {
    emit(state.copyWith(pendingStoreChangeWarningStoreId: () => storeId));
  }

  void setPickup(bool isPickup) {
    emit(state.copyWith(isPickup: isPickup));
  }

  void setProgrammaticScroll(bool isProgrammaticScroll) {
    emit(state.copyWith(isProgrammaticScroll: isProgrammaticScroll));
  }

  void setChangingStoreAcrossBrands(bool isChangingStoreAcrossBrands) {
    emit(state.copyWith(isChangingStoreAcrossBrands: isChangingStoreAcrossBrands));
  }

  void toggleFavourite(int productId) {
    final updated = Set<int>.from(state.favouritedIds);
    if (updated.contains(productId)) {
      updated.remove(productId);
    } else {
      updated.add(productId);
    }
    emit(state.copyWith(favouritedIds: updated));
  }

  void toggleDietaryTag(String tag) {
    final updated = Set<String>.from(state.selectedDietaryTags);
    if (updated.contains(tag)) {
      updated.remove(tag);
    } else {
      updated.add(tag);
    }
    emit(state.copyWith(selectedDietaryTags: updated));
    _saveDietaryTags(updated);
  }

  void clearDietaryTags() {
    emit(state.copyWith(selectedDietaryTags: const {}));
    _saveDietaryTags(const {});
  }

  void _saveDietaryTags(Set<String> tags) {
    try {
      final prefs = sl<SharedPreferences>();
      prefs.setStringList(_dietaryTagsPrefsKey, tags.toList());
    } catch (_) {}
  }
}
