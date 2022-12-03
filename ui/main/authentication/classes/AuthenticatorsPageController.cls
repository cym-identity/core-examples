public with sharing class AuthenticatorsPageController extends AuthPageController {

  public AuthenticatorChoice[] authenticators { get; private set; }
  public String kind { get; private set; }


  public PageReference load() {
    AuthContext context = new AuthContext(this.request, this.level);
    AuthContext.Step step = context.next();

    if (step.kind != AuthContext.StepKind.AUTHENTICATOR_REGISTER && step.kind != AuthContext.StepKind.AUTHENTICATOR_VERIFY) return context.getNextStep(step, this.startURL);
    if (step.authenticator != null) return context.getNextStep(step, this.startURL);
    if (step.steps.pluck('authenticator').unique().size() == 1) return new PageReference(
      new AuthenticatorChoice(
        (cym.Community.Authenticator) context.idp.authenticators.find('id', step.steps.get(0).get('authenticator')),
        context,
        this.startURL
      ).link
    );

    this.kind = step.kind.name().toUpperCase();

    this.authenticators = new AuthenticatorChoice[] {};
    for (cym.Collection.Item item : context.idp.authenticators.filter('id', step.steps.pluck('authenticator').asIds()).asList()) this.authenticators.add(new AuthenticatorChoice((cym.Community.Authenticator) item, context, this.startURL));

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
