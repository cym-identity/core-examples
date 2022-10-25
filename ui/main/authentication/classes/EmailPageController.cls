public with sharing class EmailPageController extends AuthPageController {
  public String transactionId { get; private set; }

  public EmailPageController() {
    super();
  }

  public PageReference load() {
    AuthContext context = new AuthContext(this.request);

    // TODO : The user does not have to verify her identity, redirect to the correct authenticator
    AuthContext.Step next = context.next();
    if (next.authenticator?.name != 'email') return context.getNextStep(next, this.startURL);

    if (context.owner.authenticators.indexOf('email') == -1) next.authenticator.provider.initRegistration(context.owner.session, null);
    else this.transactionId = (String) ((Map<String, Object>) next.authenticator.provider.initVerification(context.owner.session, null)).get('transactionId');

    return null;
  }

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String otp = params.get('otp');
    if (String.isBlank(otp)) return null;

    AuthContext context = new AuthContext(this.request);

    AuthContext.Step next = context.next();
    if (next.authenticator.name != 'email') return context.getNextStep(next, this.startURL);

    Map<String, Object> response = (Map<String, Object>) (
      context.owner.authenticators.indexOf('email') == -1 ?
        next.authenticator.provider.verifyRegistration(context.owner.session, new Map<String, Object> { 'otp' => otp }) :
        next.authenticator.provider.verifyVerification(context.owner.session, new Map<String, Object> { 'transactionId' => this.transactionId, 'otp' => otp })
    );

    Boolean isValid = (Boolean) response.get('isValid');

    if (!isValid) return null;

    context.owner.session.apply(next.authenticator, this.request.iid);

    // ReCompute the next step now that the user has verified her email
    next = context.next();

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

  public PageReference resend() {
    return this.load();
  }
}
