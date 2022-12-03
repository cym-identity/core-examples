global with sharing class DiscoveryController { // NOPMD.AvoidGlobalModifier
  public static final String[] FIRST_FACTORS  = new String[] { 'webauthn_platform', 'password', 'email', 'phone', 'Twitter', 'Facebook', 'Google', 'LinkedIn' };
  public static final String[] SECOND_FACTORS = new String[] { 'totp' };
  public static final String[] DEFAULT_SCOPES = new String[] { 'profile' };
  private static final Map<String, Object> REQUIRED_CLAIM = new Map<String, Object> { 'required' => true };
  public static final Map<String, Object> DEFAULT_CLAIMS = new Map<String, Object> { 'given_name' => REQUIRED_CLAIM, 'family_name' => REQUIRED_CLAIM };
  public static final String[][] DEFAULT_ACR = new String[][] {
    new String[] { 'webauthn_platform' },
    new String[] { 'password', 'phone' },
    new String[] { 'password', 'email' },
    new String[] { 'email', 'phone' }
  };


  public with sharing class LoadContext extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String startURL = (String) params.get('startURL');
      cym.Browser browser = cym.Browser.getCurrent();
      Auth.AuthConfiguration config = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), startURL);
      Map<String, Object> results = new Map<String, Object>{
        'logo' => config.getLogoUrl(),
        'socialProviders' => UserUtils.getCommunityAuthProviders(startURL),
        'requestId' => ConverterUtils.base64encode(Crypto.generateAesKey(256))
      };
      try {
        cym.AuthorizationContext context = cym.AuthorizationContext.getContext(startURL);
        results.put('login_hint', context.authn.login_hint);
        results.put('app', new Map<String, Object> {
          'logo_uri' => context.client.logo_uri,
          'tos_uri' => context.client.tos_uri,
          'policy_uri' => context.client.policy_uri,
          'client_name' => context.client.client_name,
          'client_uri' => context.client.client_uri
        });
        if (String.isNotBlank(context.authn.iid)) results.put('requestId', context.authn.iid);
      } catch (Exception ignored) { System.debug(ConverterUtils.toMap(ignored)); }

      Set<Id> userIds = new Set<Id>(browser.sessions.pluck('ownerId').asIds());
      results.put('users', userIds.size() > 0 ? new UserUtils.Repository().getUsers(new List<Id>(userIds)) : new Object[]{});

      results.put('login', new Map<String, Object> {
        'email' => true,
        'phone' => cym.Community.getCurrent().authenticators.find('name', 'phone') != null
      });

      return results;
    }
  }

  public with sharing class Discover extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String login_hint = (String) params.get('login_hint');
      Users.LoginType login_type_hint = Users.LoginType.valueOf(params.get('login_type') != null ? (String) params.get('login_type') : 'unknown');
      String startURL = (String) params.get('startURL');
      String requestId = (String) params.get('requestId');

      if (String.isBlank(login_hint)) throw new InvalidArgumentException('Invalid login_hint');
      if (String.isBlank(startURL)) throw new InvalidArgumentException('Invalid startURL');
      if (String.isBlank(requestId)) throw new InvalidArgumentException('Invalid requestId');

      User u = new UserUtils.Repository().findByUsername(UserUtils.buildUsername(login_hint));
      Id user_id = u?.Id;

      String acr;
      Integer maxAge;
      String[] scopes;
      try {
        cym.AuthorizationContext context = cym.AuthorizationContext.getContext(startURL);
        cym.Authentication.Request authn = context.authn;
        cym.Authorization.Request authz = context.authz;
        acr = (authn.acr_values!= null && authn.acr_values.size() > 0) ? authn.acr_values[0] : null;
        maxAge = authn.max_age;
        if (authz.scopes != null) scopes = authz.scopes;
      } catch (Exception ignored) {}

      // The user doesn't exist, she must register
      if (String.isBlank(user_id)) return new Map<String, Object> {
        'action' => 'identity.register',
        'user' => new Map<String, Object> {
          'attributes' => new Map<String, Object> {
            'id' => user_id,
            'login' => login_hint,
            'picture' => Site.getBaseRequestUrl() + '/profilephoto/005/M'
          },
          'socialProviders' => UserUtils.getCommunityAuthProviders(startURL),
          'fields'=> scopes != null ? new UserUtils.Repository().getClaims(scopes) : DEFAULT_CLAIMS,
          'picklists' => UserUtils.getPicklists()
        }
      };

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), user_id);

      // String[] authenticators = (String[]) JSON.deserialize(session.getRemoteApex(DiscoveryController.ListUserAuthenticators.class).invoke(), List<String>.class);
      String[] authenticators = new UserUtils.Repository().getUserFactors(UserInfo.getUserId());

      Map<String, Object> attributes = new Map<String, Object> {
        'id' => user_id,
        'login' => UserUtils.getUserLogin(u),
        'picture' =>  u.MediumPhotoUrl
      };

      // The user has never verified his / her identity in the current session. It must be done right now and will also verify the email / phone
      if (authenticators.indexOf(Users.getLoginType(login_hint).name()) == -1) {
        return new Map<String, Object> {
          'action' => 'identity.register.' + Users.getLoginType(login_hint),
          'user' => new Map<String, Object> { 'attributes' => attributes }
        };
      }

      // Check the available authenticators and choose the right one
      cym.Community idp = cym.Community.getCurrent();
      cym.Community.Authenticator webauthnAuthenticator = (cym.Community.Authenticator) idp.authenticators.find('name', 'webauthn_platform');

      // Webauthn_platform is configured for the community
      if (webauthnAuthenticator != null) {

        // The user has already used device biometrics on this session
        if (session.verifications.find('authenticator', webauthnAuthenticator.id) != null) authenticators.add('webauthn_platform');
      }

      Map<String, Object> next = getNextAction(session, authenticators, DEFAULT_ACR, requestId, maxAge, startURL);
      next.put('user', new Map<String, Object> { 'attributes' => attributes });
      return next;
    }
  }

  public static Map<String, Object> getNextAction(cym.Browser.Session session, String[] userAuthenticators, String[][] acrs, String requestId, Integer maxAge, String startURL) {
    cym.Community idp = cym.Community.getCurrent();
    // Filter the ACR to see which paths the user can go through
    String[][] availableFactorsForUser = new String[][]{};
    for (String[] factors : acrs) {
      Boolean isAvailableForUser = true;
      for (String factor : factors) if (userAuthenticators.indexOf(factor) == -1) { isAvailableForUser = false; break; }
      if (isAvailableForUser) availableFactorsForUser.add(factors);
    }

    // The user will be requested to complete the first available combination
    if (availableFactorsForUser.size() > 0) {
      String[] factors = availableFactorsForUser[0];
      for (String factor : factors) {
        cym.Community.Authenticator authenticator = (cym.Community.Authenticator) idp.authenticators.find('name', factor);
        cym.Browser.SessionVerification verification = (cym.Browser.SessionVerification) session.verifications.find('authenticator', authenticator?.get('Id'));
        if (verification != null && verification.isActive(requestId, maxAge == null ? authenticator.ttl : maxAge)) continue;
        return new Map<String, Object> {'action' => 'authenticator.challenge.' + factor};
      }
      // If we reach this point, it means that the user has completed all factors from the combination
      // Log her in
      return new Map<String, Object> {
        // Propose webauthn_platform enrollement
        // Ask the user to register webauthn_platform - The UI is responsible to detect if the navigator doesn't support it
        'action' => userAuthenticators.indexOf('webauthn_platform') == -1 ? 'authenticator.register.webauthn_platform' : 'redirect',
        'redirect' => session.resume(startURL).getUrl()
      };
    }

    String[] requestedFactors;
    // The user cannot complete any of the combinations
    // Pick the first one where she has an authenticator, or the first one of all
    for (String[] factors : acrs) {
      for (String factor : factors) if (userAuthenticators.indexOf(factor) > -1) { requestedFactors = factors; break; }
      if (requestedFactors != null) break;
    }
    if (requestedFactors == null) requestedFactors = acrs[0];

    for (String factor : requestedFactors) {
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) idp.authenticators.find('name', factor);
      cym.Browser.SessionVerification verification = (cym.Browser.SessionVerification) session.verifications.find('authenticator', authenticator?.get('Id'));
      if (verification == null || !verification.isActive(requestId, maxAge == null ? authenticator.ttl : maxAge)) {
        return new Map<String, Object> {'action' => 'authenticator.'+ (userAuthenticators.indexOf(factor) > -1 ? 'challenge' : 'register') +  '.' + factor};
      }
    }

    throw new InvalidArgumentException('Reached an unreacheable location');
  }

  public with sharing class Authenticate extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      String password = (String) params.get('password');
      String requestId = (String) params.get('requestId');
      User u = new UserUtils.Repository().findById(userId);
      String username = u?.username;
      if (String.isBlank(username)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');
      cym.Community idp = cym.Community.getCurrent();

      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) idp.authenticators.find('name', 'password');
      cym.SalesforceAuthenticator.Password provider = (cym.SalesforceAuthenticator.Password) authenticator.provider;

      if (provider.compromisesCount(password) > 0) throw new InvalidPasswordException('weak_password');


      PageReference pr = Site.login(username, password, '/');

      if (pr == null) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);
      session.apply((cym.Community.Authenticator) idp.authenticators.find('name', 'password'), requestId);

      return new Map<String, Object> {
        'isValid' => true
      };
    }
  }

  public with sharing class ResetWeakPassword extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String email = (String) params.get('email');
      String startURL = (String) params.get('startURL');
      String password = (String) params.get('password');
      String newPassword = (String) params.get('newPassword');
      cym.Community idp = cym.Community.getCurrent();
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) idp.authenticators.find('name', 'password');
      cym.SalesforceAuthenticator.Password provider = (cym.SalesforceAuthenticator.Password) authenticator.provider;
      User u = new UserUtils.Repository().findByEmail(email);
      String username = u?.username;
      if (String.isBlank(username)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');

      // Checks that the user chosen password is compliant to Authenticator policy ie.: HaveIBeenPwnd check.
      if (provider.compromisesCount(newPassword) > 0) throw new InvalidPasswordException('weak_password');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), u.Id);
      // Setting the user password requires higher permissions than a Guest user or normal user. Hence calling using the Community Technical User
      session.getRemoteApex(DiscoveryController.ResetUserPassword.class).invoke(
        JSON.serialize(
          new Map<String, Object> {
            'userId' => u.Id,
            'oldPassword' => password,
            'newPassword' => newPassword,
            'startURL' => startURL
          }
        )
      );
      return new Map<String, Object> {
        'redirect' => session
          .apply(authenticator)
          .resume(startURL)
          .getUrl()
      };

    }
  }

  global class ListUserAuthenticators extends cym.Remote.Function {
    global override String execute(String p) {
      return JSON.serialize(new UserUtils.Repository().getUserFactors(UserInfo.getUserId()));
    }
  }

  global class ListUsers extends cym.Remote.Function {
    global override String execute(String p) {
      List<Id> userIds = new List<Id>();
      for (String userId : ConverterUtils.fromObjectArrayToStringArray((Object[]) JSON.deserializeUntyped(p))) userIds.add((Id) userId);
      return JSON.serialize(new UserUtils.Repository().getUsers(userIds));
    }
  }

  global class ResetUserPassword extends cym.Remote.Function {
    global override String execute(String p) {
      Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(p);
      String newPassword = (String) params.get('newPassword');
      String oldPassword = (String) params.get('oldPassword');

      Site.changePassword(newPassword, newPassword, oldPassword);

      return '{}';
    }
  }


  private class Factor {
    String authenticatorName;
    Integer maxAge;
    public Factor(String authenticatorName, Integer maxAge) {
      this.authenticatorName = authenticatorName;
      this.maxAge = maxAge;
    }
  }

  public class InvalidUsernameException extends Exception {}
  public class InvalidPasswordException extends Exception {}
  public class InvalidArgumentException extends Exception {}
}
