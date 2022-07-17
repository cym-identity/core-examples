global with sharing class DiscoveryController { // NOPMD.AvoidGlobalModifier
  public static final String[] firstFactors = new String[] { 'webauthn_platform', 'email', 'phone', 'Twitter', 'Facebook', 'Google', 'LinkedIn' };
  public static final String[] secondFactors = new String[] { 'totp' };

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
      String[] scopes = new String[] {'profile'};
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
          'fields'=> new UserUtils.Repository().getClaims(scopes),
          'picklists' => UserUtils.getPicklists()
        }
      };

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), user_id).activate();

      String[] authenticators = ConverterUtils.fromObjectArrayToStringArray(
        (Object[]) JSON.deserializeUntyped(session.getRemoteApex(DiscoveryController.ListUserAuthenticators.class).invoke())
      );

      Map<String, Object> attributes = new Map<String, Object> {
        'id' => user_id,
        'login' => UserUtils.getUserLogin(u),
        'picture' =>  u.MediumPhotoUrl
      };

      // The user has not verified his / her identity in the current session. It must be done right now and will also verify the email / phone
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
        if (session.verifications.find('authenticatorId', webauthnAuthenticator.id) != null) authenticators.add('webauthn_platform');
      }

      // The minimum possible is the Identity Verification method : email or phone or a social provider
      Boolean completedFirstFactor = false;
      for (String a : firstFactors) {
        cym.Browser.SessionVerification verification = (cym.Browser.SessionVerification) session.verifications.find('authenticatorId', idp.authenticators.find('name', a)?.get('Id'));
        if (verification != null && verification.isActive(maxAge) && verification.requestId == requestId) { completedFirstFactor = true; break; }
      }

      if (!completedFirstFactor) {
        String firstFactor;
        for (String factor : firstFactors) if (authenticators.indexOf(factor) > -1) { firstFactor = factor; break; }
        return new Map<String, Object> {
          'action' => 'authenticator.challenge.' + firstFactor,
          'user' => new Map<String, Object> { 'attributes' => attributes }
        };
      }


      if (acr == 'AAL1') {
        if (authenticators.indexOf('totp') > -1) {
          cym.Browser.SessionVerification verification = (cym.Browser.SessionVerification) session.verifications.find('authenticatorId', idp.authenticators.find('name', 'totp')?.get('Id'));
          if (verification == null || !verification.isActive(maxAge) || verification.requestId != requestId) return new Map<String, Object> {
            'action' => 'authenticator.challenge.totp',
            'user' => new Map<String, Object> { 'attributes' => attributes }
          };

        }
        // Either the user hasn't registered TOTP yet or has a valid verification

        // The user hasn't registered Totp yet
        if (authenticators.indexOf('totp') == -1) return new Map<String, Object> {
          'action' => 'authenticator.register.totp',
          'user' => new Map<String, Object> { 'attributes' => attributes }
        };
      }

      return new Map<String, Object> {
        // Propose webauthn_platform enrollement
        // Ask the user to register webauthn_platform - The UI is responsible to detect if the navigator doesn't support it
        'action' => authenticators.indexOf('webauthn_platform') == -1 ? 'authenticator.register.webauthn_platform' : 'redirect',
        'user' => new Map<String, Object> { 'attributes' => attributes },
        'redirect' => session.resume(startURL).getUrl()
      };
    }
  }

  public with sharing class Authenticate extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String email = (String) params.get('email');
      String startURL = (String) params.get('startURL');
      String password = (String) params.get('password');
      User u = new UserUtils.Repository().findByEmail(email);
      String username = u?.username;
      if (String.isBlank(username)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');
      cym.Community idp = cym.Community.getCurrent();

      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) idp.authenticators.find('name', 'password');
      cym.SalesforceAuthenticator.Password provider = (cym.SalesforceAuthenticator.Password) authenticator.provider;

      if (provider.compromiseInstances(password) > 0) throw new InvalidPasswordException('weak_password');

      PageReference pr = Site.login(username, password, startUrl);

      if (pr == null) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');

      return new Map<String, Object> {
        'redirect' => BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), u.Id)
          .activate()
          .apply(authenticator)
          .resume(startURL)
          .getUrl()
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
      if (provider.compromiseInstances(newPassword) > 0) throw new InvalidPasswordException('weak_password');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), u.Id).activate();
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

  public class InvalidUsernameException extends Exception {}
  public class InvalidPasswordException extends Exception {}
  public class InvalidArgumentException extends Exception {}
}
