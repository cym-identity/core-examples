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
    cym.AuthorizationContext context = cym.AuthorizationContext.currentContext();
    System.debug(String.valueOf(context.getVerifications()));

    User current_user = new Repository().findById(UserInfo.getUserId());
    Map<String, Object> sms = sendSms(current_user, context);
    if (sms != null) RESPONSE.putAll(sms);

    // Must call the below method to be able to use RemoteActions
    context.save();
    return null;
  }

  private static Map<String, Object> sendSms(User current_user, cym.AuthorizationContext context) {
    if (String.isNotBlank(current_user.MobilePhone)) {
      return Auth.CommunitiesUtil.isInternalUser() ? sendSalesforceSms(current_user, context) : sendTwilioSms(current_user, context);
    }
    return null;
  }

  private static Map<String, Object> sendTwilioSms(User current_user, cym.AuthorizationContext context) {
    // Assuming a Twilio SMS authenticator with name `accounts_twilio_verify` exists on the community
    TwilioVerify.Sms authenticator = new TwilioVerify.Sms(context.getAuthenticatorByName('accounts_twilio_verify'));
    // Trigger an SMS directly
    Map<String, Object> verification = authenticator.initChallenge(
      new Map<String, Object> {
        'phoneNumber' => current_user.MobilePhone,
        // Override the Twilio Locale for example
        'Locale' => UserInfo.getLanguage().substring(0, 2)
      }
    );
    if (verification.containsKey('sid')) {
      return new Map<String, Object> {
        'phoneNumber' => current_user.MobilePhone,
        'transactionId' => (String) verification.get('sid')
      };
    }
    return verification;
  }

  private static Map<String, Object> sendSalesforceSms(User current_user, cym.AuthorizationContext context) {
    // Assuming a Twilio SMS authenticator with name `accounts_twilio_verify` exists on the community
    TwilioVerify.Sms authenticator = new TwilioVerify.Sms(context.getAuthenticatorByName('accounts_twilio_verify'));
    // Trigger an SMS directly
    Map<String, Object> verificationId = authenticator.initChallenge(
      new Map<String, Object> {
        'phoneNumber' => current_user.MobilePhone,
        // Override the Twilio Locale for example
        'Locale' => UserInfo.getLanguage()
      }
    );
    return new Map<String, Object> {
      'phoneNumber' => current_user.MobilePhone,
      'transactionId' => verificationId
    };
  }


  @RemoteAction
  public static Map<String, Object> challenge(String phoneNumber) {
    User u = new User(Id = UserInfo.getUserId(), MobilePhone = phoneNumber);
    Map<String, Object> response = sendSms(u, cym.AuthorizationContext.currentContext());
    update u;
    return response;
  }

  @RemoteAction
  public static Map<String, Object> verify(String transactionId, String otp) {
    cym.AuthorizationContext context = cym.AuthorizationContext.currentContext();
    cym.AuthorizationContext.Authenticator authenticator = context.getAuthenticatorByName('accounts_twilio_verify');
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
        context.addVerification(authenticator, null, null).save();
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

  public PageReference done() {
    cym.AuthorizationContext context = cym.AuthorizationContext.currentContext();
    Auth.SessionManagement.finishLoginFlow();
    System.debug(String.valueOf(context.getVerifications()));
    if (context.getVerifications().size() != 2) return null;
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
  }
}
