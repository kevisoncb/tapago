class AppConstants {
  static const appName = 'Pagô';
  static const tagline = 'E aí, pagô?';
  static const versionLabel = 'Pagô v2.4.0';
  static const logoAsset = 'assets/brand/pago-icon.jpg';
  static const premiumPrice = 39.90;
  static const premiumPriceLabel = r'R$ 39,90';
  static const siteOrigin = 'https://usepago.app';
  static const checkoutUrl =
      'https://play.google.com/store/apps/details?id=app.usepago';
  static const premiumProductId = 'pago_premium_monthly';
  static const apiBase = String.fromEnvironment(
    'PAGO_API_BASE',
    defaultValue: 'https://tapago-ae948.web.app/api',
  );
  static const asaasApiBase = String.fromEnvironment(
    'ASAAS_API_BASE',
    defaultValue: 'https://tapago-ae948.web.app/api',
  );
  static const termsUrl = '$siteOrigin/termos';
  static const privacyUrl = '$siteOrigin/privacidade';
  static const lgpdUrl = '$siteOrigin/lgpd';
  static const supportWhatsApp = '5527999019162';
  static const helpUrl =
      'https://wa.me/$supportWhatsApp?text=Oi%2C%20vim%20pelo%20Pag%C3%B4%20e%20quero%20tirar%20uma%20d%C3%BAvida.';
  static const demoUserId = 'user_joao_dinamico';
  static const demoBuild = bool.fromEnvironment('PAGO_DEMO');
}
