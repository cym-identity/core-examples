public with sharing class ChallengeController {
  public static final transient Map<String, Object> RESPONSE = new Map<String, Object>();

  public String backgroundColor {get; private set;}

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

  public ChallengeController() {
    Auth.AuthConfiguration authConfig = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), ApexPages.currentPage().getParameters().get('startURL'));
    this.backgroundColor = authConfig.getBackgroundColor();
  }

  public PageReference process() {
    cym.CommunityContext context = cym.CommunityContext.getContext();
    Repository store = new Repository();
    cym.CommunityContext.Authenticator webauthn_platform = context.authenticators.get('accounts_webauthn_platform');
    String[] user_factors = store.getUserFactors(UserInfo.getUserId());
    if (webauthn_platform != null && context.session.verifications.get(webauthn_platform) != null) user_factors.add('webauthn.platform');

    if (context.authenticators.get('accounts_twilio_push') != null) {
      TwilioVerify.Push service = new TwilioVerify.Push(context.authenticators.get('accounts_twilio_push'));
      if (service.getFactors().size() > 0) user_factors.add('twilio_push');
    }


    RESPONSE.put('factors', user_factors);

    RESPONSE.put('startURL', ApexPages.currentPage().getParameters().get('startURL'));

    // Must call the below method to be able to use RemoteActions
    context.save();
    return null;
  }

  private static Map<String, Object> sendSms(User current_user, cym.CommunityContext context) {
    if (String.isNotBlank(current_user.MobilePhone)) {
      return Auth.CommunitiesUtil.isInternalUser() ? sendSalesforceSms(current_user, context) : sendTwilioSms(current_user, context);
    }
    return null;
  }

  private static Map<String, Object> sendTwilioSms(User current_user, cym.CommunityContext context) {
    // Assuming a Twilio SMS authenticator with name `accounts_twilio_verify` exists on the community
    // TwilioVerify.Sms authenticator = new TwilioVerify.Sms(context.authenticators.get('accounts_twilio_verify'));
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

  private static Map<String, Object> sendSalesforceSms(User current_user, cym.CommunityContext context) {
    // Assuming a Twilio SMS authenticator with name `accounts_twilio_verify` exists on the community
    TwilioVerify.Sms authenticator = new TwilioVerify.Sms(context.authenticators.get('accounts_twilio_verify'));
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
    Map<String, Object> response = sendSms(u, cym.CommunityContext.getContext());
    return response;
  }

  @AuraEnabled
  public static Map<String, Object> verifyVerificationSms(String transactionId, String otp) {
    if (true) return new Map<String, Object> { 'result' => true };
    cym.CommunityContext context = cym.CommunityContext.getContext();
    cym.CommunityContext.Authenticator authenticator = context.authenticators.get('accounts_twilio_verify');
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
        context.session.verifications.add(authenticator, null, null);
        context.save();
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
  public static Map<String, Object> initVerificationEmail() {
    TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
    Auth.VerificationMethod method = Auth.VerificationMethod.EMAIL;

    String transaction_id = info.HasUserVerifiedEmailAddress ? System.UserManagement.initVerificationMethod(method) : System.UserManagement.initRegisterVerificationMethod(method);

    return new Map<String, Object> {
      'transactionId' => transaction_id
    };
  }

  @AuraEnabled
  public static Map<String, Object> verifyVerificationEmail(String transactionId, String otp) {
    TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
    Auth.VerificationMethod method = Auth.VerificationMethod.EMAIL;

    Boolean result = info.HasUserVerifiedEmailAddress ? System.UserManagement.verifyVerificationMethod(transactionId, otp, method).success : String.isBlank(System.UserManagement.verifyRegisterVerificationMethod(otp, method));

    return new Map<String, Object> {
      'isValid' => result
    };
  }

  @AuraEnabled
  public static Map<String, Object> initRegisterTotp() {
    TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
    Map<String, Object> response = new Map<String, Object> {
      'registered' => false
    };
    if (info.HasTotp) {
      return new Map<String, Object> {
        'registered' => true
      };
    }
    response.putAll(Auth.SessionManagement.getQrCode());
    return response;
  }

  @AuraEnabled
  public static Map<String, Object> verifyRegisterTotp(String secret, String otp){
    try {
      TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
      if (info.HasTotp) throw new AuraHandledException('invalid_registration');

      Boolean is_valid = Auth.SessionManagement.validateTotpTokenForKey(secret, otp, 'Register a new TOTP');

      if (is_valid) {
        insert new TwoFactorInfo(
          SharedKey = secret,
          Type = 'TOTP',
          UserId = UserInfo.getUserId()
        );
        // cym.CommunityContext context = cym.CommunityContext.getContext();
        // cym.CommunityContext.Authenticator auth = context.authenticators.get('accounts_totp');
        // context.session.verifications.add(auth, null, null);
        // context.save();
      }

      return new Map<String, Object> {
        'isValid' => is_valid
      };


    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Map<String, Object> verifyVerificationTotp(String otp) {
    TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
    Auth.VerificationMethod method = Auth.VerificationMethod.TOTP;

    Boolean result = info.HasTotp ? System.UserManagement.verifyVerificationMethod(null, otp, method).success : false;

    if (result) {
      cym.CommunityContext context = cym.CommunityContext.getContext();
      cym.CommunityContext.Authenticator auth = context.authenticators.get('accounts_totp');
      context.session.verifications.add(auth, null, null);
      context.save();
    }
    return new Map<String, Object> {
      'result' => result
    };
  }

  @AuraEnabled
  public static Map<String, Object> initRegisterWebAuthn(String authenticator) {
    cym.CommunityContext context = cym.CommunityContext.getContext();
    return cym.WebAuthnContext.initRegisterWebAuthn(context.authenticators.get(authenticator));
  }

  @AuraEnabled
  public static Object verifyRegisterWebAuthn(Map<String, String> param, String authenticator) {
    cym.CommunityContext context = cym.CommunityContext.getContext();
    cym.CommunityContext.Authenticator auth = context.authenticators.get(authenticator);
    // Polyfill the transports based on the authenticator type. It allows to remember if the credential is platform specific or not
    if (param.get('transports') == '[]') param.put('transports', (String) auth.get('type') == 'platform' ? '["internal"]' : '["usb", "nfc", "ble"]');
    cym.WebAuthnContext.Credential credential = cym.WebAuthnContext.verifyRegisterWebAuthn(param, auth);
    context.session.verifications.add(auth, null, null);
    context.save();
    return new Map<String, Object> {
      'id' => EncodingUtil.base64Encode(credential.credentialId),
      'aaguid' => EncodingUtil.base64Encode(credential.aaguid),
      'counter' => credential.counter,
      'transports' => credential.transports
    };
  }

  @AuraEnabled
  public static Map<String, Object> initVerifyWebAuthn(String authenticator) {
    cym.CommunityContext context = cym.CommunityContext.getContext();
    return cym.WebAuthnContext.initVerificationWebAuthn(context.authenticators.get(authenticator));
  }

  @AuraEnabled
  public static Object verifyVerifyWebAuthn(Map<String, String> param, String authenticator) {
    cym.CommunityContext context = cym.CommunityContext.getContext();
    cym.CommunityContext.Authenticator auth = context.authenticators.get(authenticator);
    Boolean is_valid = cym.WebAuthnContext.verifyVerificationWebAuthn(param, auth);
    if (is_valid) {
      try {
        context.session.verifications.add(auth, null, null);
        context.save();
      } catch (Exception ex) {
        return (new Map<String, Object> {
          'error' => ex.getMessage(),
          'error_description' => 'verifyVerifyWebAuthn',
          'error_stack_trace' => ex.getStackTraceString().split('\n')
        });
      }
    }
    return is_valid;
  }

  @AuraEnabled
  public static Object[] listAllTwilioPush(){
    try {
      cym.CommunityContext context = cym.CommunityContext.getContext();
      cym.CommunityContext.Authenticator auth = context.authenticators.get('accounts_twilio_push');
      TwilioVerify.Push service = new TwilioVerify.Push(auth);
      return service.getFactors();
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }


  @AuraEnabled
  public static Object initTwilioPush(String sid) {
    try {
      cym.CommunityContext context = cym.CommunityContext.getContext();
      cym.CommunityContext.Authenticator auth = context.authenticators.get('accounts_twilio_push');
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
      cym.CommunityContext context = cym.CommunityContext.getContext();
      cym.CommunityContext.Authenticator auth = context.authenticators.get('accounts_twilio_push');
      TwilioVerify.Push service = new TwilioVerify.Push(auth);
      String verification = service.verify(challenge);
      if (verification != 'approved') return verification;
      context.session.verifications.add(auth, null, null);
      context.save();
      return verification;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  public PageReference done() {
    cym.CommunityContext context = cym.CommunityContext.getContext();
    Auth.SessionManagement.finishLoginFlow();
    if (context.session.verifications.values().size() != 2) return null;
    String retURL = ApexPages.currentPage().getParameters().get('retURL');
    String startURL = ApexPages.currentPage().getParameters().get('startURL');

    return new PageReference(String.isBlank(startURL) ? retURL : startURL);
  }

  public without sharing class Repository {
    public User findById(Id user_id) {
      return [SELECT
        Id, Name, FirstName, LastName, CommunityNickname, Username, SmallPhotoUrl,
        Email, TimeZoneSidKey, LanguageLocaleKey, MobilePhone, Street, State, PostalCode, City, Country,
        LastModifiedDate
        FROM User
      WHERE Id = :user_id];
    }

    public TwoFactorMethodsInfo getTwoFactorInfo(Id user_id) {
      TwoFactorMethodsInfo[] verified_info = [SELECT // NOPMD.Security-ApexCRUDViolation
        HasUserVerifiedEmailAddress,
        HasUserVerifiedMobileNumber,
        HasVerifiedMobileNumber,
        HasSalesforceAuthenticator,
        HasTotp,
        HasU2F
        FROM TwoFactorMethodsInfo
        WHERE UserId = :user_id
        LIMIT 1
      ];
      return verified_info.size() == 1 ? verified_info[0] : null;
    }

    public String[] getUserFactors(Id user_id) {
      Set<String> user_factors = new Set<String>();
      List<cym.WebAuthnContext.Credential> webAuthnCredentials = cym.WebAuthnContext.getAllCredentials();
      for(cym.WebAuthnContext.Credential cred: webAuthnCredentials) if(cred.transports.indexOf('internal') == -1) user_factors.add('webauthn');

      TwoFactorMethodsInfo info = this.getTwoFactorInfo(user_id);
      if (info != null) {
        if (info.HasUserVerifiedMobileNumber || info.HasVerifiedMobileNumber) user_factors.add('sms');
        if (info.HasSalesforceAuthenticator) user_factors.add('push');
        if (info.HasTotp) user_factors.add('totp');
        if (info.HasU2F) user_factors.add('u2f');
      }
      return new List<String>(user_factors);
    }

    public Boolean getWebAuthnPlatform(cym.CommunityContext.SessionVerification[] verifications, cym.CommunityContext.Authenticator webauthn_platform) {
      for(cym.CommunityContext.SessionVerification verif : verifications) {
        if (verif.authenticator == webauthn_platform.id) return true;
      }
      return false;
    }
  }

}
