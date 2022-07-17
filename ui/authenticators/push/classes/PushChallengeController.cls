global with sharing class PushChallengeController { // NOPMD.AvoidGlobalModifier

  public with sharing class InitRegistration extends Fetch.Function {
    public override Object execute(Map<String, Object> param) {
      String startURL = (String) param.get('startURL');
      // Only allow the registration for already logged in users
      if (Auth.CommunitiesUtil.isGuestUser()) throw new AuraHandledException('This method cannot be called by a guest user');
      // Start a SalesforceAuthenticatorRegistration
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'salesforce_push');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), UserInfo.getUserId());
      PageReference pr = (PageReference) authenticator.provider.initRegistration(session, new Map<String, Object> {'startURL' => startURL});
      return new Map<String, Object> {'redirect' => pr.getUrl()};
    }
  }

  public with sharing class InitVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> param) {
      // Only allow the registration for already logged in users
      if (Auth.CommunitiesUtil.isGuestUser()) throw new AuraHandledException('This method cannot be called by a guest user');
      // Start a SalesforceAuthenticatorRegistration
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'salesforce_push');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), UserInfo.getUserId());
      return authenticator.provider.initVerification(session, null);
    }
  }

  public with sharing class VerifyVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> param) {
      // Only allow the registration for already logged in users
      if (Auth.CommunitiesUtil.isGuestUser()) throw new AuraHandledException('This method cannot be called by a guest user');
      // Start a SalesforceAuthenticatorRegistration
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'salesforce_push');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), UserInfo.getUserId());
      Map<String, Object> result = (Map<String, Object>) authenticator.provider.verifyVerification(session, param);
      if ((Boolean) result.get('success')) session.apply(authenticator);
      return result;
    }
  }

}
