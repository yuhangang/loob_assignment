import 'package:flutter_bloc/flutter_bloc.dart';

class MenuPageLocalState {
  final int? selectedStoreId;
  final int? selectedCategoryId;
  final int? pendingStoreChangeWarningStoreId;
  final bool isPickup;
  final bool isProgrammaticScroll;
  final bool isChangingStoreAcrossBrands;
  final Set<int> favouritedIds;

  const MenuPageLocalState({
    this.selectedStoreId,
    this.selectedCategoryId,
    this.pendingStoreChangeWarningStoreId,
    this.isPickup = true,
    this.isProgrammaticScroll = false,
    this.isChangingStoreAcrossBrands = false,
    this.favouritedIds = const {},
  });

  MenuPageLocalState copyWith({
    int? Function()? selectedStoreId,
    int? Function()? selectedCategoryId,
    int? Function()? pendingStoreChangeWarningStoreId,
    bool? isPickup,
    bool? isProgrammaticScroll,
    bool? isChangingStoreAcrossBrands,
    Set<int>? favouritedIds,
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
    );
  }
}

class MenuPageCubit extends Cubit<MenuPageLocalState> {
  MenuPageCubit() : super(const MenuPageLocalState());

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
}
