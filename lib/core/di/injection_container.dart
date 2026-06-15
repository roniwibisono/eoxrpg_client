import 'package:get_it/get_it.dart';

import '../config/app_config.dart';
import '../logger/app_logger.dart';

final sl = GetIt.instance;

Future<void> initCore(AppConfig config) async {
  sl.registerLazySingleton(() => config);
  sl.registerLazySingleton(() => AppLogger('EOX', enabled: !config.env.isProd));
}
