public with sharing class EmailPageController extends AuthPageController {
  public String transactionId { get; private set; }

  public EmailPageController() {
    super();
  }

  public PageReference load() {
    AuthContext context = new AuthContext(this.request, this.level);

    // TODO : The user does not have to verify her identity, redirect to the correct authenticator
    AuthContext.Step next = context.next();
    cym.Community.Authenticator email = (cym.Community.Authenticator) context.idp.authenticators.find('name', 'email');
    if (next.authenticator?.name != 'email' && next.steps.find('authenticator', email.get('id')) == null) return context.getNextStep(next, this.startURL);

    if (context.owner.authenticators.indexOf('email') == -1) email.provider.initRegistration(context.owner.session, null);
    else this.transactionId = (String) ((Map<String, Object>) email.provider.initVerification(context.owner.session, null)).get('transactionId');

    return null;
  }

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String otp = params.get('otp');
    if (String.isBlank(otp)) return null;

    AuthContext context = new AuthContext(this.request, this.level);

    AuthContext.Step next = context.next();
    cym.Community.Authenticator email = (cym.Community.Authenticator) context.idp.authenticators.find('name', 'email');
    if (next.authenticator?.name != 'email' && next.steps.find('authenticator', email.get('id')) == null) return context.getNextStep(next, this.startURL);

    Map<String, Object> response = (Map<String, Object>) (
      context.owner.authenticators.indexOf('email') == -1 ?
        email.provider.verifyRegistration(context.owner.session, new Map<String, Object> { 'otp' => otp }) :
        email.provider.verifyVerification(context.owner.session, new Map<String, Object> { 'transactionId' => this.transactionId, 'otp' => otp })
    );

    Boolean isValid = (Boolean) response.get('isValid');

    if (!isValid) return null;

    context.owner.session.apply(email, this.request.iid);
    if (context.owner.authenticators.indexOf('email') == -1) context.owner.authenticators.add('email');

    return this.redirect(context);
  }

  public PageReference resend() {
    return this.load();
  }
}
