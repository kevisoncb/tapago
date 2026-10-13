import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'store_ids.dart';

/// No iPhone o `in_app_purchase_storekit` (StoreKit 2, padrão do pacote) se
/// registra sozinho: a compra volta como transação assinada (JWS).
StoreKind currentStore() =>
    Platform.isIOS || Platform.isMacOS ? StoreKind.appStore : StoreKind.googlePlay;

PurchaseParam buildPurchaseParam(ProductDetails details, {String? userId}) {
  if (currentStore() == StoreKind.appStore) {
    return PurchaseParam(
      productDetails: details,
      applicationUserName: userId == null ? null : appAccountTokenFor(userId),
    );
  }
  if (details is! GooglePlayProductDetails) {
    return PurchaseParam(productDetails: details, applicationUserName: userId);
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
    applicationUserName: userId,
    offerToken: token,
  );
}
