global with sharing class PasswordPageController extends AuthPageController { // NOPMD.AvoidGlobalModifier
  public String kind { get; private set; }

  public PageReference load() {
    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    this.logo = context.logo;

    cym.Community.Authenticator password = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'password');
    if (password == null) return null; // Don't know how the user reached this point

    if (!context.isNext(password)) return context.redirect();

    this.kind = context.isNext(AuthContext.StepKind.AUTHENTICATOR_REGISTER) ? 'register' : 'verify';

    return null;
  }

  public PageReference register() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String new_password = params.get('password');
    String confirm_password = params.get('confirm_password');

    if (new_password != confirm_password) return null;

    cym.Community.Authenticator password = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'password');
    if (password == null) return null; // Don't know how the user reached this point

    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    if (!context.isNext(password)) return context.redirect();

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      context.owner.session.getRemoteApex(PasswordPageController.SetPassword.class).invoke(JSON.serialize(new Map<String, Object> { 'userId' => context.owner.user.Id, 'password' => new_password}))
    );

    if (!(Boolean) response.get('isValid')) return null;

    context.apply(password);

    return context.redirect();
  }

  public PageReference verify() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String current_password = params.get('password');

    cym.Community.Authenticator password = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'password');
    if (password == null) return null; // Don't know how the user reached this point

    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    if (!context.isNext(password)) return context.redirect();

    if (Site.login(context.owner.user.Username, current_password, context.startURL) == null) return null;
    return context.apply(password).redirect();
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
