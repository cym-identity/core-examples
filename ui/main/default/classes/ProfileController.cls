global with sharing class ProfileController { // NOPMD.AvoidGlobalModifiers
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

  public ProfileController() {
    this.backgroundColor =  new Auth.AuthConfiguration(Site.getBaseRequestUrl(), '/').getBackgroundColor();
  }

  private static String[] translate(String[] labels) {
    String[] response = new String[] {};
    for (String lbl : labels) {
      try {
        Component.Apex.OutputText output = new Component.Apex.OutputText();
        output.expressions.value = '{!$Label.' + lbl + '}';
        response.add(String.valueOf(output.value));
      } catch (Exception ex) {
        response.add(lbl);
      }
    }
    return response;
  }

  public with sharing class GetProfile extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      User u = new UserUtils.Repository().findById(UserInfo.getUserId());

      String login = UserUtils.getUserLogin(u);
      String photo = u.MediumPhotoUrl;

      Map<String, Object> user = new Map<String, Object> {
        'id' => UserInfo.getUserId(),
        'login' => login,
        'picture' => photo,
        'given_name' => u.FirstName,
        'family_name' => u.LastName,
        'company_name' => u.CompanyName,
        'company_id' => u.AccountId,
        'locale' => u.LocaleSidKey,
        'zoneinfo' => u.TimeZoneSidKey,
        'address' => new Map<String, Object> {
          'street' => u.Street,
          'city' => u.City,
          'state' => u.state,
          'zipcode' => u.PostalCode,
          'country' => u.Country
        }
      };
      return new Map<String, Object> {
        'fields'=> new UserUtils.Repository().getClaims('openid profile email address phone profile.extended'.split(' ')),
        'attributes' => user,
        'picklists' => UserUtils.getPicklists()
      };
    }
  }

  public without sharing class UpdateProfile extends Fetch.Function {
    public override Object execute(Map<String, Object> args) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      // Set the user picture if provided
      Map<String, Object> picture = (Map<String, Object>) args.remove('picture');

      args.put('id', UserInfo.getUserId());

      // Create the Account and Contact
      User existing_user = new UserUtils.Repository().findById(UserInfo.getUserId());
      // The User is contactless
      if (existing_user.ContactId == null) {
        Map<String, Object> anc = (Map<String, Object>) JSON.deserializeUntyped(
          cym.Community.getCurrent().getRemoteApex(ProfileController.UpdateAccountContactRemote.class).invoke(JSON.serialize(args))
        );
        // Add the contact which was just created, the value may be null as well
        args.put('ContactId', anc.get('ContactId'));
      }

      // Update the user as the community admin
      cym.Community.getCurrent().getRemoteApex(ProfileController.UpdateProfileRemote.class).invoke(JSON.serialize(args));

      if (picture != null) {
        ConnectApi.BinaryInput input = new ConnectApi.BinaryInput(
          EncodingUtil.base64Decode((String) picture.get('blob')),
          (String) picture.get('contentType'),
          (String) picture.get('filename')
        );
        ConnectApi.UserProfiles.setPhoto((Id) Network.getNetworkId(), UserInfo.getUserId(), input);
      }
      return new GetProfile().execute(null);
    }
  }

  public with sharing class UpdateAccountContactRemote extends cym.Remote.Function {
    public override String execute(String param) {
      Map<String, Object> args = (Map<String, Object>) JSON.deserializeUntyped(param);
      User u = UserUtils.fromUiModel(args);

      Account a = UserUtils.getAccount(u);
      // The user has filled the information needed to create an Account
      if (a != null) {
        insert a; // NOPMD.ApexCRUDViolation
        Contact c = UserUtils.getContact(u, a);
        insert c; // NOPMD.ApexCRUDViolation
        return JSON.serialize(new Map<String, Object> {'ContactId' => c.Id});
      }
      return '{}';
    }
  }

  public with sharing class UpdateProfileRemote extends cym.Remote.Function {
    public override String execute(String param) {
      Map<String, Object> args = (Map<String, Object>) JSON.deserializeUntyped(param);
      User u = UserUtils.fromUiModel(args);
      u.Id = (Id) args.get('id');
      if (args.get('ContactId') != null) u.ContactId = (Id) args.get('ContactId');
      update u; // NOPMD-ApexCRUDViolation
      return JSON.serialize(new Map<String, Object> {'userId' => u.Id});
    }
  }

  public with sharing class GetAllConsent extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      cym.ResourceOwner context = cym.ResourceOwner.getCurrent();
      System.debug(context.consents.asObjects());
      cym.Community idp = cym.Community.getCurrent();
      Set<Id> clientIds = new Set<Id>(context.consents.pluck('client').asIds());
      System.debug(clientIds);
      Map<Id, Map<String, Object>> clients = new Map<Id, Map<String, Object>>();
      for(cym__Client__c client: new ClientRepository().find(clientIds)) {
        clients.put(client.Id, new Map<String, Object> {
          'id' => client.Id,
          'client_name' => client.Name,
          'client_uri' => client.cym__ClientUri__c,
          'logo_uri' => client.cym__LogoUri__c
        });
      }
      System.debug(clients);

      Object[] response = new Object[] {};
      for (cym.Collection.Item v : context.consents.asList()) {
        cym.ResourceOwner.Consent consent = (cym.ResourceOwner.Consent) v;
        Map<String, Object> c = clients.get(consent.client);
        if (consent.scopes.size() == 0) continue;
        c.put('scopes', ProfileController.translate(consent.scopes));
        c.put('createdDate', consent.CreatedDate.getTime());
        response.add(c);
      }
      return response;
    }
  }

  public with sharing class RevokeConsent extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      Id client = (Id) params.get('client');
      cym.ResourceOwner context = cym.ResourceOwner.getCurrent();
      cym.ResourceOwner.Consent clientConsent = (cym.ResourceOwner.Consent) context.consents.find('client', client);
      clientConsent?.revoke();
      return null;
    }
  }

  public with sharing class GetAllBrowsers extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      cym.Collection sessions = cym.ResourceOwner.getCurrent().sessions;
      Id[] loginHistoryIds = sessions.pluck('lastLoginHistoryId').asIds();
      Map<Id, LoginHistory> lhs = new Map<Id, LoginHistory> (new UserRepository().getLoginHistoryByIds(loginHistoryIds));

      Object[] response = new Object[] {};
      cym.Browser.Session currentSession = this.session;
      for (cym.Collection.Item v : sessions.asList()) {
        cym.ResourceOwner.Session s = (cym.ResourceOwner.Session) v;
        response.add(new Map<String, Object> {
          'id' => s.id,
          'browser' => lhs.get(s.lastLoginHistoryId).Browser,
          'platform' => lhs.get(s.lastLoginHistoryId).Platform,
          'lastSeen' => s.lastModifiedDate.getTime(),
          'isCurrent' => s.id == currentSession?.id
        });
      }
      return response;
    }
  }

  public with sharing class RevokeSession extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      cym.ResourceOwner.Session session = (cym.ResourceOwner.Session) cym.ResourceOwner.getCurrent().sessions.find('id', (Id) params.get('session'));
      if (session != null) session.revoke();
      return null;
    }
  }

  public with sharing class GetAllClientSession extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      cym.ResourceOwner context = cym.ResourceOwner.getCurrent();
      Map<Id, Object[]> groupedByClientId = new Map<Id, Object[]>();
      for (cym.Collection.Item t : context.refreshtokens.asList()) {
        cym.ResourceOwner.RefreshToken token = (cym.ResourceOwner.RefreshToken) t;
        if (!groupedByClientId.containsKey(token.client)) groupedByClientId.put(token.client, new Object[] {});
        groupedByClientId.get(token.client).add(token.id);
      }

      Object[] response = new Object[] {};
      for (cym__Client__c c : new ClientRepository().find(groupedByClientId.keySet())) {
        response.add(new Map<String, Object> {
          'id' => c.Id,
          'client_name' => c.Name,
          'client_uri' => c.cym__ClientUri__c,
          'logo_uri' => c.cym__LogoUri__c,
          'sessions' => groupedByClientId.get(c.Id).size()
        });
      }

      return response;
    }
  }

  public with sharing class RevokeClientSession extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      cym.ResourceOwner context = cym.ResourceOwner.getCurrent();
      context.refreshtokens.revoke((Id) params.get('client'));
      return null;
    }
  }

  public with sharing class RevokeClientSessions extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      cym.ResourceOwner context = cym.ResourceOwner.getCurrent();
      context.refreshtokens.revoke();
      return null;
    }
  }

  public with sharing class RevokeSessions extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      cym.ResourceOwner context = cym.ResourceOwner.getCurrent();
      context.sessions.revoke();
      // Add login to revoke all Salesforce Sessions as well
      // delete (AuthSession[]) [SELECT Id FROM AuthSession WHERE UsersId = :UserInfo.getUserId()];
      return null;
    }
  }

  public with sharing class RenameCredential extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      Id userId = UserInfo.getUserId();
      String name = (String) params.get('name');
      Id id = (Id) params.get('id');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);
      String response = session.getRemoteApex(
        WebAuthnController.RenameCredentialRemote.class
      ).invoke(
        JSON.serialize(
          new Map<String, Object> {
            'id' => id,
            'name' => name
          }
        )
      );
      return (Map<String, Object>) JSON.deserializeUntyped(response);
    }
  }

  public with sharing class GetAllWebAuthnCredentials extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      return cym.WebAuthn.getAllCredentials().pluck(new String[] {'id', 'name', 'transports'}).asObjects();
    }
  }

  public with sharing class GetSecurityStatus extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      TwoFactorMethodsInfo info = new UserUtils.Repository().getTwoFactorInfo(UserInfo.getUserId());
      return new Map<String, Object> {
        'id' => UserInfo.getUserId(),
        'lastPasswordChangeTime' => new UserRepository().getLastPasswordChangeDate()?.getTime(),
        'hasUserVerifiedEmailAddress' => info.hasUserVerifiedEmailAddress,
        'hasTotp' => info.hasTotp,
        'totpCreationDate' => new UserRepository().getTotpEnrollementDate()?.getTime(),
        'socialProviders' => new Map<String, Object> {
          'available' => UserUtils.getCommunityAuthProviders('/me'),
          'enrolled' => new UserUtils.Repository().findThirdPartyAccountLink(UserInfo.getUserId())
        },
        'hasSalesforceAuthenticator' => info.HasSalesforceAuthenticator
      };
    }
  }


  public with sharing class GetSecurityProfile extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return Network.forwardToAuthPage('/me');
      TwoFactorMethodsInfo info = new UserUtils.Repository().getTwoFactorInfo(UserInfo.getUserId());
      User u = new UserUtils.Repository().findById(UserInfo.getUserId());
      return new Map<String, Object> {
        'id' => UserInfo.getUserId(),
        'identifiers' => new Map<String, Object> {
          'primary' => Users.getPrimaryIdentifier(u),
          'secondary' => Users.getSecondaryIdentifier(u)
        },
        'authenticators' => new Map<String, Object> {
          'password' => new Map<String, Object> {'enabled' => true, 'lastModifiedDate' => new UserRepository().getLastPasswordChangeDate()?.getTime()},
          'totp' => !info.hasTotp ? new Map<String, Object> {'enabled' => false} : new Map<String, Object> {'enabled' => true, 'createdDate' => new UserRepository().getTotpEnrollementDate().getTime() },
          'socialProviders' => new Map<String, Object> {
            'available' => UserUtils.getCommunityAuthProviders('/me'),
            'enrolled' => new UserUtils.Repository().findThirdPartyAccountLink(UserInfo.getUserId())
          },
          'push' => new Map<String, Object> {'enabled' => info.HasSalesforceAuthenticator }
        }
      };
    }
  }



  public with sharing class CheckCriticalAccess extends Fetch.Function {
    public override Object execute(Map<String, Object> param) {
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), UserInfo.getUserId());

      cym.Collection.Item[] verifications = session.verifications.asList();
      cym.Community.Authenticator webauthn_platform = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'webauthn_platform');
      cym.Community.Authenticator salesforce_push   = (cym.Community.Authenticator) cym.Community.getCurrent().authenticators.find('name', 'salesforce_push');
      Boolean isValid = false;
      for (cym.Collection.Item v : verifications) {
        cym.Browser.SessionVerification verification = (cym.Browser.SessionVerification) v;
        if (verification.authenticator == webauthn_platform.id && verification.lastVerificationTime.addSeconds(30) > Datetime.now()) {isValid = true; break;}
        if (verification.authenticator == salesforce_push.id   && verification.lastVerificationTime.addSeconds(30) > Datetime.now()) {isValid = true; break;}
      }
      return new Map<String, Object> { 'isValid' => isValid };
    }
  }




  public without sharing class ClientRepository {
    public cym__Client__c[] find(Set<Id> ids) {
      return (cym__Client__c[]) [SELECT Id, Name, cym__ClientUri__c, cym__LogoUri__c, cym__Realm__c FROM cym__Client__c WHERE Id IN :ids];
    }
  }

  public without sharing class UserRepository {
    public Datetime getLastPasswordChangeDate () {
      return [SELECT LastPasswordChangeDate FROM User WHERE Id = :UserInfo.getUserId()].LastPasswordChangeDate; // NOPMD.ApexCRUDViolation
    }
    public Datetime getTotpEnrollementDate () {
      return [SELECT CreatedDate FROM TwoFactorInfo WHERE UserId = :UserInfo.getUserId()]?.CreatedDate; // NOPMD.ApexCRUDViolation
    }

    public LoginHistory[] getLoginHistoryByIds(Id[] ids) {
      return (LoginHistory[]) [SELECT Id, Browser, Platform FROM LoginHistory WHERE Id IN :ids];
    }
  }
}
