global with sharing class RealmExtensionCallable implements Callable { // NOPMD.AvoidGlobalModifier
  global Object call(String action, Map<String, Object> args) {
    if (action == 'lookup:sub') {
      return new Repository().findByEmail((String) args.get('sub')).Id;
    }

    User current_user = new Repository().findById((Id) args.get('user_id'));
    if (action == 'before:authorize:page') {
      Map<String, String> request = (Map<String, String>) args.get('request');

      // Check if there are some roles required for login
      if (new Repository().isMissingRequiredClientRoles(request.get('client_id'), (Id) args.get('user_id'))) { return '/forbidden'; }

      String[] scopes = ((String) request.get('scope')).split(' ');
      if (scopes.indexOf('l3') > -1 && (
        String.isBlank(current_user.CompanyName) ||
        String.isBlank(current_user.Street) ||
        String.isBlank(current_user.State) ||
        String.isBlank(current_user.PostalCode) ||
        String.isBlank(current_user.City) ||
        String.isBlank(current_user.Country)
      )) {
        return '/UpdateProfile';
      }
      if (scopes.indexOf('l2') > -1 && String.isBlank(current_user.CompanyName)) {
        return '/UpdateProfile';
      }
      return null;
    }
    if (action == 'get:claims') {
      Id user_id = (Id) args.get('user_id');
      String[] claims = (String[]) args.get('claims');

      // Group roles by client_id
      Map<String, Object[]> roles = new Map<String, Object[]>();
      for (UserClientLink__c link : (UserClientLink__c[]) current_user.UserClientLinks__r) {
        // Init the role array per client_id if not already done
        if (!roles.containsKey(link.ClientRole__r.Client__r.cym__ClientId__c)) roles.put(link.ClientRole__r.Client__r.cym__ClientId__c, new Object[] {});
        roles.get(link.ClientRole__r.Client__r.cym__ClientId__c).add(link.ClientRole__r.Name__c);
      }

      Map<String, Object> response = new Map<String, Object> {
        'accountId' => current_user.Account,
        'accountName' => current_user.CompanyName,
        'accountAddress' => new Map<String, Object> {
          'street' => current_user.Street,
          'state' => current_user.State,
          'zipCode' => current_user.PostalCode,
          'city' => current_user.City,
          'country' => current_user.Country
        },
        'sub' => current_user.Email,
        'roles'=> roles,
        'profile' => Site.getBaseRequestUrl() + '/me'
      };
      response.put('custom_attributes', JSON.deserializeUntyped(JSON.serialize(response)));
      return response;
    }
    if (action == 'get:consent:page') {
      return new PageReference('/approval');
    }
    if (action == 'ciba:init:challenge') {
      TwilioVerify.Push service = (TwilioVerify.Push) cym.Community.getCurrent().authenticators.find('name', 'twilio_push');
      Object[] factors = service.getFactors(current_user.Id);
      if (factors.size() == 0) return null;
      Map<String, Object> status = service.challenge(current_user.Id, (String)((Map<String, Object>) factors[0]).get('sid'));
      return new Map<String, Object> { 'auth_req_id' => (String) status.get('sid')};
    }
    if (action == 'ciba:verify:challenge') {
      TwilioVerify.Push service = (TwilioVerify.Push) cym.Community.getCurrent().authenticators.find('name', 'twilio_push');
      String status = service.verify((Id) args.get('user_id'), (String) args.get('auth_req_id'));
      return new Map<String, Object> { 'status' => status, 'amrs' => service.amrs };
    }
    return null;
  }

  public without sharing class Repository {
    public User findById(Id user_id) {
      return [SELECT // NOPMD.ApexCRUDViolation
        Id, Name, FirstName, LastName, CommunityNickname, Username, SmallPhotoUrl,
        Email, TimeZoneSidKey, LanguageLocaleKey, MobilePhone, Street, State, PostalCode, City, Country,
        LastModifiedDate, CompanyName,
        Account.Name, Account.BillingAddress, Account.Id,

        (SELECT ClientRole__r.Name__c, ClientRole__r.Client__r.cym__ClientId__c FROM UserClientLinks__r WHERE User__c =: user_id)
        FROM User
      WHERE Id = :user_id];
    }
    public User findByEmail(String email) {
      return [SELECT Id FROM User WHERE Email = :email]; // NOPMD.ApexCRUDViolation
    }
    public Boolean isMissingRequiredClientRoles(String client_id, Id user_id) {
      ClientRole__c[] roles = [SELECT Id FROM ClientRole__c WHERE IsRequiredForLogin__c = true AND Client__r.cym__ClientId__c = :client_id]; // NOPMD.ApexCRUDViolation
      if (roles.size() == 0) return false;
      Set<Id> ids = new Set<Id>();
      for (ClientRole__c r : roles) ids.add(r.Id);
      UserClientLink__c[] user_roles = [SELECT Id FROM UserClientLink__c WHERE ClientRole__c IN :ids AND User__c =: user_id]; // NOPMD.ApexCRUDViolation
      return user_roles.size() != roles.size();
    }
  }
}
