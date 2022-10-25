public with sharing virtual class AuthPageController {
  public String log {
    get {
      try {
        return JSON.serialize(DEBUG_LOG);
      } catch (Exception ex) {
        return JSON.serialize(ConverterUtils.toMap(ex));
      }
    }
  }
  protected final Map<String, Object> DEBUG_LOG = new Map<String, Object> {};

  public String logo {get; protected set;}
  private transient cym.Authentication.Request p_request;
  public transient cym.Authentication.Request request {
    get {
      if (p_request == null) p_request = getRequest();
      return this.p_request;
    } 
  }
  public transient String startURL {
    get {
      Map<String, String> params = ApexPages.currentPage().getParameters();
      return String.isBlank(params.get('startURL')) ? '/' : params.get('startURL');
    }
  }

  public AuthPageController() {
    Auth.AuthConfiguration config = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), this.startURL);
    this.logo = config.getLogoUrl();
  }

  private cym.Authentication.Request getRequest() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String login_hint = params.get('login_hint');
    try {
      cym.AuthorizationContext context = cym.AuthorizationContext.getContext(this.startURL);

      return new cym.Authentication.Request(
        new Map<String, Object> { 
          'iid'        => context.authn.iid,
          'login_hint' => String.isNotBlank(login_hint) ? login_hint : context.authn.login_hint,
          'max_age'    => context.authn.max_age
        }
      );
    } catch (Exception ignored) {
      return new cym.Authentication.Request(
        new Map<String, Object> {
          'iid'        => String.isNotBlank(params.get('iid')) ? params.get('iid') : ConverterUtils.base64encode(Crypto.generateAesKey(256)),
          'login_hint' => login_hint,
          'max_age'    => null
        }
      );
    }
  }
}
