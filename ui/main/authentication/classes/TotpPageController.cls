public with sharing class TotpPageController extends AuthPageController {
  public String secretKey { get; private set; }
  public String qrCodeUrl { get; private set; }
  public String mobileUrl { get; private set; }
  public String kind { get; private set; }

  public PageReference load() {
    cym.Community.Authenticator totp = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'totp');
    if (totp == null) return null; // Don't know how the user reached this point

    AuthContext context = new AuthContext(this.request);
    AuthContext.Step next = context.next();

    if (next.authenticator?.name != 'totp') return context.getNextStep(next, this.startURL);

    DEBUG_LOG.put('context', context);
    DEBUG_LOG.put('authenticators', context.idp.authenticators.asObjects());
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

    AuthContext context = new AuthContext(this.request);
    Map<String, Object> response = (Map<String, Object>) (
      context.owner.authenticators.indexOf('totp') == -1 ?
        totp.provider.verifyRegistration(context.owner.session, new Map<String, Object> { 'otp' => otp, 'secret' => this.secretKey }) :
        totp.provider.verifyVerification(context.owner.session, new Map<String, Object> { 'otp' => otp, 'description' => 'User Authentication' })
    );

    Boolean isValid = (Boolean) response.get('isValid');

    if (!isValid) return null;

    context.owner.session.apply(totp, this.request.iid);

    AuthContext.Step next = context.next();

    if ( next.kind == AuthContext.StepKind.REDIRECT ) {
      Boolean isWebAuthnEnabled = Boolean.valueOf(params.get('is-webauthn'));
      if (isWebAuthnEnabled) {
        PageReference pr = new PageReference('/web_authn');
        pr.getParameters().putAll(
          new Map<String, String> {
            'login_hint' => this.request.login_hint,
            'startURL'   => this.startURL,
            'iid'        => this.request.iid
          }
        );
        return pr;
      } else {
        return context.owner.session.resume(this.startURL);
      }
    } else {
      return context.getNextStep(next, this.startURL);
    }

  }
}
