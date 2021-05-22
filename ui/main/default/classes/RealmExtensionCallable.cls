global with sharing class RealmExtensionCallable implements Callable{ // NOPMD.AvoidGlobalModifier
  global Object call(String action, Map<String, Object> args) {
    User current_user = new Repository().findById((Id) args.get('user_id'));
    if (action == 'before:authorize:page') {

      if (
        String.isBlank(current_user.Street) ||
        String.isBlank(current_user.State) ||
        String.isBlank(current_user.PostalCode) ||
        String.isBlank(current_user.City) ||
        String.isBlank(current_user.Country)
      ) {
        PageReference response = new PageReference('/UpdateProfile');
        response.getParameters().putAll(new Map<String, String> {
          'field' => 'address'
        });

        return response;
      }
      return null;
    }
    if (action == 'get:challenge:page') {
      return new PageReference('/challenge');
    }
    if (action == 'get:consent:page') {
      return new PageReference('/approval');
    }
    return null;
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
