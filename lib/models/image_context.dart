enum ImageContext {
  user,
  company,
  product,
  category,
  brand,
  system,
}

extension ImageContextX on ImageContext {
  String get value => switch (this) {
        ImageContext.user => 'user',
        ImageContext.company => 'company',
        ImageContext.product => 'product',
        ImageContext.category => 'category',
        ImageContext.brand => 'brand',
        ImageContext.system => 'system',
      };
}
