import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_automation_mock/src/contract/mock_api_request.dart';

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
  group('MockApiRequest Tests', () {
    _mockApiRequest_should_readThePathRelativeToTheBaseUrl();
    _mockApiRequest_should_keepThePathWhenTheBaseUrlHasNoPath();
    _mockApiRequest_should_readTheTrailingId();
    _mockApiRequest_should_leaveThePathIdNullWithoutATrailingNumber();
    _mockApiRequest_should_readAMapBody();
    _mockApiRequest_should_leaveTheBodyEmptyWithoutAMapPayload();
    _mockApiRequest_should_readTheQueryParameters();
    _mockApiRequest_should_leaveTheQueryParametersEmptyWithoutAQuery();
    _mockApiRequest_should_readAStringTrailingSegment();
    _mockApiRequest_should_readTheFullPathOfAnAbsoluteUrl();
    _mockApiRequest_should_readTheQueryWrittenIntoTheUrl();
    _mockApiRequest_should_keepTheBytesItIsGiven();
    _mockApiRequest_should_readTheAcceptLanguageHeader();
    _mockApiRequest_should_leaveTheAcceptLanguageNullWithoutTheHeader();
    _mockApiRequest_should_readTheMethod();
  });
}

void _mockApiRequest_should_readThePathRelativeToTheBaseUrl() {
  test('MockApiRequest should read the path relative to the base url', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(baseUrl: _baseUrl, path: _textPath),
    );

    expect(request.path, _textPath);
  });
}

void _mockApiRequest_should_keepThePathWhenTheBaseUrlHasNoPath() {
  test('MockApiRequest should keep the path when the base url has no path', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(baseUrl: _rootBaseUrl, path: _textPath),
    );

    expect(request.path, _textPath);
  });
}

void _mockApiRequest_should_readTheTrailingId() {
  test('MockApiRequest should read the trailing id', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(baseUrl: _baseUrl, path: '$_endpointPath/$_itemId'),
    );

    expect(request.pathId, _itemId);
  });
}

void _mockApiRequest_should_leaveThePathIdNullWithoutATrailingNumber() {
  test(
    'MockApiRequest should leave the path id null without a trailing number',
    () {
      final request = MockApiRequest.fromOptions(
        _createOptions(baseUrl: _baseUrl, path: _endpointPath),
      );

      expect(request.pathId, isNull);
    },
  );
}

void _mockApiRequest_should_readAMapBody() {
  test('MockApiRequest should read a map body', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(
        baseUrl: _baseUrl,
        path: _endpointPath,
        data: const {_bodyKey: _bodyValue},
      ),
    );

    expect(request.body[_bodyKey], _bodyValue);
  });
}

void _mockApiRequest_should_leaveTheBodyEmptyWithoutAMapPayload() {
  test('MockApiRequest should leave the body empty without a map payload', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(baseUrl: _baseUrl, path: _endpointPath, data: _bodyValue),
    );

    expect(request.body, isEmpty);
  });
}

void _mockApiRequest_should_readTheQueryParameters() {
  test('MockApiRequest should read the query parameters', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(
        baseUrl: _baseUrl,
        path: _endpointPath,
        queryParameters: const {_queryKey: _queryValue},
      ),
    );

    expect(request.queryParameters[_queryKey], _queryValue);
  });
}

void _mockApiRequest_should_leaveTheQueryParametersEmptyWithoutAQuery() {
  test(
    'MockApiRequest should leave the query parameters empty without a query',
    () {
      final request = MockApiRequest.fromOptions(
        _createOptions(baseUrl: _baseUrl, path: _endpointPath),
      );

      expect(request.queryParameters, isEmpty);
    },
  );
}

void _mockApiRequest_should_readAStringTrailingSegment() {
  test('MockApiRequest should read a string trailing segment', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(baseUrl: _baseUrl, path: '$_endpointPath/$_attachmentId'),
    );

    expect(request.pathSegment, _attachmentId);
    expect(request.pathId, isNull);
  });
}

void _mockApiRequest_should_readTheFullPathOfAnAbsoluteUrl() {
  test('MockApiRequest should read the full path of an absolute url', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(baseUrl: '', path: _fileUrl),
    );

    expect(request.path, '/file-attachment/original/$_attachmentId');
  });
}

void _mockApiRequest_should_readTheQueryWrittenIntoTheUrl() {
  test('MockApiRequest should read the query written into the url', () {
    final request = MockApiRequest.fromOptions(
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

void _mockApiRequest_should_keepTheBytesItIsGiven() {
  test('MockApiRequest should keep the bytes it is given', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(baseUrl: '', path: _fileUrl, data: _bytes),
      bytes: _bytes,
    );

    expect(request.bytes, _bytes);
    expect(request.body, isEmpty);
  });
}

void _mockApiRequest_should_readTheAcceptLanguageHeader() {
  test('MockApiRequest should read the accept language header', () {
    final request = MockApiRequest.fromOptions(
      _createOptions(
        baseUrl: _baseUrl,
        path: _textPath,
        headers: {'Accept-Language': _acceptLanguage},
      ),
    );

    expect(request.acceptLanguage, _acceptLanguage);
  });
}

void _mockApiRequest_should_leaveTheAcceptLanguageNullWithoutTheHeader() {
  test(
    'MockApiRequest should leave the accept language null without the header',
    () {
      final request = MockApiRequest.fromOptions(
        _createOptions(baseUrl: _baseUrl, path: _textPath),
      );

      expect(request.acceptLanguage, isNull);
    },
  );
}

void _mockApiRequest_should_readTheMethod() {
  test('MockApiRequest should read the method', () {
    final request = MockApiRequest.fromOptions(
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
