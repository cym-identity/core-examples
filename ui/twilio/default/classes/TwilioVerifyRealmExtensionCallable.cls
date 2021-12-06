public with sharing class TwilioVerifyRealmExtensionCallable implements Callable {
  public Object call(String action, Map<String, Object> args) {
    User current_user = new RealmExtensionCallable.Repository().findById((Id) args.get('user_id'));
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
}
