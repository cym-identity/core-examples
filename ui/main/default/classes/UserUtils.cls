public with sharing class UserUtils {
  public without sharing class Repository {
    public User[] getUsers(Id[] userIds) {
      User[] users = [SELECT Id, Email, SmallPhotoUrl, Name, FirstName, LastName FROM User WHERE Id IN :userIds]; // NOPMD.ApexCrudViolation
      return users;
    }
    public User findById(Id user_id) {
      return [SELECT // NOPMD.ApexCRUDViolation
        Id, Name, FirstName, LastName, CommunityNickname, Username, SmallPhotoUrl,
        Email, TimeZoneSidKey, LanguageLocaleKey, MobilePhone, Street, State, PostalCode, City, Country,
        LastModifiedDate
        FROM User
      WHERE Id = :user_id];
    }
    public User findByEmail(String email) {
      User[] users = [SELECT Id, Username, IsActive FROM User WHERE Email = :email]; // NOPMD.ApexCrudViolation
      if (users.size() > 0) return users[0];
      return null;
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

    public Id[] findThirdPartyAccountLink(Id user_id) {
      ThirdPartyAccountLink[] links = [SELECT SsoProviderId FROM ThirdPartyAccountLink WHERE UserId = :user_id]; // NOPMD.ApexCrudViolation
      Id[] resp = new Id[] {};
      for (ThirdPartyAccountLink link : links) resp.add((Id) link.SsoProviderId);
      return resp;
    }

    public String[] getUserFactors(Id user_id) {
      Set<String> user_factors = new Set<String>{'password'};
      List<cym.WebAuthn.Credential> webAuthnCredentials = cym.WebAuthn.getAllCredentials();
      for(cym.WebAuthn.Credential cred: webAuthnCredentials) user_factors.add(cred.transports.indexOf('internal') == -1 ? 'webauthn': 'webauthn.platform');

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
}
