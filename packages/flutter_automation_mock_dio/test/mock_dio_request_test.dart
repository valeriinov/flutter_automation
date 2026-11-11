import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_mock_dio/flutter_automation_mock_dio.dart';

const _baseUrl = 'https://example.test/app';
const _rootBaseUrl = 'https://example.test';
const _endpointPath = '/items/details';
const _textPath = '/places/popular';
const _itemId = 42;
const _bodyKey = 'amount';
const _bodyValue = 550;
const _queryKey = 'id';
const _queryValue = 7;
const _attachmentId = '3f1c2a7e-mock';
const _variantKey = 'variant';
const _variantValue = 'preview';
const _acceptLanguage = 'en-GB';
const _putMethod = 'PUT';
const _fileUrl =
    'https://file-host.mock.invalid/file-attachment/original/$_attachmentId';

final _bytes = Uint8List.fromList(const [1, 2, 3]);

void main() {
  group('MockDioRequest Tests', () {
    _mockDioRequest_should_readThePathRelativeToTheBaseUrl();
    _mockDioRequest_should_keepThePathWhenTheBaseUrlHasNoPath();
    _mockDioRequest_should_readTheTrailingId();
    _mockDioRequest_should_leaveThePathIdNullWithoutATrailingNumber();
    _mockDioRequest_should_readAMapBody();
    _mockDioRequest_should_leaveTheBodyEmptyWithoutAMapPayload();
    _mockDioRequest_should_readTheQueryParameters();
    _mockDioRequest_should_leaveTheQueryParametersEmptyWithoutAQuery();
    _mockDioRequest_should_readAStringTrailingSegment();
    _mockDioRequest_should_readTheFullPathOfAnAbsoluteUrl();
    _mockDioRequest_should_readTheQueryWrittenIntoTheUrl();
    _mockDioRequest_should_keepTheBytesItIsGiven();
    _mockDioRequest_should_readTheAcceptLanguageHeader();
    _mockDioRequest_should_leaveTheAcceptLanguageNullWithoutTheHeader();
    _mockDioRequest_should_readTheMethod();
  });
}

void _mockDioRequest_should_readThePathRelativeToTheBaseUrl() {
  test('MockDioRequest should read the path relative to the base url', () {
    final request = MockDioRequest.read(
      _createOptions(baseUrl: _baseUrl, path: _textPath),
    );

    expect(request.path, _textPath);
  });
}

void _mockDioRequest_should_keepThePathWhenTheBaseUrlHasNoPath() {
  test('MockDioRequest should keep the path when the base url has no path', () {
    final request = MockDioRequest.read(
      _createOptions(baseUrl: _rootBaseUrl, path: _textPath),
    );

    expect(request.path, _textPath);
  });
}

void _mockDioRequest_should_readTheTrailingId() {
  test('MockDioRequest should read the trailing id', () {
    final request = MockDioRequest.read(
      _createOptions(baseUrl: _baseUrl, path: '$_endpointPath/$_itemId'),
    );

    expect(request.pathId, _itemId);
  });
}

void _mockDioRequest_should_leaveThePathIdNullWithoutATrailingNumber() {
  test(
    'MockDioRequest should leave the path id null without a trailing number',
    () {
      final request = MockDioRequest.read(
        _createOptions(baseUrl: _baseUrl, path: _endpointPath),
      );

      expect(request.pathId, isNull);
    },
  );
}

void _mockDioRequest_should_readAMapBody() {
  test('MockDioRequest should read a map body', () {
    final request = MockDioRequest.read(
      _createOptions(
        baseUrl: _baseUrl,
        path: _endpointPath,
        data: const {_bodyKey: _bodyValue},
      ),
    );

    expect(request.body[_bodyKey], _bodyValue);
  });
}

void _mockDioRequest_should_leaveTheBodyEmptyWithoutAMapPayload() {
  test('MockDioRequest should leave the body empty without a map payload', () {
    final request = MockDioRequest.read(
      _createOptions(baseUrl: _baseUrl, path: _endpointPath, data: _bodyValue),
    );

    expect(request.body, isEmpty);
  });
}

