sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data);
  final T data;
}

final class ApiValidationError<T> extends ApiResult<T> {
  const ApiValidationError(this.errors, {this.message});
  final Map<String, List<String>> errors;
  final String? message;
}

final class ApiBadRequest<T> extends ApiResult<T> {
  const ApiBadRequest(this.message);
  final String message;
}

final class ApiNetworkError<T> extends ApiResult<T> {
  const ApiNetworkError(this.message);
  final String message;
}

final class ApiUnauthorized<T> extends ApiResult<T> {
  const ApiUnauthorized([this.message]);
  final String? message;
}

final class ApiRateLimited<T> extends ApiResult<T> {
  const ApiRateLimited(this.message, {this.retryAfterSeconds});
  final String message;
  final int? retryAfterSeconds;
}

final class ApiConflict<T> extends ApiResult<T> {
  const ApiConflict(this.message);
  final String message;
}

final class ApiServerError<T> extends ApiResult<T> {
  const ApiServerError(this.message);
  final String message;
}
