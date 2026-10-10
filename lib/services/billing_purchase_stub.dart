import 'package:in_app_purchase/in_app_purchase.dart';

PurchaseParam buildPurchaseParam(ProductDetails details, {String? userId}) {
  return PurchaseParam(productDetails: details, applicationUserName: userId);
}
