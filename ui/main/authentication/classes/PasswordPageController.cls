global with sharing class PasswordPageController extends AuthPageController { // NOPMD.AvoidGlobalModifier
  public String kind { get; private set; }

  public PageReference load() {
    cym.Community.Authenticator password = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'password');
    if (password == null) return null; // Don't know how the user reached this point

    AuthContext context = new AuthContext(this.request, this.level);
    AuthContext.Step next = context.next();
    if (next.authenticator?.name != 'password' && next.steps.find('authenticator', password.get('id')) == null) return context.getNextStep(next, this.startURL);

    this.kind = context.owner.authenticators.indexOf('password') == -1 ? 'register' : 'verify';

    return null;
  }

  public PageReference register() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String new_password = params.get('password');
    String confirm_password = params.get('confirm_password');

    if (new_password != confirm_password) return null;

    cym.Community.Authenticator password = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'password');
    if (password == null) return null; // Don't know how the user reached this point

    AuthContext context = new AuthContext(this.request, this.level);
    AuthContext.Step next = context.next();
    if (next.authenticator?.name != 'password' && next.steps.find('authenticator', password.get('id')) == null) return context.getNextStep(next, this.startURL);

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      context.owner.session.getRemoteApex(PasswordPageController.SetPassword.class).invoke(JSON.serialize(new Map<String, Object> { 'userId' => context.owner.user.Id, 'password' => new_password}))
    );

    if (!(Boolean) response.get('isValid')) return null;

    context.owner.session.apply(password, this.request.iid);

    next = context.next();

    if ( next.kind == AuthContext.StepKind.REDIRECT ) {
      Boolean isWebAuthnEnabled = Boolean.valueOf(params.get('is-webauthn'));
      if (isWebAuthnEnabled && next.authenticator?.name == 'webauth_platform') {
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

  public PageReference verify() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String current_password = params.get('password');

    cym.Community.Authenticator password = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'password');
    if (password == null) return null; // Don't know how the user reached this point

    AuthContext context = new AuthContext(this.request, this.level);
    AuthContext.Step next = context.next();
    if (next.authenticator?.name != 'password' && next.steps.find('authenticator', password.get('id')) == null) return context.getNextStep(next, this.startURL);

    PageReference isValid = Site.login(context.owner.user.Username, current_password, this.startURL);

    if (isValid == null) return null;

    context.owner.session.apply(password, this.request.iid);

    next = context.next();

    if ( next.kind == AuthContext.StepKind.REDIRECT ) {
      Boolean isWebAuthnEnabled = Boolean.valueOf(params.get('is-webauthn'));
      if (isWebAuthnEnabled && next.authenticator?.name == 'webauth_platform') {
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

  global inherited sharing class SetPassword extends cym.Remote.Function {
    global override String execute(String param) {
      Map<String, Object> request = (Map<String, Object>) JSON.deserializeUntyped(param);
      Id userId = (Id) request.get('userId');
      String password = (String) request.get('password');

      System.setPassword(userId, password);

      return JSON.serialize(new Map<String, Object> { 'isValid' => true });
    }
  }
}
