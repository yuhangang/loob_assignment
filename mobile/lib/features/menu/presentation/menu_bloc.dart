import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/di/injection.dart';
import '../data/models/catalog_model.dart';
import '../data/models/store_model.dart';
import '../domain/repositories/menu_repository.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class MenuEvent extends Equatable {
  const MenuEvent();

  @override
  List<Object?> get props => [];
}

class LoadMenu extends MenuEvent {
  final String countryCode;
  final String language;
  final int? storeId;
  final int brandId;

  const LoadMenu({
    required this.countryCode,
    required this.language,
    this.storeId,
    required this.brandId,
  });

  @override
  List<Object?> get props => [countryCode, language, storeId, brandId];
}

// ── States ───────────────────────────────────────────────────────────────────

abstract class MenuState extends Equatable {
  const MenuState();

  @override
  List<Object?> get props => [];
}

class MenuInitial extends MenuState {}

class MenuLoading extends MenuState {}

class MenuLoaded extends MenuState {
  final CatalogModel catalog;
  final List<StoreModel> stores;
  final StoreModel selectedStore;

  const MenuLoaded({
    required this.catalog,
    required this.stores,
    required this.selectedStore,
  });

  @override
  List<Object?> get props => [catalog, stores, selectedStore];
}

class MenuError extends MenuState {
  final String message;

  const MenuError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

/// Uses BLoC (not Cubit) because menu loading involves complex async flows
/// that may need debouncing for search/filter in the future.
class MenuBloc extends Bloc<MenuEvent, MenuState> {
  final IMenuRepository _repository;

  MenuBloc({IMenuRepository? repository})
    : _repository = repository ?? sl<IMenuRepository>(),
      super(MenuInitial()) {
    on<LoadMenu>(_onLoadMenu);
  }

  Future<void> _onLoadMenu(LoadMenu event, Emitter<MenuState> emit) async {
    emit(MenuLoading());
    try {
      final stores = await _repository.listStores(
        countryId: event.countryCode,
        brandId: event.brandId,
      );
      if (stores.isEmpty) {
        emit(const MenuError('No active outlets found for this brand.'));
        return;
      }
      final selectedStore = stores.firstWhere(
        (store) => store.id == event.storeId,
        orElse: () => stores.first,
      );
      final catalog = await _repository.loadCategoryBackedCatalog(
        countryCode: event.countryCode,
        language: event.language,
        storeId: selectedStore.id,
        brandId: event.brandId,
      );
      emit(
        MenuLoaded(
          catalog: catalog,
          stores: stores,
          selectedStore: selectedStore,
        ),
      );
    } catch (e) {
      emit(MenuError(e.toString()));
    }
  }
}
