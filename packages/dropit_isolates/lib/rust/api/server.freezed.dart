// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RsServerEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RsServerEvent()';
}


}

/// @nodoc
class $RsServerEventCopyWith<$Res>  {
$RsServerEventCopyWith(RsServerEvent _, $Res Function(RsServerEvent) __);
}


/// Adds pattern-matching-related methods to [RsServerEvent].
extension RsServerEventPatterns on RsServerEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RsServerEvent_Register value)?  register,TResult Function( RsServerEvent_PrepareUpload value)?  prepareUpload,TResult Function( RsServerEvent_FileUpload value)?  fileUpload,TResult Function( RsServerEvent_SessionEnd value)?  sessionEnd,TResult Function( RsServerEvent_PrepareUploadAborted value)?  prepareUploadAborted,TResult Function( RsServerEvent_CancelReceived value)?  cancelReceived,TResult Function( RsServerEvent_WebPrepareDownload value)?  webPrepareDownload,TResult Function( RsServerEvent_WebFileDownload value)?  webFileDownload,TResult Function( RsServerEvent_Show value)?  show_,TResult Function( RsServerEvent_Chat value)?  chat,TResult Function( RsServerEvent_ListenerFailed value)?  listenerFailed,TResult Function( RsServerEvent_BrowserSessionChanged value)?  browserSessionChanged,TResult Function( RsServerEvent_BrowserSessionClosed value)?  browserSessionClosed,TResult Function( RsServerEvent_BrowserOfferResponse value)?  browserOfferResponse,TResult Function( RsServerEvent_BrowserDownloadRequested value)?  browserDownloadRequested,TResult Function( RsServerEvent_BrowserDownloadProgress value)?  browserDownloadProgress,TResult Function( RsServerEvent_BrowserDownloadFinished value)?  browserDownloadFinished,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RsServerEvent_Register() when register != null:
return register(_that);case RsServerEvent_PrepareUpload() when prepareUpload != null:
return prepareUpload(_that);case RsServerEvent_FileUpload() when fileUpload != null:
return fileUpload(_that);case RsServerEvent_SessionEnd() when sessionEnd != null:
return sessionEnd(_that);case RsServerEvent_PrepareUploadAborted() when prepareUploadAborted != null:
return prepareUploadAborted(_that);case RsServerEvent_CancelReceived() when cancelReceived != null:
return cancelReceived(_that);case RsServerEvent_WebPrepareDownload() when webPrepareDownload != null:
return webPrepareDownload(_that);case RsServerEvent_WebFileDownload() when webFileDownload != null:
return webFileDownload(_that);case RsServerEvent_Show() when show_ != null:
return show_(_that);case RsServerEvent_Chat() when chat != null:
return chat(_that);case RsServerEvent_ListenerFailed() when listenerFailed != null:
return listenerFailed(_that);case RsServerEvent_BrowserSessionChanged() when browserSessionChanged != null:
return browserSessionChanged(_that);case RsServerEvent_BrowserSessionClosed() when browserSessionClosed != null:
return browserSessionClosed(_that);case RsServerEvent_BrowserOfferResponse() when browserOfferResponse != null:
return browserOfferResponse(_that);case RsServerEvent_BrowserDownloadRequested() when browserDownloadRequested != null:
return browserDownloadRequested(_that);case RsServerEvent_BrowserDownloadProgress() when browserDownloadProgress != null:
return browserDownloadProgress(_that);case RsServerEvent_BrowserDownloadFinished() when browserDownloadFinished != null:
return browserDownloadFinished(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RsServerEvent_Register value)  register,required TResult Function( RsServerEvent_PrepareUpload value)  prepareUpload,required TResult Function( RsServerEvent_FileUpload value)  fileUpload,required TResult Function( RsServerEvent_SessionEnd value)  sessionEnd,required TResult Function( RsServerEvent_PrepareUploadAborted value)  prepareUploadAborted,required TResult Function( RsServerEvent_CancelReceived value)  cancelReceived,required TResult Function( RsServerEvent_WebPrepareDownload value)  webPrepareDownload,required TResult Function( RsServerEvent_WebFileDownload value)  webFileDownload,required TResult Function( RsServerEvent_Show value)  show_,required TResult Function( RsServerEvent_Chat value)  chat,required TResult Function( RsServerEvent_ListenerFailed value)  listenerFailed,required TResult Function( RsServerEvent_BrowserSessionChanged value)  browserSessionChanged,required TResult Function( RsServerEvent_BrowserSessionClosed value)  browserSessionClosed,required TResult Function( RsServerEvent_BrowserOfferResponse value)  browserOfferResponse,required TResult Function( RsServerEvent_BrowserDownloadRequested value)  browserDownloadRequested,required TResult Function( RsServerEvent_BrowserDownloadProgress value)  browserDownloadProgress,required TResult Function( RsServerEvent_BrowserDownloadFinished value)  browserDownloadFinished,}){
final _that = this;
switch (_that) {
case RsServerEvent_Register():
return register(_that);case RsServerEvent_PrepareUpload():
return prepareUpload(_that);case RsServerEvent_FileUpload():
return fileUpload(_that);case RsServerEvent_SessionEnd():
return sessionEnd(_that);case RsServerEvent_PrepareUploadAborted():
return prepareUploadAborted(_that);case RsServerEvent_CancelReceived():
return cancelReceived(_that);case RsServerEvent_WebPrepareDownload():
return webPrepareDownload(_that);case RsServerEvent_WebFileDownload():
return webFileDownload(_that);case RsServerEvent_Show():
return show_(_that);case RsServerEvent_Chat():
return chat(_that);case RsServerEvent_ListenerFailed():
return listenerFailed(_that);case RsServerEvent_BrowserSessionChanged():
return browserSessionChanged(_that);case RsServerEvent_BrowserSessionClosed():
return browserSessionClosed(_that);case RsServerEvent_BrowserOfferResponse():
return browserOfferResponse(_that);case RsServerEvent_BrowserDownloadRequested():
return browserDownloadRequested(_that);case RsServerEvent_BrowserDownloadProgress():
return browserDownloadProgress(_that);case RsServerEvent_BrowserDownloadFinished():
return browserDownloadFinished(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RsServerEvent_Register value)?  register,TResult? Function( RsServerEvent_PrepareUpload value)?  prepareUpload,TResult? Function( RsServerEvent_FileUpload value)?  fileUpload,TResult? Function( RsServerEvent_SessionEnd value)?  sessionEnd,TResult? Function( RsServerEvent_PrepareUploadAborted value)?  prepareUploadAborted,TResult? Function( RsServerEvent_CancelReceived value)?  cancelReceived,TResult? Function( RsServerEvent_WebPrepareDownload value)?  webPrepareDownload,TResult? Function( RsServerEvent_WebFileDownload value)?  webFileDownload,TResult? Function( RsServerEvent_Show value)?  show_,TResult? Function( RsServerEvent_Chat value)?  chat,TResult? Function( RsServerEvent_ListenerFailed value)?  listenerFailed,TResult? Function( RsServerEvent_BrowserSessionChanged value)?  browserSessionChanged,TResult? Function( RsServerEvent_BrowserSessionClosed value)?  browserSessionClosed,TResult? Function( RsServerEvent_BrowserOfferResponse value)?  browserOfferResponse,TResult? Function( RsServerEvent_BrowserDownloadRequested value)?  browserDownloadRequested,TResult? Function( RsServerEvent_BrowserDownloadProgress value)?  browserDownloadProgress,TResult? Function( RsServerEvent_BrowserDownloadFinished value)?  browserDownloadFinished,}){
final _that = this;
switch (_that) {
case RsServerEvent_Register() when register != null:
return register(_that);case RsServerEvent_PrepareUpload() when prepareUpload != null:
return prepareUpload(_that);case RsServerEvent_FileUpload() when fileUpload != null:
return fileUpload(_that);case RsServerEvent_SessionEnd() when sessionEnd != null:
return sessionEnd(_that);case RsServerEvent_PrepareUploadAborted() when prepareUploadAborted != null:
return prepareUploadAborted(_that);case RsServerEvent_CancelReceived() when cancelReceived != null:
return cancelReceived(_that);case RsServerEvent_WebPrepareDownload() when webPrepareDownload != null:
return webPrepareDownload(_that);case RsServerEvent_WebFileDownload() when webFileDownload != null:
return webFileDownload(_that);case RsServerEvent_Show() when show_ != null:
return show_(_that);case RsServerEvent_Chat() when chat != null:
return chat(_that);case RsServerEvent_ListenerFailed() when listenerFailed != null:
return listenerFailed(_that);case RsServerEvent_BrowserSessionChanged() when browserSessionChanged != null:
return browserSessionChanged(_that);case RsServerEvent_BrowserSessionClosed() when browserSessionClosed != null:
return browserSessionClosed(_that);case RsServerEvent_BrowserOfferResponse() when browserOfferResponse != null:
return browserOfferResponse(_that);case RsServerEvent_BrowserDownloadRequested() when browserDownloadRequested != null:
return browserDownloadRequested(_that);case RsServerEvent_BrowserDownloadProgress() when browserDownloadProgress != null:
return browserDownloadProgress(_that);case RsServerEvent_BrowserDownloadFinished() when browserDownloadFinished != null:
return browserDownloadFinished(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String ip,  RegisterDtoV2 info)?  register,TResult Function( String sessionId,  String ip,  RegisterDtoV2 info,  String? certFingerprint,  Map<String, FileDto> files)?  prepareUpload,TResult Function( String sessionId,  String fileId,  FileDto file)?  fileUpload,TResult Function( String sessionId,  SessionEndReasonV2 reason)?  sessionEnd,TResult Function( String sessionId)?  prepareUploadAborted,TResult Function( String ip,  String sessionId)?  cancelReceived,TResult Function( String ip,  String sessionId,  String? userAgent)?  webPrepareDownload,TResult Function( String sessionId,  String fileId,  FileDto file)?  webFileDownload,TResult Function( List<String> args)?  show_,TResult Function( String senderFingerprint,  ChatEnvelope envelope)?  chat,TResult Function( String error)?  listenerFailed,TResult Function( String sessionId,  String clientId,  String ip,  String? userAgent,  String browserName,  BrowserDeviceType deviceType,  String platform,  bool connected,  bool ready)?  browserSessionChanged,TResult Function( String sessionId,  BrowserSessionEndReason reason)?  browserSessionClosed,TResult Function( String offerId,  String sessionId,  bool accepted)?  browserOfferResponse,TResult Function( String sessionId,  String offerId,  String fileId,  FileDto file)?  browserDownloadRequested,TResult Function( String sessionId,  String offerId,  String fileId,  BigInt downloadedBytes,  BigInt totalBytes)?  browserDownloadProgress,TResult Function( String sessionId,  String offerId,  String fileId)?  browserDownloadFinished,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RsServerEvent_Register() when register != null:
return register(_that.ip,_that.info);case RsServerEvent_PrepareUpload() when prepareUpload != null:
return prepareUpload(_that.sessionId,_that.ip,_that.info,_that.certFingerprint,_that.files);case RsServerEvent_FileUpload() when fileUpload != null:
return fileUpload(_that.sessionId,_that.fileId,_that.file);case RsServerEvent_SessionEnd() when sessionEnd != null:
return sessionEnd(_that.sessionId,_that.reason);case RsServerEvent_PrepareUploadAborted() when prepareUploadAborted != null:
return prepareUploadAborted(_that.sessionId);case RsServerEvent_CancelReceived() when cancelReceived != null:
return cancelReceived(_that.ip,_that.sessionId);case RsServerEvent_WebPrepareDownload() when webPrepareDownload != null:
return webPrepareDownload(_that.ip,_that.sessionId,_that.userAgent);case RsServerEvent_WebFileDownload() when webFileDownload != null:
return webFileDownload(_that.sessionId,_that.fileId,_that.file);case RsServerEvent_Show() when show_ != null:
return show_(_that.args);case RsServerEvent_Chat() when chat != null:
return chat(_that.senderFingerprint,_that.envelope);case RsServerEvent_ListenerFailed() when listenerFailed != null:
return listenerFailed(_that.error);case RsServerEvent_BrowserSessionChanged() when browserSessionChanged != null:
return browserSessionChanged(_that.sessionId,_that.clientId,_that.ip,_that.userAgent,_that.browserName,_that.deviceType,_that.platform,_that.connected,_that.ready);case RsServerEvent_BrowserSessionClosed() when browserSessionClosed != null:
return browserSessionClosed(_that.sessionId,_that.reason);case RsServerEvent_BrowserOfferResponse() when browserOfferResponse != null:
return browserOfferResponse(_that.offerId,_that.sessionId,_that.accepted);case RsServerEvent_BrowserDownloadRequested() when browserDownloadRequested != null:
return browserDownloadRequested(_that.sessionId,_that.offerId,_that.fileId,_that.file);case RsServerEvent_BrowserDownloadProgress() when browserDownloadProgress != null:
return browserDownloadProgress(_that.sessionId,_that.offerId,_that.fileId,_that.downloadedBytes,_that.totalBytes);case RsServerEvent_BrowserDownloadFinished() when browserDownloadFinished != null:
return browserDownloadFinished(_that.sessionId,_that.offerId,_that.fileId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String ip,  RegisterDtoV2 info)  register,required TResult Function( String sessionId,  String ip,  RegisterDtoV2 info,  String? certFingerprint,  Map<String, FileDto> files)  prepareUpload,required TResult Function( String sessionId,  String fileId,  FileDto file)  fileUpload,required TResult Function( String sessionId,  SessionEndReasonV2 reason)  sessionEnd,required TResult Function( String sessionId)  prepareUploadAborted,required TResult Function( String ip,  String sessionId)  cancelReceived,required TResult Function( String ip,  String sessionId,  String? userAgent)  webPrepareDownload,required TResult Function( String sessionId,  String fileId,  FileDto file)  webFileDownload,required TResult Function( List<String> args)  show_,required TResult Function( String senderFingerprint,  ChatEnvelope envelope)  chat,required TResult Function( String error)  listenerFailed,required TResult Function( String sessionId,  String clientId,  String ip,  String? userAgent,  String browserName,  BrowserDeviceType deviceType,  String platform,  bool connected,  bool ready)  browserSessionChanged,required TResult Function( String sessionId,  BrowserSessionEndReason reason)  browserSessionClosed,required TResult Function( String offerId,  String sessionId,  bool accepted)  browserOfferResponse,required TResult Function( String sessionId,  String offerId,  String fileId,  FileDto file)  browserDownloadRequested,required TResult Function( String sessionId,  String offerId,  String fileId,  BigInt downloadedBytes,  BigInt totalBytes)  browserDownloadProgress,required TResult Function( String sessionId,  String offerId,  String fileId)  browserDownloadFinished,}) {final _that = this;
switch (_that) {
case RsServerEvent_Register():
return register(_that.ip,_that.info);case RsServerEvent_PrepareUpload():
return prepareUpload(_that.sessionId,_that.ip,_that.info,_that.certFingerprint,_that.files);case RsServerEvent_FileUpload():
return fileUpload(_that.sessionId,_that.fileId,_that.file);case RsServerEvent_SessionEnd():
return sessionEnd(_that.sessionId,_that.reason);case RsServerEvent_PrepareUploadAborted():
return prepareUploadAborted(_that.sessionId);case RsServerEvent_CancelReceived():
return cancelReceived(_that.ip,_that.sessionId);case RsServerEvent_WebPrepareDownload():
return webPrepareDownload(_that.ip,_that.sessionId,_that.userAgent);case RsServerEvent_WebFileDownload():
return webFileDownload(_that.sessionId,_that.fileId,_that.file);case RsServerEvent_Show():
return show_(_that.args);case RsServerEvent_Chat():
return chat(_that.senderFingerprint,_that.envelope);case RsServerEvent_ListenerFailed():
return listenerFailed(_that.error);case RsServerEvent_BrowserSessionChanged():
return browserSessionChanged(_that.sessionId,_that.clientId,_that.ip,_that.userAgent,_that.browserName,_that.deviceType,_that.platform,_that.connected,_that.ready);case RsServerEvent_BrowserSessionClosed():
return browserSessionClosed(_that.sessionId,_that.reason);case RsServerEvent_BrowserOfferResponse():
return browserOfferResponse(_that.offerId,_that.sessionId,_that.accepted);case RsServerEvent_BrowserDownloadRequested():
return browserDownloadRequested(_that.sessionId,_that.offerId,_that.fileId,_that.file);case RsServerEvent_BrowserDownloadProgress():
return browserDownloadProgress(_that.sessionId,_that.offerId,_that.fileId,_that.downloadedBytes,_that.totalBytes);case RsServerEvent_BrowserDownloadFinished():
return browserDownloadFinished(_that.sessionId,_that.offerId,_that.fileId);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String ip,  RegisterDtoV2 info)?  register,TResult? Function( String sessionId,  String ip,  RegisterDtoV2 info,  String? certFingerprint,  Map<String, FileDto> files)?  prepareUpload,TResult? Function( String sessionId,  String fileId,  FileDto file)?  fileUpload,TResult? Function( String sessionId,  SessionEndReasonV2 reason)?  sessionEnd,TResult? Function( String sessionId)?  prepareUploadAborted,TResult? Function( String ip,  String sessionId)?  cancelReceived,TResult? Function( String ip,  String sessionId,  String? userAgent)?  webPrepareDownload,TResult? Function( String sessionId,  String fileId,  FileDto file)?  webFileDownload,TResult? Function( List<String> args)?  show_,TResult? Function( String senderFingerprint,  ChatEnvelope envelope)?  chat,TResult? Function( String error)?  listenerFailed,TResult? Function( String sessionId,  String clientId,  String ip,  String? userAgent,  String browserName,  BrowserDeviceType deviceType,  String platform,  bool connected,  bool ready)?  browserSessionChanged,TResult? Function( String sessionId,  BrowserSessionEndReason reason)?  browserSessionClosed,TResult? Function( String offerId,  String sessionId,  bool accepted)?  browserOfferResponse,TResult? Function( String sessionId,  String offerId,  String fileId,  FileDto file)?  browserDownloadRequested,TResult? Function( String sessionId,  String offerId,  String fileId,  BigInt downloadedBytes,  BigInt totalBytes)?  browserDownloadProgress,TResult? Function( String sessionId,  String offerId,  String fileId)?  browserDownloadFinished,}) {final _that = this;
switch (_that) {
case RsServerEvent_Register() when register != null:
return register(_that.ip,_that.info);case RsServerEvent_PrepareUpload() when prepareUpload != null:
return prepareUpload(_that.sessionId,_that.ip,_that.info,_that.certFingerprint,_that.files);case RsServerEvent_FileUpload() when fileUpload != null:
return fileUpload(_that.sessionId,_that.fileId,_that.file);case RsServerEvent_SessionEnd() when sessionEnd != null:
return sessionEnd(_that.sessionId,_that.reason);case RsServerEvent_PrepareUploadAborted() when prepareUploadAborted != null:
return prepareUploadAborted(_that.sessionId);case RsServerEvent_CancelReceived() when cancelReceived != null:
return cancelReceived(_that.ip,_that.sessionId);case RsServerEvent_WebPrepareDownload() when webPrepareDownload != null:
return webPrepareDownload(_that.ip,_that.sessionId,_that.userAgent);case RsServerEvent_WebFileDownload() when webFileDownload != null:
return webFileDownload(_that.sessionId,_that.fileId,_that.file);case RsServerEvent_Show() when show_ != null:
return show_(_that.args);case RsServerEvent_Chat() when chat != null:
return chat(_that.senderFingerprint,_that.envelope);case RsServerEvent_ListenerFailed() when listenerFailed != null:
return listenerFailed(_that.error);case RsServerEvent_BrowserSessionChanged() when browserSessionChanged != null:
return browserSessionChanged(_that.sessionId,_that.clientId,_that.ip,_that.userAgent,_that.browserName,_that.deviceType,_that.platform,_that.connected,_that.ready);case RsServerEvent_BrowserSessionClosed() when browserSessionClosed != null:
return browserSessionClosed(_that.sessionId,_that.reason);case RsServerEvent_BrowserOfferResponse() when browserOfferResponse != null:
return browserOfferResponse(_that.offerId,_that.sessionId,_that.accepted);case RsServerEvent_BrowserDownloadRequested() when browserDownloadRequested != null:
return browserDownloadRequested(_that.sessionId,_that.offerId,_that.fileId,_that.file);case RsServerEvent_BrowserDownloadProgress() when browserDownloadProgress != null:
return browserDownloadProgress(_that.sessionId,_that.offerId,_that.fileId,_that.downloadedBytes,_that.totalBytes);case RsServerEvent_BrowserDownloadFinished() when browserDownloadFinished != null:
return browserDownloadFinished(_that.sessionId,_that.offerId,_that.fileId);case _:
  return null;

}
}

}

