// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mock_api_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MockApiFailure {

/// Status the answer carries.
 int get statusCode;/// Code that the app reads out of the payload to map the error.
 String? get errorCode;/// Message the payload carries next to [errorCode].
 String? get message;/// Whether the request never reaches the backend, the way a device without
/// a connection fails it.
///
/// Turned on, the request fails with the connection error that the HTTP
/// client raises for a socket that cannot connect. The request does not
/// read [statusCode], [errorCode] and [message].
 bool get isConnectionError;
/// Create a copy of MockApiFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MockApiFailureCopyWith<MockApiFailure> get copyWith => _$MockApiFailureCopyWithImpl<MockApiFailure>(this as MockApiFailure, _$identity);

  /// Serializes this MockApiFailure to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MockApiFailure;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MockApiFailure&&(identical(other.statusCode, _this.statusCode) || other.statusCode == _this.statusCode)&&(identical(other.errorCode, _this.errorCode) || other.errorCode == _this.errorCode)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.isConnectionError, _this.isConnectionError) || other.isConnectionError == _this.isConnectionError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MockApiFailure;
  return Object.hash(runtimeType,_this.statusCode,_this.errorCode,_this.message,_this.isConnectionError);
}

@override
String toString() {
  final _this = this as MockApiFailure;
  return 'MockApiFailure(statusCode: ${_this.statusCode}, errorCode: ${_this.errorCode}, message: ${_this.message}, isConnectionError: ${_this.isConnectionError})';
}


}

/// @nodoc
abstract mixin class $MockApiFailureCopyWith<$Res>  {
  factory $MockApiFailureCopyWith(MockApiFailure value, $Res Function(MockApiFailure) _then) = _$MockApiFailureCopyWithImpl;
@useResult
$Res call({
 int statusCode, String? errorCode, String? message, bool isConnectionError
});




}
/// @nodoc
class _$MockApiFailureCopyWithImpl<$Res>
    implements $MockApiFailureCopyWith<$Res> {
  _$MockApiFailureCopyWithImpl(this._self, this._then);

  final MockApiFailure _self;
  final $Res Function(MockApiFailure) _then;

/// Create a copy of MockApiFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? statusCode = null,Object? errorCode = freezed,Object? message = freezed,Object? isConnectionError = null,}) {
  return _then(MockApiFailure(
statusCode: null == statusCode ? _self.statusCode : statusCode // ignore: cast_nullable_to_non_nullable
as int,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,isConnectionError: null == isConnectionError ? _self.isConnectionError : isConnectionError // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _MockApiFailure implements MockApiFailure {
  const _MockApiFailure({this.statusCode = HttpStatus.internalServerError, this.errorCode, this.message, this.isConnectionError = false});
  factory _MockApiFailure.fromJson(Map<String, dynamic> json) => _$MockApiFailureFromJson(json);

/// Status the answer carries.
@override@JsonKey() final  int statusCode;
/// Code that the app reads out of the payload to map the error.
@override final  String? errorCode;
/// Message the payload carries next to [errorCode].
@override final  String? message;
/// Whether the request never reaches the backend, the way a device without
/// a connection fails it.
///
/// Turned on, the request fails with the connection error that the HTTP
/// client raises for a socket that cannot connect. The request does not
/// read [statusCode], [errorCode] and [message].
@override@JsonKey() final  bool isConnectionError;

/// Create a copy of MockApiFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MockApiFailureCopyWith<_MockApiFailure> get copyWith => __$MockApiFailureCopyWithImpl<_MockApiFailure>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MockApiFailureToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MockApiFailure&&(identical(other.statusCode, statusCode) || other.statusCode == statusCode)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.message, message) || other.message == message)&&(identical(other.isConnectionError, isConnectionError) || other.isConnectionError == isConnectionError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,statusCode,errorCode,message,isConnectionError);
}

@override
String toString() {
    return 'MockApiFailure(statusCode: $statusCode, errorCode: $errorCode, message: $message, isConnectionError: $isConnectionError)';
}


}

/// @nodoc
abstract mixin class _$MockApiFailureCopyWith<$Res> implements $MockApiFailureCopyWith<$Res> {
  factory _$MockApiFailureCopyWith(_MockApiFailure value, $Res Function(_MockApiFailure) _then) = __$MockApiFailureCopyWithImpl;
@override @useResult
$Res call({
 int statusCode, String? errorCode, String? message, bool isConnectionError
});




}
/// @nodoc
class __$MockApiFailureCopyWithImpl<$Res>
    implements _$MockApiFailureCopyWith<$Res> {
  __$MockApiFailureCopyWithImpl(this._self, this._then);

  final _MockApiFailure _self;
  final $Res Function(_MockApiFailure) _then;

/// Create a copy of MockApiFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? statusCode = null,Object? errorCode = freezed,Object? message = freezed,Object? isConnectionError = null,}) {
  return _then(_MockApiFailure(
statusCode: null == statusCode ? _self.statusCode : statusCode // ignore: cast_nullable_to_non_nullable
as int,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,isConnectionError: null == isConnectionError ? _self.isConnectionError : isConnectionError // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