void _mockDioRequest_should_readTheQueryParameters() {
  test('MockDioRequest should read the query parameters', () {
    final request = MockDioRequest.read(
      _createOptions(
        baseUrl: _baseUrl,
        path: _endpointPath,
        queryParameters: const {_queryKey: _queryValue},
      ),
    );

    expect(request.queryParameters[_queryKey], _queryValue);
  });
}

void _mockDioRequest_should_leaveTheQueryParametersEmptyWithoutAQuery() {
  test(
    'MockDioRequest should leave the query parameters empty without a query',
    () {
      final request = MockDioRequest.read(
        _createOptions(baseUrl: _baseUrl, path: _endpointPath),
      );

      expect(request.queryParameters, isEmpty);
    },
  );
}

void _mockDioRequest_should_readAStringTrailingSegment() {
  test('MockDioRequest should read a string trailing segment', () {
    final request = MockDioRequest.read(
      _createOptions(baseUrl: _baseUrl, path: '$_endpointPath/$_attachmentId'),
    );

    expect(request.pathSegment, _attachmentId);
    expect(request.pathId, isNull);
  });
}

void _mockDioRequest_should_readTheFullPathOfAnAbsoluteUrl() {
  test('MockDioRequest should read the full path of an absolute url', () {
    final request = MockDioRequest.read(
      _createOptions(baseUrl: '', path: _fileUrl),
    );

    expect(request.path, '/file-attachment/original/$_attachmentId');
  });
}

void _mockDioRequest_should_readTheQueryWrittenIntoTheUrl() {
  test('MockDioRequest should read the query written into the url', () {
    final request = MockDioRequest.read(
      _createOptions(
        baseUrl: _baseUrl,
        path: '$_endpointPath/$_attachmentId?$_variantKey=$_variantValue',
        queryParameters: const {_queryKey: _queryValue},
      ),
    );

    expect(request.queryParameters, {
      _variantKey: _variantValue,
      _queryKey: _queryValue,
    });
    expect(request.pathSegment, _attachmentId);
  });
}

void _mockDioRequest_should_keepTheBytesItIsGiven() {
  test('MockDioRequest should keep the bytes it is given', () {
    final request = MockDioRequest.read(
      _createOptions(baseUrl: '', path: _fileUrl, data: _bytes),
      bytes: _bytes,
    );

    expect(request.bytes, _bytes);
    expect(request.body, isEmpty);
  });
}

void _mockDioRequest_should_readTheAcceptLanguageHeader() {
  test('MockDioRequest should read the accept language header', () {
    final request = MockDioRequest.read(
      _createOptions(
        baseUrl: _baseUrl,
        path: _textPath,
        headers: {'Accept-Language': _acceptLanguage},
      ),
    );

    expect(request.acceptLanguage, _acceptLanguage);
  });
}

void _mockDioRequest_should_leaveTheAcceptLanguageNullWithoutTheHeader() {
  test(
    'MockDioRequest should leave the accept language null without the header',
    () {
      final request = MockDioRequest.read(
        _createOptions(baseUrl: _baseUrl, path: _textPath),
      );

      expect(request.acceptLanguage, isNull);
    },
  );
}

void _mockDioRequest_should_readTheMethod() {
  test('MockDioRequest should read the method', () {
    final request = MockDioRequest.read(
      _createOptions(baseUrl: _baseUrl, path: _textPath, method: _putMethod),
    );

    expect(request.method, _putMethod);
  });
}

RequestOptions _createOptions({
  required String baseUrl,
  required String path,
  Object? data,
  Map<String, dynamic>? queryParameters,
  Map<String, dynamic>? headers,
  String? method,
}) {
  return RequestOptions(
    baseUrl: baseUrl,
    path: path,
    method: method,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
  );
}
