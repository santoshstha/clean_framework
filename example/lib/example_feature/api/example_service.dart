import 'package:clean_framework/clean_framework.dart';
import 'package:clean_framework/clean_framework_defaults.dart';
import 'package:clean_framework_example/example_locator.dart';

import 'example_service_response_model.dart';

class ExampleService extends JsonService {
  ExampleService({
    JsonServiceResponseHandler<ExampleServiceResponseModel> handler,
  })  : assert(handler != null),
        super(
            handler: handler,
            method: RestMethod.get,
            restApi: ExampleLocator().api,
            path: 'login-history');

  @override
  ExampleServiceResponseModel parseResponse(Map<String, dynamic> jsonResponse) {
    return ExampleServiceResponseModel.fromJson(jsonResponse);
  }
}