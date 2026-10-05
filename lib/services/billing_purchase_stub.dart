import 'package:in_app_purchase/in_app_purchase.dart';

PurchaseParam buildPurchaseParam(ProductDetails details) {
  return PurchaseParam(productDetails: details);
}
