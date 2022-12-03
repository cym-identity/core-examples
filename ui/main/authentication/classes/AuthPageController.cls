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
      if (p_request == null) read();
      return this.p_request;
    }
  }

  private transient cym.Authentication.Level p_level;
  public transient cym.Authentication.Level level {
    get {
      if (this.p_level == null) read();
      return this.p_level;
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

  private void read() {
    Map<String, String> params = ApexPages.currentPage().getParameters();
    String login_hint = params.get('login_hint');
    try {
      cym.AuthorizationContext context = cym.AuthorizationContext.getContext(this.startURL);
      this.p_level = context.authn.acr_values.size() > 0 ? (cym.Authentication.Level) context.realm.acrs.find('name', context.authn.acr_values[0]) : (cym.Authentication.Level) cym.Community.getCurrent().acrs.get(0);

      this.p_request = new cym.Authentication.Request(
        new Map<String, Object> { 
          'iid'        => context.authn.iid,
          'login_hint' => String.isNotBlank(login_hint) ? login_hint : context.authn.login_hint,
          'max_age'    => context.authn.max_age
        }
      );
    } catch (Exception ignored) {
      this.p_level = (cym.Authentication.Level) cym.Community.getCurrent().acrs.get(0);
      this.p_request = new cym.Authentication.Request(
        new Map<String, Object> {
          'iid'        => String.isNotBlank(params.get('iid')) ? params.get('iid') : ConverterUtils.base64encode(Crypto.generateAesKey(256)),
          'login_hint' => login_hint,
          'max_age'    => null
        }
      );
    }
  }

  protected PageReference redirect(AuthContext context) {
    AutContext.Step next = context.next();
    if ( next.kind == AuthContext.StepKind.REDIRECT ) {
      Boolean isWebAuthnEnabled = Boolean.valueOf(params.get('is-webauthn'));
      if (isWebAuthnEnabled && next.authenticator?.name == 'webauth_platform') {
        PageReference pr = new PageReference('/web_authn');
        pr.getParameters().putAll(
          new Map<String, String> {
            'login_hint' => this.request.login_hint,
            'startURL'   => this.startURL,
            'iid'        => this.request.iid
          }
        );
        return pr;
      } else {
        return context.owner.session.resume(this.startURL);
      }
    } else {
      return context.getNextStep(next, this.startURL);
    }
  }
}
