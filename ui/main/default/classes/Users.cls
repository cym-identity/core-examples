public with sharing class Users {
  public abstract class Base {
    public String username;
    public String firstName;
    public String lastName;
    public abstract User toSObject();
    public abstract LoginType getLoginType();
    public abstract Boolean isVerified();
  }

  private static Map<String, String> p_social_providers;
  private static Map<String, String> social_providers {
    get {
      if (p_social_providers != null) return p_social_providers;
      p_social_providers = new Map<String, String>();
      {
        AuthProvider[] providers = [SELECT Id, DeveloperName FROM AuthProvider];
        for (AuthProvider provider: providers) p_social_providers.put(provider.Id, provider.DeveloperName.toLowerCase());
      }
      {
        SamlSsoConfig[] providers = [SELECT Id, DeveloperName FROM SamlSsoConfig];
        for (SamlSsoConfig provider: providers) p_social_providers.put(provider.Id, provider.DeveloperName.toLowerCase());
      }
      return p_social_providers;
    }
  }

  public enum LoginType {
    phone,
    email,
    Twitter,
    Facebook,
    Linkedin,
    Google,
    unknown
  }

  public static LoginType getLoginType(User u) {
    return getLoginType(u.Username);
  }

  /**
   * A Method which reads a login entered by the user and returns the type of login entered
   * @param login_hint can be either a Salesforce username or a login_hint entered by the user
   */
  public static LoginType getLoginType(String login_hint) {
    if (login_hint.contains('@') && login_hint.endsWith('.' + UserInfo.getOrganizationId().toLowerCase())) return LoginType.email;
    if (login_hint.endsWith('@' + UserInfo.getOrganizationId().toLowerCase() + '.io')) return LoginType.phone;
    for(String key : social_providers.keySet()) if (login_hint.endsWith('@' + key.toLowerCase() + '.io')) return LoginType.valueOf(social_providers.get(key));
    if (!login_hint.contains('@')) return LoginType.phone;
    if (login_hint.contains('@')) return LoginType.email;
    return LoginType.unknown;
  }

  public static String getLoginHint(User u) {
    switch on getLoginType(u) {
      when phone { return u.MobilePhone; }
      when email { return u.Email; }
      when else { return u.Username; }
    }
  }

  private static String getUsernameFromLoginHint(String login_hint) {
    // The user has entered a phone number
    if (!login_hint.contains('@')) return login_hint + '@' + UserInfo.getOrganizationId() + '.io';
    // The user has entered a standard email address
    return login_hint + '.' + UserInfo.getOrganizationId() + '.io';
  }

  public static LoginType getUserType(User u) {
    if (u.Username == u.Email + '.' + UserInfo.getOrganizationId() + '.io') return LoginType.email;
    if (u.Username == u.MobilePhone + '@' + UserInfo.getOrganizationId() + '.io') return LoginType.phone;
    return LoginType.unknown;
  }

  public static Map<String, Object> getPrimaryIdentifier(User u) {
    return new Map<String, Object> { 'type' => Users.getUserType(u), 'value' => Users.getLoginHint(u) };
  }

  public static Map<String, Object> getSecondaryIdentifier(User u) {
    return Users.getUserType(u) == LoginType.email ?
      (u.MobilePhone == null ? null : new Map<String, Object> { 'type' => LoginType.phone, 'value' => u.MobilePhone }) :
      (u.Email == u.Username ? null : new Map<String, Object> { 'type' => LoginType.email, 'value' => u.Email });
  }
}
