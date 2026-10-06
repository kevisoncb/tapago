class AppConstants {
  static const appName = 'TáPago';
  static const versionLabel = 'TáPago v2.4.0';
  static const logoAsset = 'assets/brand/tapago-icon.jpg';
  static const premiumPrice = 39.90;
  static const premiumPriceLabel = r'R$ 39,90';
  static const siteOrigin = 'https://tapago-ae948.web.app';
  static const checkoutUrl =
      'https://play.google.com/store/apps/details?id=com.tapago.tapago_app';
  static const premiumProductId = 'tapago_premium_monthly';
  static const apiBase = String.fromEnvironment(
    'TAPAGO_API_BASE',
    defaultValue: 'https://tapago-ae948.web.app/api',
  );
  static const asaasApiBase = String.fromEnvironment(
    'ASAAS_API_BASE',
    defaultValue: 'https://tapago-ae948.web.app/api',
  );
  static const termsUrl = '$siteOrigin/termos';
  static const privacyUrl = '$siteOrigin/privacidade';
  static const lgpdUrl = '$siteOrigin/lgpd';
  static const helpUrl = siteOrigin;
  static const demoUserId = 'user_joao_dinamico';
}
