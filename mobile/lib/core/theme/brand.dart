/// The three brand contexts available in the Loob app.
///
/// - [discover]: Neutral zone showing cross-brand content.
/// - [tealive]: Purple/playful immersion.
/// - [baskbear]: Charcoal+Orange/urban immersion.
enum LoobBrand {
  discover,
  tealive,
  baskbear;

  String get displayName {
    switch (this) {
      case LoobBrand.discover:
        return 'Discover';
      case LoobBrand.tealive:
        return 'Tealive';
      case LoobBrand.baskbear:
        return 'Baskbear';
    }
  }

  /// Maps to the backend brand_id. Discover has no single brand.
  int? get brandId {
    switch (this) {
      case LoobBrand.discover:
        return null;
      case LoobBrand.tealive:
        return 1;
      case LoobBrand.baskbear:
        return 2;
    }
  }
}