/// @nodoc


class RsServerEvent_Register extends RsServerEvent {
  const RsServerEvent_Register({required this.ip, required this.info}): super._();
  

 final  String ip;
 final  RegisterDtoV2 info;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_RegisterCopyWith<RsServerEvent_Register> get copyWith => _$RsServerEvent_RegisterCopyWithImpl<RsServerEvent_Register>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_Register&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.info, info) || other.info == info));
}


@override
int get hashCode => Object.hash(runtimeType,ip,info);

@override
String toString() {
  return 'RsServerEvent.register(ip: $ip, info: $info)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_RegisterCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_RegisterCopyWith(RsServerEvent_Register value, $Res Function(RsServerEvent_Register) _then) = _$RsServerEvent_RegisterCopyWithImpl;
@useResult
$Res call({
 String ip, RegisterDtoV2 info
});




}
/// @nodoc
class _$RsServerEvent_RegisterCopyWithImpl<$Res>
    implements $RsServerEvent_RegisterCopyWith<$Res> {
  _$RsServerEvent_RegisterCopyWithImpl(this._self, this._then);

  final RsServerEvent_Register _self;
  final $Res Function(RsServerEvent_Register) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? info = null,}) {
  return _then(RsServerEvent_Register(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as RegisterDtoV2,
  ));
}


}

