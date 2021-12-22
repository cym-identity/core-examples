global with sharing class WebAuthnController { // NOPMD.AvoidGlobalModifier

  public static final Map<String, Object> RESPONSE = new Map<String,Object>();
  public String log {
    get {
      return JSON.serialize(RESPONSE);
    }
  }

  public String contentType {get; private set;}
  public WebAuthnController() {}

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
          when 'initRegisterWebAuthn' {
            RESPONSE.putAll(WebAuthnController.initRegisterWebAuthn(body.get('authenticator'), (Id) body.get('userId')));
            return null;
          }

          when 'verifyRegisterWebAuthn' {
            Map<String, String> params = body.clone();
            String startURL = params.remove('startURL');
            String authenticator = params.remove('authenticator');
            Id userId = params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
            RESPONSE.putAll(WebAuthnController.verifyRegisterWebAuthn(params, authenticator, startURL, userId));
          }

          when 'initVerifyWebAuthn' {
            RESPONSE.putAll(WebAuthnController.initVerifyWebAuthn(body.get('authenticator'), (Id) body.get('userId')));
          }

          when 'verifyVerifyWebAuthn' {
            Map<String, String> params = body.clone();
            String startURL = params.remove('startURL');
            String authenticator = params.remove('authenticator');
            Id userId = params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
            RESPONSE.putAll(WebAuthnController.verifyVerifyWebAuthn(params, authenticator, startURL, userId));
          }

          when else {
            return null;
          }
        }
      } catch (Exception ex) {
        RESPONSE.putAll(ConverterUtils.toMap(ex));
      }
    } else {
      String name = ApexPages.currentPage().getParameters().get('authenticator');
      if (String.isBlank(name)) return null;

      RESPONSE.put('requestor', ApexPages.currentPage().getParameters().get('requestor')); // NOPMD.ApexXSSFromUrlParam

      cym.Community.Authenticator authenticator = cym.Community.getCurrent().authenticators.find('name', name); // NOPMD.ApexXSSFromUrlParam
      if (authenticator == null) return null;

      String type = (String) authenticator.get('type');
      String userVerification = (String) authenticator.get('user_verification');

      RESPONSE.put('authenticator', new Map<String, Object> { 'type' => type, 'userVerification' => userVerification});
    }
    return null;
  }

  public static Map<String, Object> initRegisterWebAuthn(String authenticator, Id userId) {
    if (userId == null) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      userId = UserInfo.getUserId();
    }

    cym.Browser.Session session = WebAuthnController.findOrAddSession(cym.Browser.getCurrent(), userId);
    String response = session.getRemoteApex(
      WebAuthnController.InitRegisterWebAuthn.class
    ).invoke(
      JSON.serialize(
        new Map<String, Object> {
          'authenticator' => authenticator,
          'handle' => cym.Browser.getCurrent().handle.value
        }
      )
    );

    return (Map<String, Object>) JSON.deserializeUntyped(response);
  }

  public static Map<String, Object> verifyRegisterWebAuthn(Map<String, String> publicKeyCredential, String authenticator, String startURL, Id userId) {
    if (userId == null) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      userId = UserInfo.getUserId();
    }

    cym.Browser.Session session = WebAuthnController.findOrAddSession(cym.Browser.getCurrent(), userId);
    String response = session.getRemoteApex(
      WebAuthnController.VerifyRegisterWebAuthn.class
    ).invoke(
      JSON.serialize(
        new Map<String, Object> {
          'publicKeyCredential' => publicKeyCredential,
          'authenticator' => authenticator,
          'handle' => cym.Browser.getCurrent().handle.value
        }
      )
    );

    Map<String, Object> credential = (Map<String, Object>)((Map<String, Object>) JSON.deserializeUntyped(response)).get('credential');
    try {
      cym.Community.Authenticator auth = cym.Community.getCurrent().authenticators.find('name', authenticator);
      return new Map<String, Object> {
        'credential' => credential,
        'url' => session.activate().apply(auth, null, null).resume(startURL).getUrl()
      };
    } catch (Exception ex) {
      return (new Map<String, Object> {
        'error' => ex.getMessage(),
        'error_description' => 'verifyVerifyWebAuthn',
        'error_stack_trace' => ex.getStackTraceString().split('\n')
      });
    }
  }

  public static Map<String, Object> initVerifyWebAuthn(String authenticator, Id userId) {
    if (userId == null) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      userId = UserInfo.getUserId();
    }
    String response = WebAuthnController.findOrAddSession(
      cym.Browser.getCurrent(),
      userId
    ).getRemoteApex(
      WebAuthnController.InitVerifyWebAuthn.class
    ).invoke(
      JSON.serialize(
        new Map<String, Object> {
          'authenticator' => authenticator,
          'handle' => cym.Browser.getCurrent().handle.value
        }
      )
    );
    return (Map<String, Object>) JSON.deserializeUntyped(response);
  }

  public static Map<String, Object> verifyVerifyWebAuthn(Map<String, String> publicKeyCredential, String authenticator, String startURL, Id userId) {
    if (userId == null) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      userId = UserInfo.getUserId();
    }
    cym.Browser.Session session = WebAuthnController.findOrAddSession(cym.Browser.getCurrent(), userId);
    String response = session.getRemoteApex(WebAuthnController.VerifyVerifyWebAuthn.class).invoke(JSON.serialize(new Map<String, Object> {'publicKeyCredential' => publicKeyCredential, 'authenticator' => authenticator, 'handle' => cym.Browser.getCurrent().handle.value}));

    Boolean is_valid = (Boolean) ((Map<String, Object>) JSON.deserializeUntyped(response)).get('isValid');

    if (is_valid) {
      try {
        cym.Community.Authenticator auth = cym.Community.getCurrent().authenticators.find('name', authenticator);
        return new Map<String, Object> {
          'isValid' => true,
          'url' => session.activate().apply(auth, null, null).resume(startURL).getUrl()
        };
      } catch (Exception ex) {
        return (new Map<String, Object> {
          'error' => ex.getMessage(),
          'error_description' => 'verifyVerifyWebAuthn',
          'error_stack_trace' => ex.getStackTraceString().split('\n')
        });
      }
    }
    return new Map<String, Object> {
      'isValid' => false
    };
  }


  global class InitRegisterWebAuthn extends cym.Remote.Function {
    global override String execute(String params) {
      Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(params);

      cym.Community context = cym.Community.getCurrent();
      cym.WebAuthn auth = (cym.WebAuthn) context.authenticators.find('name', (String) o.get('authenticator'));
      String handle = (String) o.get('handle');

      return JSON.serialize(auth.initRegistration(new Map<String, Object> { 'handle' => handle }));
    }
  }

  global class VerifyRegisterWebAuthn extends cym.Remote.Function {
    global override String execute(String params) {
      Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(params);

      cym.Community context = cym.Community.getCurrent();
      cym.WebAuthn auth = (cym.WebAuthn) context.authenticators.find('name', (String) o.get('authenticator'));

      Map<String, Object> publicKeyCredential = (Map<String, Object>) o.get('publicKeyCredential');
      String handle = (String) o.get('handle');
      // Polyfill the transports based on the authenticator type. It allows to remember if the credential is platform specific or not
      if (publicKeyCredential.get('transports') == '[]') publicKeyCredential.put('transports', (String) auth.get('type') == 'platform' ? '["internal"]' : '["usb", "nfc", "ble"]');

      cym.WebAuthn.Credential credential = (cym.WebAuthn.Credential) auth.verifyRegistration(
        new Map<String, Object> {
          'handle' => handle,
          'publicKeyCredential' => publicKeyCredential
        }
      );

      return JSON.serialize(
        new Map<String, Object> {
          'credential' => new Map<String, Object> {
            'id' => EncodingUtil.base64Encode(credential.credentialId),
            'aaguid' => EncodingUtil.base64Encode(credential.aaguid),
            'counter' => credential.counter,
            'transports' => credential.transports
          }
        }
      );
    }
  }

  global class InitVerifyWebAuthn extends cym.Remote.Function {
    global override String execute(String params) {
      Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(params);

      cym.Community context = cym.Community.getCurrent();
      cym.WebAuthn auth = (cym.WebAuthn) context.authenticators.find('name', (String) o.get('authenticator'));
      String handle = (String) o.get('handle');

      return JSON.serialize(auth.initVerification(new Map<String, Object> {'handle' => handle}));
    }
  }

  global class VerifyVerifyWebAuthn extends cym.Remote.Function {
    global override String execute(String params) {
      Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(params);

      cym.Community context = cym.Community.getCurrent();
      cym.WebAuthn auth = (cym.WebAuthn) context.authenticators.find('name', (String) o.get('authenticator'));
      String handle = (String) o.get('handle');
      Boolean is_valid = (Boolean) auth.verifyVerification(
        new Map<String, Object> {
          'handle' => handle,
          'publicKeyCredential' => (Map<String, Object>) o.get('publicKeyCredential')
        }
      );
      //  cym.WebAuthn.verifyVerificationWebAuthn(cym.Browser.fromHandle(handle), auth, );

      return JSON.serialize(new Map<String, Object> {'isValid' => is_valid});
    }
  }

  public static cym.Browser.Session findOrAddSession(cym.Browser browser, Id userId) {
    cym.Browser.Session session;
    for (cym.Browser.Session s : browser.sessions.asList()) {
      if (s.OwnerId == userId) {
        session = s;
        break;
      }
    }
    if (session == null) session = browser.sessions.add(userId);
    return session;
  }

}
