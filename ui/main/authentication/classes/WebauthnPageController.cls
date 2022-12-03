public with sharing class WebauthnPageController extends AuthPageController {
  public String publicKey { get; private set; }
  public String kind { get; private set; }
  public String skip { get; private set; }
  public Boolean auto { get; private set; }
  public WebauthnPageController() {
    this.auto = true;
  }

  public PageReference load() {
    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'webauthn_platform');
    if (webauthn == null) return null; // Don't know how the user reached this point

    AuthContext context = new AuthContext(this.request, this.level);
    AuthContext.Step next = context.next();
    if (next.authenticator?.name != 'webauthn_platform' && next.steps.find('authenticator', webauthn.get('id')) == null) return context.getNextStep(next, this.startURL);

    this.kind = context.owner.authenticators.indexOf('webauthn_platform') == -1 ? 'register' : 'verify';
    this.publicKey = JSON.serialize(
      context.owner.authenticators.indexOf('webauthn_platform') == -1 ?
        webauthn.provider.initRegistration(context.owner.session, new Map<String, Object> {}) :
        webauthn.provider.initVerification(context.owner.session, new Map<String, Object> {})
    );

    if (this.kind == 'register' && next.kind == AuthContext.StepKind.REDIRECT) {
      this.skip = context.owner.session.resume(this.startURL).getURL();
    }

    return null;
  }

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(params.get('payload'));
    Boolean isAlreadyRegistered = Boolean.valueOf(params.get('is-registered'));

    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'webauthn_platform');
    if (webauthn == null) return null; // Don't know how the user reached this point

    AuthContext context = new AuthContext(this.request, this.level);

    // The user has already registered webauthn; but the tracking has been wrong
    if (isAlreadyRegistered && this.kind == 'register') {
      this.publicKey = JSON.serialize(
        webauthn.provider.initVerification(context.owner.session, new Map<String, Object> {})
      );
      this.kind = 'try';
      return null;
    }
    Map<String, Object> response = (Map<String, Object>) (
      context.owner.authenticators.indexOf('webauthn_platform') == -1 && this.kind == 'register' ?
        webauthn.provider.verifyRegistration(context.owner.session, payload) :
        webauthn.provider.verifyVerification(context.owner.session, payload)
    );

    Boolean isValid = (Boolean) response.get('isValid');

    if (!isValid) return null;

    context.owner.session.apply(webauthn, this.request.iid);

    return this.redirect(context);
  }

}