/// @nodoc


class RsServerEvent_PrepareUpload extends RsServerEvent {
  const RsServerEvent_PrepareUpload({required this.sessionId, required this.ip, required this.info, this.certFingerprint, required final  Map<String, FileDto> files}): _files = files,super._();
  

/// The session ID the upload session will have when the request is accepted.
 final  String sessionId;
 final  String ip;
 final  RegisterDtoV2 info;
/// The SHA-256 fingerprint (uppercase hex) of the sender's client
/// certificate verified during the mTLS handshake. Unlike
/// `info.fingerprint`, this value cannot be spoofed.
/// `None` when the server runs without TLS.
 final  String? certFingerprint;
 final  Map<String, FileDto> _files;
 Map<String, FileDto> get files {
  if (_files is EqualUnmodifiableMapView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_files);
}


/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_PrepareUploadCopyWith<RsServerEvent_PrepareUpload> get copyWith => _$RsServerEvent_PrepareUploadCopyWithImpl<RsServerEvent_PrepareUpload>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_PrepareUpload&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.info, info) || other.info == info)&&(identical(other.certFingerprint, certFingerprint) || other.certFingerprint == certFingerprint)&&const DeepCollectionEquality().equals(other._files, _files));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,ip,info,certFingerprint,const DeepCollectionEquality().hash(_files));

