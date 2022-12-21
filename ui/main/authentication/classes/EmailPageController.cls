public with sharing class EmailPageController extends AuthPageController {
  public String transactionId { get; private set; }

  public PageReference load() {
    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    this.logo = context.logo;

    // TODO : The user does not have to verify her identity, redirect to the correct authenticator
    cym.Community.Authenticator email = (cym.Community.Authenticator) context.community.authenticators.find('name', 'email');
    if (!context.isNext(email)) return context.redirect();

    if (context.isNext(new AuthContext.StepKind[] {AuthContext.StepKind.AUTHENTICATOR_REGISTER, AuthContext.StepKind.IDENTITY_VERIFY})) email.provider.initRegistration(context.owner.session, null);
    else this.transactionId = (String) ((Map<String, Object>) email.provider.initVerification(context.owner.session, null)).get('transactionId');

    return null;
  }

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String otp = params.get('otp');
    if (String.isBlank(otp)) return null;

    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    cym.Community.Authenticator email = (cym.Community.Authenticator) context.community.authenticators.find('name', 'email');
    if (!context.isNext(email)) return context.redirect();

    Map<String, Object> response = (Map<String, Object>) (
      context.isNext(new AuthContext.StepKind[] {AuthContext.StepKind.AUTHENTICATOR_REGISTER, AuthContext.StepKind.IDENTITY_VERIFY}) ?
        email.provider.verifyRegistration(context.owner.session, new Map<String, Object> { 'otp' => otp }) :
        email.provider.verifyVerification(context.owner.session, new Map<String, Object> { 'transactionId' => this.transactionId, 'otp' => otp })
    );

    if (!(Boolean) response.get('isValid')) return null;
    return context.apply(email).redirect();
  }

  public PageReference resend() {
    return this.load();
  }
}
