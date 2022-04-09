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
    String name = ApexPages.currentPage().getParameters().get('authenticator');
    if (String.isBlank(name)) return null;

    RESPONSE.put('requestor', ApexPages.currentPage().getParameters().get('requestor')); // NOPMD.ApexXSSFromUrlParam

    cym.Community.Authenticator authenticator = cym.Community.getCurrent().authenticators.find('name', name); // NOPMD.ApexXSSFromUrlParam
    if (authenticator == null) return null;

    String type = (String) authenticator.get('type');
    String userVerification = (String) authenticator.get('user_verification');

    RESPONSE.put('authenticator', new Map<String, Object> { 'type' => type, 'userVerification' => userVerification, 'name' => authenticator.name});
    RESPONSE.put('baseUrl', Site.getBaseRequestUrl());

    return null;
  }

  public with sharing class InitRegisterWebAuthn extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String authenticator = (String) params.remove('authenticator');
      Id userId = params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }

      cym.Browser.Session session = WebAuthnController.findOrAddSession(cym.Browser.getCurrent(), userId);
      String response = session.getRemoteApex(
        WebAuthnController.InitRegisterWebAuthnRemote.class
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
  }

  public with sharing class VerifyRegisterWebAuthn extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String startURL = (String) params.remove('startURL');
      String authenticator = (String) params.remove('authenticator');
      Id userId = (String) params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      Map<String, Object> publicKeyCredential = params;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }

      cym.Browser.Session session = WebAuthnController.findOrAddSession(cym.Browser.getCurrent(), userId);
      String response = session.getRemoteApex(
        WebAuthnController.VerifyRegisterWebAuthnRemote.class
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
  }

  public with sharing class InitVerifyWebAuthn extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String authenticator = (String) params.remove('authenticator');
      Id userId = params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }
      String response = WebAuthnController.findOrAddSession(
        cym.Browser.getCurrent(),
        userId
      ).getRemoteApex(
        WebAuthnController.InitVerifyWebAuthnRemote.class
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
  }

  public with sharing class VerifyVerifyWebAuthn extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String startURL = (String) params.remove('startURL');
      String authenticator = (String) params.remove('authenticator');
      Id userId = (String) params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }
      cym.Browser.Session session = WebAuthnController.findOrAddSession(cym.Browser.getCurrent(), userId);
      String response = session.getRemoteApex(WebAuthnController.VerifyVerifyWebAuthnRemote.class).invoke(JSON.serialize(new Map<String, Object> {'publicKeyCredential' => params, 'authenticator' => authenticator, 'handle' => cym.Browser.getCurrent().handle.value}));

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
  }

  public with sharing class RenameCredential extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id id = (Id) params.remove('id');
      String name = (String) params.remove('name');
      Id userId = params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }

      cym.Community.Authenticator webauthn_platform = cym.Community.getCurrent().authenticators.find('name', 'webauthn_platform');

      if (webauthn_platform == null) throw new InvalidArgumentException('invalid_authenticator');

      cym.Browser.Session session = WebAuthnController.findOrAddSession(cym.Browser.getCurrent(), userId);

      // During a normal registration flow, the authenticator is always used in the current session, must check it before accepting the name change
      Boolean isWebAuthnPlatformExecutedInCurrentSession = false;
      for (cym.Browser.SessionVerification verif : session.verifications.asList()) {
        if (verif.authenticatorId == webauthn_platform.id) {isWebAuthnPlatformExecutedInCurrentSession = true; break;}
      }

      if (!isWebAuthnPlatformExecutedInCurrentSession) throw new InvalidArgumentException('invalid_authenticator');

      String response = session.getRemoteApex(
        WebAuthnController.RenameCredentialRemote.class
      ).invoke(
        JSON.serialize(
          new Map<String, Object> {
            'id' => id,
            'name' => name
          }
        )
      );

      return (Map<String, Object>) JSON.deserializeUntyped(response);
    }
  }


  global class InitRegisterWebAuthnRemote extends cym.Remote.Function {
    global override String execute(String params) {
      Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(params);

      cym.Community context = cym.Community.getCurrent();
      cym.WebAuthn auth = (cym.WebAuthn) context.authenticators.find('name', (String) o.get('authenticator'));
      String handle = (String) o.get('handle');

      return JSON.serialize(auth.initRegistration(new Map<String, Object> { 'handle' => handle }));
    }
  }

  global class VerifyRegisterWebAuthnRemote extends cym.Remote.Function {
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
            'id' => credential.id,
            'credentialId' => EncodingUtil.base64Encode(credential.credentialId),
            'aaguid' => EncodingUtil.base64Encode(credential.aaguid),
            'counter' => credential.counter,
            'transports' => credential.transports
          }
        }
      );
    }
  }

  global class RenameCredentialRemote extends cym.Remote.Function {
    global override String execute(String params) {
      Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(params);

      Id id = (Id) o.get('id');
      String name = (String) o.get('name');

      cym.WebAuthn.Credential credential;
      cym.WebAuthn.Credential[] credentials = cym.WebAuthn.getAllCredentials();
      for(cym.WebAuthn.Credential cred : credentials) if (cred.id == id) {credential = cred; break;}

      if (credential == null) return JSON.serialize(new Map<String, Object> {'error' => 'invalid_credential'});

      credential = credential.rename(name);

      return JSON.serialize(new Map<String, Object> {'name' => credential.id, 'name' => credential.name});
    }
  }

  global class InitVerifyWebAuthnRemote extends cym.Remote.Function {
    global override String execute(String params) {
      Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(params);

      cym.Community context = cym.Community.getCurrent();
      cym.WebAuthn auth = (cym.WebAuthn) context.authenticators.find('name', (String) o.get('authenticator'));
      String handle = (String) o.get('handle');

      return JSON.serialize(auth.initVerification(new Map<String, Object> {'handle' => handle}));
    }
  }

  global class VerifyVerifyWebAuthnRemote extends cym.Remote.Function {
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

  public class InvalidArgumentException extends Exception {}
}