@override
String toString() {
  return 'RsServerEvent.prepareUpload(sessionId: $sessionId, ip: $ip, info: $info, certFingerprint: $certFingerprint, files: $files)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_PrepareUploadCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_PrepareUploadCopyWith(RsServerEvent_PrepareUpload value, $Res Function(RsServerEvent_PrepareUpload) _then) = _$RsServerEvent_PrepareUploadCopyWithImpl;
@useResult
$Res call({
 String sessionId, String ip, RegisterDtoV2 info, String? certFingerprint, Map<String, FileDto> files
});




}
/// @nodoc
class _$RsServerEvent_PrepareUploadCopyWithImpl<$Res>
    implements $RsServerEvent_PrepareUploadCopyWith<$Res> {
  _$RsServerEvent_PrepareUploadCopyWithImpl(this._self, this._then);

  final RsServerEvent_PrepareUpload _self;
  final $Res Function(RsServerEvent_PrepareUpload) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? ip = null,Object? info = null,Object? certFingerprint = freezed,Object? files = null,}) {
  return _then(RsServerEvent_PrepareUpload(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as RegisterDtoV2,certFingerprint: freezed == certFingerprint ? _self.certFingerprint : certFingerprint // ignore: cast_nullable_to_non_nullable
as String?,files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as Map<String, FileDto>,
  ));
}


}

/// @nodoc


