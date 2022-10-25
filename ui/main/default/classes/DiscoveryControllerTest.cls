@isTest
public with sharing class DiscoveryControllerTest {
  private static final String EMAIL = 'hello@kitty.fr';
  private static final String PHONE = '+33123456789';
  private static final String PHONE_VERIFIED = '+33123456780';

  // @TestSetup
  // static void makeData(){
  //   cym__Community__c idp = cym.CommunityTest.setupCurrentCommunity(UserInfo.getOrganizationId());

  //   insert new cym__CommunityAuthenticator__c[]{
  //     new cym__CommunityAuthenticator__c(Name= 'password', cym__Community__c = idp.Id, cym__TimeToLive__c = 0, cym__Provider__c = 'cym_SalesforceAuthenticator_Password', cym__Amrs__c = 'pwd'),
  //     new cym__CommunityAuthenticator__c(Name= 'email', cym__Community__c = idp.Id, cym__TimeToLive__c = 0, cym__Provider__c = 'cym_SalesforceAuthenticator_Password', cym__Amrs__c = 'email;otp'),
  //     new cym__CommunityAuthenticator__c(Name= 'phone', cym__Community__c = idp.Id, cym__TimeToLive__c = 300, cym__Provider__c = 'TwilioVerify_Sms', cym__Amrs__c = 'sms;otp')
  //     };

  //   System.runAs(new User(Id = UserInfo.getUserId())) {
  //     new MyCommunitiesSelfRegController.CreateUser().execute(new Map<String, Object> {
  //       'login' => EMAIL,
  //       'given_name' => 'hello',
  //       'family_name' => 'kitty'
  //     });

  //     new MyCommunitiesSelfRegController.CreateUser().execute(new Map<String, Object> {
  //       'login' => PHONE,
  //       'given_name' => 'hello',
  //       'family_name' => 'kitty'
  //     });

  //     Map<String, Object> phone_verified_user = (Map<String, Object>) JSON.deserializeUntyped(
  //       new MyCommunitiesSelfRegController.CreateUser().execute(new Map<String, Object> {
  //         'login' => PHONE_VERIFIED,
  //         'given_name' => 'hello',
  //         'family_name' => 'kitty'
  //       })
  //     );

  //     Id phone_verified_user_id = (Id) phone_verified_user.get('userId');
  //     update new User(
  //       Id = phone_verified_user_id,
  //       MobilePhone = PHONE_VERIFIED,
  //       MobilePhoneVerified__c = ConverterUtils.base64encode(
  //         // add the UserId to the mobile number to avoid copy paste from one user to the other
  //         Crypto.generateDigest('SHA-256', Blob.valueOf(phone_verified_user_id + PHONE_VERIFIED))
  //       )
  //     );
  //   }
  // }

  // @isTest
  // static void Discover_Register () {
  //   Test.setCurrentPage(new PageReference('/'));

  //   Map<String, Object> discover = (Map<String, Object>) new DiscoveryController.Discover().execute(new Map<String, Object> {
  //     'login_hint' => UserInfo.getUserEmail(),
  //     'startURL' => '/',
  //     'requestId' => 'requestId'
  //   });

  //   System.assertEquals('identity.register', (String) discover.get('action'), 'The default user must register since the Username does not follow the defined format');
  // }

  // @isTest
  // static void Discover_VerifyIdentityEmail() {
  //   Test.setCurrentPage(new PageReference('/'));

  //   Map<String, Object> discover = (Map<String, Object>) new DiscoveryController.Discover().execute(new Map<String, Object> {
  //     'login_hint' => Email,
  //     'startURL' => '/',
  //     'requestId' => 'requestId'
  //   });

  //   System.assertEquals('identity.register.email', (String) discover.get('action'), 'The user must verify her email');
  // }

  // @isTest
  // static void Discover_VerifyIdentityPhone() {
  //   Test.setCurrentPage(new PageReference('/'));

  //   cym.Browser browser = cym.Browser.getCurrent();
  //   cym.Browser.Session session = browser.sessions.add(UserInfo.getUserId());

  //   cym.CommunityTest.setCurrentCommunity(UserInfo.getOrganizationId());
  //   cym.Community idp = cym.Community.getCurrent();

  //   session.apply((cym.Community.Authenticator) idp.authenticators.find('name', 'password'));

  //   System.assertEquals(1, session.verifications.asList().size(), 'The authenticator has been registered');
  //   Map<String, Object> discover = (Map<String, Object>) new DiscoveryController.Discover().execute(new Map<String, Object> {
  //     'login_hint' => PHONE,
  //     'startURL' => '/',
  //     'requestId' => 'requestId'
  //   });

  //   System.assertEquals('identity.register.phone', (String) discover.get('action'), 'The user must verify her phone');
  // }

  // @isTest
  // static void GetNextAction() {
  //   Test.setCurrentPage(new PageReference('/'));
  //   cym.Browser.Session session = cym.Browser.getCurrent().sessions.add(UserInfo.getUserId());

  //   cym.CommunityTest.setCurrentCommunity(UserInfo.getOrganizationId());
  //   cym.Community.Authenticators authenticators = cym.Community.getCurrent().authenticators;

  //   cym.Community.Authenticator password = (cym.Community.Authenticator) authenticators.find('name', 'password');
  //   cym.Community.Authenticator phone = (cym.Community.Authenticator) authenticators.find('name', 'phone');
  //   String[][] acrs = new String[][] {
  //     new String[] { 'password', 'phone' },
  //     new String[] { 'email', 'phone' }
  //   };
  //   Integer maxAge;
  //   String startURL = '/';
  //   String requestId = ConverterUtils.base64encode(Crypto.generateAesKey(256));
  //   // The user has verified his email or phone, therefore she has at least one authenticator
  //   {
  //     String[] userAuthenticators = new String[] {'email'};
  //     Map<String, Object> nextAction = DiscoveryController.getNextAction(session, userAuthenticators, acrs, requestId, maxAge, startURL);
  //     System.assertEquals('authenticator.challenge.email', (String) nextAction.get('action'), 'The user is challenged for her first factor');
  //   }
  //   {
  //     String[] userAuthenticators = new String[] {'email', 'password'};
  //     Map<String, Object> nextAction = DiscoveryController.getNextAction(session, userAuthenticators, acrs, requestId, maxAge, startURL);
  //     System.assertEquals('authenticator.challenge.password', (String) nextAction.get('action'), 'The user is challenged by the first path where she has an authenticator ');
  //   }
  //   {
  //     String[] userAuthenticators = new String[] {'email', 'password'};
  //     session.apply(password, 'requestId',  null);
  //     Map<String, Object> nextAction = DiscoveryController.getNextAction(session, userAuthenticators, acrs, requestId, maxAge, startURL);
  //     System.assertEquals('authenticator.challenge.password', (String) nextAction.get('action'), 'The user is challenged by the first factor since the requestId does not work');
  //   }
  //   {
  //     String[] userAuthenticators = new String[] {'email', 'password'};
  //     session.apply(password, 'requestId', null);
  //     Map<String, Object> nextAction = DiscoveryController.getNextAction(session, userAuthenticators, acrs, requestId, maxAge, startURL);
  //     System.assertEquals('authenticator.challenge.password', (String) nextAction.get('action'), 'The user is challenged by the first factor since the requestId does not work');
  //   }
  //   {
  //     String[] userAuthenticators = new String[] {'email', 'password'};
  //     session.apply(password, requestId, null);
  //     Map<String, Object> nextAction = DiscoveryController.getNextAction(session, userAuthenticators, acrs, requestId, maxAge, startURL);
  //     System.assertEquals('authenticator.register.phone', (String) nextAction.get('action'), 'The user is challenged by the second factor since the first is compliant');
  //   }
  // }
}
