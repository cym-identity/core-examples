public with sharing class ProfileController {
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

  @AuraEnabled
  public static Map<String, Object> getAllConsent(){
    cym.UserContext context = cym.UserContext.getContext();
    Map<String, Object> response = new Map<String, Object>();
    try {
      Set<Id> clientIds = new Set<Id>();
      for (cym.UserContext.Consent consent : context.consents.asList()) clientIds.add(consent.client);
      Map<Id, Object> clients = new ClientRepository().find(clientIds);
      for (cym.UserContext.Consent consent : context.consents.asList()) {
        response.put(consent.client, new Map<String, Object>{
          'client' => clients.get(consent.client),
          'scopes' => consent.scopes
        });
      }
      return response;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void revokeConsent(Id client_id){
    cym.UserContext context = cym.UserContext.getContext();
    try {
      cym.UserContext.Consent clientConsent = null;
      for (cym.UserContext.Consent consent : context.consents.asList()) {
        if (consent.client == client_id) {
          clientConsent = consent;
          break;
        }
      }
      clientConsent?.revoke();
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Map<Id, Object> getAllClientSession(){
    cym.UserContext context = cym.UserContext.getContext();
    try {
      // return new ClientRepository().find(context.refreshtokens.keySet());
      return null;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void revokeClientSession(Id client_id){
    cym.UserContext context = cym.UserContext.getContext();
    try {
      context.refreshtokens.revoke();
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void revokeSessions(Id client_id){
    cym.UserContext context = cym.UserContext.getContext();
    try {
      context.sessions.revoke();
      // Add login to revoke all Salesforce Sessions as well
      // delete (AuthSession[]) [SELECT Id FROM AuthSession WHERE UsersId = :UserInfo.getUserId()];
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  public without sharing class ClientRepository {
    public Map<Id, Object> find(Set<Id> ids) {
      cym__Client__c[] clients = [SELECT Id, Name, cym__ClientUri__c, cym__Realm__c FROM cym__Client__c WHERE Id IN :ids];
      Map<Id, Object> results = new Map<Id, Object>();
      for(cym__Client__c client: clients) {
        results.put(client.Id, new Map<String, Object> {
          'client_name' => client.Name,
          'client_uri' => client.cym__ClientUri__c
        });
      }
      return results;
    }
  }
}
