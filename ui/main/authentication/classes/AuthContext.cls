public with sharing class AuthContext {
  public RessourceOwner owner { get; private set; }
  public cym.Community idp { get; private set; }
  public cym.Authentication.Request request { get; private set; }

  public AuthContext(cym.Authentication.Request request) {
    this.request = request;
    this.idp = cym.Community.getCurrent();
    this.owner = AuthContext.getRessourceOwner(request.login_hint);
    if (this.owner == null) return;

    cym.Community.Authenticator webauthnAuthenticator = (cym.Community.Authenticator) this.idp.authenticators.find('name', 'webauthn_platform');

    // Webauthn_platform is configured for the community
    if (webauthnAuthenticator != null) {
      // The user has already used device biometrics on this session
      if (this.owner.session.verifications.find('authenticator', webauthnAuthenticator.id) != null) this.owner.authenticators.add('webauthn_platform');
    }
  }

  public PageReference getNextStep(Step step, String startURL) {
    switch on step.kind {
      when IDENTITY_CHOOSE {
        PageReference pr = new PageReference('/discover');
        pr.getParameters().putAll(
          new Map<String, String> {
            'iid' => this.request.iid,
            'startURL' => startURL
          }
        );
        return pr;
      }
      when IDENTITY_REGISTER {
        PageReference pr = new PageReference('/register');
        pr.getParameters().putAll(
          new Map<String, String> {
            'iid' => this.request.iid,
            'login_hint' => this.request.login_hint,
            'startURL' => startURL
          }
        );
        return pr;
      }
      when IDENTITY_VERIFY {
        PageReference pr = new PageReference('/email');
        pr.getParameters().putAll(
          new Map<String, String> {
            'iid' => this.request.iid,
            'login_hint' => this.request.login_hint,
            'startURL' => startURL
          }
        );
        return pr;
      }
      when REDIRECT {
        return this.owner.session.resume(startURL);
      }
      when else {
        if (step.authenticator.name == 'webauthn_platform') {
          PageReference pr = new PageReference('/web_authn');
          pr.getParameters().putAll(
            new Map<String, String> {
              'iid' => this.request.iid,
              'login_hint' => this.request.login_hint,
              'startURL' => startURL
            }
          );
          return pr;
        }
        if (step.authenticator.name == 'totp') {
          PageReference pr = new PageReference('/totp');
          pr.getParameters().putAll(
            new Map<String, String> {
              'iid' => this.request.iid,
              'login_hint' => this.request.login_hint,
              'startURL' => startURL
            }
          );
          return pr;
        }
        if (step.authenticator.name == 'email') {
          PageReference pr = new PageReference('/email');
          pr.getParameters().putAll(
            new Map<String, String> {
              'iid' => this.request.iid,
              'login_hint' => this.request.login_hint,
              'startURL' => startURL
            }
          );
          return pr;
        }
        return null;
      }
    }
  }

  public Step next() {
    if (String.isBlank(this.request.login_hint)) return new Step(StepKind.IDENTITY_CHOOSE, null);
    if (this.owner == null) return new Step(StepKind.IDENTITY_REGISTER, null);
    cym.Community.Authenticator email = (cym.Community.Authenticator) this.idp.authenticators.find('name', 'email');
    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) this.idp.authenticators.find('name', 'webauthn_platform');
    // The user has never verified her identity
    if (this.owner.authenticators.indexOf('email') == -1) return new Step(StepKind.IDENTITY_VERIFY, email);


    cym.Browser.SessionVerification email_verification = (cym.Browser.SessionVerification) this.owner.session.verifications.find('authenticator', email.id);
    // The user has not validated her identity in the current session
    // The email verification has expired (in case it has not been cleaned yet)
    if (email_verification == null || !(Boolean) email_verification.get('isActive')) return new Step(StepKind.AUTHENTICATOR_VERIFY, email);

    cym.Authentication.Level level = (cym.Authentication.Level) this.idp.acrs.get(0);

    // The user is already compliant with the Community authentication policies
    if (this.owner.session.verify(level, this.request)) return new Step(StepKind.REDIRECT, webauthn);

    // If this point is reached, it means the user session is not compliant with the Authentication Levels defined.

    cym.Authentication.Path[] pathsWhichCanBeCompleted = new cym.Authentication.Path[] {};
    cym.Authentication.Path[] pathsWhichCanBeStarted = new cym.Authentication.Path[] {};
    Id[] userAuthenticatorIds = this.idp.authenticators.filter('name', this.owner.authenticators).pluck('id').asIds();
    for (cym.Collection.Item p : level.paths.asList()) {
      cym.Authentication.Path path = (cym.Authentication.Path) p;
      Integer pathUserFactorsCount = path.factors.filter('authenticator', userAuthenticatorIds).size();
      // Only add paths which can be fully completed
      if ( pathUserFactorsCount == path.factors.size()) pathsWhichCanBeCompleted.add(path);
      // Remove paths which only consist of factors that the user does not have
      if ( pathUserFactorsCount > 0 ) pathsWhichCanBeStarted.add(path);
    }
    cym.Authentication.Factors factorsToComplete;
    if (pathsWhichCanBeCompleted.size() > 0) {
      factorsToComplete = (cym.Authentication.Factors) new cym.Collection(pathsWhichCanBeCompleted)
        .pluck('factors')
        .sort('size', cym.Collection.SortOrder.ASCENDING)
        .get(0);
    } else {
      // The user need to register extra authenticators
      // We take the shortest incomplete path to avoid user friction
      factorsToComplete = (cym.Authentication.Factors) new cym.Collection(pathsWhichCanBeStarted)
        .pluck('factors')
        .sort('size', cym.Collection.SortOrder.ASCENDING)
        .get(0);
    }

    // List all authenticators which are compliant with the request
    Id[] activeAuthenticators = new Id[]{};
    for (cym.Collection.Item i : this.owner.session.verifications.asList()) {
      cym.Browser.SessionVerification verification = (cym.Browser.SessionVerification) i;
      cym.Authentication.Factor factor = (cym.Authentication.Factor) factorsToComplete.find('authenticator', verification.authenticator);
      if (factor == null) continue;
      if (cym.Authentication.verify(factor, this.request, verification)) activeAuthenticators.add(verification.authenticator);
    }

    // Start with the factors that the user already has and which are not already completed
    Id[] factorsToCompleteIds = factorsToComplete
        .filter('authenticator', userAuthenticatorIds)
        .reject('authenticator', activeAuthenticators)
        .pluck('authenticator')
        .asIds();

    if (factorsToCompleteIds.size() > 0) return new Step(StepKind.AUTHENTICATOR_VERIFY, (cym.Community.Authenticator) this.idp.authenticators.find('id', factorsToCompleteIds[0]));

    // Request for the user to register the missing authenticators
    Id[] factorsToRegisterIds = factorsToComplete.reject('authenticator', userAuthenticatorIds).pluck('authenticator').asIds();
    if (factorsToRegisterIds.size() > 0) return new Step(StepKind.AUTHENTICATOR_REGISTER, (cym.Community.Authenticator) this.idp.authenticators.find('id', factorsToRegisterIds[0]));

    // The user has authenticated as part of the current authentication request, continue
    return new Step(StepKind.REDIRECT, webauthn);

    // cym.Browser.SessionVerification webauthn_verification = (cym.Browser.SessionVerification) this.owner.session.verifications.find('authenticator', webauthn.id);

    // // The user has used a platform authenticator in the current session on a previous request
    // if (webauthn_verification != null && !webauthn_verification.isActive(this.request.iid, null)) return new Step(StepKind.AUTHENTICATOR_VERIFY, webauthn);
    // // The user has successfully logged in with WebAuthn
    // if (webauthn_verification != null && webauthn_verification.isActive(this.request.iid, null)) return new Step(StepKind.REDIRECT, webauthn);

    // // The user did not authenticate as part of the current authentication request
    // if (email_verification != null && !email_verification.isActive(this.request.iid, null)) return new Step(StepKind.AUTHENTICATOR_VERIFY, email);

    // // The user has authenticated as part of the current authentication request, continue
    // return new Step(StepKind.REDIRECT, webauthn);
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
    public Step(StepKind kind, cym.Community.Authenticator authenticator) {
      this.kind = kind;
      this.authenticator = authenticator;
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
