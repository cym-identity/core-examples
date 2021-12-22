global with sharing class ChallengeController { // NOPMD.AvoidGlobalModifier
  public static final transient Map<String, Object> RESPONSE = new Map<String, Object>();
  public String log {
    get {
      try {
        return JSON.serialize(RESPONSE);
      } catch (Exception ex) {
        return JSON.serialize(new Map<String, Object> {
          'error' => ex.getMessage(),
          'error_description' => null,
          'error_stack_trace' => ex.getStackTraceString().split('\n')
        });
      }
    }
  }

  public String contentType {get; private set;}

  public String backgroundColor {get; private set;}


  public ChallengeController() {}

  public PageReference init() {
    Map<String, String> headers = ApexPages.currentPage().getHeaders();

    this.contentType = headers.get('Accept') == 'application/json' ? 'application/json;charset=UTF-8' : 'text/html;charset=UTF-8';

    // This is a POST request from Javascript
    if (headers.get('Accept') == 'application/json' && headers.containsKey('Content-Length') && Integer.valueOf(headers.get('Content-Length')) > 0) {
      String origin = headers.get('Origin');
      String allowedOrigin = 'https://' + new URL(Site.getBaseRequestUrl()).getHost();
      // Do not support CORS
      ApexPages.currentPage().getHeaders().put('Access-Control-Allow-Origin', new URL(Site.getBaseRequestUrl()).getHost());

      // Only requests from the same domain are processed
      if (origin != allowedOrigin) return null;

      // This an XHR request made from the page itself, process it
      try {
        Map<String, String> body = ApexPages.currentPage().getParameters();

        switch on body.remove('action') {
          when 'loadContext' {
            if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage(body.get('startURL'));
            RESPONSE.putAll(loadContext(body.get('startURL')));
            return null;
          }

          when else {
            return null;
          }
        }
      } catch (Exception ex) {
        RESPONSE.putAll(ConverterUtils.toMap(ex));
      }
    } else {
      this.backgroundColor = [SELECT AssetCategory, TextAsset FROM CustomBrandAsset WHERE AssetCategory = 'LoginQuaternaryColor' AND CustomBrandId IN (SELECT Id FROM CustomBrand WHERE ParentId =: Network.getNetworkId())].TextAsset; 
      RESPONSE.putAll(Auth.SessionManagement.getCurrentSession());
    }

    return null;
  }

  public Map<String, Object> loadContext(String startURL) {
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
      TwilioVerify.Push service = new TwilioVerify.Push(context.authenticators.find('name', 'twilio_push'));
      if (service.getFactors().size() > 0) user_factors.add('twilio_push');
    }

    return response;
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
      cym.Community.Authenticator auth = context.authenticators.find('name', 'twilio_push');
      TwilioVerify.Push service = new TwilioVerify.Push(auth);
      return service.getFactors();
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Object initTwilioPush(String sid) {
    try {
      cym.Community context = cym.Community.getCurrent();
      cym.Community.Authenticator auth = context.authenticators.find('name', 'twilio_push');
      TwilioVerify.Push service = new TwilioVerify.Push(auth);
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
      cym.Community.Authenticator auth = context.authenticators.find('name', 'twilio_push');
      TwilioVerify.Push service = new TwilioVerify.Push(auth);
      String verification = service.verify(challenge);
      if (verification != 'approved') return verification;
      // context.session.verifications.add(auth, null, null);
      return verification;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

}
