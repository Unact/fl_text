import 'package:diod/main.dart';
import 'package:diod/config/app_config.dart';

void main() {
  App.setup(AppConfig(
    env: 'production',
    databaseVersion: 1,
    apiBaseUrl: 'https://rapi.unact.ru/api/'
  )).run();
}
