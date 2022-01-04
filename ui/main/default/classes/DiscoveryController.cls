global with sharing class DiscoveryController { // NOPMD.AvoidGlobalModifier
  public static final Map<String, Object> RESPONSE = new Map<String,Object>();
  public String log {
    get {
      return JSON.serialize(RESPONSE);
    }
  }

  public String contentType {get; private set;}
  public DiscoveryController() {}

  public PageReference init() {
    Map<String, String> headers = ApexPages.currentPage().getHeaders();

    this.contentType = headers.get('Accept') == 'application/json' ? 'application/json;charset=UTF-8' : 'text/html;charset=UTF-8';

    // This is a POST request from Javascript
    if (headers.get('Accept') == 'application/json' && headers.containsKey('Content-Length') && Integer.valueOf(headers.get('Content-Length')) > 0) {
      String origin = headers.get('Origin');
      String allowedOrigin = 'https://' + new URL(Site.getBaseRequestUrl()).getHost();
      // Do not support CORS
      ApexPages.currentPage().getHeaders().put('Access-Control-Allow-Origin', new URL(Site.getBaseRequestUrl()).getHost());

      // Only requests from the same domain are processed
      if (origin != allowedOrigin) return null;


      // This an XHR request made from the page itself, process it

      try {
        Map<String, String> body = ApexPages.currentPage().getParameters();

        switch on body.remove('action') {
          when 'loadContext' {
            RESPONSE.putAll(loadContext(body.get('startURL')));
            return null;
          }

          when else {
            return null;
          }
        }
      } catch (Exception ex) {
        RESPONSE.putAll(ConverterUtils.toMap(ex));
      }
    }

    return null;
  }


  @AuraEnabled
  public static String authenticate(String email, String password, String startURL, String handle){
    try {
      User u = new UserUtils.Repository().findByEmail(email);
      String username = u?.username;
      if (String.isBlank(username)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');
      cym.Community idp = cym.Community.getCurrent();

      cym.SalesforceAuthenticator.Password authenticator = (cym.SalesforceAuthenticator.Password) idp.authenticators.find('name', 'password');
      PageReference pr = (PageReference) authenticator.verifyVerification(
        new Map<String, Object> {
          'username' => username,
          'password' => password,
          'startURL' => startURL
        }
      );

      return BrowserSessionUtils.findOrAddSession(cym.Browser.fromHandle(handle), u.Id)
        .activate()
        .apply(authenticator, null, null)
        .resume(startURL)
        .getUrl();

    } catch (Exception ex) {
      throw new AuraHandledException(ex.getMessage());
    }
  }

  @AuraEnabled
  public static string resetWeakPassword(String email, String password, String newPassword, String startURL, String handle){
    cym.Community idp = cym.Community.getCurrent();
    cym.SalesforceAuthenticator.Password authenticator = (cym.SalesforceAuthenticator.Password) idp.authenticators.find('name', 'password');
    User u = new UserUtils.Repository().findByEmail(email);
    String username = u?.username;
    try {
      if (String.isBlank(username)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');
      PageReference pr = (PageReference) authenticator.verifyVerification(
        new Map<String, Object> {
          'username' => username,
          'password' => password,
          'startURL' => startURL
        }
      );
      // The flow should always throw a weak_password or else this is not part of the usual flow
      throw new AuraHandledException('invalid_request');
    } catch (Exception e) {
      if (e.getMessage() != 'weak_password') throw new AuraHandledException('invalid_request');
    }

    try {
      // Checks that the user chosen password is compliant to Authenticator policy ie.: HaveIBeenPwnd check.
      authenticator.initRegistration(
        new Map<String, Object> {
          'userId' => u.Id,
          'password' => newPassword,
          'startURL' => startURL
        }
      );
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.fromHandle(handle), u.Id).activate();
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
      return session
        .apply(authenticator, null, null)
        .resume(startURL)
        .getUrl();
    } catch (Exception ex) {
      throw new AuraHandledException(ex.getMessage());
    }
  }

  @AuraEnabled
  public static Object discover(String email, String startURL, String handle){
    try {
      User u = new UserUtils.Repository().findByEmail(email);
      Id user_id = u?.Id;
      if (String.isBlank(user_id)) return new Map<String, Object> {
        'action' => 'password',
        'socialProviders' => new Object[]{}
      };

      cym.Browser browser = cym.Browser.fromHandle(handle);
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, user_id);

      Map<String, Object> userAuthenticators = (Map<String, Object>) JSON.deserializeUntyped(
        session.getRemoteApex(DiscoveryController.ListUserAuthenticators.class).invoke()
      );

      String[] authenticators = ConverterUtils.fromObjectArrayToStringArray((Object[]) userAuthenticators.get('authenticators'));
      String[] socialProviders = ConverterUtils.fromObjectArrayToStringArray((Object[]) userAuthenticators.get('socialProviders'));

      cym.Community idp = cym.Community.getCurrent();
      cym.Community.Authenticator webauthnAuthenticator = idp.authenticators.find('name', 'webauthn_platform');

      if (webauthnAuthenticator == null) return new Map<String, Object> {
        'action' => 'password',
        'userId' => user_id,
        'authenticators' => authenticators,
        'socialProviders' => socialProviders
      };

      cym.Browser.SessionVerification webAuthnVerification;
      for (cym.Browser.SessionVerification v : session.verifications.asList()) if (v.authenticatorId == webauthnAuthenticator.Id) {webAuthnVerification = v; break;}

      return new Map<String, Object> {
        'action' => 'authenticator_chooser', // webAuthnVerification != null ? 'webauthn_platform' : (authenticators.size() > 1 ? 'authenticator_chooser' : authenticators[0]),
        'userId' => user_id,
        'authenticators' => authenticators,
        'socialProviders' => socialProviders
      };

    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  public Map<String, Object> loadContext(String startURL) {
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

    PageReference registrationPage = new PageReference(config.getSelfRegistrationUrl());
    registrationPage.getParameters().put('startURL', startURL);
    results.put('registrationUrl', registrationPage.getUrl());

    PageReference forgotPasswordPage = new PageReference(config.getForgotPasswordUrl());
    forgotPasswordPage.getParameters().put('startURL', startURL);
    results.put('forgotPasswordUrl', forgotPasswordPage.getUrl());

    results.put('socialProviders', getCommunityAuthProviders(startURL));

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
    return results;
  }

  private static Object[] getCommunityAuthProviders(String startURL) {
    Auth.AuthConfiguration config = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), startUrl);
    Object[] response = new Object[] {};
    for (AuthProvider provider : config.getAuthProviders()) {
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
      cym.Community idp = cym.Community.getCurrent();
      cym.SalesforceAuthenticator.Password authenticator = (cym.SalesforceAuthenticator.Password) idp.authenticators.find('name', 'password');

      authenticator.verifyRegistration(
        new Map<String, Object> {
          'userId' => params.get('userId'),
          'oldPassword' => params.get('oldPassword'),
          'newPassword' => params.get('newPassword'),
          'startURL' => params.get('startURL')
        }
      );

      return '{}';
    }
  }

  public class InvalidUsernameException extends Exception {}
}
