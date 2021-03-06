import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:diod/app/app.dart';
import 'package:diod/app/models/user.dart';
import 'package:diod/config/app_config.dart';

class Api {
  Api(AppConfig config);

  final JsonDecoder _decoder = JsonDecoder();
  final JsonEncoder _encoder = JsonEncoder();
  String _token;
  User _loggedUser;

  User loggedUser() {
    _loggedUser = _loggedUser ?? User.currentUser();
    return _loggedUser;
  }

  bool isLogged() {
    return loggedUser() != null;
  }

  Future<dynamic> get(String method) async {
    try {
      return parseResponse(await _get(method));
    } on AuthException {
      if (loggedUser() != null) {
        await relogin();
        return parseResponse(await _get(method));
      }
    } on SocketException {
      throw new ApiConnException();
    }
  }

  Future<dynamic> post(String method, {body}) async {
    try {
      return parseResponse(await _post(method, body));
    } on AuthException {
      if (loggedUser() != null) {
        await relogin();
        return parseResponse(await _post(method, body));
      }
    } on SocketException {
      throw new ApiConnException();
    }
  }

  Future<http.Response> _get(String method) async {
    return await http.get(
      App.application.config.apiBaseUrl + method,
      headers: {
        'Authorization': 'Renew client_id=${App.application.config.clientId},token=$_token',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    );
  }

  Future<http.Response> _post(String method, body) async {
    return await http.post(
      App.application.config.apiBaseUrl + method,
      body: _encoder.convert(body),
      headers: {
        'Authorization': 'Renew client_id=${App.application.config.clientId},token=$_token',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    );
  }

  Future<void> resetPassword(String username) async {
    try {
      await http.post(
        App.application.config.apiBaseUrl + 'v1/reset_password',
        headers: {
          'Authorization': 'Renew client_id=${App.application.config.clientId},login=$username'
        }
      );
    } on SocketException {
      throw new ApiConnException();
    }
  }

  Future<void> login(String username, String password) async {
    await _authenticate(username, password);
    _loggedUser = User.create({'username': username, 'password': password});
  }

  Future<void> logout() async {
    _loggedUser.delete();
    _loggedUser = null;
    _token = null;
  }

  Future<void> relogin() async {
    await _authenticate(loggedUser().username, loggedUser().password);
  }

  Future<void> _authenticate(String username, String password) async {
    try {
      http.Response response = await http.post(
        App.application.config.apiBaseUrl + 'v1/authenticate',
        headers: {
          'Authorization': 'Renew client_id=${App.application.config.clientId},login=$username,password=$password'
        }
      );

      _token = parseResponse(response)['token'];
    } on SocketException {
      throw new ApiConnException();
    }
  }

  dynamic parseResponse(http.Response response) {
      final int statusCode = response.statusCode;
      final String body = response.body;
      dynamic parsedResp;

      if (statusCode < 200) {
        throw new ApiException('Ошибка при получении данных', statusCode);
      } else {
        parsedResp = _decoder.convert(body);
      }

      if (statusCode == 401) {
        throw new AuthException(parsedResp['error']);
      }
      if (statusCode >= 400) {
        throw new ApiException(parsedResp['error'], statusCode);
      }

      return _decoder.convert(body);
  }
}

class ApiException implements Exception {
  String errorMsg;
  int statusCode;

  ApiException(this.errorMsg, this.statusCode);
}

class AuthException extends ApiException {
  AuthException(errorMsg) : super(errorMsg, 401);
}

class ApiConnException extends ApiException {
  ApiConnException() : super('Нет связи', 503);
}
