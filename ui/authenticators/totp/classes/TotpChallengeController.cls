global with sharing class TotpChallengeController { // NOPMD.AvoidGlobalModifier

  @AuraEnabled
  public static Map<String, Object> initRegister(Id userId) {
    userId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();
    TwoFactorMethodsInfo info = new UserUtils.Repository().getTwoFactorInfo(userId);
    Map<String, Object> response = new Map<String, Object> {
      'registered' => false
    };
    response.putAll(Auth.SessionManagement.getQrCode());
    return response;
  }

  /**
   * In this sample application, TOTP registration is only done after the user has successfully registered or logged in with another factor (like a password or an SMS)
   */
  @AuraEnabled
  public static Map<String, Object> verifyRegister(String secret, String otp, String handle, String startURL, Id userId){
    if (userId == null) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      userId = UserInfo.getUserId();
    }
    try {
      TwoFactorMethodsInfo info = new UserUtils.Repository().getTwoFactorInfo(userId);
      if (info.HasTotp) throw new AuraHandledException('invalid_registration');

      cym.Browser browser = cym.Browser.fromHandle(handle);
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, userId).activate();
      cym.SalesforceAuthenticator.Totp auth = (cym.SalesforceAuthenticator.Totp) cym.Community.getCurrent().authenticators.find('name', 'totp');


      // Verifying a TOTP requires the connected user
      String response = session.getRemoteApex(TotpChallengeController.RegisterTotp.class).invoke(JSON.serialize (new Map<String, Object> {'authenticator' => 'totp', 'secret' => secret, 'otp' => otp, 'userId' => UserInfo.getUserId()}) );
      Boolean isValid = (Boolean) ((Map<String, Object>) JSON.deserializeUntyped(response)).get('isValid');

      if (isValid) {
        session.apply(auth, null, null);

        PageReference resume = session.resume(startURL);

        return new Map<String, Object> {
          'isValid' => true,
          'redirect' => resume.getUrl()
        };
      } else {
        return new Map<String, Object> {
          'isValid' => false
        };
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  global with sharing class RegisterTotp extends cym.Remote.Function {
    global override String execute(String param) {
      Map<String, Object> args = (Map<String, Object>) JSON.deserializeUntyped(param);
      String secret = (String) args.get('secret');
      String otp = (String) args.get('otp');
      String name = (String) args.get('authenticator');
      cym.SalesforceAuthenticator.Totp auth = (cym.SalesforceAuthenticator.Totp) cym.Community.getCurrent().authenticators.find('name', name);

      return JSON.serialize(auth.verifyRegistration(
        new Map<String, Object> {
          'otp' => otp,
          'secret' => secret,
          'userId' => UserInfo.getUserId()
        }
      ));
    }
  }

  @AuraEnabled
  public static Map<String, Object> verifyVerification(String otp, String handle, String startURL, Id userId) {
    userId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();

    cym.Browser browser = cym.Browser.fromHandle(handle);
    cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, userId).activate();


    // Verifying a TOTP requires the user to be logged in
    String response = session.getRemoteApex(TotpChallengeController.VerifyTotp.class).invoke(JSON.serialize(new Map<String, Object> {'otp' => otp, 'authenticator' => 'totp'}));
    Boolean isValid = (Boolean) ((Map<String, Object>) JSON.deserializeUntyped(response)).get('isValid');

    if (isValid) {
      cym.Community.Authenticator auth = cym.Community.getCurrent().authenticators.find('name', 'totp');
      PageReference resume = session.apply(auth, null, null).resume(startURL);
      return new Map<String, Object> {
        'isValid' => true,
        'redirect' => resume.getUrl()
      };
    } else {
      return new Map<String, Object> {
        'isValid' => false
      };
    }
  }

  global with sharing class VerifyTotp extends cym.Remote.Function {
    global override String execute(String param) {
      Map<String, Object> args = (Map<String, Object>) JSON.deserializeUntyped(param);
      String otp = (String) args.get('otp');
      String name = (String) args.get('authenticator');
      cym.SalesforceAuthenticator.Totp auth = (cym.SalesforceAuthenticator.Totp) cym.Community.getCurrent().authenticators.find('name', name);

      return JSON.serialize(auth.verifyVerification(
        new Map<String, Object> {
          'otp' => otp,
          'description' => 'Community Authentication'
        }
      ));
    }
  }
}