class RsServerEvent_FileUpload extends RsServerEvent {
  const RsServerEvent_FileUpload({required this.sessionId, required this.fileId, required this.file}): super._();
  

 final  String sessionId;
 final  String fileId;
 final  FileDto file;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_FileUploadCopyWith<RsServerEvent_FileUpload> get copyWith => _$RsServerEvent_FileUploadCopyWithImpl<RsServerEvent_FileUpload>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_FileUpload&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.file, file) || other.file == file));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,fileId,file);

@override
String toString() {
  return 'RsServerEvent.fileUpload(sessionId: $sessionId, fileId: $fileId, file: $file)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_FileUploadCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_FileUploadCopyWith(RsServerEvent_FileUpload value, $Res Function(RsServerEvent_FileUpload) _then) = _$RsServerEvent_FileUploadCopyWithImpl;
@useResult
$Res call({
 String sessionId, String fileId, FileDto file
});




}
/// @nodoc
class _$RsServerEvent_FileUploadCopyWithImpl<$Res>
    implements $RsServerEvent_FileUploadCopyWith<$Res> {
  _$RsServerEvent_FileUploadCopyWithImpl(this._self, this._then);

  final RsServerEvent_FileUpload _self;
  final $Res Function(RsServerEvent_FileUpload) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? fileId = null,Object? file = null,}) {
  return _then(RsServerEvent_FileUpload(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as FileDto,
  ));
}


}

/// @nodoc


class RsServerEvent_SessionEnd extends RsServerEvent {
  const RsServerEvent_SessionEnd({required this.sessionId, required this.reason}): super._();
  

 final  String sessionId;
 final  SessionEndReasonV2 reason;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_SessionEndCopyWith<RsServerEvent_SessionEnd> get copyWith => _$RsServerEvent_SessionEndCopyWithImpl<RsServerEvent_SessionEnd>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_SessionEnd&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,reason);

@override
String toString() {
  return 'RsServerEvent.sessionEnd(sessionId: $sessionId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_SessionEndCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_SessionEndCopyWith(RsServerEvent_SessionEnd value, $Res Function(RsServerEvent_SessionEnd) _then) = _$RsServerEvent_SessionEndCopyWithImpl;
@useResult
$Res call({
 String sessionId, SessionEndReasonV2 reason
});




}
/// @nodoc
class _$RsServerEvent_SessionEndCopyWithImpl<$Res>
    implements $RsServerEvent_SessionEndCopyWith<$Res> {
  _$RsServerEvent_SessionEndCopyWithImpl(this._self, this._then);

  final RsServerEvent_SessionEnd _self;
  final $Res Function(RsServerEvent_SessionEnd) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? reason = null,}) {
  return _then(RsServerEvent_SessionEnd(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as SessionEndReasonV2,
  ));
}


}

/// @nodoc


class RsServerEvent_PrepareUploadAborted extends RsServerEvent {
  const RsServerEvent_PrepareUploadAborted({required this.sessionId}): super._();
  

 final  String sessionId;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_PrepareUploadAbortedCopyWith<RsServerEvent_PrepareUploadAborted> get copyWith => _$RsServerEvent_PrepareUploadAbortedCopyWithImpl<RsServerEvent_PrepareUploadAborted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_PrepareUploadAborted&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId);

@override
String toString() {
  return 'RsServerEvent.prepareUploadAborted(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_PrepareUploadAbortedCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_PrepareUploadAbortedCopyWith(RsServerEvent_PrepareUploadAborted value, $Res Function(RsServerEvent_PrepareUploadAborted) _then) = _$RsServerEvent_PrepareUploadAbortedCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$RsServerEvent_PrepareUploadAbortedCopyWithImpl<$Res>
    implements $RsServerEvent_PrepareUploadAbortedCopyWith<$Res> {
  _$RsServerEvent_PrepareUploadAbortedCopyWithImpl(this._self, this._then);

  final RsServerEvent_PrepareUploadAborted _self;
  final $Res Function(RsServerEvent_PrepareUploadAborted) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(RsServerEvent_PrepareUploadAborted(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsServerEvent_CancelReceived extends RsServerEvent {
  const RsServerEvent_CancelReceived({required this.ip, required this.sessionId}): super._();
  

 final  String ip;
 final  String sessionId;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_CancelReceivedCopyWith<RsServerEvent_CancelReceived> get copyWith => _$RsServerEvent_CancelReceivedCopyWithImpl<RsServerEvent_CancelReceived>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_CancelReceived&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}


@override
int get hashCode => Object.hash(runtimeType,ip,sessionId);

@override
String toString() {
  return 'RsServerEvent.cancelReceived(ip: $ip, sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_CancelReceivedCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_CancelReceivedCopyWith(RsServerEvent_CancelReceived value, $Res Function(RsServerEvent_CancelReceived) _then) = _$RsServerEvent_CancelReceivedCopyWithImpl;
@useResult
$Res call({
 String ip, String sessionId
});




}
/// @nodoc
class _$RsServerEvent_CancelReceivedCopyWithImpl<$Res>
    implements $RsServerEvent_CancelReceivedCopyWith<$Res> {
  _$RsServerEvent_CancelReceivedCopyWithImpl(this._self, this._then);

  final RsServerEvent_CancelReceived _self;
  final $Res Function(RsServerEvent_CancelReceived) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? sessionId = null,}) {
  return _then(RsServerEvent_CancelReceived(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsServerEvent_WebPrepareDownload extends RsServerEvent {
  const RsServerEvent_WebPrepareDownload({required this.ip, required this.sessionId, this.userAgent}): super._();
  

 final  String ip;
 final  String sessionId;
 final  String? userAgent;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_WebPrepareDownloadCopyWith<RsServerEvent_WebPrepareDownload> get copyWith => _$RsServerEvent_WebPrepareDownloadCopyWithImpl<RsServerEvent_WebPrepareDownload>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_WebPrepareDownload&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.userAgent, userAgent) || other.userAgent == userAgent));
}


@override
int get hashCode => Object.hash(runtimeType,ip,sessionId,userAgent);

@override
String toString() {
  return 'RsServerEvent.webPrepareDownload(ip: $ip, sessionId: $sessionId, userAgent: $userAgent)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_WebPrepareDownloadCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_WebPrepareDownloadCopyWith(RsServerEvent_WebPrepareDownload value, $Res Function(RsServerEvent_WebPrepareDownload) _then) = _$RsServerEvent_WebPrepareDownloadCopyWithImpl;
@useResult
$Res call({
 String ip, String sessionId, String? userAgent
});




}
/// @nodoc
class _$RsServerEvent_WebPrepareDownloadCopyWithImpl<$Res>
    implements $RsServerEvent_WebPrepareDownloadCopyWith<$Res> {
  _$RsServerEvent_WebPrepareDownloadCopyWithImpl(this._self, this._then);

  final RsServerEvent_WebPrepareDownload _self;
  final $Res Function(RsServerEvent_WebPrepareDownload) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? sessionId = null,Object? userAgent = freezed,}) {
  return _then(RsServerEvent_WebPrepareDownload(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class RsServerEvent_WebFileDownload extends RsServerEvent {
  const RsServerEvent_WebFileDownload({required this.sessionId, required this.fileId, required this.file}): super._();
  

 final  String sessionId;
 final  String fileId;
 final  FileDto file;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_WebFileDownloadCopyWith<RsServerEvent_WebFileDownload> get copyWith => _$RsServerEvent_WebFileDownloadCopyWithImpl<RsServerEvent_WebFileDownload>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_WebFileDownload&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.file, file) || other.file == file));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,fileId,file);

@override
String toString() {
  return 'RsServerEvent.webFileDownload(sessionId: $sessionId, fileId: $fileId, file: $file)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_WebFileDownloadCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_WebFileDownloadCopyWith(RsServerEvent_WebFileDownload value, $Res Function(RsServerEvent_WebFileDownload) _then) = _$RsServerEvent_WebFileDownloadCopyWithImpl;
@useResult
$Res call({
 String sessionId, String fileId, FileDto file
});




}
/// @nodoc
class _$RsServerEvent_WebFileDownloadCopyWithImpl<$Res>
    implements $RsServerEvent_WebFileDownloadCopyWith<$Res> {
  _$RsServerEvent_WebFileDownloadCopyWithImpl(this._self, this._then);

  final RsServerEvent_WebFileDownload _self;
  final $Res Function(RsServerEvent_WebFileDownload) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? fileId = null,Object? file = null,}) {
  return _then(RsServerEvent_WebFileDownload(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as FileDto,
  ));
}


}

