// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mock_api_failure.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MockApiFailure _$MockApiFailureFromJson(Map<String, dynamic> json) =>
    _MockApiFailure(
      statusCode:
          (json['statusCode'] as num?)?.toInt() ??
          HttpStatus.internalServerError,
      errorCode: json['errorCode'] as String?,
      message: json['message'] as String?,
      isConnectionError: json['isConnectionError'] as bool? ?? false,
    );

Map<String, dynamic> _$MockApiFailureToJson(_MockApiFailure instance) =>
    <String, dynamic>{
      'statusCode': instance.statusCode,
      'errorCode': ?instance.errorCode,
      'message': ?instance.message,
      'isConnectionError': instance.isConnectionError,
    };
