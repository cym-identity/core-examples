public with sharing class DiscoverPageController extends AuthPageController {

  public DiscoverPageController.DisplayUser[] users {get; private set;}
  public ExternalAuthProvider[] providers {get; private set; }

  public DiscoverPageController() {
    super();
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String startURL = params.get('startURL');

    this.providers = new ExternalAuthProvider[]{};
    cym.Community idp = cym.Community.getCurrent();
    for (AuthProvider provider : new Auth.AuthConfiguration(Site.getBaseRequestUrl(), startURL).getAuthProviders()) {
      if (idp.authenticators.find('name', provider.FriendlyName) == null) continue;
      this.providers.add(new ExternalAuthProvider(provider, startURL));
    }
  }

  public PageReference load() {
    try {
      AuthContext context = new AuthContext(this.request);

      Map<String, String> redirectParams = new Map<String, String> {
        'iid'        => this.request.iid,
        'login_hint' => this.request.login_hint,
        'startURL'   => this.startURL
      };
      AuthContext.Step next = context.next();
      if (next.kind != AuthContext.StepKind.IDENTITY_CHOOSE) return context.getNextStep(next, this.startURL);
      Set<Id> userIds = new Set<Id>(cym.Browser.getCurrent().sessions.pluck('ownerId').asIds());
      User[] users = new UserUtils.Repository().findUsers(userIds);
      // Only show if active users
      if (users.size() > 0) {
        this.users = new DiscoverPageController.DisplayUser[] {};
        for (User u : users) this.users.add(new DiscoverPageController.DisplayUser(u, this.request, this.startURL));
      }
    } catch (Exception ex) {
      System.debug(ConverterUtils.toMap(ex));
    }
    return null;
  }

  public PageReference next() {
    return this.load();
  }


  public class DisplayUser {
    public String name { get; private set; }
    public String login_hint { get; private set; }
    public String next { get; private set; }
    public String picture { get; private set; }

    public DisplayUser(User u, cym.Authentication.Request request, String startURL) {
      this.name = name;
      this.login_hint = Users.getLoginHint(u);
      this.picture = u.MediumPhotoUrl;
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
  public class ExternalAuthProvider {
    private AuthProvider provider;
    private String startURL;
    public Id id { get { return provider.Id; } }
    public String iconUrl { get { return provider.IconUrl; } }
    public String friendlyName { get { return provider.FriendlyName; } }
    public String url {
      get {
        PageReference callback = new PageReference( new URL(Network.getLoginUrl(Network.getNetworkId())).getPath() );
        callback.getParameters().put('startURL', String.isBlank(startURL) ? '/' : startURL);
        PageReference authorize = new PageReference(Site.getBaseRequestUrl() + '/services/auth/sso/' + UserInfo.getOrganizationId() + '/' + provider.DeveloperName);
        authorize.getParameters().put('startURL', callback.getUrl());
        return authorize.getUrl();
      }
    }
    public ExternalAuthProvider(AuthProvider provider, String startURL) {
      this.provider = provider;
      this.startURL = startURL;
    }
  }

}
