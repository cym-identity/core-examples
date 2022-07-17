global with sharing class EmailChallengeController { // NOPMD-AvoidGlobalModifier
  public with sharing class InitRegistration extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId).activate();
      return ((cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'email')).provider.initRegistration(session, null);
    }
  }

  public with sharing class VerifyRegistration extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      String requestId = (String) params.get('requestId');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId).activate();

      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'email');
      Map<String, Object> response = (Map<String, Object>) authenticator.provider.verifyRegistration(session, params);
      if (! (Boolean) response.get('isValid')) return new Map<String, Object> { 'isValid' => false };
      session.apply(authenticator, requestId);
      return new Map<String, Object> { 'isValid' => true };
    }
  }


  public with sharing class InitVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId).activate();
      return ((cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'email')).provider.initVerification(session, null);  
    }
  }

  public with sharing class VerifyVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
        Id userId = (Id) params.get('userId');
        String requestId = (String) params.get('requestId');
        cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId).activate();
        cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'email');

        Map<String, Object> response = (Map<String, Object>) authenticator.provider.verifyVerification(session, params);

        if (!(Boolean) response.get('isValid')) return new Map<String, Object> { 'isValid' => false };

        session.apply(authenticator, requestId);
        return new Map<String, Object> { 'isValid' => true };
    }
  }
}
