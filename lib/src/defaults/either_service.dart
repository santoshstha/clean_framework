import 'dart:convert';

import 'package:clean_framework/clean_framework.dart';
import 'package:either_option/either_option.dart';
import 'package:flutter/foundation.dart';

import 'json_service.dart';

abstract class EitherService<R extends JsonRequestModel,
    S extends JsonResponseModel> implements Service<R, S> {
  RestApi _restApi;
  String _path;
  RestMethod _method;

  final String path;

  EitherService(
      {@required RestMethod method,
      @required this.path,
      @required RestApi restApi})
      : assert(method != null),
        assert(path != null && path.isNotEmpty),
        assert(restApi != null),
        _path = path,
        _method = method,
        _restApi = restApi;

  @override
  Future<Either<ServiceError, S>> request({R requestModel}) async {
    if (await Locator().connectivity.getConnectivityStatus() ==
        ConnectivityStatus.offline) {
      Locator().logger.debug('JsonService response no connectivity error');
      return Left(NoConnectivityServiceError());
    }

    Map<String, dynamic> requestJson;
    if (requestModel != null) {
      requestJson = requestModel.toJson();
      if (!isRequestModelJsonValid(requestJson)) {
        Locator().logger.debug('JsonService response invalid request error');
        return Left(GeneralServiceError());
      }
    }

    final variablesInPath = _getVariablesFromPath();
    if (variablesInPath.length > 0) {
      if (requestModel == null) {
        // If a service has a variable in the path, request data is required
        Locator()
            .logger
            .debug('JsonService response missing request parameters');
        return Left(GeneralServiceError());
      }
      requestJson =
          _filterRequestDataAndUpdatePath(variablesInPath, requestJson);
      if (_getVariablesFromPath(check: true).isNotEmpty) {
        // Some variables where not substituted by request fields
        Locator()
            .logger
            .debug('JsonService response invalid request parameters');
        return Left(GeneralServiceError());
      }
    }

    final response = await _restApi.request(
        method: _method, path: _path, requestBody: requestJson);

    if (response.type == RestResponseType.timeOut) {
      Locator().logger.debug('JsonService response no connectivity error');
      return Left(NoConnectivityServiceError());
    } else if (response.type != RestResponseType.success) {
      ServiceError error = onError(response);
      if (!(error is NoServiceError)) {
        return Left(error);
      }
    }

    S model;

    try {
      final content = response?.content as String ?? '';
      final Map<String, dynamic> jsonResponse =
          json.decode(content) ?? <String, dynamic>{};
      model = parseResponse(jsonResponse);
    } on Error catch (e) {
      Locator().logger.debug('JsonService response parse error', e.toString());
      return Left(GeneralServiceError());
    } on Exception catch (e) {
      Locator()
          .logger
          .debug('JsonService response parse exception', e.toString());
      return Left(GeneralServiceError());
    }

    return Right(model);
  }

  List<String> _getVariablesFromPath({bool check = false}) {
    RegExp exp = RegExp(r'{(\w+)}');
    Iterable<RegExpMatch> matches = exp.allMatches(check ? _path : path);
    final foundVariables =
        matches.map((m) => m.group(1)).toList(growable: false);
    return foundVariables;
  }

  Map<String, dynamic> _filterRequestDataAndUpdatePath(
    List<String> variables,
    Map<String, dynamic> requestData,
  ) {
    Map<String, dynamic> filteredRequestData = Map.from(requestData);
    variables.forEach((variable) {
      if (requestData.containsKey(variable)) {
        _path =
            path.replaceAll('{$variable}', requestData[variable].toString());
        filteredRequestData.remove(variable);
      }
    });

    return filteredRequestData;
  }

  bool isRequestModelJsonValid(Map<String, dynamic> json) {
    try {
      if (json == null || json.isEmpty) {
        return false;
      }
      if (_jsonContainsNull(json)) return false;
    } catch (e) {
      return false;
    }
    return true;
  }

  bool _jsonContainsNull(Map<String, dynamic> json) {
    bool containsNull = false;
    List values = json.values.toList();
    for (int i = 0; i < values.length; i++) {
      if (values[i] is Map)
        containsNull = _jsonContainsNull(values[i]);
      else if (values[i] == null) containsNull = true;
      if (containsNull) break;
    }
    return containsNull;
  }

  S parseResponse(Map<String, dynamic> jsonResponse);

  ServiceError onError(RestResponse response) {
    return NoServiceError();
  }
}

abstract class ServiceError {}

class NoServiceError extends ServiceError {}

class GeneralServiceError extends ServiceError {}

class NoConnectivityServiceError extends ServiceError {}
