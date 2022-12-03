public with sharing class AuthContext {
  public RessourceOwner owner { get; private set; }
  public cym.Community idp { get; private set; }
  public cym.Authentication.Request request { get; private set; }
  public cym.Authentication.Level level { get; private set; }

  public AuthContext(cym.Authentication.Request request, cym.Authentication.Level level) {
    this.request = request;
    this.idp = cym.Community.getCurrent();
    this.owner = AuthContext.getRessourceOwner(request.login_hint);
    this.level = level;
    if (this.owner == null) return;

    cym.Community.Authenticator webauthnAuthenticator = (cym.Community.Authenticator) this.idp.authenticators.find('name', 'webauthn_platform');

    // Webauthn_platform is configured for the community
    if (webauthnAuthenticator != null) {
      // The user has already used device biometrics on this session
      if (this.owner.session.verifications.find('authenticator', webauthnAuthenticator.id) != null) this.owner.authenticators.add('webauthn_platform');
    }
  }

  public Step next() {
    if (String.isBlank(this.request.login_hint)) return new Step(StepKind.IDENTITY_CHOOSE, null, null);
    if (this.owner == null) return new Step(StepKind.IDENTITY_REGISTER, null, null);
    cym.Community.Authenticator email = (cym.Community.Authenticator) this.idp.authenticators.find('name', 'email');
    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) this.idp.authenticators.find('name', 'webauthn_platform');
    // The user has never verified her identity
    if (this.owner.authenticators.indexOf('email') == -1) return new Step(StepKind.IDENTITY_VERIFY, email, null);


    cym.Browser.SessionVerification email_verification = (cym.Browser.SessionVerification) this.owner.session.verifications.find('authenticator', email.id);
    // The user has not validated her identity in the current session
    // The email verification has expired (in case it has not been cleaned yet)
    if (email_verification == null || !(Boolean) email_verification.get('isActive')) return new Step(StepKind.AUTHENTICATOR_VERIFY, email, null);

    if (this.level == null || this.level.steps.size() == 0) return new Step(StepKind.REDIRECT, webauthn, null);

    // The user is already compliant with the Community authentication policies
    if (this.owner.session.verify(this.level, this.request)) return new Step(StepKind.REDIRECT, webauthn, null);

    // If this point is reached, it means the user session is not compliant with the Authentication Levels defined.

    cym.Authentication.Steps steps = this.level.steps.next(this.owner.session, this.request);
    Id[] userAuthenticatorIds = this.idp.authenticators.filter('name', this.owner.authenticators).pluck('id').asIds();
    // Check if the user already has register authenticators which can move her across the next step
    Collection stepsWhichCanBeCompleted = steps.filter('authenticator', userAuthenticatorIds);
    if (stepsWhichCanBeCompleted.size() > 0) return new Step(StepKind.AUTHENTICATOR_VERIFY, null, stepsWhichCanBeCompleted);

    // The user has to register at least one new authenticator, ensure that she has completed one challenge in this request
    cym.Collection.Item verificationFromCurrentRequest = this.owner.session.verifications.find('requestId', this.request.iid);
    if (verificationFromCurrentRequest == null) return new Step(StepKind.AUTHENTICATOR_VERIFY, email, null);

    // Only keep the path that the user has potentially started
    cym.Authentication.Step current = this.level.steps.start;

    cym.Collection stepsWhichCanBeStarted = this.level.steps.filter('id', current.next).filter('authenticator', userAuthenticatorIds);
    if (stepsWhichCanBeStarted.size() == 0) return new Step(StepKind.AUTHENTICATOR_REGISTER, null, steps);

    cym.Collection s = new cym.Collection( new cym.Authentication.Step[] {} );
    for (cym.Collection.Item i : stepsWhichCanBeStarted.asList()) s = s.concat(this.level.steps.next(this.owner.session, this.request, (cym.Authentication.Step) i));
    return new Step(StepKind.AUTHENTICATOR_REGISTER, null, s);
  }

  public PageReference getNextStep(Step step, String startURL) {
    Map<String, String> params = new Map<String, String> {
      'iid' => this.request.iid,
      'startURL' => startURL
    };
    if (String.isNotBlank(this.request.login_hint)) params.put('login_hint', this.request.login_hint);
    switch on step.kind {
      when IDENTITY_CHOOSE {
        PageReference pr = new PageReference('/discover');
        pr.getParameters().putAll(params);
        return pr;
      }
      when IDENTITY_REGISTER {
        PageReference pr = new PageReference('/register');
        pr.getParameters().putAll(params);
        return pr;
      }
      when IDENTITY_VERIFY {
        PageReference pr = new PageReference('/email');
        pr.getParameters().putAll(params);
        return pr;
      }
      when REDIRECT {
        return this.owner.session.resume(startURL);
      }
      when else {
        PageReference pr = AuthContext.getNextPageReference(step, this.idp.authenticators);
        if (pr != null) pr.getParameters().putAll(params);
        return pr;
      }
    }
  }

  private static PageReference getNextPageReference(Step step, cym.Community.Authenticators authenticators) {
    if (step.authenticator != null) return AuthContext.getAuthenticatorPageReference(step.authenticator);
    return step.steps.pluck('authenticator').unique().size() > 1 ? new PageReference('/authenticators') : AuthContext.getAuthenticatorPageReference((cym.Community.Authenticator) authenticators.find('id', step.steps.get(0).get('authenticator')));
  }

  public static PageReference getAuthenticatorPageReference(cym.Community.Authenticator authenticator) {
    if (authenticator.name == 'webauthn_platform') return new PageReference('/web_authn');
    if (authenticator.name == 'totp') return new PageReference('/totp');
    if (authenticator.name == 'email') return new PageReference('/email');
    if (authenticator.name == 'password') return new PageReference('/password');
    if (authenticator.name == 'Facebook') return new PageReference('/facebook');
    if (authenticator.name == 'LinkedIn') return new PageReference('/linkedin');
    if (authenticator.name == 'Google') return new PageReference('/google');
    if (authenticator.name == 'Twitter') return new PageReference('/twitter');
    return null;
  }

  public enum StepKind {
    IDENTITY_CHOOSE,
    IDENTITY_REGISTER,
    IDENTITY_VERIFY,
    AUTHENTICATOR_REGISTER,
    AUTHENTICATOR_VERIFY,
    REDIRECT
  }

  public class Step {
    public StepKind kind;
    public cym.Community.Authenticator authenticator;
    public cym.Collection steps;
    public Step(StepKind kind, cym.Community.Authenticator authenticator, cym.Collection steps) {
      this.kind = kind;
      this.authenticator = authenticator;
      this.steps = steps;
    }
  }

  public class RessourceOwner {
    public User user { get; private set; }
    public String[] authenticators { get; private set; }
    public cym.Browser.session session { get; private set; }
  }

  // Builder classes
  private static RessourceOwner getRessourceOwner(String login_hint) {
    if (String.isBlank(login_hint)) return null;
    User u = new UserUtils.Repository().findByUsername(UserUtils.buildUsername(login_hint));
    if (u == null) return null;

    RessourceOwner owner = new RessourceOwner();
    owner.user = u;
    owner.authenticators = new UserUtils.Repository().getUserFactors(u.Id);
    owner.session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), u.Id);
    return owner;
  }

}
