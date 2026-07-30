/// Top-level admin platform modules.
enum AdminModule {
  connect,
  shop,
  calculator,
  seo,
  aiBusinessOs,
}

extension AdminModuleLabel on AdminModule {
  String get title {
    switch (this) {
      case AdminModule.connect:
        return 'Connect';
      case AdminModule.shop:
        return 'Shop';
      case AdminModule.calculator:
        return 'Calculator';
      case AdminModule.seo:
        return 'SEO';
      case AdminModule.aiBusinessOs:
        return 'AI Business OS';
    }
  }
}
