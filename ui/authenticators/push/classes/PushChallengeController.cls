global with sharing class PushChallengeController { // NOPMD.AvoidGlobalModifier

  @AuraEnabled
  public static Map<String, Object> initRegistration(String startURL){
    try {
      // Only allow the registration for already logged in users
      if (Auth.CommunitiesUtil.isGuestUser()) throw new AuraHandledException('This method cannot be called by a guest user');
      if (Auth.CommunitiesUtil.isInternalUser()) {
        // Start a SalesforceAuthenticatorRegistration
        cym.SalesforceAuthenticator.Push authenticator = (cym.SalesforceAuthenticator.Push) cym.Community.getCurrent().authenticators.find('name', 'salesforce_push');
        PageReference pr = (PageReference) authenticator.initRegistration(new Map<String, Object> {'startURL' => startURL});
        return new Map<String, Object> {'redirect' => pr.getUrl()};
      } else {
        // Start an External User 
        return null;
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}
