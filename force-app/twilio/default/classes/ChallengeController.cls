public with sharing class ChallengeController {
  public static final transient Map<String, Object> DEBUG_LOG = new Map<String, Object>();

  public String backgroundColor {get; private set;}

  public String log {
    get {
      try {
        return JSON.serialize(DEBUG_LOG);
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

    User current_user = new Repository().findById(UserInfo.getUserId());
    if (String.isNotBlank(current_user.MobilePhone)) {
      DEBUG_LOG.put('phoneNumber', current_user.MobilePhone);
      DEBUG_LOG.put('transactionId', 'transationId_' + Crypto.getRandomInteger());
    }

  }

  public PageReference process() {
    cym.AuthorizationContext.currentContext().save();
    return null;
  }

  @RemoteAction
  public static Map<String, Object> challenge(String phoneNumber) {
    User u = new User(Id = UserInfo.getUserId(), MobilePhone = phoneNumber);
    update u;
    return new Map<String, Object> {
      'phoneNumber' => phoneNumber,
      'transactionId' => 'transationId_' + Crypto.getRandomInteger()
    };
  }

  @RemoteAction
  public static Map<String, Object> verify(String phoneNumber, String transactionId, String otp) {
    return new Map<String, Object> {
      'phoneNumber' => phoneNumber,
      'transactionId' => transactionId,
      'otp' => otp
    };
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
