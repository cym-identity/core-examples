global with sharing class DiscoveryController { // NOPMD.AvoidGlobalModifier
  public static final Map<String, Object> RESPONSE = new Map<String,Object>();
  public String log {
    get {
      try {
        return JSON.serialize(RESPONSE);
      } catch (Exception ex) {
        return JSON.serialize(ConverterUtils.toMap(ex));
      }
    }
  }

  public static final String[][] defaultAuthenticationFlows = new String[][] {
    new String[] { 'password', 'totp' },
    new String[] { 'webauthn_platform' }
  };

  public DiscoveryController() {}

  public with sharing class LoadContext extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String startURL = (String) params.get('startURL');
      Map<String, Object> results = new Map<String, Object>{};
      try {
        cym.AuthorizationContext context = cym.AuthorizationContext.getContext(startURL);
        results.put('request', new Map<String, Object> {
          'scope' => context.request.scope,
          'acr_values' => context.request.acr_values,
          'login_hint' => context.request.login_hint
        });
        results.put('app', context.client);
        results.put('startUrl', startURL);
      } catch (Exception ignored) { System.debug(ignored); System.debug(ignored.getStackTraceString().split('\n')); }

      cym.Browser browser = cym.Browser.getCurrent();

      Auth.AuthConfiguration config = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), startURL);

      results.put('logo', config.getLogoUrl());

      PageReference registrationPage = new PageReference(config.getSelfRegistrationUrl());
      registrationPage.getParameters().put('startURL', startURL);
      results.put('registrationUrl', registrationPage.getUrl());

      PageReference forgotPasswordPage = new PageReference(config.getForgotPasswordUrl());
      forgotPasswordPage.getParameters().put('startURL', startURL);
      results.put('forgotPasswordUrl', forgotPasswordPage.getUrl());


      PageReference socialProviderPageReference = new PageReference('/auth/register');
      socialProviderPageReference.getParameters().put('startURL', String.isBlank(startURL) ? '/' : startURL);
      results.put('socialProviders', getCommunityAuthProviders(socialProviderPageReference.getUrl()));

      Set<Id> userIds = new Set<Id>();
      List<Object> verifications = new List<Object>();
      for (cym.Browser.Session session : browser.sessions.asList()) if (session.verifications.size() > 0) userIds.add(session.OwnerId);

      if (Auth.CommunitiesUtil.isGuestUser()) {
        // The guest user is by default not allowed to see user's SmallPhotoUrl, therefore making a request on behalf of an admin to get it
        cym.Community community = cym.Community.getCurrent();
        String resp = community.getRemoteApex(DiscoveryController.ListUsers.class)
          .invoke(
            JSON.serialize(
              new Map<String, Object> {
                'userIds' => userIds
              }
            )
          );
        results.put('users', JSON.deserializeUntyped(resp));
      } else {
        results.put('users', new UserUtils.Repository().getUsers(new List<Id>(userIds)));
      }
      results.put('paths', defaultAuthenticationFlows);
      return results;
    }
  }

  public with sharing class Discover extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String email = (String) params.get('email');
      String startURL = (String) params.get('startURL');
      User u = new UserUtils.Repository().findByEmail(email);
      Id user_id = u?.Id;
      if (String.isBlank(user_id)) {
        PageReference socialProviderPageReference = new PageReference('/auth/register');
        socialProviderPageReference.getParameters().put('startURL', String.isBlank(startURL) ? '/' : startURL);

        return new Map<String, Object> {
          'action' => 'authenticator_chooser',
          'user' => new Map<String, Object> {
            'id' => user_id,
            'email' => email,
            'authenticators' => new String[] { 'password' },
            'socialProviders' => getCommunityAuthProviders(socialProviderPageReference.getUrl())
          }
        };
      }

      cym.Browser browser = cym.Browser.getCurrent();
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, user_id);

      Map<String, Object> userAuthenticators = (Map<String, Object>) JSON.deserializeUntyped(
        session.getRemoteApex(DiscoveryController.ListUserAuthenticators.class).invoke()
      );

      String[] authenticators = ConverterUtils.fromObjectArrayToStringArray((Object[]) userAuthenticators.get('authenticators'));
      String[] socialProviders = ConverterUtils.fromObjectArrayToStringArray((Object[]) userAuthenticators.get('socialProviders'));

      cym.Community idp = cym.Community.getCurrent();
      cym.Community.Authenticator webauthnAuthenticator = idp.authenticators.find('name', 'webauthn_platform');

      if (webauthnAuthenticator == null) return new Map<String, Object> {
        'action' => 'authenticator_chooser',
        'user' => new Map<String, Object> {
          'id' => user_id,
          'email' => email,
          'authenticators' => authenticators,
          'socialProviders' => socialProviders
        }
      };

      // The user has already used device biometrics on this session
      for (cym.Browser.SessionVerification verif : session.verifications.asList()) if (verif.authenticatorId == webauthnAuthenticator.id) authenticators.add('webauthn_platform');

      return new Map<String, Object> {
        'action' => 'authenticator_chooser',
        'user' => new Map<String, Object> {
          'id' => user_id,
          'email' => email,
          'authenticators' => authenticators,
          'socialProviders' => socialProviders
        }
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

      cym.SalesforceAuthenticator.Password authenticator = (cym.SalesforceAuthenticator.Password) idp.authenticators.find('name', 'password');

      if (authenticator.compromiseInstances(password) > 0) throw new InvalidPasswordException('weak_password');

      PageReference pr = Site.login(username, password, startUrl);

      if (pr == null) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');

      return new Map<String, Object> {
        'redirect' => BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), u.Id)
          .activate()
          .apply(authenticator, null, null)
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
      cym.SalesforceAuthenticator.Password authenticator = (cym.SalesforceAuthenticator.Password) idp.authenticators.find('name', 'password');
      User u = new UserUtils.Repository().findByEmail(email);
      String username = u?.username;
      if (String.isBlank(username)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');

      // Checks that the user chosen password is compliant to Authenticator policy ie.: HaveIBeenPwnd check.
      if (authenticator.compromiseInstances(newPassword) > 0) throw new InvalidPasswordException('weak_password');
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
          .apply(authenticator, null, null)
          .resume(startURL)
          .getUrl()
      };

    }
  }

  private static Object[] getCommunityAuthProviders(String startURL) {
    Auth.AuthConfiguration config = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), startUrl);

    cym.Community idp = cym.Community.getCurrent();

    Object[] response = new Object[] {};
    for (AuthProvider provider : config.getAuthProviders()) {
      // Only keep authenticators which are provisionned in the cym__Community__c object
      // This assumes that the name is the same as the AuthProvider.Name
      if (idp.authenticators.find('name', provider.FriendlyName) == null) continue;
      response.add(new Map<String, Object> {
        'id' => provider.Id,
        'iconUrl' => provider.IconUrl,
        'friendlyName' => provider.FriendlyName,
        'url' => Auth.AuthConfiguration.getAuthProviderSsoUrl(Site.getBaseRequestUrl(), startUrl, provider.DeveloperName)
      });
    }
    return response;
  }

  global class ListUserAuthenticators extends cym.Remote.Function {
    global override String execute(String p) {
      UserUtils.Repository repo = new UserUtils.Repository();

      return JSON.serialize(
        new Map<String, Object> {
          'authenticators' => repo.getUserFactors(UserInfo.getUserId()),
          'socialProviders' => repo.findThirdPartyAccountLink(UserInfo.getUserId())
        }
      );
    }
  }

  global class ListUsers extends cym.Remote.Function {
    global override String execute(String p) {
      Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(p);

      List<Id> userIds = new List<Id>();
      for (String userId : ConverterUtils.fromObjectArrayToStringArray((Object[]) params.get('userIds'))) userIds.add((Id) userId);

      return JSON.serialize(
        new UserUtils.Repository().getUsers(userIds)
      );
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
}
