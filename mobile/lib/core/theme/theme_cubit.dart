import 'package:flutter_bloc/flutter_bloc.dart';

import 'brand.dart';

/// Simple Cubit for toggling the active brand theme.
///
/// Usage from UI: `context.read<ThemeCubit>().switchBrand(LoobBrand.tealive)`
class ThemeCubit extends Cubit<LoobBrand> {
  ThemeCubit() : super(LoobBrand.discover);

  void switchBrand(LoobBrand brand) => emit(brand);

  void discover() => emit(LoobBrand.discover);
  void tealive() => emit(LoobBrand.tealive);
  void baskbear() => emit(LoobBrand.baskbear);
}
