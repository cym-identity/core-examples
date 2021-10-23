global with sharing class ChallengeController { // NOPMD.AvoidGlobalModifier
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
    cym.Community context = cym.Community.getCurrent();
    Repository store = new Repository();
    cym.Community.Authenticator webauthn_platform = context.authenticators.find('name', 'accounts_webauthn_platform');

    if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage(ApexPages.currentPage().getParameters().get('startURL'));

    cym.Browser browser = cym.Browser.getCurrent();
    cym.Browser.Session session = findOrAddSession(browser, UserInfo.getUserId()).sync();

    System.debug(session);
    for (cym.Browser.SessionVerification v : session.verifications.asList()) System.debug(v);

    String[] user_factors = store.getUserFactors(UserInfo.getUserId());

    for (cym.Browser.SessionVerification verification : session.verifications.asList()) {
      if (verification.authenticatorId == webauthn_platform.id) {
        user_factors.add('webauthn.platform');
        break;
      }
    }

    if (context.authenticators.find('name', 'accounts_twilio_push') != null) {
      TwilioVerify.Push service = new TwilioVerify.Push(context.authenticators.find('name', 'accounts_twilio_push'));
      if (service.getFactors().size() > 0) user_factors.add('twilio_push');
    }

    RESPONSE.put('factors', user_factors);
    RESPONSE.put('LoginHistoryId', Auth.SessionManagement.getCurrentSession().get('LoginHistoryId'));
    RESPONSE.put('handle', cym.Browser.getCurrent().handle.extendUntil(Datetime.now().addSeconds(3600)).value);
    RESPONSE.put('basePath', Site.getBaseRequestUrl());

    RESPONSE.put('startURL', ApexPages.currentPage().getParameters().get('startURL')); // NOPMD.ApexXSSFromUrlParam
    return null;
  }

  private static Map<String, Object> sendSms(User current_user, cym.Community context) {
    if (String.isNotBlank(current_user.MobilePhone)) {
      return Auth.CommunitiesUtil.isInternalUser() ? sendSalesforceSms(current_user, context) : sendTwilioSms(current_user, context);
    }
    return null;
  }

  private static Map<String, Object> sendTwilioSms(User current_user, cym.Community context) {
    // Assuming a Twilio SMS authenticator with name `accounts_twilio_verify` exists on the community
    // TwilioVerify.Sms authenticator = new TwilioVerify.Sms(context.authenticators.find('name', 'accounts_twilio_verify'));
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
    // Assuming a Twilio SMS authenticator with name `accounts_twilio_verify` exists on the community
    TwilioVerify.Sms authenticator = new TwilioVerify.Sms(context.authenticators.find('name', 'accounts_twilio_verify'));
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
    cym.Community.Authenticator authenticator = context.authenticators.find('name', 'accounts_twilio_verify');
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
  public static Map<String, Object> initVerificationEmail() {
    TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
    Auth.VerificationMethod method = Auth.VerificationMethod.EMAIL;

    String transaction_id = info.HasUserVerifiedEmailAddress ? System.UserManagement.initVerificationMethod(method) : System.UserManagement.initRegisterVerificationMethod(method);

    return new Map<String, Object> {
      'transactionId' => transaction_id
    };
  }

  @AuraEnabled
  public static Map<String, Object> verifyVerificationEmail(String transactionId, String otp, String handle) {
    TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
    Auth.VerificationMethod method = Auth.VerificationMethod.EMAIL;

    Boolean result = info.HasUserVerifiedEmailAddress ? System.UserManagement.verifyVerificationMethod(transactionId, otp, method).success : String.isBlank(System.UserManagement.verifyRegisterVerificationMethod(otp, method));

    cym.Browser browser = cym.Browser.fromHandle(handle);
    cym.Browser.Session session = findOrAddSession(browser, UserInfo.getUserId()).activate();
    cym.Community.Authenticator auth = cym.Community.getCurrent().authenticators.find('name', 'accounts_totp');
    session.apply(auth, null, null);

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


  /**
   * In this sample application, TOTP registration is only done after the user has successfully registered or logged in with another factor (like a password or an SMS)
   */
  @AuraEnabled
  public static Map<String, Object> verifyRegisterTotp(String secret, String otp, String handle, String startURL){
    try {
      TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
      if (info.HasTotp) throw new AuraHandledException('invalid_registration');

      cym.Browser browser = cym.Browser.fromHandle(handle);
      cym.Browser.Session session = findOrAddSession(browser, UserInfo.getUserId()).activate();

      // Registering a TOTP makes a DML on a Setup object, it must be run in a different transaction
      String response = session.getRemoteApex(ChallengeController.RegisterTotp.class).invoke(JSON.serialize(new Map<String, Object> {'secret' => secret, 'otp' => otp}));
      Boolean isValid = (Boolean) ((Map<String, Object>) JSON.deserializeUntyped(response)).get('isValid');

      if (isValid) {
        cym.Community.Authenticator auth = cym.Community.getCurrent().authenticators.find('name', 'accounts_totp');
        session.apply(auth, null, null);

        PageReference resume = session.resume(startURL);

        return new Map<String, Object> {
          'isValid' => true,
          'redirect' => resume.getUrl()
        };
      } else {
        return new Map<String, Object> {
          'isValid' => false
        };
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  global with sharing class RegisterTotp extends cym.Remote.Function {
    global override String execute(String param) {
      Map<String, Object> args = (Map<String, Object>) JSON.deserializeUntyped(param);
      String secret = (String) args.get('secret');
      String otp = (String) args.get('otp');
      Boolean isValid = Auth.SessionManagement.validateTotpTokenForKey(secret, otp);
      if (!isValid) return JSON.serialize(new Map<String, Object> {'isValid' => false});
      insert new TwoFactorInfo( // NOPMD.ApexCRUDViolation
        SharedKey = secret,
        Type = 'TOTP',
        UserId = UserInfo.getUserId()
      );
      return JSON.serialize(new Map<String, Object> {'isValid' => true});
    }
  }

  @AuraEnabled
  public static Map<String, Object> verifyVerificationTotp(String otp, String handle, String startURL) {
    TwoFactorMethodsInfo info = new Repository().getTwoFactorInfo(UserInfo.getUserId());
    Auth.VerificationMethod method = Auth.VerificationMethod.TOTP;

    cym.Browser browser = cym.Browser.fromHandle(handle);
    cym.Browser.Session session = findOrAddSession(browser, UserInfo.getUserId()).activate();

    // This call makes a DML. It must be done after the activate call
    Boolean result = info.HasTotp ? System.UserManagement.verifyVerificationMethod(null, otp, method).success : false;

    if (result) {
      cym.Community.Authenticator auth = cym.Community.getCurrent().authenticators.find('name', 'accounts_totp');
      session.apply(auth, null, null);
      PageReference resume = session.resume(startURL);
      return new Map<String, Object> {
        'result' => true,
        'redirect' => resume.getUrl()
      };
    } else {
      return new Map<String, Object> {
        'result' => false
      };
    }
  }

  @AuraEnabled
  public static Map<String, Object> initRegisterWebAuthn(String authenticator) {
    cym.Community context = cym.Community.getCurrent();
    return cym.WebAuthn.initRegisterWebAuthn(context.authenticators.find('name', authenticator));
  }

  @AuraEnabled
  public static Object verifyRegisterWebAuthn(Map<String, String> param, String authenticator, String handle, String startURL) {
    cym.Community context = cym.Community.getCurrent();
    cym.Community.Authenticator auth = context.authenticators.find('name', authenticator);
    // Polyfill the transports based on the authenticator type. It allows to remember if the credential is platform specific or not
    if (param.get('transports') == '[]') param.put('transports', (String) auth.get('type') == 'platform' ? '["internal"]' : '["usb", "nfc", "ble"]');
    cym.WebAuthn.Credential credential = cym.WebAuthn.verifyRegisterWebAuthn(param, auth);
    cym.Browser browser = cym.Browser.fromHandle(handle);
    cym.Browser.Session session = findOrAddSession(browser, UserInfo.getUserId()).activate();
    session.apply(auth, null, null);
    return new Map<String, Object> {
      'id' => EncodingUtil.base64Encode(credential.credentialId),
      'aaguid' => EncodingUtil.base64Encode(credential.aaguid),
      'counter' => credential.counter,
      'transports' => credential.transports
    };
  }

  @AuraEnabled
  public static Map<String, Object> initVerifyWebAuthn(String authenticator) {
    cym.Community context = cym.Community.getCurrent();
    return cym.WebAuthn.initVerificationWebAuthn(context.authenticators.find('name', authenticator));
  }

  @AuraEnabled
  public static Object verifyVerifyWebAuthn(Map<String, String> param, String authenticator, String handle, String startURL) {
    cym.Community context = cym.Community.getCurrent();
    cym.Community.Authenticator auth = context.authenticators.find('name', authenticator);
    Boolean is_valid = cym.WebAuthn.verifyVerificationWebAuthn(param, auth);
    if (is_valid) {
      try {
        cym.Browser browser = cym.Browser.fromHandle(handle);
        cym.Browser.Session session = findOrAddSession(browser, UserInfo.getUserId()).activate();
        session.apply(auth, null, null);
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
      cym.Community context = cym.Community.getCurrent();
      cym.Community.Authenticator auth = context.authenticators.find('name', 'accounts_twilio_push');
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
      cym.Community.Authenticator auth = context.authenticators.find('name', 'accounts_twilio_push');
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
      cym.Community.Authenticator auth = context.authenticators.find('name', 'accounts_twilio_push');
      TwilioVerify.Push service = new TwilioVerify.Push(auth);
      String verification = service.verify(challenge);
      if (verification != 'approved') return verification;
      // context.session.verifications.add(auth, null, null);
      return verification;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  public without sharing class Repository {
    public User findById(Id user_id) {
      return [SELECT // NOPMD.ApexCRUDViolation
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
      List<cym.WebAuthn.Credential> webAuthnCredentials = cym.WebAuthn.getAllCredentials();
      for(cym.WebAuthn.Credential cred: webAuthnCredentials) if(cred.transports.indexOf('internal') == -1) user_factors.add('webauthn');

      TwoFactorMethodsInfo info = this.getTwoFactorInfo(user_id);
      if (info != null) {
        if (info.HasUserVerifiedMobileNumber || info.HasVerifiedMobileNumber) user_factors.add('sms');
        if (info.HasSalesforceAuthenticator) user_factors.add('push');
        if (info.HasTotp) user_factors.add('totp');
        if (info.HasU2F) user_factors.add('u2f');
      }
      return new List<String>(user_factors);
    }
  }


  public static cym.Browser.Session findOrAddSession(cym.Browser browser, Id userId) {
    cym.Browser.Session session;
    for (cym.Browser.Session s : browser.sessions.asList()) {
      if (s.OwnerId == userId) {
        session = s;
        break;
      }
    }
    if (session == null) session = browser.sessions.add(userId);
    return session;
  }

}
