global with sharing class RealmExtensionCallable implements Callable { // NOPMD.AvoidGlobalModifier
  global Object call(String action, Map<String, Object> args) {
    if (action == 'lookup:sub') {
      return new Repository().findByEmail((String) args.get('sub')).Id;
    }

    User current_user = new Repository().findById((Id) args.get('user_id'));
    if (action == 'before:authorize:page') {
      Map<String, Object> request = (Map<String, Object>) args.get('request');
      String[] scopes = ((String) request.get('scope')).split(' ');
      if (scopes.indexOf('l3') > -1 && (
        String.isBlank(current_user.CompanyName) ||
        String.isBlank(current_user.Street) ||
        String.isBlank(current_user.State) ||
        String.isBlank(current_user.PostalCode) ||
        String.isBlank(current_user.City) ||
        String.isBlank(current_user.Country)
      )) {
        return new PageReference('/UpdateProfile');
      }
      if (scopes.indexOf('l2') > -1 && String.isBlank(current_user.CompanyName)) {
        return new PageReference('/UpdateProfile');
      }
      return null;
    }
    if (action == 'get:challenge:page') {
      return new PageReference('/challenge');
    }
    if (action == 'get:claims') {
      Id user_id = (Id) args.get('user_id');
      String[] claims = (String[]) args.get('claims');

      return new Map<String, Object> {
        'accountId' => current_user.Account,
        'accountName' => current_user.Account.Name,
        'accountAddress' => current_user.Account.BillingAddress,
        'sub' => current_user.Email
      };
    }
    if (action == 'get:consent:page') {
      return new PageReference('/approval');
    }
    if (action == 'ciba:init:challenge') {
      TwilioVerify.Push service = new TwilioVerify.Push(cym.Community.getCurrent().authenticators.find('name', 'twilio_push'));
      Object[] factors = service.getFactors(current_user.Id);
      if (factors.size() == 0) return null;
      Map<String, Object> status = service.challenge(current_user.Id, (String)((Map<String, Object>) factors[0]).get('sid'));
      return new Map<String, Object> { 'auth_req_id' => (String) status.get('sid')};
    }
    if (action == 'ciba:verify:challenge') {
      cym.Community.Authenticator authenticator = cym.Community.getCurrent().authenticators.find('name', 'twilio_push');
      TwilioVerify.Push service = new TwilioVerify.Push(authenticator);
      String status = service.verify((Id) args.get('user_id'), (String) args.get('auth_req_id'));
      return new Map<String, Object> { 'status' => status, 'amrs' => authenticator.amrs };
    }
    return null;
  }

  public without sharing class Repository {
    public User findById(Id user_id) {
      return [SELECT
        Id, Name, FirstName, LastName, CommunityNickname, Username, SmallPhotoUrl,
        Email, TimeZoneSidKey, LanguageLocaleKey, MobilePhone, Street, State, PostalCode, City, Country,
        LastModifiedDate, CompanyName,
        Account.Name, Account.BillingAddress, Account.Id
        FROM User
      WHERE Id = :user_id];
    }
    public User findByEmail(String email) {
      return [SELECT Id FROM User WHERE Email = :email];
    }
  }
}
