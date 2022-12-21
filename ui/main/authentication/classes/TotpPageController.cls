public with sharing class TotpPageController extends AuthPageController {
  public String secretKey { get; private set; }
  public String qrCodeUrl { get; private set; }
  public String mobileUrl { get; private set; }
  public String kind { get; private set; }

  public PageReference load() {
    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    this.logo = context.logo;

    cym.Community.Authenticator totp = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'totp');
    if (totp == null) return null; // Don't know how the user reached this point

    if (!context.isNext(totp)) return context.redirect();

    this.kind = context.owner.authenticators.indexOf('totp') == -1 ? 'register' : 'verify';

    if (this.kind == 'register') {
      Map<String, String> registrationParams = (Map<String, String>) totp.provider.initRegistration(context.owner.session, new Map<String, Object> {});
      this.secretKey = registrationParams.get('secret');
      this.qrCodeUrl = registrationParams.get('qrCodeUrl');
      this.mobileUrl = 'otpauth://totp/' + EncodingUtil.urlEncode(context.owner.user.Username, 'UTF-8') + '?secret=' + this.secretKey;
    }

    return null;
  }

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String otp = params.get('otp');

    cym.Community.Authenticator totp = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'totp');
    if (totp == null) return null; // Don't know how the user reached this point

    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    if (!context.isNext(totp)) return context.redirect();

    Map<String, Object> response = (Map<String, Object>) (
      context.owner.authenticators.indexOf('totp') == -1 ?
        totp.provider.verifyRegistration(context.owner.session, new Map<String, Object> { 'otp' => otp, 'secret' => this.secretKey }) :
        totp.provider.verifyVerification(context.owner.session, new Map<String, Object> { 'otp' => otp, 'description' => 'User Authentication' })
    );

    if (!(Boolean) response.get('isValid')) return null;
    return context.apply(totp).redirect();
  }
}
