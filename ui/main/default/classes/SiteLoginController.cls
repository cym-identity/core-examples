/**
 * An apex page controller that exposes the site login functionality
 */
public with sharing class SiteLoginController implements Auth.LoginDiscoveryHandler {
  public String username {get; set;}
  public String password {get; set;}

  public String backgroundColor {get; set;}

  public String app_string {
    get {
      return this.app != null ? JSON.serialize(this.app) : JSON.serialize(new Map<String, Object> {});
    }
  }
  public String startURL {get; set;}
  public String registrationUrl {get; set;}
  public String forgotPasswordUrl {get; set;}
  public List<Object> socialAuthProviders = new List<Object>();
  public String socialLogins {
    get { return JSON.serialize(this.socialAuthProviders); }
  }

  public Object[] users = new Object[] {};
  public String browserUsers {
    get { return JSON.serialize(this.users); }
  }

  public String handle {get; private set;}

  public cym.AuthorizationContext.Client app {get; set;}
  public SiteLoginController () {
    try {
      this.startUrl = System.currentPageReference().getParameters().get('startURL');
      cym.AuthorizationContext context = cym.AuthorizationContext.getContext(startURL);
      this.app = context.client;
    } catch (Exception ignored) { System.debug(ignored); }

    cym.Browser browser = cym.Browser.getCurrent();
    this.handle = JSON.serialize(new Map<String, String> { 'value' => browser.handle.extendUntil(Datetime.now().addSeconds(600)).value});

    Auth.AuthConfiguration config = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), startUrl);
    this.backgroundColor = config.getBackgroundColor();

    PageReference registrationPage = new PageReference(config.getSelfRegistrationUrl());
    registrationPage.getParameters().put('startURL', startURL);
    this.registrationUrl = registrationPage.getUrl();

    PageReference forgotPasswordPage = new PageReference(config.getForgotPasswordUrl());
    forgotPasswordPage.getParameters().put('startURL', startURL);
    this.forgotPasswordUrl = forgotPasswordPage.getUrl();

    this.socialAuthProviders.addAll(getCommunityAuthProviders(startURL));

    Set<Id> userIds = new Set<Id>();
    for (cym.Browser.Session session : browser.sessions.asList()) {
      userIds.add(session.OwnerId);
    }
    this.users.addAll(new Repository().getUsers(new List<Id>(userIds)));
  }


  public PageReference login() {
    String startUrl = System.currentPageReference().getParameters().get('startURL');
    return Site.login(username, password, startUrl);
  }

  @AuraEnabled
  public static String authenticate(String email, String password, String startURL, String handle){
    try {
      User u = new Repository().findByEmail(email);
      String userName = u?.Username;
      if (String.isBlank(userName)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');
      PageReference pr = Site.login(userName, password, startURL);


      cym.Community idp = cym.Community.getCurrent();
      cym.Browser browser = cym.Browser.fromHandle(handle);

      ChallengeController.findOrAddSession(browser, u.Id)
        .activate()
        .apply(idp.authenticators.find('name', 'accounts_password'), null, new String[] {'pwd'})
        .resume(startURL)
        .getUrl();

      return pr.getUrl();

    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Object discover(String email, String startURL, String handle){
    try {
      Id user_id = new Repository().findByEmail(email)?.Id;
      return new Map<String, Object> {
        'action' => 'login',
        'socialProviders' => new Object[]{}
      };
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
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

  public without sharing class Repository {
    public User[] getUsers(Id[] userIds) {
      User[] users = [SELECT Id, Email, SmallPhotoUrl, Name, FirstName, LastName FROM User WHERE Id IN :userIds]; // NOPMD.ApexCrudViolation
      return users;
    }
    public User findByEmail(String email) {
      User[] users = [SELECT Id, Username FROM User WHERE Email = :email]; // NOPMD.ApexCrudViolation
      if (users.size() > 0) return users[0];
      return null;
    }

    public Id[] findThirdPartyAccountLink(Id user_id) {
      ThirdPartyAccountLink[] links = [SELECT SsoProviderId FROM ThirdPartyAccountLink WHERE UserId = :user_id]; // NOPMD.ApexCrudViolation
      Id[] resp = new Id[] {};
      for (ThirdPartyAccountLink link : links) resp.add((Id) link.SsoProviderId);
      return resp;
    }
  }

  public PageReference login(String identifier, String startUrl, Map<String, String> requestAttributes) { return null; }
  public class InvalidUsernameException extends Exception {}

}
