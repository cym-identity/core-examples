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

    cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', name); // NOPMD.ApexXSSFromUrlParam
    if (authenticator == null) return null;

    String type = (String) authenticator.provider.get('type');
    String userVerification = (String) authenticator.provider.get('user_verification');

    RESPONSE.put('authenticator', new Map<String, Object> { 'type' => type, 'userVerification' => userVerification, 'name' => authenticator.name});
    RESPONSE.put('baseUrl', Site.getBaseRequestUrl());

    return null;
  }

  public with sharing class InitRegisterWebAuthn extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', (String) params.remove('authenticator'));

      return authenticator.provider.initRegistration(session, new Map<String, Object> ());
    }
  }

  public with sharing class VerifyRegisterWebAuthn extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String requestId = (String) params.remove('requestId');
      Id userId = (String) params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', (String) params.remove('authenticator'));

      // Polyfill the transports based on the authenticator type. It allows to remember if the credential is platform specific or not
      if (params.get('transports') == '[]') params.put('transports', (String) authenticator.get('type') == 'platform' ? '["internal"]' : '["usb", "nfc", "ble"]');

      Map<String, Object> response = (Map<String, Object>) authenticator.provider.verifyRegistration(session, params);
      cym.WebAuthn.Credential credential = (cym.WebAuthn.Credential) response.get('credential');

      try {
        session.apply(authenticator, requestId);
        return new Map<String, Object> {
          'credential' => new Map<String, Object> {
            'id' => credential.id,
            'credentialId' => EncodingUtil.base64Encode(credential.credentialId),
            'aaguid' => EncodingUtil.base64Encode(credential.aaguid),
            'counter' => credential.counter,
            'transports' => credential.transports
          }
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
      Id userId = params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', (String) params.remove('authenticator'));

      return authenticator.provider.initVerification(session, new Map<String, Object> {});
    }
  }

  public with sharing class VerifyVerifyWebAuthn extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String requestId = (String) params.remove('requestId');
      Id userId = (String) params.get('userId') != 'undefined' ? (Id) params.remove('userId') : null;
      if (userId == null) {
        if (Auth.CommunitiesUtil.isGuestUser()) return null;
        userId = UserInfo.getUserId();
      }

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', (String) params.remove('authenticator'));

      Map<String, Object> response = (Map<String, Object>) authenticator.provider.verifyVerification(session, params);
      Boolean isValid = (Boolean) response.get('isValid');

      if (isValid) {
        try {
          session.apply(authenticator, requestId);
          return new Map<String, Object> {
            'isValid' => true
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

      cym.Community.Authenticator webauthn_platform = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'webauthn_platform');

      if (webauthn_platform == null) throw new InvalidArgumentException('invalid_authenticator');

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);

      // During a normal registration flow, the authenticator is always used in the current session, must check it before accepting the name change
      if (session.verifications.find('authenticator', webauthn_platform.id) == null) throw new InvalidArgumentException('invalid_authenticator');

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

  global class RenameCredentialRemote extends cym.Remote.Function {
    global override String execute(String params) {
      Map<String, Object> o = (Map<String, Object>) JSON.deserializeUntyped(params);

      Id id = (Id) o.get('id');
      String name = (String) o.get('name');

      cym.WebAuthn.Credential credential = (cym.WebAuthn.Credential) cym.WebAuthn.getAllCredentials().find('id', id);
      if (credential == null) return JSON.serialize(new Map<String, Object> {'error' => 'invalid_credential'});

      credential = credential.rename(name);

      return JSON.serialize(new Map<String, Object> {'name' => credential.id, 'name' => credential.name});
    }
  }

  public class InvalidArgumentException extends Exception {}
}
