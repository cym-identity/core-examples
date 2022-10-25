global with sharing class TotpChallengeController { // NOPMD.AvoidGlobalModifier

  public class InitRegister extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      String requestId = (String) params.get('requestId');
      // Must check that the user is allowed to initialize a registration
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);
      if (UserInfo.getUserId() != userId) {
        if (String.isBlank(requestId)) throw new InvalidInvocationException('Unauthorized');

        // Check that the user has entered another factor in the current session
        if (session.verifications.find('requestId', requestId) == null) throw new InvalidInvocationException('Unauthorized');
      }

      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'totp');
      Map<String, Object> init = (Map<String, Object>) authenticator.provider.initRegistration(session, params);
      Map<String, Object> response = new Map<String, Object> ();
      response.putAll(init);
      response.put('mobileUrl', 'otpauth://totp/' + EncodingUtil.urlEncode(new UserUtils.Repository().findById(userId).Username, 'UTF-8') + '?secret=' + (String) init.get('secret'));
      return response;
    }
  }

  public class VerifyRegister extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      String secret = (String) params.get('secret');
      String otp = (String) params.get('otp');
      String requestId = (String) params.get('requestId');
      TwoFactorMethodsInfo info = new UserUtils.Repository().getTwoFactorInfo(userId);
      if (info.HasTotp) throw new AuraHandledException('invalid_registration');

      cym.Browser browser = cym.Browser.getCurrent();
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, userId);
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'totp');

      Map<String, Object> response = (Map<String, Object>) authenticator.provider.verifyRegistration(session, params);
      Boolean isValid = (Boolean) response.get('isValid');

      if (isValid) session.apply(authenticator, requestId);
      return new Map<String, Object> { 'isValid' => isValid };
    }
  }

  public class VerifyVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String requestId = (String) params.remove('requestId');
      params.put('description', 'Totp challenge');

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), (Id) params.get('userId'));
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'totp');

      Map<String, Object> response = (Map<String, Object>) authenticator.provider.verifyVerification(session, params);
      Boolean isValid = (Boolean) response.get('isValid');
      if (isValid) session.apply(authenticator, requestId);
      return new Map<String, Object> { 'isValid' => isValid };
    }
  }

  public class InvalidInvocationException extends Exception {}
}