/// @nodoc


class RsServerEvent_Show extends RsServerEvent {
  const RsServerEvent_Show({required final  List<String> args}): _args = args,super._();
  

/// Command-line arguments forwarded by the other application instance.
 final  List<String> _args;
/// Command-line arguments forwarded by the other application instance.
 List<String> get args {
  if (_args is EqualUnmodifiableListView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_args);
}


/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_ShowCopyWith<RsServerEvent_Show> get copyWith => _$RsServerEvent_ShowCopyWithImpl<RsServerEvent_Show>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_Show&&const DeepCollectionEquality().equals(other._args, _args));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_args));

@override
String toString() {
  return 'RsServerEvent.show_(args: $args)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_ShowCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_ShowCopyWith(RsServerEvent_Show value, $Res Function(RsServerEvent_Show) _then) = _$RsServerEvent_ShowCopyWithImpl;
@useResult
$Res call({
 List<String> args
});




}
/// @nodoc
class _$RsServerEvent_ShowCopyWithImpl<$Res>
    implements $RsServerEvent_ShowCopyWith<$Res> {
  _$RsServerEvent_ShowCopyWithImpl(this._self, this._then);

  final RsServerEvent_Show _self;
  final $Res Function(RsServerEvent_Show) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? args = null,}) {
  return _then(RsServerEvent_Show(
args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class RsServerEvent_Chat extends RsServerEvent {
  const RsServerEvent_Chat({required this.senderFingerprint, required this.envelope}): super._();
  

 final  String senderFingerprint;
 final  ChatEnvelope envelope;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_ChatCopyWith<RsServerEvent_Chat> get copyWith => _$RsServerEvent_ChatCopyWithImpl<RsServerEvent_Chat>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_Chat&&(identical(other.senderFingerprint, senderFingerprint) || other.senderFingerprint == senderFingerprint)&&(identical(other.envelope, envelope) || other.envelope == envelope));
}


@override
int get hashCode => Object.hash(runtimeType,senderFingerprint,envelope);

@override
String toString() {
  return 'RsServerEvent.chat(senderFingerprint: $senderFingerprint, envelope: $envelope)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_ChatCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_ChatCopyWith(RsServerEvent_Chat value, $Res Function(RsServerEvent_Chat) _then) = _$RsServerEvent_ChatCopyWithImpl;
@useResult
$Res call({
 String senderFingerprint, ChatEnvelope envelope
});




}
/// @nodoc
class _$RsServerEvent_ChatCopyWithImpl<$Res>
    implements $RsServerEvent_ChatCopyWith<$Res> {
  _$RsServerEvent_ChatCopyWithImpl(this._self, this._then);

  final RsServerEvent_Chat _self;
  final $Res Function(RsServerEvent_Chat) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? senderFingerprint = null,Object? envelope = null,}) {
  return _then(RsServerEvent_Chat(
senderFingerprint: null == senderFingerprint ? _self.senderFingerprint : senderFingerprint // ignore: cast_nullable_to_non_nullable
as String,envelope: null == envelope ? _self.envelope : envelope // ignore: cast_nullable_to_non_nullable
as ChatEnvelope,
  ));
}


}

/// @nodoc


