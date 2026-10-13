import 'package:uuid/uuid.dart';

import '../utils/constants.dart';

enum StoreKind { googlePlay, appStore }

extension StoreKindInfo on StoreKind {
  String get premiumProductId => this == StoreKind.appStore
      ? AppConstants.premiumProductIdIos
      : AppConstants.premiumProductId;

  String get label => this == StoreKind.appStore ? 'App Store' : 'Google Play';

  String get cancelHint => this == StoreKind.appStore
      ? 'Cancele quando quiser nos Ajustes do iPhone'
      : 'Cancele quando quiser na Google Play';

  String get manageHint => this == StoreKind.appStore
      ? 'Ajustes → seu nome → Assinaturas'
      : 'Play Store → Pagamentos e assinaturas';
}

/// Aviso de renovação automática exigido no paywall (App Store 3.1.2).
String premiumRenewalNotice(StoreKind store, String price) {
  final account = store == StoreKind.appStore ? 'conta Apple' : 'conta Google';
  return 'Assinatura mensal de $price com renovação automática. O valor é cobrado '
      'na sua $account ao confirmar a compra e renova todo mês pelo mesmo valor, '
      'a menos que você cancele até 24 horas antes do fim do período. '
      'Gerencie ou cancele em ${store.manageHint}.';
}

bool isPremiumProductId(String id) =>
    id == AppConstants.premiumProductId || id == AppConstants.premiumProductIdIos;

/// O StoreKit 2 só aceita UUID em `appAccountToken`. O UUID v5 do uid é
/// sempre o mesmo, então o servidor recalcula e confere de quem é a compra.
String appAccountTokenFor(String uid) =>
    const Uuid().v5(Namespace.url.value, 'https://usepago.app/uid/$uid');
