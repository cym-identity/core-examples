public with sharing class EmailChallengeController {
  public with sharing class InitRegistration extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      try {
        cym.SalesforceAuthenticator.Email authenticator = (cym.SalesforceAuthenticator.Email) cym.Community.getCurrent().authenticators.find('name', 'email');
        authenticator.initRegistration(null);
        return new Map<String, Object> {};
      } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
      }
    }
  }

  public with sharing class VerifyRegistration extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String otp = (String) params.get('otp');
      String startURL = (String) params.get('startURL');
      try {
        cym.SalesforceAuthenticator.Email authenticator = (cym.SalesforceAuthenticator.Email) cym.Community.getCurrent().authenticators.find('name', 'email');
        Boolean isValid = (Boolean) ((Map<String, Object>) authenticator.verifyRegistration(new Map<String, Object> {'otp' => otp})).get('isValid');
        if (!isValid) return new Map<String, Object> { 'isValid' => false };
        cym.Browser browser = cym.Browser.getCurrent();
        cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, UserInfo.getUserId()).activate();
        session.apply(authenticator, null, null);
        return new Map<String, Object> {
          'isValid' => true,
          'redirect' => session.resume(startURL).getUrl()
        };
      } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
      }
    }
  }

  public with sharing class InitVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      try {
        cym.SalesforceAuthenticator.Email authenticator = (cym.SalesforceAuthenticator.Email) cym.Community.getCurrent().authenticators.find('name', 'email');
        String transactionId = (String) authenticator.initVerification(null);
        return new Map<String, Object> { 'transactionId' => transactionId };
      } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
      }
    }
  }

  public with sharing class VerifyVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String transactionId = (String) params.get('transactionId');
      String otp = (String) params.get('otp');
      String startURL = (String) params.get('startURL');

      try {
        cym.SalesforceAuthenticator.Email authenticator = (cym.SalesforceAuthenticator.Email) cym.Community.getCurrent().authenticators.find('name', 'email');

        Boolean isValid = (Boolean) ((Map<String, Object>) authenticator.verifyVerification(new Map<String, Object> {'transactionId' => transactionId, 'otp' => otp})).get('isValid');
        if (!isValid) return new Map<String, Object> { 'isValid' => false };

        cym.Browser browser = cym.Browser.getCurrent();
        cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, UserInfo.getUserId()).activate();
        session.apply(authenticator, null, null);

        return new Map<String, Object> {
          'isValid' => true,
          'redirect' => session.resume(startURL).getUrl()
        };
      } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
      }
    }
  }
}
