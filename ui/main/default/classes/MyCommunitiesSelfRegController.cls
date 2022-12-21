/**
 * An apex page controller that supports self registration of users in communities that allow self registration
 */
global with sharing class MyCommunitiesSelfRegController { // NOPMD.AvoidGlobalModifier

  public MyCommunitiesSelfRegController() {}

  global with sharing class RegisterUser extends Fetch.Function {
    global override Object execute(Map<String, Object> args) {

      String requestId = (String) args.get('requestId');

      cym.Community community = cym.Community.getCurrent();
      String resp = community.getRemoteApex(MyCommunitiesSelfRegController.CreateUser.class)
        .invoke(
          JSON.serialize(args)
        );

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp);

      Id userId = (Id) response.get('userId');
      community.getRemoteApex(MyCommunitiesSelfRegController.AssignPermSetAndLicense.class)
        .invoke(
          JSON.serialize(
            new Map<String, Object> {
              'userId' => userId
            }
          )
        );
      cym.Browser.Session session = cym.Browser.getCurrent().sessions.add(userId);
      if (String.isNotBlank((String) args.get('password'))) session.apply((cym.Community.Authenticator) community.authenticators.find('name', 'password'), requestId);

      return new Map<String, Object> { 'isValid' => true };
    }
  }

  // This function is Supposed to be run with an Admin user
  global with sharing class CreateUser extends cym.Remote.Function {
    global override String execute(String param) {
      return this.execute((Map<String,Object>) JSON.deserializeUntyped(param));
    }
    global String execute(Map<String,Object> args) {

      String password = (String) args.get('password');

      String key = ConverterUtils.base64encode(Crypto.generateAesKey(128));

      User u = UserUtils.fromUiModel(args);

      Auth.AuthConfiguration conf = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), '/');

      u.ProfileId = conf.getDefaultProfileForRegistration(); //[SELECT Id FROM Profile WHERE Name = 'sample-external-user'].Id;
      u.IsPasswordless__c = false; // String.isBlank(password);
      u.CommunityNickname = key;
      u.Alias = key.substring(0, 8);

      Account a = UserUtils.getAccount(u);
      if (a != null) {
        insert a; // NOPMD.ApexCRUDViolation
        Contact c = UserUtils.getContact(u, a);
        insert c; // NOPMD.ApexCRUDViolation
        u.ContactId = c.Id;
      }

      insert u; // NOPMD.ApexCRUDViolation
      System.debug(JSON.serializePretty(u));

      if (String.isNotBlank(password)) {
        System.debug('Setting Password');
        System.setPassword(u.Id, password);
      }

      // Set the user picture if provided
      Map<String, Object> picture = (Map<String, Object>) args.get('picture');
      if (picture != null) {
        ConnectApi.BinaryInput input = new ConnectApi.BinaryInput(
          EncodingUtil.base64Decode((String) picture.get('blob')),
          (String) picture.get('contentType'),
          (String) picture.get('filename')
        );
        ConnectApi.UserProfiles.setPhoto((Id) Network.getNetworkId(), u.Id, input);
      }

      return JSON.serialize(new Map<String, Object> { 'userId' => u.Id });
    }
  }

  // This function is Supposed to be run with an Admin user
  global with sharing class AssignPermSetAndLicense extends cym.Remote.Function {
    global override String execute(String param) {
      Map<String, Object> args = (Map<String,Object>) JSON.deserializeUntyped(param);

      Id userId = (Id) args.get('userId');

      PermissionSet[] permsets = [SELECT Id FROM PermissionSet WHERE Name = 'cym_identity_user']; // NOPMD
      PermissionSetAssignment psa = new PermissionSetAssignment(PermissionSetId = permsets[0].Id, AssigneeId = userId);

      insert psa; // NOPMD.ApexCRUDViolation

      PackageLicense[] pls = [SELECT Id FROM PackageLicense WHERE NamespacePrefix = 'cym']; // NOPMD
      // Subscribers will never fall outside this condition
      // This is during testing where package licensing isn't available.
      if (pls.size() > 0) insert new UserPackageLicense(UserId = userId, PackageLicenseId = pls[0].id); // NOPMD

      return JSON.serialize(new Map<String, Object> { 'userId' => userId });
    }
  }

}
