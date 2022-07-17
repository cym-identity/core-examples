global with sharing class TwitterProvider implements Auth.RegistrationHandler { // NOPMD.AvoidGlobalModifier
  public static String AuthProviderId {
    get {
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'Twitter');
      if (authenticator == null) throw new InvalidContextException('You are trying to login to a community that does not support Twitter Login');
      return (String) authenticator.provider.get('auth_provider_id');
    }
  }

  global Schema.User createUser(Id portalId, Auth.UserData data){
    TwitterProvider.User t = new TwitterProvider.User(data);

    UserUtils.Repository db = new UserUtils.Repository();
    Schema.User u = db.findByUsername(t.username);
    if (u != null) return u;

    u = t.toSObject();

    u.ProfileId = [SELECT Id FROM Profile WHERE Name = 'sample-external-user'].Id;
    u.IsPasswordless__c = true;
    u.CommunityNickname = ConverterUtils.base64encode(Crypto.generateAesKey(128));
    u.Alias = u.CommunityNickname.substring(0, 8);

    return u;
  }
  global void updateUser(Id userId, Id portalId, Auth.UserData data){
    System.debug(Network.getNetworkId());
  }





  public class User extends Users.Base {
    public User(Auth.UserData params) {
      this.username = params.identifier + '@' + TwitterProvider.AuthProviderId + '.io';
      String[] name = params.fullName.split(' ');
      if (name.size() > 1) {
        this.firstName = name.remove(0);
        this.lastName = String.join(name, ' ');
      } else {
        this.lastName = params.fullName;
      }
    }
    public override LoginType getLoginType() { return Users.LoginType.twitter; }
    public override Boolean isVerified() { return true; }
    public override Schema.User toSObject() {
      return new Schema.User(
        Username = this.username,
        Email = this.username,
        FirstName = this.firstName,
        LastName = this.lastName,
        LocaleSidKey = UserInfo.getLocale(),
        TimeZoneSidKey = UserInfo.getTimeZone().getId(),
        LanguageLocaleKey = 'en_US',
        EmailEncodingKey = 'UTF-8'
      );
    }
  }

  public static User fromLoginHint(String login_hint) {
    return null;
  }







  public class InvalidContextException extends Exception {}
}
