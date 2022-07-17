global with sharing class TwilioVerifyRealmExtensionCallable implements Callable { // NOPMD.AvoidGlobalModifier
  global Object call(String action, Map<String, Object> args) {
    // User current_user = new RealmExtensionCallable.Repository().findById((Id) args.get('user_id'));
    // if (action == 'ciba:init:challenge') {
    //   Community.Authenticator service = (Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'twilio_push');
    //   Object[] factors = service.getFactors(current_user.Id);
    //   if (factors.size() == 0) return null;
    //   Map<String, Object> status = service.challenge(current_user.Id, (String)((Map<String, Object>) factors[0]).get('sid'));
    //   return new Map<String, Object> { 'auth_req_id' => (String) status.get('sid')};
    // }
    // if (action == 'ciba:verify:challenge') {
    //   Community.Authenticator service = (Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'twilio_push');
    //   String status = service.verify((Id) args.get('user_id'), (String) args.get('auth_req_id'));
    //   return new Map<String, Object> { 'status' => status, 'amrs' => service.amrs };
    // }
    return null;
  }
}
