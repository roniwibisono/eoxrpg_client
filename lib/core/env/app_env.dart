enum AppEnv {
  dev._('dev'),
  staging._('staging'),
  prod._('prod');

  final String name;
  const AppEnv._(this.name);

  bool get isDebug => this == AppEnv.dev;
  bool get isStaging => this == AppEnv.staging;
  bool get isProd => this == AppEnv.prod;
}
