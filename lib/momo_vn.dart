import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:eventify/eventify.dart';
import 'dart:convert' as convert;

class MomoVn {
  // Response codes from platform
  static const _CODE_PAYMENT_SUCCESS = 0; //User xác nhận thanh toán thành công
  static const _CODE_PAYMENT_TIMEOUT =
      5; // Hết thời gian thực hiện giao dịch (Timeout transaction)
  static const _CODE_PAYMENT_CANCEL = 6; // Người dùng huỷ thanh toán
  static const _CODE_PAYMENT_ERROR = 7; // Lỗi Không xác định

  // Event names
  static const EVENT_PAYMENT_SUCCESS = 'payment.success';
  static const EVENT_PAYMENT_ERROR = 'payment.error';

  static const MethodChannel _channel = const MethodChannel('momo_vn');

  late EventEmitter _eventEmitter;

  MomoVn() {
    _eventEmitter = new EventEmitter();
  }

  /// Opens checkout
  void open(MomoPaymentInfo options) async {
    PaymentResponse validationResult = _validateOptions(options);
    if (!validationResult.isSuccess!) {
      _handleResult({'type': _CODE_PAYMENT_ERROR, 'data': validationResult});
      return;
    }
    var response = await _channel.invokeMethod('open', options.toJson());
    _handleResult({'data': response, 'type': response['status']});
  }

  /// Handles checkout response from platform
  void _handleResult(Map<dynamic, dynamic> response) {
    String eventName;
    dynamic payload;
    payload = PaymentResponse.fromMap(response['data']);
    switch (response['type']) {
      case _CODE_PAYMENT_SUCCESS:
        eventName = EVENT_PAYMENT_SUCCESS;
        break;
      case _CODE_PAYMENT_TIMEOUT:
      case _CODE_PAYMENT_CANCEL:
        eventName = EVENT_PAYMENT_ERROR;
        break;
      default:
        eventName = EVENT_PAYMENT_ERROR;
        payload = PaymentResponse(
            false, _CODE_PAYMENT_ERROR, '', '', 'Lỗi không xác định', '', '');
    }
    _eventEmitter.emit(eventName, null, payload);
  }

  void on(String event, Function handler) {
    EventCallback cb = (event, cont) {
      handler(event.eventData);
    };
    _eventEmitter.on(event, null, cb);
  }

  void clear() {
    _eventEmitter.clear();
  }

  /// Validate payment options
  static PaymentResponse _validateOptions(MomoPaymentInfo options) {
    bool error = false;
    String mes = '';
    if (options.merchantCode == null) {
      mes =
          'merchantcode is required. Please check if key is present in options.';
      error = true;
    }
    if (options.merchantName.isEmpty) {
      mes =
          'merchantcode is required. Please check if key is present in options.';
      error = true;
    }
    if (options.partner.isEmpty) {
      mes =
          'merchantcode is required. Please check if key is present in options.';
      error = true;
    }
    if (Platform.isIOS && (options.appScheme.isEmpty)) {
      mes = 'appScheme is required. Please check if key is present in options.';
      error = true;
    }
    if (options.amount < 0) {
      mes = 'amount is required. Please check if key is present in options.';
      error = true;
    }
    if (options.description == null || options.description!.isEmpty) {
      mes =
          'description is required. Please check if key is present in options.';
      error = true;
    }
    return error
        ? PaymentResponse(false, _CODE_PAYMENT_ERROR, '', '', mes, '', '')
        : PaymentResponse(true, _CODE_PAYMENT_SUCCESS, '', '', '', '', '');
  }
}

class PaymentResponse {
  bool? isSuccess;
  int status;
  String? token;
  String? phoneNumber;
  String? data;
  String? message;
  String? extra;

  PaymentResponse(this.isSuccess, this.status, this.token, this.phoneNumber,
      this.message, this.data, this.extra);

  static PaymentResponse fromMap(Map<dynamic, dynamic> map) {
    bool? isSuccess = map["isSuccess"];
    int status = int.parse(map['status'].toString());
    String? token = map["token"];
    String? phoneNumber = map["phoneNumber"];
    String? data = map["data"];
    String? message = map["message"];
    String? extra = "";
    extra = map["extra"];
    return new PaymentResponse(
        isSuccess, status, token, phoneNumber, data, message, extra);
  }
}

class MomoPaymentInfo {
  String appScheme; //partnerSchemeId đối tác lấy tại from business.momo.vn
  String merchantName; //Tên đối tác. được đăng ký tại https://business.momo.vn. VD: Google, Apple, Tiki , CGV Cinemas
  String merchantCode; //Mã đối tác, được cung cấp bởi MoMo tại https://business.momo.vn
  String partnerCode;
  String merchantNameLabel; //Nhãn tên đối tác
  int amount; //Số tiền thanh toán, kiểu integer
  int fee; //Phí dịch vụ nếu có, Kiểu integer
  String? description; //Mô tả đơn hàng - short description
  String? extra; //json string - that should be more bill extra info
  String? username; //user id/user identify/user email
  String orderId; //uniqueue id cho Bill order, giá trị duy nhất cho mỗi đơn hàng
  String orderLabel; //gán nhãn
  bool isTestMode; //bật chế độ test/bật chế độ test

  MomoPaymentInfo({
    required this.appScheme,
    required this.merchantName,
    required this.merchantCode,
    required this.partnerCode,
    required this.amount,
    required this.orderId,
    required this.orderLabel,
    required this.merchantNameLabel,
    required this.fee,
    this.description,
    this.username,
    this.extra,
    this.isTestMode = false,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      "merchantname": this.merchantName,
      "merchantcode": this.merchantCode,
      "partnercode": this.partnerCode,
      "amount": this.amount,
      "orderid": this.orderId,
      "orderlabel": this.orderLabel,
      "fee": this.fee,
      "isTestMode": isTestMode,
      "merchantnamelabel": merchantNameLabel
    };
    if (Platform.isIOS) {
      json["appScheme"] = appScheme;
    }
    if (description != null) {
      json["description"] = description;
    }
    if (username != null) {
      json["username"] = username;
    }
    if (extra != null) {
      json["extra"] = extra;
    }
    return json;
  }
}
