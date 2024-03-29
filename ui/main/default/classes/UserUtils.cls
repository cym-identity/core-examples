public with sharing class UserUtils {
  public without sharing class Repository {
    public User[] findUsers(Set<Id> userIds) {
      return (User[]) [SELECT Id, Username, IsActive, Email, MobilePhone, SmallPhotoUrl, MediumPhotoUrl, Name, FirstName, LastName FROM User WHERE Id IN :userIds AND IsActive = true]; // NOPMD.ApexCrudViolation
    }
    public User findById(Id user_id) {
      return [SELECT // NOPMD.ApexCRUDViolation
        Id, Username, Name, IsActive, Email, FirstName, LastName, MobilePhone, CommunityNickname, SmallPhotoUrl, MediumPhotoUrl, TimeZoneSidKey, LocaleSidKey,
        CompanyName, Street, State, PostalCode, City, Country,
        IsPasswordless__c, MobilePhoneVerified__c, LastPasswordChangeDate,
        AccountId, ContactId,
        LastModifiedDate
        FROM User
        WHERE Id = :user_id
      ];
    }
    public User findByEmail(String email) {
      User[] users = [SELECT // NOPMD.ApexCrudViolation
        Id, Username, Name, IsActive, Email, FirstName, LastName, MobilePhone, CommunityNickname, SmallPhotoUrl, MediumPhotoUrl, TimeZoneSidKey, LocaleSidKey,
        CompanyName, Street, State, PostalCode, City, Country,
        IsPasswordless__c, MobilePhoneVerified__c, LastPasswordChangeDate,
        AccountId, ContactId,
        LastModifiedDate
        FROM User
        WHERE Email = :email
      ];
      if (users.size() > 0) return users[0];
      return null;
    }
    public User findByUsername(String username) {
      User[] users = [SELECT // NOPMD.ApexCrudViolation
        Id, Username, Name, IsActive, Email, FirstName, LastName, MobilePhone, CommunityNickname, SmallPhotoUrl, MediumPhotoUrl, TimeZoneSidKey, LocaleSidKey,
        CompanyName, Street, State, PostalCode, City, Country,
        IsPasswordless__c, MobilePhoneVerified__c, LastPasswordChangeDate,
        AccountId, ContactId,
        LastModifiedDate
        FROM User
        WHERE Username = :username
      ];
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
      User u = this.findById(user_id);
      Set<String> user_factors = u.IsPasswordless__c ? new Set<String>() : (u.LastPasswordChangeDate == null ? new Set<String>() : new Set<String> {'password'});

      for(cym.Collection.Item cred: cym.WebAuthn.getAllCredentials().asList()) {
        if(((cym.WebAuthn.Credential) cred).transports.indexOf('internal') == -1) user_factors.add( 'webauthn_roaming' );
      }

      ThirdPartyAccountLink[] links = [SELECT SsoProviderName FROM ThirdPartyAccountLink WHERE UserId = :user_id]; // NOPMD.ApexCrudViolation
      for(ThirdPartyAccountLink link : links) user_factors.add(link.SsoProviderName);

      TwoFactorMethodsInfo info = this.getTwoFactorInfo(user_id);
      if (info != null) {
        if (info.HasUserVerifiedEmailAddress) user_factors.add('email');
        if (info.HasSalesforceAuthenticator) user_factors.add('push');
        if (info.HasTotp) user_factors.add('totp');
        if (info.HasU2F) user_factors.add('u2f');
      }
      if (hasVerifiedMobilePhone(u)) user_factors.add('phone');
      return new List<String>(user_factors);
    }

    public Map<String, Object> getClaims(String[] scopes) {
      String[] computedClaims = new String[] {'sub', 'name', 'middle_name', 'nickname', 'preferred_username', 'profile', 'gender', 'birthdate', 'updated_at', 'email', 'email_verified', 'phone', 'phone_verified'};
      // cym__RealmClaim__c[] claims = [SELECT Id, Name FROM cym__RealmClaim__c WHERE cym__Scope__r.Name IN :scopes]; // NOPMD.ApexCRUDViolation
      Map<String, Object> response = new Map<String, Object> {};
      // for (cym__RealmClaim__c claim : claims) if (computedClaims.indexOf(claim.Name) == -1) response.put(claim.Name, new Map<String, Object> { 'required' => true });
      return response;
    }
  }

  public static String buildUsername(String login_hint) {
    if (login_hint.indexOf('@') > 0) return login_hint + '.' + UserInfo.getOrganizationId() + '.io';
    return login_hint + '@' + UserInfo.getOrganizationId() + '.io';
  }
  public static String buildEmail(String login_hint) {
    if (login_hint.indexOf('@') > 0) return login_hint;
    return login_hint + '@' + UserInfo.getOrganizationId() + '.io';
  }
  public static String buildPhoneNumber(String login_hint) {
    if (login_hint.indexOf('@') > 0) return null;
    return login_hint;
  }

  public static Boolean hasVerifiedMobilePhone(User u) {
    return ConverterUtils.base64encode(
      // add the UserId to the mobile number to avoid copy paste from one user to the other
      Crypto.generateDigest('SHA-256', Blob.valueOf(u.Id + u.MobilePhone))
    ) == u.MobilePhoneVerified__c;
  }

  public static String getUserLogin(User u) {
    if (u.Username == u.MobilePhone + '@' + UserInfo.getOrganizationId() + '.io') return u.MobilePhone;
    return u.Email;
  }

  public static Users.LoginType getLoginType(User u) {
    if (u.Username == u.MobilePhone + '@' + UserInfo.getOrganizationId() + '.io') return Users.LoginType.phone;
    if (u.Username.endsWith('@' + TwitterProvider.AuthProviderId + '.io')) return Users.LoginType.twitter;
    return Users.LoginType.email;
  }

  public static Object[] getCommunityAuthProviders(String startURL) {
    if (Test.isRunningTest()) return new Object[] {};
    Auth.AuthConfiguration config = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), startURL);

    PageReference callback = new PageReference( new URL(Network.getLoginUrl(Network.getNetworkId())).getPath() );
    callback.getParameters().put('startURL', String.isBlank(startURL) ? '/' : startURL);

    cym.Community idp = cym.Community.getCurrent();

    Object[] response = new Object[] {};
    for (AuthProvider provider : config.getAuthProviders()) {
      if (idp.authenticators.find('name', provider.FriendlyName) == null) continue;

      PageReference authorize = new PageReference(Site.getBaseRequestUrl() + '/services/auth/sso/' + UserInfo.getOrganizationId() + '/' + provider.DeveloperName);
      authorize.getParameters().put('startURL', callback.getUrl());
      // Only keep authenticators which are provisionned in the cym__Community__c object
      // This assumes that the name is the same as the AuthProvider.Name
      response.add(new Map<String, Object> {
        'id' => provider.Id,
        'iconUrl' => provider.IconUrl,
        'friendlyName' => provider.FriendlyName,
        'url' => authorize.getUrl()
      });
    }
    return response;
  }

  public static Map<String, Object> getPicklists() {
    return new Map<String, Object> {
      'locale' => User.LocaleSidKey.getDescribe().getPicklistValues(),
      'zoneinfo' => User.TimeZoneSidKey.getDescribe().getPicklistValues()
    };
  }
  public static User fromUiModel(Map<String, Object> args) {
    User u = new User(
      LanguageLocaleKey = 'en_US',
      EmailEncodingKey = 'UTF-8'
    );

    String login = (String) args.get('login');

    u.UserName = UserUtils.buildUsername(login);
    u.Email = UserUtils.buildEmail(login);
    u.MobilePhone = UserUtils.buildPhoneNumber(login);

    if (args.containsKey('given_name')) u.FirstName = (String) args.get('given_name');
    if (args.containsKey('family_name')) u.LastName = (String) args.get('family_name');

    String locale = (String) args.get('locale');
    u.LocaleSidKey = String.isNotBlank(locale) ? locale : UserInfo.getLocale();

    String zoneinfo = (String) args.get('zoneinfo');
    u.TimeZoneSidKey = String.isNotBlank(zoneinfo) ? zoneinfo : UserInfo.getTimeZone().getId();

    if (args.containsKey('address')) {
      Map<String, Object> address = (Map<String, Object>) args.get('address');
      if (address == null) address = new Map<String, Object> {};
      u.Street = (String) address.get('street');
      u.City = (String) address.get('city');
      u.State = (String) address.get('state');
      u.PostalCode = (String) address.get('zipcode');
      u.Country = (String) address.get('country');
    }

    if (args.containsKey('company_name')) u.CompanyName = (String) args.get('company_name');

    return u;
  }

  public static Map<String, Object> fromUser(User u) {

    return null;
  }

  public static Contact getContact(User u, Account a) {
    return new Contact(
      AccountId = a.Id,
      FirstName = u.FirstName,
      LastName = u.LastName,
      Email = getLoginType(u) == Users.LoginType.email ? u.Email : null,
      MobilePhone = u.MobilePhone
    );
  }

  public static Account getAccount(User u) {
    if (String.isBlank(u.CompanyName)) return null;
    return new Account(
      Name = u.CompanyName,
      BillingStreet = u.Street,
      BillingCity = u.City,
      BillingState = u.State,
      BillingPostalCode = u.PostalCode,
      BillingCountry = u.Country
    );
  }

  public enum AuthenticationStepType {
    IDENTITY_REGISTER,
    IDENTITY_VERIFY,
    AUTHENTICATOR_REGISTER,
    AUTHENTICATOR_VERIFY,
    REDIRECT
  }

  public class AuthenticationStep {
    public AuthenticationStepType type;
    public cym.Community.Authenticator authenticator;
    public cym.Browser.Session session;
    public AuthenticationStep(AuthenticationStepType type, cym.Community.Authenticator authenticator, cym.Browser.Session session) {
      this.type = type;
      this.authenticator = authenticator;
      this.session = session;
    }
    public PageReference getPage(Map<String, String> redirectParams) {
      PageReference next = this.nextPage();
      if (next == null) return null;
      next.getParameters().putAll(redirectParams);
      return next;
    }
    private PageReference nextPage() {
      switch on this.type {
        when IDENTITY_REGISTER {
          return new Auth.AuthConfiguration(Site.getBaseRequestUrl(), '/').getSelfRegistrationEnabled() ? new PageReference('/register') : null;
        }
        when IDENTITY_VERIFY {
          if (this.authenticator.name == 'email') {
            return new PageReference('/email');
          }
          return null;
        }
        when AUTHENTICATOR_VERIFY {
          switch on this.authenticator.name {
            when 'password' {
              return new PageReference('/password');
            }
            when 'email' {
              return new PageReference('/email');
            }
            when else {
              return null;
            }
          }
        }
        when else {
          return null;
        }
      }
    }
  }

  public class InvalidArgumentException extends Exception {}
}
