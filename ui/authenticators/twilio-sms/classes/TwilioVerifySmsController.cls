public with sharing class TwilioVerifySmsController {

  public class InitVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      String requestId = (String) params.get('requestId');

      User u = new UserUtils.Repository().findById(userId);
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);

      if (UserUtils.getLoginType(u) != Users.LoginType.phone) throw new InvalidUserException('The user chosen does not have a Mobile Login');

      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'phone');

      Map<String, Object> response = (Map<String, Object>) authenticator.provider.initVerification(session, new Map<String, Object> { 'phoneNumber' => u.MobilePhone });

      return new Map<String, Object> {'sid' => response.get('sid')};
    }
  }

  public without sharing class VerifyVerification extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      String requestId = (String) params.get('requestId');
      String sid = (String) params.get('sid');
      String otp = (String) params.get('otp');

      User u = new UserUtils.Repository().findById(userId);

      if (UserUtils.getLoginType(u) != Users.LoginType.phone) throw new InvalidUserException('The user chosen does not have a Mobile Login');


      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId).activate();
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'phone');

      Map<String, Object> response = (Map<String, Object>) authenticator.provider.verifyVerification(session, new Map<String, Object> { 'phoneNumber' => u.MobilePhone, 'VerificationSid' => sid, 'Code' => otp });

      if (!(Boolean) response.get('valid')) throw new InvalidVerificationException('The OTP entered is either expired or invalid');

      // Mark Phone Number as Verified if not already
      User toUpdate = new User(
        Id = u.Id,
        MobilePhoneVerified__c = ConverterUtils.base64encode(
          // add the UserId to the mobile number to avoid copy paste from one user to the other
          Crypto.generateDigest('SHA-256', Blob.valueOf(u.Id + u.MobilePhone))
        )
      );
      update toUpdate; // NOPMD.ApexCRUDViolation

      session.apply(authenticator, requestId);
      return new Map<String, Object> { 'isValid' => true };
    }
  }

  public class InvalidUserException extends Exception {}
  public class InvalidVerificationException extends Exception {}
}
