import '../env/app_env.dart';

class AppConfig {
  final AppEnv env;
  final String baseUrl;
  final String cdnBaseUrl;
  final int masterDataVersion;
  final bool legacyRealtimeCombat;

  const AppConfig({
    required this.env,
    required this.baseUrl,
    required this.cdnBaseUrl,
    this.masterDataVersion = 1,
    this.legacyRealtimeCombat = false,
  });

  factory AppConfig.dev() => AppConfig(
        env: AppEnv.dev,
        baseUrl: 'http://localhost:8080',
        cdnBaseUrl: 'https://cdn.jsdelivr.net/gh/skyalley/eox-master-data@v1',
        legacyRealtimeCombat: true,
      );

  factory AppConfig.staging() => AppConfig(
        env: AppEnv.staging,
        baseUrl: 'https://staging-api.eox.skyalley.id',
        cdnBaseUrl: 'https://cdn.jsdelivr.net/gh/skyalley/eox-master-data@v1',
      );

  factory AppConfig.prod() => AppConfig(
        env: AppEnv.prod,
        baseUrl: 'https://api.eox.skyalley.id',
        cdnBaseUrl: 'https://cdn.jsdelivr.net/gh/skyalley/eox-master-data@v1',
      );

  String get apiBase => '$baseUrl/api';
}
