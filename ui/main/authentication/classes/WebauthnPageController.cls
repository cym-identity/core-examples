public with sharing class WebauthnPageController extends AuthPageController {
  public String publicKey { get; private set; }
  public String kind { get; private set; }
  public WebauthnPageController() {}

  public PageReference load() {
    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'webauthn_platform');
    if (webauthn == null) return null; // Don't know how the user reached this point

    AuthContext context = new AuthContext(this.request);
    AuthContext.Step next = context.next();

    if (next.authenticator?.name != 'webauthn_platform') return context.getNextStep(next, this.startURL);

    this.kind = context.owner.authenticators.indexOf('webauthn_platform') == -1 ? 'register' : 'verify';
    this.publicKey = JSON.serialize(
      context.owner.authenticators.indexOf('webauthn_platform') == -1 ?
        webauthn.provider.initRegistration(context.owner.session, new Map<String, Object> {}) :
        webauthn.provider.initVerification(context.owner.session, new Map<String, Object> {})
    );

    return null;
  }

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(params.get('payload'));

    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'webauthn_platform');
    if (webauthn == null) return null; // Don't know how the user reached this point

    AuthContext context = new AuthContext(this.request);
    Map<String, Object> response = (Map<String, Object>) (
      context.owner.authenticators.indexOf('webauthn_platform') == -1 ?
        webauthn.provider.verifyRegistration(context.owner.session, payload) :
        webauthn.provider.verifyVerification(context.owner.session, payload)
    );

    Boolean isValid = (Boolean) response.get('isValid');

    if (!isValid) return null;

    context.owner.session.apply(webauthn, this.request.iid);

    AuthContext.Step next = context.next();

    if ( next.kind == AuthContext.StepKind.REDIRECT ) {
      return context.owner.session.resume(this.startURL);
    } else {
      return context.getNextStep(next, this.startURL);
    }
  }

}
