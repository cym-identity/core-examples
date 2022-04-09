
global with sharing class ChallengeController { // NOPMD.AvoidGlobalModifier
  public String backgroundColor {get; private set;}
  public ChallengeController() {
    this.backgroundColor = [SELECT AssetCategory, TextAsset FROM CustomBrandAsset WHERE AssetCategory = 'LoginQuaternaryColor' AND CustomBrandId IN (SELECT Id FROM CustomBrand WHERE ParentId =: Network.getNetworkId())].TextAsset; 
  }

  public with sharing class LoadContext extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Map<String, Object> response = new Map<String, Object> ();
      cym.Community context = cym.Community.getCurrent();
      cym.Community.Authenticator webauthn_platform = context.authenticators.find('name', 'webauthn_platform');

      cym.Browser browser = cym.Browser.getCurrent();
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(browser, UserInfo.getUserId()).sync();

      String[] user_factors = new UserUtils.Repository().getUserFactors(UserInfo.getUserId());
      if (user_factors.indexOf('password') > -1) user_factors.remove(user_factors.indexOf('password'));
      RESPONSE.put('factors', user_factors);

      // System.debug(session);
      // for (cym.Browser.SessionVerification v : session.verifications.asList()) System.debug(v);


      String[] sessionFactors = new String[] {};
      for (cym.Browser.SessionVerification verification : session.verifications.asList()) {
        cym.Community.Authenticator authenticator = context.authenticators.find('id', verification.authenticatorId);
        if (authenticator != null && verification.isActive()) sessionFactors.add(authenticator.name);
      }
      RESPONSE.put('sessionFactors', sessionFactors);

      if (context.authenticators.find('name', 'twilio_push') != null) {
        TwilioVerify.Push service = (TwilioVerify.Push) context.authenticators.find('name', 'twilio_push');
        if (service.getFactors().size() > 0) user_factors.add('twilio_push');
      }

      return response;
    }
  }

  private static Map<String, Object> sendSms(User current_user, cym.Community context) {
    if (String.isNotBlank(current_user.MobilePhone)) {
      return Auth.CommunitiesUtil.isInternalUser() ? sendSalesforceSms(current_user, context) : sendTwilioSms(current_user, context);
    }
    return null;
  }

  private static Map<String, Object> sendTwilioSms(User current_user, cym.Community context) {
    // Assuming a Twilio SMS authenticator with name `twilio_verify` exists on the community
    // TwilioVerify.Sms authenticator = new TwilioVerify.Sms(context.authenticators.find('name', 'twilio_verify'));
    // Trigger an SMS directly
    // Map<String, Object> verification = authenticator.initChallenge(
    //   new Map<String, Object> {
    //     'phoneNumber' => current_user.MobilePhone
    //     // Override the Twilio Locale for example
    //     // 'Locale' => UserInfo.getLanguage().substring(0, 2)
    //   }
    // );
    Map<String, Object> verification = new Map<String, Object> {
      'transactionId' => EncodingUtil.base64Encode(Crypto.generateAESKey(128))
    };
    if (verification.containsKey('sid')) {
      return new Map<String, Object> {
        'phoneNumber' => current_user.MobilePhone,
        'transactionId' => (String) verification.get('sid')
      };
    }
    return verification;
  }

  private static Map<String, Object> sendSalesforceSms(User current_user, cym.Community context) {
    // Assuming a Twilio SMS authenticator with name `twilio_verify` exists on the community
    TwilioVerify.Sms authenticator = new TwilioVerify.Sms(context.authenticators.find('name', 'twilio_verify'));
    // Trigger an SMS directly
    Map<String, Object> verification = authenticator.initChallenge(
      new Map<String, Object> {
        'phoneNumber' => current_user.MobilePhone
        // Override the Twilio Locale for example
        // 'Locale' => UserInfo.getLanguage()
      }
    );
    return new Map<String, Object> {
      'phoneNumber' => current_user.MobilePhone,
      'transactionId' => (String) verification.get('sid')
    };
  }


  @AuraEnabled
  public static Map<String, Object> initVerificationSms(String phoneNumber) {
    User u = new User(Id = UserInfo.getUserId(), MobilePhone = phoneNumber);
    Map<String, Object> response = sendSms(u, cym.Community.getCurrent());
    return response;
  }

  @AuraEnabled
  public static Map<String, Object> verifyVerificationSms(String transactionId, String otp) {
    if (true) return new Map<String, Object> { 'result' => true };
    cym.Community context = cym.Community.getCurrent();
    cym.Community.Authenticator authenticator = context.authenticators.find('name', 'twilio_verify');
    TwilioVerify.Sms sms = new TwilioVerify.Sms(authenticator);
    // Trigger an SMS directly
    Map<String, Object> verification = sms.verifyChallenge(
      new Map<String, Object> {
        'Code' => otp,
        // Override the Twilio Locale for example
        'VerificationSid' => transactionId
      }
    );
    if (verification.containsKey('status') && (String) verification.get('status') == 'approved') {
      try {
        // Update the user with the new verified phone Number
        update new User(Id = UserInfo.getUserId(), MobilePhone = (String) verification.get('to')); // NOPMD.ApexCrudViolation
        // context.session.verifications.add(authenticator, null, null);
      } catch (Exception ex) {
        verification.putAll(new Map<String, Object> {
          'error' => ex.getMessage(),
          'error_description' => 'finishLoginFlow',
          'error_stack_trace' => ex.getStackTraceString().split('\n')
        });
      }
    }
    return verification;
  }

  @AuraEnabled
  public static Object[] listAllTwilioPush(){
    try {
      cym.Community context = cym.Community.getCurrent();
      TwilioVerify.Push service = (TwilioVerify.Push) context.authenticators.find('name', 'twilio_push');
      return service.getFactors();
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Object initTwilioPush(String sid) {
    try {
      cym.Community context = cym.Community.getCurrent();
      TwilioVerify.Push service = (TwilioVerify.Push) context.authenticators.find('name', 'twilio_push');
      return service.challenge(sid);
      // Object[] factors = service.getFactors();
      // if (factors.size() > 0) {
      // }
      // return null;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static String verifyTwilioPush(String challenge){
    try {
      cym.Community context = cym.Community.getCurrent();
      TwilioVerify.Push service = (TwilioVerify.Push) context.authenticators.find('name', 'twilio_push');
      String verification = service.verify(challenge);
      if (verification != 'approved') return verification;
      // context.session.verifications.add(auth, null, null);
      return verification;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

}