class RsServerEvent_ListenerFailed extends RsServerEvent {
  const RsServerEvent_ListenerFailed({required this.error}): super._();
  

/// Description of the failure.
 final  String error;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_ListenerFailedCopyWith<RsServerEvent_ListenerFailed> get copyWith => _$RsServerEvent_ListenerFailedCopyWithImpl<RsServerEvent_ListenerFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_ListenerFailed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'RsServerEvent.listenerFailed(error: $error)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_ListenerFailedCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_ListenerFailedCopyWith(RsServerEvent_ListenerFailed value, $Res Function(RsServerEvent_ListenerFailed) _then) = _$RsServerEvent_ListenerFailedCopyWithImpl;
@useResult
$Res call({
 String error
});




}
/// @nodoc
class _$RsServerEvent_ListenerFailedCopyWithImpl<$Res>
    implements $RsServerEvent_ListenerFailedCopyWith<$Res> {
  _$RsServerEvent_ListenerFailedCopyWithImpl(this._self, this._then);

  final RsServerEvent_ListenerFailed _self;
  final $Res Function(RsServerEvent_ListenerFailed) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(RsServerEvent_ListenerFailed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RsServerEvent_BrowserSessionChanged extends RsServerEvent {
  const RsServerEvent_BrowserSessionChanged({required this.sessionId, required this.clientId, required this.ip, this.userAgent, required this.browserName, required this.deviceType, required this.platform, required this.connected, required this.ready}): super._();
  

 final  String sessionId;
 final  String clientId;
 final  String ip;
 final  String? userAgent;
 final  String browserName;
 final  BrowserDeviceType deviceType;
 final  String platform;
/// Whether heartbeats are being received.
 final  bool connected;
/// Whether the event stream is established and offers can be sent.
 final  bool ready;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_BrowserSessionChangedCopyWith<RsServerEvent_BrowserSessionChanged> get copyWith => _$RsServerEvent_BrowserSessionChangedCopyWithImpl<RsServerEvent_BrowserSessionChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_BrowserSessionChanged&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.userAgent, userAgent) || other.userAgent == userAgent)&&(identical(other.browserName, browserName) || other.browserName == browserName)&&(identical(other.deviceType, deviceType) || other.deviceType == deviceType)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.connected, connected) || other.connected == connected)&&(identical(other.ready, ready) || other.ready == ready));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,clientId,ip,userAgent,browserName,deviceType,platform,connected,ready);

@override
String toString() {
  return 'RsServerEvent.browserSessionChanged(sessionId: $sessionId, clientId: $clientId, ip: $ip, userAgent: $userAgent, browserName: $browserName, deviceType: $deviceType, platform: $platform, connected: $connected, ready: $ready)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_BrowserSessionChangedCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_BrowserSessionChangedCopyWith(RsServerEvent_BrowserSessionChanged value, $Res Function(RsServerEvent_BrowserSessionChanged) _then) = _$RsServerEvent_BrowserSessionChangedCopyWithImpl;
@useResult
$Res call({
 String sessionId, String clientId, String ip, String? userAgent, String browserName, BrowserDeviceType deviceType, String platform, bool connected, bool ready
});




}
/// @nodoc
class _$RsServerEvent_BrowserSessionChangedCopyWithImpl<$Res>
    implements $RsServerEvent_BrowserSessionChangedCopyWith<$Res> {
  _$RsServerEvent_BrowserSessionChangedCopyWithImpl(this._self, this._then);

  final RsServerEvent_BrowserSessionChanged _self;
  final $Res Function(RsServerEvent_BrowserSessionChanged) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? clientId = null,Object? ip = null,Object? userAgent = freezed,Object? browserName = null,Object? deviceType = null,Object? platform = null,Object? connected = null,Object? ready = null,}) {
  return _then(RsServerEvent_BrowserSessionChanged(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,userAgent: freezed == userAgent ? _self.userAgent : userAgent // ignore: cast_nullable_to_non_nullable
as String?,browserName: null == browserName ? _self.browserName : browserName // ignore: cast_nullable_to_non_nullable
as String,deviceType: null == deviceType ? _self.deviceType : deviceType // ignore: cast_nullable_to_non_nullable
as BrowserDeviceType,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as bool,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class RsServerEvent_BrowserSessionClosed extends RsServerEvent {
  const RsServerEvent_BrowserSessionClosed({required this.sessionId, required this.reason}): super._();
  

 final  String sessionId;
 final  BrowserSessionEndReason reason;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_BrowserSessionClosedCopyWith<RsServerEvent_BrowserSessionClosed> get copyWith => _$RsServerEvent_BrowserSessionClosedCopyWithImpl<RsServerEvent_BrowserSessionClosed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_BrowserSessionClosed&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,reason);

@override
String toString() {
  return 'RsServerEvent.browserSessionClosed(sessionId: $sessionId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_BrowserSessionClosedCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_BrowserSessionClosedCopyWith(RsServerEvent_BrowserSessionClosed value, $Res Function(RsServerEvent_BrowserSessionClosed) _then) = _$RsServerEvent_BrowserSessionClosedCopyWithImpl;
@useResult
$Res call({
 String sessionId, BrowserSessionEndReason reason
});




}
/// @nodoc
class _$RsServerEvent_BrowserSessionClosedCopyWithImpl<$Res>
    implements $RsServerEvent_BrowserSessionClosedCopyWith<$Res> {
  _$RsServerEvent_BrowserSessionClosedCopyWithImpl(this._self, this._then);

  final RsServerEvent_BrowserSessionClosed _self;
  final $Res Function(RsServerEvent_BrowserSessionClosed) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? reason = null,}) {
  return _then(RsServerEvent_BrowserSessionClosed(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as BrowserSessionEndReason,
  ));
}


}

/// @nodoc


class RsServerEvent_BrowserOfferResponse extends RsServerEvent {
  const RsServerEvent_BrowserOfferResponse({required this.offerId, required this.sessionId, required this.accepted}): super._();
  

 final  String offerId;
 final  String sessionId;
 final  bool accepted;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_BrowserOfferResponseCopyWith<RsServerEvent_BrowserOfferResponse> get copyWith => _$RsServerEvent_BrowserOfferResponseCopyWithImpl<RsServerEvent_BrowserOfferResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_BrowserOfferResponse&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.accepted, accepted) || other.accepted == accepted));
}


@override
int get hashCode => Object.hash(runtimeType,offerId,sessionId,accepted);

