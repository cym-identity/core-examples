public with sharing class EmailChallengeController {
  @AuraEnabled
  public static Map<String, Object> initRegistration() {
    cym.SalesforceAuthenticator.Email authenticator = (cym.SalesforceAuthenticator.Email) cym.Community.getCurrent().authenticators.find('name', 'email');

    authenticator.initRegistration(null);

    return new Map<String, Object> {};
  }

  @AuraEnabled
  public static Map<String, Object> verifyRegistration(String otp, String handle, String startURL) {
    cym.SalesforceAuthenticator.Email authenticator = (cym.SalesforceAuthenticator.Email) cym.Community.getCurrent().authenticators.find('name', 'email');

    Boolean isValid = (Boolean) ((Map<String, Object>) authenticator.verifyRegistration(new Map<String, Object> {'otp' => otp})).get('isValid');

    if (!isValid) return new Map<String, Object> { 'isValid' => false };

    cym.Browser browser = cym.Browser.fromHandle(handle);
    cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, UserInfo.getUserId()).activate();
    session.apply(authenticator, null, null);

    return new Map<String, Object> {
      'isValid' => true,
      'redirect' => session.resume(startURL).getUrl()
    };
  }
  @AuraEnabled
  public static Map<String, Object> initVerification() {
    cym.SalesforceAuthenticator.Email authenticator = (cym.SalesforceAuthenticator.Email) cym.Community.getCurrent().authenticators.find('name', 'email');

    String transactionId = (String) authenticator.initVerification(null);

    return new Map<String, Object> { 'transactionId' => transactionId };
  }

  @AuraEnabled
  public static Map<String, Object> verifyVerification(String transactionId, String otp, String handle, String startURL) {
    cym.SalesforceAuthenticator.Email authenticator = (cym.SalesforceAuthenticator.Email) cym.Community.getCurrent().authenticators.find('name', 'email');

    Boolean isValid = (Boolean) ((Map<String, Object>) authenticator.verifyVerification(new Map<String, Object> {'transactionId' => transactionId, 'otp' => otp})).get('isValid');

    if (!isValid) return new Map<String, Object> { 'isValid' => false };

    cym.Browser browser = cym.Browser.fromHandle(handle);
    cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, UserInfo.getUserId()).activate();
    session.apply(authenticator, null, null);

    return new Map<String, Object> {
      'isValid' => true,
      'redirect' => session.resume(startURL).getUrl()
    };
  }
}
