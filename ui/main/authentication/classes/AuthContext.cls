public with sharing class AuthContext {
  public ResourceOwner owner { get; private set; }
  public cym.Community community { get; private set; }
  public cym.Authentication.Request request { get; private set; }
  public cym.Authentication.Level level { get; private set; }
  // public ResourceOwners users { get; private set; }
  public String startURL { get; private set; }
  public String logo { get; private set; }

  public static AuthContext fromParameters(Map<String, String> params) {
    String login_hint = params.get('login_hint');
    String startURL = String.isBlank(params.get('startURL')) ? '/' : params.get('startURL');
    try {
      cym.Authorization.Context context = cym.Authorization.getContext(startURL);
      return new AuthContext(
        new cym.Authentication.Request(
          new Map<String, Object> {
            'iid'        => context.authn.iid,
            'login_hint' => String.isNotBlank(login_hint) ? login_hint : context.authn.login_hint,
            'max_age'    => context.authn.max_age
          }
        ),
        context.authn.acr_values.size() > 0 ? (cym.Authentication.Level) context.realm.acrs.find('name', context.authn.acr_values[0]) : (cym.Authentication.Level) cym.Community.getCurrent().acrs.get(0),
        startURL,
        context.client.logo_uri
      );
    } catch (Exception ignored) {
      return new AuthContext(
        new cym.Authentication.Request(
          new Map<String, Object> {
            'iid'        => String.isNotBlank(params.get('iid')) ? params.get('iid') : ConverterUtils.base64encode(Crypto.generateAesKey(256)),
            'login_hint' => login_hint,
            'max_age'    => null
          }
        ),
        (cym.Authentication.Level) cym.Community.getCurrent().acrs.get(0),
        startURL,
        null
      );
    }
  }

  public transient Step next;

  private AuthContext(cym.Authentication.Request request, cym.Authentication.Level level, String startURL, String logo) {
    this.request = request;
    this.level = level;
    this.startURL = startURL;
    this.community = cym.Community.getCurrent();
    this.owner = AuthContext.getResourceOwner(request.login_hint);
    this.logo = String.isNotBlank(logo) ? logo : new Auth.AuthConfiguration(Site.getBaseRequestUrl(), '/').getLogoUrl();

    if (this.owner == null) {
      this.next = this.computeNextStep();
      return;
    }

    cym.Community.Authenticator webauthnAuthenticator = (cym.Community.Authenticator) this.community.authenticators.find('name', 'webauthn_platform');

    // Webauthn_platform is configured for the community
    if (webauthnAuthenticator != null) {
      // The user has already used device biometrics on this session
      if (this.owner.session.verifications.find('authenticator', webauthnAuthenticator.id) != null) this.owner.authenticators.add('webauthn_platform');
    }
    this.next = this.computeNextStep();
  }

  private Step computeNextStep() {
    if (String.isBlank(this.request.login_hint)) return new Step(StepKind.IDENTITY_CHOOSE, null);
    if (this.owner == null) return new Step(StepKind.IDENTITY_REGISTER, null);
    cym.Community.Authenticator email = (cym.Community.Authenticator) this.community.authenticators.find('name', 'email');
    cym.Community.Authenticator webauthn = (cym.Community.Authenticator) this.community.authenticators.find('name', 'webauthn_platform');
    // The user has never verified her identity
    if (this.owner.authenticators.indexOf('email') == -1) return new Step(StepKind.IDENTITY_VERIFY, getAuthenticators(email));

    cym.Browser.SessionVerification email_verification = (cym.Browser.SessionVerification) this.owner.session.verifications.find('authenticator', email.id);
    // The user has not validated her identity in the current session
    // The email verification has expired (in case it has not been cleaned yet)
    if (email_verification == null || !(Boolean) email_verification.get('isActive')) return new Step(StepKind.AUTHENTICATOR_VERIFY, getAuthenticators(email));

    if (this.level == null || this.level.steps.size() == 0) return new Step(StepKind.REDIRECT, getAuthenticators(webauthn));

    // The user is already compliant with the Community authentication policies
    if (this.owner.session.verify(this.level, this.request)) return new Step(StepKind.REDIRECT, getAuthenticators(webauthn));

    // If this point is reached, it means the user session is not compliant with the Authentication Levels defined.

    cym.Authentication.Steps steps = this.level.steps.next(this.owner.session, this.request);
    Id[] userAuthenticatorIds = this.community.authenticators.filter('name', this.owner.authenticators).pluck('id').asIds();
    // Check if the user already has register authenticators which can move her across the next step
    Collection stepsWhichCanBeCompleted = steps.filter('authenticator', userAuthenticatorIds);
    if (stepsWhichCanBeCompleted.size() > 0) return new Step(StepKind.AUTHENTICATOR_VERIFY, getAuthenticators(this.community.authenticators, stepsWhichCanBeCompleted));

    // The user has to register at least one new authenticator, ensure that she has completed one challenge in this request
    cym.Collection.Item verificationFromCurrentRequest = this.owner.session.verifications.find('requestId', this.request.iid);
    if (verificationFromCurrentRequest == null) return new Step(StepKind.AUTHENTICATOR_VERIFY, getAuthenticators(email));

    // Only keep the path that the user has potentially started
    cym.Authentication.Step current = this.level.steps.start;

    cym.Collection stepsWhichCanBeStarted = this.level.steps.filter('id', current.next).filter('authenticator', userAuthenticatorIds);
    if (stepsWhichCanBeStarted.size() == 0) return new Step(StepKind.AUTHENTICATOR_REGISTER, getAuthenticators(this.community.authenticators, steps));

    cym.Collection s = new cym.Collection( new cym.Authentication.Step[] {} );
    for (cym.Collection.Item i : stepsWhichCanBeStarted.asList()) s = s.concat(this.level.steps.next(this.owner.session, this.request, (cym.Authentication.Step) i));
    return new Step(StepKind.AUTHENTICATOR_REGISTER, getAuthenticators(this.community.authenticators, s));
  }

  private static cym.Collection getAuthenticators(cym.Community.Authenticator authenticator) {
    return new Collection(new cym.Collection.Item[] { authenticator });
  }

  private static cym.Collection getAuthenticators(cym.Community.Authenticators authenticators, cym.Collection steps) {
    return authenticators.filter('id', steps.pluck('authenticator').asStrings());
  }

  public Boolean isNext(StepKind kind) { return this.next.kind == kind; }

  public Boolean isNext(StepKind[] kinds) { return kinds.indexOf(this.next.kind) > -1; }

  public Boolean isNext(cym.Community.Authenticator authenticator) { return this.next.authenticators.find('id', authenticator.id) != null; }

  public AuthContext apply(cym.Community.Authenticator authenticator) {
    this.owner.session.apply(authenticator, this.request.iid);
    this.owner.authenticators.add(authenticator.name);
    this.next = this.computeNextStep();
    return this;
  }

  public PageReference redirect() {
    if ( this.next.kind == AuthContext.StepKind.REDIRECT ) {
      Map<String, String> params = ApexPages.currentPage().getParameters();
      Boolean isWebAuthnEnabled = String.isNotBlank(params.get('is-webauthn')) && Boolean.valueOf(params.get('is-webauthn'));
      if (isWebAuthnEnabled && this.next.authenticators.find('name', 'webauth_platform') != null) {
        PageReference pr = new PageReference('/webauthn');
        pr.getParameters().putAll(
          new Map<String, String> {
            'login_hint' => this.request.login_hint,
            'startURL'   => this.startURL,
            'iid'        => this.request.iid
          }
        );
        return pr;
      } else {
        return this.owner.session.resume(this.startURL);
      }
    } else {
      Map<String, String> params = new Map<String, String> {
        'iid' => this.request.iid,
        'startURL' => this.startURL
      };
      if (String.isNotBlank(this.request.login_hint)) params.put('login_hint', this.request.login_hint);
      switch on this.next.kind {
        when IDENTITY_CHOOSE {
          PageReference pr = new PageReference('/discover');
          pr.getParameters().putAll(params);
          return pr;
        }
        when IDENTITY_REGISTER {
          Auth.AuthConfiguration conf = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), this.startURL);
          PageReference pr = new PageReference(conf.getSelfRegistrationUrl());
          pr.getParameters().putAll(params);
          return pr;
        }
        when IDENTITY_VERIFY {
          PageReference pr = new PageReference('/email');
          pr.getParameters().putAll(params);
          return pr;
        }
        when REDIRECT {
          return this.owner.session.resume(this.startURL);
        }
        when else {
          PageReference pr = AuthContext.getNextPageReference(this.next);
          if (pr != null) pr.getParameters().putAll(params);
          return pr;
        }
      }
    }
  }

  private static PageReference getNextPageReference(Step step) {
    return step.authenticators.size() > 1 ? new PageReference('/authenticators') : AuthContext.getAuthenticatorPageReference((cym.Community.Authenticator) step.authenticators.get(0));
  }

  public static PageReference getAuthenticatorPageReference(cym.Community.Authenticator authenticator) {
    if (authenticator.name == 'webauthn_platform') return new PageReference('/webauthn');
    if (authenticator.name == 'webauthn_roaming') return new PageReference('/roaming');
    if (authenticator.name == 'totp') return new PageReference('/totp');
    if (authenticator.name == 'email') return new PageReference('/email');
    if (authenticator.name == 'password') return new PageReference('/password');
    if (authenticator.name == 'Facebook') return new PageReference('/facebook');
    if (authenticator.name == 'LinkedIn') return new PageReference('/linkedin');
    if (authenticator.name == 'Google') return new PageReference('/google');
    if (authenticator.name == 'Twitter') return new PageReference('/twitter');
    return null;
  }

  public ExternalAuthProvider[] getCommunityAuthProviders() {
    return (ExternalAuthProvider[]) new cym.Collection(
      new Auth.AuthConfiguration(Site.getBaseRequestUrl(), '/').getAuthProviders()
    )
      .filter('FriendlyName', this.community.authenticators.pluck('name').asStrings())
      .asList((cym.Collection.AsList) cym.Func.of(CastToExternalAuthProviderList.class).bind('startURL', this.startURL));
  }

  public DisplayUser[] getBrowserUsers() {
    return (DisplayUser[]) new cym.Collection(
      new UserUtils.Repository().findUsers(new Set<Id>(cym.Browser.getCurrent().sessions.pluck('ownerId').asIds()))
    ).asList((cym.Collection.AsList) cym.Func.of(CastToDisplayUserList.class).bind('request', this.request).bind('startURL', this.startURL));
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
    public cym.Collection authenticators;
    public Step(StepKind kind, cym.Collection authenticators) {
      this.kind = kind;
      this.authenticators = authenticators;
    }
  }

  public class ResourceOwner {
    public User user { get; private set; }
    public String[] authenticators { get; private set; }
    public cym.Browser.session session { get; private set; }
  }

  // Builder classes
  private static ResourceOwner getResourceOwner(String login_hint) {
    if (String.isBlank(login_hint)) return null;
    User u = new UserUtils.Repository().findByUsername(UserUtils.buildUsername(login_hint));
    if (u == null) return null;

    ResourceOwner owner = new ResourceOwner();
    owner.user = u;
    owner.authenticators = new UserUtils.Repository().getUserFactors(u.Id);
    owner.session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), u.Id);
    return owner;
  }

  public class CastToExternalAuthProviderList extends cym.Collection.AsList {
    public override Object[] execute(cym.Collection users) {
      cym.Authentication.Request request = (cym.Authentication.Request) this.arguments.get('request');
      String startURL = (String) this.arguments.get('startURL');
      ExternalAuthProvider[] results = new ExternalAuthProvider[] {};
      for (cym.Collection.Item o : users.asList()) results.add(new ExternalAuthProvider((cym.Collection.SObjectItem) o, startURL));
      return results;
    }
  }

  public class ExternalAuthProvider {
    public Id id { get; private set; }
    public String iconUrl { get; private set; }
    public String friendlyName { get; private set; }
    public String url { get; private set; }
    public ExternalAuthProvider(cym.Collection.SObjectItem provider, String startURL) {
      this.id = (Id) provider.get('Id');
      this.iconUrl = (String) provider.get('IconUrl');
      this.friendlyName = (String) provider.get('FriendlyName');
      PageReference callback = new PageReference( new URL(Network.getLoginUrl(Network.getNetworkId())).getPath() );
      callback.getParameters().put('startURL', String.isBlank(startURL) ? '/' : startURL);
      PageReference authorize = new PageReference(Site.getBaseRequestUrl() + '/services/auth/sso/' + UserInfo.getOrganizationId() + '/' + provider.get('DeveloperName'));
      authorize.getParameters().put('startURL', callback.getUrl());
      this.url = authorize.getUrl();
    }
  }

  public class CastToDisplayUserList extends cym.Collection.AsList {
    public override Object[] execute(cym.Collection users) {
      cym.Authentication.Request request = (cym.Authentication.Request) this.arguments.get('request');
      String startURL = (String) this.arguments.get('startURL');
      DisplayUser[] results = new DisplayUser[] {};
      for (cym.Collection.Item o : users.asList()) results.add(new DisplayUser((cym.Collection.SObjectItem) o, request, startURL));
      return results;
    }
  }

  public class DisplayUser {
    public Id id { get; private set; }
    public String name { get; private set; }
    public String login_hint { get; private set; }
    public String next { get; private set; }
    public String picture { get; private set; }
    public String login_type = 'email';

    public DisplayUser(cym.Collection.SObjectItem u, cym.Authentication.Request request, String startURL) {
      this.id = (Id) u.get('Id');
      this.name = (String) u.get('FirstName') + ' ' + (String) u.get('LastName');
      this.login_hint = (String) u.get('Email');
      this.picture = (String) u.get('MediumPhotoUrl');
      PageReference pr  = new PageReference('/discover');
      pr.getParameters().putAll(
        new Map<String, String> {
          'login_hint' => this.login_hint,
          'startURL' => startURL,
          'iid' => request.iid
        }
      );
      this.next = pr.getUrl();
    }
  }
}
