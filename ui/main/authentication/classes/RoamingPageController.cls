public with sharing class RoamingPageController extends AuthPageController {
  public String publicKey { get; private set; }
  public String kind { get; private set; }
  public String skip { get; private set; }
  public Boolean auto { get; private set; }

  public PageReference load() {
    this.auto = true;
    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    this.logo = context.logo;

    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'webauthn_roaming');
    if (webauthn == null) return null; // Don't know how the user reached this point

    if (!context.isNext(webauthn)) return context.redirect();

    this.kind = context.owner.authenticators.indexOf('webauthn_roaming') == -1 ? 'register' : 'verify';
    this.publicKey = JSON.serialize(
      context.owner.authenticators.indexOf('webauthn_roaming') == -1 ?
        webauthn.provider.initRegistration(context.owner.session, new Map<String, Object> {}) :
        webauthn.provider.initVerification(context.owner.session, new Map<String, Object> {})
    );

    if (this.kind == 'register' && context.isNext(AuthContext.StepKind.REDIRECT)) {
      this.skip = context.owner.session.resume(context.startURL).getURL();
    }

    return null;
  }

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(params.get('payload'));
    Boolean isAlreadyRegistered = Boolean.valueOf(params.get('is-registered'));

    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'webauthn_roaming');
    if (webauthn == null) return null; // Don't know how the user reached this point

    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());

    // The user has already registered webauthn; but the tracking has been wrong
    if (isAlreadyRegistered && this.kind == 'register') {
      this.publicKey = JSON.serialize(
        webauthn.provider.initVerification(context.owner.session, new Map<String, Object> {})
      );
      this.kind = 'try';
      return null;
    }
    Map<String, Object> response = (Map<String, Object>) (
      context.owner.authenticators.indexOf('webauthn_roaming') == -1 && this.kind == 'register' ?
        webauthn.provider.verifyRegistration(context.owner.session, payload) :
        webauthn.provider.verifyVerification(context.owner.session, payload)
    );

    if (!(Boolean) response.get('isValid')) return null;
    return context.apply(webauthn).redirect();
  }

}