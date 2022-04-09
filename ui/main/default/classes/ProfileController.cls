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
    Auth.AuthConfiguration authConfig = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), ApexPages.currentPage().getParameters().get('startURL'));
    this.backgroundColor = authConfig.getBackgroundColor();
  }

  global class Translate extends cym.Remote.Function {
    global override String execute(String param) {
      Object[] scopes = (Object[]) JSON.deserializeUntyped(param);
      String[] response = new String[] {};
      for (Object scp : scopes) {
        try {
          Component.Apex.OutputText output = new Component.Apex.OutputText();
          output.expressions.value = '{!$Label.' + (String) scp + '}';
          response.add(String.valueOf(output.value));
        } catch (Exception ex) {
          response.add((String) scp);
        }
      }
      return JSON.serialize(response);
    }
  }

  public with sharing class GetAllConsent extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      cym.UserContext context = cym.UserContext.getContext();
      cym.Community idp = cym.Community.getCurrent();
      try {
        Set<Id> clientIds = new Set<Id>();
        for (cym.UserContext.Consent consent : context.consents.asList()) clientIds.add(consent.client);
        Map<Id, Map<String, Object>> clients = new Map<Id, Map<String, Object>>();
        for(cym__Client__c client: new ClientRepository().find(clientIds)) {
          clients.put(client.Id, new Map<String, Object> {
            'id' => client.Id,
            'client_name' => client.Name,
            'client_uri' => client.cym__ClientUri__c,
            'logo_uri' => client.cym__LogoUri__c
          });
        }

        Object[] response = new Object[] {};
        for (cym.UserContext.Consent consent : context.consents.asList()) {
          Map<String, Object> c = clients.get(consent.client);
          c.put('scopes', (Object[]) JSON.deserializeUntyped(idp.getRemoteApex(ProfileController.Translate.class).invoke(JSON.serialize(consent.scopes))));
          c.put('createdDate', consent.CreatedDate.getTime());
          response.add(c);
        }
        return response;
      } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
      }
    }
  }

  public with sharing class RevokeConsent extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id client = (Id) params.get('client');
      cym.UserContext context = cym.UserContext.getContext();
      try {
        cym.UserContext.Consent clientConsent = null;
        for (cym.UserContext.Consent consent : context.consents.asList()) {
          if (consent.client == client) {
            clientConsent = consent;
            break;
          }
        }
        clientConsent?.revoke();
      } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
      }
      return null;
    }
  }

  public with sharing class GetAllBrowsers extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      cym.UserContext.Session[] sessions = cym.UserContext.getContext().sessions.asList();
      Id[] loginHistoryIds = new Id[]{};
      for (cym.UserContext.Session s : sessions) loginHistoryIds.add(s.lastLoginHistoryId);
      Map<Id, LoginHistory> lhs = new Map<Id, LoginHistory> (new UserRepository().getLoginHistoryByIds(loginHistoryIds));

      Object[] response = new Object[] {};
      cym.Browser.Session currentSession = this.session;
      for (cym.UserContext.Session s : sessions) {
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
        cym.UserContext.Session session;
        for (cym.UserContext.Session s : cym.UserContext.getContext().sessions.asList()) if (s.id == (Id) params.get('session')) { session = s; break;}
        if (session != null) session.revoke();
        return null;
    }
  }

  public with sharing class GetAllClientSession extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      cym.UserContext context = cym.UserContext.getContext();
      Map<Id, Object[]> groupedByClientId = new Map<Id, Object[]>();
      for (cym.UserContext.RefreshToken token : context.refreshtokens.asList()) {
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
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      cym.UserContext context = cym.UserContext.getContext();
      context.refreshtokens.revoke((Id) params.get('client'));
      return null;
    }
  }

  public with sharing class RevokeClientSessions extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      cym.UserContext context = cym.UserContext.getContext();
      context.refreshtokens.revoke();
      return null;
    }
  }

  public with sharing class RevokeSessions extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      cym.UserContext context = cym.UserContext.getContext();
      context.sessions.revoke();
      // Add login to revoke all Salesforce Sessions as well
      // delete (AuthSession[]) [SELECT Id FROM AuthSession WHERE UsersId = :UserInfo.getUserId()];
      return null;
    }
  }

  public with sharing class RenameCredential extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      Id userId = UserInfo.getUserId();
      String name = (String) params.get('name');
      Id id = (Id) params.get('id');
      cym.Browser.Session session = WebAuthnController.findOrAddSession(cym.Browser.getCurrent(), userId);
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
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      Object[] credentials = new Object[] {};
      for (cym.WebAuthn.Credential cred : cym.WebAuthn.getAllCredentials()) {
        credentials.add(
          new Map<String, Object> {
            'id' => cred.id,
            'name' => cred.name,
            'transports' => cred.transports
          }
        );
      }
      return credentials;
    }
  }

  public with sharing class GetSecurityStatus extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      if (Auth.CommunitiesUtil.isGuestUser()) return null;
      TwoFactorMethodsInfo info = new UserUtils.Repository().getTwoFactorInfo(UserInfo.getUserId());
      return new Map<String, Object> {
        'lastPasswordChangeTime' => new UserRepository().getLastPasswordChangeDate().getTime(),
        'hasUserVerifiedEmailAddress' => info.hasUserVerifiedEmailAddress,
        'hasTotp' => info.hasTotp,
        'totpCreationDate' => new UserRepository().getTotpEnrollementDate()?.getTime()
      };
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