@override
String toString() {
  return 'RsServerEvent.browserOfferResponse(offerId: $offerId, sessionId: $sessionId, accepted: $accepted)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_BrowserOfferResponseCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_BrowserOfferResponseCopyWith(RsServerEvent_BrowserOfferResponse value, $Res Function(RsServerEvent_BrowserOfferResponse) _then) = _$RsServerEvent_BrowserOfferResponseCopyWithImpl;
@useResult
$Res call({
 String offerId, String sessionId, bool accepted
});




}
/// @nodoc
class _$RsServerEvent_BrowserOfferResponseCopyWithImpl<$Res>
    implements $RsServerEvent_BrowserOfferResponseCopyWith<$Res> {
  _$RsServerEvent_BrowserOfferResponseCopyWithImpl(this._self, this._then);

  final RsServerEvent_BrowserOfferResponse _self;
  final $Res Function(RsServerEvent_BrowserOfferResponse) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? offerId = null,Object? sessionId = null,Object? accepted = null,}) {
  return _then(RsServerEvent_BrowserOfferResponse(
offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class RsServerEvent_BrowserDownloadRequested extends RsServerEvent {
  const RsServerEvent_BrowserDownloadRequested({required this.sessionId, required this.offerId, required this.fileId, required this.file}): super._();
  

 final  String sessionId;
 final  String offerId;
 final  String fileId;
 final  FileDto file;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_BrowserDownloadRequestedCopyWith<RsServerEvent_BrowserDownloadRequested> get copyWith => _$RsServerEvent_BrowserDownloadRequestedCopyWithImpl<RsServerEvent_BrowserDownloadRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_BrowserDownloadRequested&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.file, file) || other.file == file));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,offerId,fileId,file);

@override
String toString() {
  return 'RsServerEvent.browserDownloadRequested(sessionId: $sessionId, offerId: $offerId, fileId: $fileId, file: $file)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_BrowserDownloadRequestedCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_BrowserDownloadRequestedCopyWith(RsServerEvent_BrowserDownloadRequested value, $Res Function(RsServerEvent_BrowserDownloadRequested) _then) = _$RsServerEvent_BrowserDownloadRequestedCopyWithImpl;
@useResult
$Res call({
 String sessionId, String offerId, String fileId, FileDto file
});




}
/// @nodoc
class _$RsServerEvent_BrowserDownloadRequestedCopyWithImpl<$Res>
    implements $RsServerEvent_BrowserDownloadRequestedCopyWith<$Res> {
  _$RsServerEvent_BrowserDownloadRequestedCopyWithImpl(this._self, this._then);

  final RsServerEvent_BrowserDownloadRequested _self;
  final $Res Function(RsServerEvent_BrowserDownloadRequested) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? offerId = null,Object? fileId = null,Object? file = null,}) {
  return _then(RsServerEvent_BrowserDownloadRequested(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as FileDto,
  ));
}


}

/// @nodoc


class RsServerEvent_BrowserDownloadProgress extends RsServerEvent {
  const RsServerEvent_BrowserDownloadProgress({required this.sessionId, required this.offerId, required this.fileId, required this.downloadedBytes, required this.totalBytes}): super._();
  

 final  String sessionId;
 final  String offerId;
 final  String fileId;
 final  BigInt downloadedBytes;
 final  BigInt totalBytes;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_BrowserDownloadProgressCopyWith<RsServerEvent_BrowserDownloadProgress> get copyWith => _$RsServerEvent_BrowserDownloadProgressCopyWithImpl<RsServerEvent_BrowserDownloadProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_BrowserDownloadProgress&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.downloadedBytes, downloadedBytes) || other.downloadedBytes == downloadedBytes)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,offerId,fileId,downloadedBytes,totalBytes);

@override
String toString() {
  return 'RsServerEvent.browserDownloadProgress(sessionId: $sessionId, offerId: $offerId, fileId: $fileId, downloadedBytes: $downloadedBytes, totalBytes: $totalBytes)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_BrowserDownloadProgressCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_BrowserDownloadProgressCopyWith(RsServerEvent_BrowserDownloadProgress value, $Res Function(RsServerEvent_BrowserDownloadProgress) _then) = _$RsServerEvent_BrowserDownloadProgressCopyWithImpl;
@useResult
$Res call({
 String sessionId, String offerId, String fileId, BigInt downloadedBytes, BigInt totalBytes
});




}
/// @nodoc
class _$RsServerEvent_BrowserDownloadProgressCopyWithImpl<$Res>
    implements $RsServerEvent_BrowserDownloadProgressCopyWith<$Res> {
  _$RsServerEvent_BrowserDownloadProgressCopyWithImpl(this._self, this._then);

  final RsServerEvent_BrowserDownloadProgress _self;
  final $Res Function(RsServerEvent_BrowserDownloadProgress) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? offerId = null,Object? fileId = null,Object? downloadedBytes = null,Object? totalBytes = null,}) {
  return _then(RsServerEvent_BrowserDownloadProgress(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,downloadedBytes: null == downloadedBytes ? _self.downloadedBytes : downloadedBytes // ignore: cast_nullable_to_non_nullable
as BigInt,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class RsServerEvent_BrowserDownloadFinished extends RsServerEvent {
  const RsServerEvent_BrowserDownloadFinished({required this.sessionId, required this.offerId, required this.fileId}): super._();
  

 final  String sessionId;
 final  String offerId;
 final  String fileId;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RsServerEvent_BrowserDownloadFinishedCopyWith<RsServerEvent_BrowserDownloadFinished> get copyWith => _$RsServerEvent_BrowserDownloadFinishedCopyWithImpl<RsServerEvent_BrowserDownloadFinished>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RsServerEvent_BrowserDownloadFinished&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.fileId, fileId) || other.fileId == fileId));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,offerId,fileId);

@override
String toString() {
  return 'RsServerEvent.browserDownloadFinished(sessionId: $sessionId, offerId: $offerId, fileId: $fileId)';
}


}

/// @nodoc
abstract mixin class $RsServerEvent_BrowserDownloadFinishedCopyWith<$Res> implements $RsServerEventCopyWith<$Res> {
  factory $RsServerEvent_BrowserDownloadFinishedCopyWith(RsServerEvent_BrowserDownloadFinished value, $Res Function(RsServerEvent_BrowserDownloadFinished) _then) = _$RsServerEvent_BrowserDownloadFinishedCopyWithImpl;
@useResult
$Res call({
 String sessionId, String offerId, String fileId
});




}
/// @nodoc
class _$RsServerEvent_BrowserDownloadFinishedCopyWithImpl<$Res>
    implements $RsServerEvent_BrowserDownloadFinishedCopyWith<$Res> {
  _$RsServerEvent_BrowserDownloadFinishedCopyWithImpl(this._self, this._then);

  final RsServerEvent_BrowserDownloadFinished _self;
  final $Res Function(RsServerEvent_BrowserDownloadFinished) _then;

/// Create a copy of RsServerEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? offerId = null,Object? fileId = null,}) {
  return _then(RsServerEvent_BrowserDownloadFinished(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
