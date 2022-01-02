/**
 * An apex page controller that supports self registration of users in communities that allow self registration
 */
global without sharing class CommunitiesSelfRegController { // NOPMD.AvoidGlobalModifier

  public String firstName {get; set;}
  public String lastName {get; set;}
  public String email {get; set;}
  public String password {get; set {password = value?.trim(); } }
  public String confirmPassword {get; set { confirmPassword = value?.trim(); } }
  public String communityNickname {get; set { communityNickname = value?.trim(); } }

  public CommunitiesSelfRegController() {
    String expid = ApexPages.currentPage().getParameters().get('expid');
    if (expId != null) {
        Site.setExperienceId(expId); 
    }
    this.email = ApexPages.currentPage().getParameters().get('login_hint');
  }

  private boolean isValidPassword() {
    return password == confirmPassword;
  }

  public PageReference registerUser() {
    // it's okay if password is null - we'll send the user a random password in that case
    if (!isValidPassword()) {
      ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR, Label.site.passwords_dont_match);
      ApexPages.addMessage(msg);
      return null;
    }

    try {

      cym.Community community = cym.Community.getCurrent();
      String resp = community.getRemoteApex(CommunitiesSelfRegController.CreateUser.class)
        .invoke(
          JSON.serialize(
            new Map<String, Object> {
              'email' => email,
              'lastName' => lastName,
              'firstName' => firstName,
              'nickname' => communityNickname,
              'password' => password
            }
          )
        );

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp);

      Id userId = (Id) response.get('userId');
      community.getRemoteApex(CommunitiesSelfRegController.AssignPermSet.class)
        .invoke(
          JSON.serialize(
            new Map<String, Object> {
              'userId' => userId
            }
          )
        );

      return cym.Browser.getCurrent()
        .sessions
        .add(userId)
        .activate()
        .apply(cym.Community.getCurrent().authenticators.find('name', 'password'), null, null)
        .resume(ApexPages.currentPage().getParameters().get('startURL'));

    } catch(Exception ex) {
      ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));

      // This message is used for debugging. Do not display this in the UI to the end user.
      // It has the information around why the user creation failed.
      System.debug(ex.getMessage());
      return null;
    }
  }
  global with sharing class CreateUser extends cym.Remote.Function {
    global override String execute(String param) {
      Map<String, Object> args = (Map<String,Object>) JSON.deserializeUntyped(param);

      String email = (String) args.get('email');
      String lastName = (String) args.get('lastName');
      String firstName = (String) args.get('firstName');
      String communityNickname = (String) args.get('nickname');
      String password = (String) args.get('password');
      String profileId = [SELECT Id FROM Profile WHERE Name = 'sample-external-user'].Id;

      String userName = email + '.' + UserInfo.getOrganizationId() +'.scratch.com';

      User u = new User(
        Username = userName,
        Email = email,
        FirstName = firstName,
        LastName = lastName,
        CommunityNickname = communityNickname,
        ProfileId = profileId,
        alias = communityNickname,

        LocaleSidKey = UserInfo.getLocale(),
        TimeZoneSidKey = UserInfo.getTimeZone().getId(),
        LanguageLocaleKey = 'en_US',
        EmailEncodingKey = 'UTF-8'
      );

      insert u; // NOPMD.ApexCRUDViolation
      System.setPassword(u.Id, password);

      return JSON.serialize(new Map<String, Object> { 'userId' => u.Id });
    }
  }

  global without sharing class AssignPermSet extends cym.Remote.Function {
    global override String execute(String param) {
      Map<String, Object> args = (Map<String,Object>) JSON.deserializeUntyped(param);

      Id userId = (Id) args.get('userId');

      PermissionSet[] permsets = [SELECT Id FROM PermissionSet WHERE Name = 'cym_identity_user']; // NOPMD
      PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = permsets[0].Id, AssigneeId = userId);

      insert psa; // NOPMD.ApexCRUDViolation

      return JSON.serialize(new Map<String, Object> { 'userId' => userId });
    }
  }


}