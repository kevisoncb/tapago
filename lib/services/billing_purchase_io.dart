import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

PurchaseParam buildPurchaseParam(ProductDetails details) {
  if (!Platform.isAndroid || details is! GooglePlayProductDetails) {
    return PurchaseParam(productDetails: details);
  }
  final offers = details.productDetails.subscriptionOfferDetails;
  final index = details.subscriptionIndex;
  final String? token;
  if (offers == null || offers.isEmpty) {
    token = null;
  } else if (index != null && index >= 0 && index < offers.length) {
    token = offers[index].offerIdToken;
  } else {
    token = offers.first.offerIdToken;
  }
  return GooglePlayPurchaseParam(
    productDetails: details,
    offerToken: token,
  );
}
