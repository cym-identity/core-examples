public with sharing class AuthenticatorsPageController extends AuthPageController {

  public AuthenticatorChoice[] authenticators { get; private set; }
  public String kind { get; private set; }


  public PageReference load() {
    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    this.logo = context.logo;

    if (! context.isNext(new AuthContext.StepKind[] {AuthContext.StepKind.AUTHENTICATOR_REGISTER, AuthContext.StepKind.AUTHENTICATOR_VERIFY})) return context.redirect();

    if (context.next.authenticators.size() == 1) return new PageReference(
      new AuthenticatorChoice(
        (cym.Community.Authenticator) context.next.authenticators.get(0),
        context,
        context.startURL
      ).link
    );

    this.kind = context.isNext(AuthContext.StepKind.AUTHENTICATOR_REGISTER) ? 'register' : 'verify';

    this.authenticators = new AuthenticatorChoice[] {};
    for (cym.Collection.Item item : context.next.authenticators.asList()) this.authenticators.add(new AuthenticatorChoice((cym.Community.Authenticator) item, context, context.startURL));

    return null;
  }

  public class AuthenticatorChoice {
    public String display { get; private set; }
    public String authenticator { get; private set; }
    public String link { get; private set; }
    public AuthenticatorChoice(cym.Community.Authenticator authenticator, AuthContext context, String startURL) {
      this.authenticator = authenticator.name;
      PageReference pr = AuthContext.getAuthenticatorPageReference(authenticator);
      pr.getParameters().putAll(new Map<String, String> {
        'iid' => context.request.iid,
        'startURL' => startURL,
        'login_hint' => context.request.login_hint
      });
      this.link = pr.getUrl();
    }
  }


}
