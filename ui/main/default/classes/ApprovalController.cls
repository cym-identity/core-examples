public with sharing class ApprovalController {

  @AuraEnabled
  public static Map<String, Object> init(String startURL){
    try {
      Map<String, String[]> scopes = new Map<String, String[]> ();
      cym.AuthorizationContext context = cym.AuthorizationContext.getContext(startURL);
      scopes.put('requested', context.request.scope);
      scopes.put('existing', context.consent.scopes);
      return new Map<String, Object> {
        'scopes' => scopes,
        'client' => JSON.deserializeUntyped(JSON.serialize(context.client))
      };
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static String save(String startURL){
    try {
      cym.AuthorizationContext context = cym.AuthorizationContext.getContext(startURL);
      context.consent.replace(context.request.scope);

      PageReference pr = new PageReference(startURL); // NOPMD-ApexOpenRedirect
      pr.getParameters().remove('prompt');
      return pr.getUrl();

    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Map<String, String[]> getScopeList(String startURL) {
    Map<String, String[]> scopes = new Map<String, String[]> ();
    cym.AuthorizationContext context = cym.AuthorizationContext.getContext(startURL);
    scopes.put('requested', context.request.scope);
    scopes.put('existing', context.consent.scopes);
    return scopes;
  }
}
