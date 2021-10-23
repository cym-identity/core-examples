public with sharing class AuthenticatorConfigController {

  @AuraEnabled
  public static Map<String,Object> getAuthenticatorConfig(Id authenticator_id){
    return (Map<String,Object>) cym.AdministrationContext.getContext().getCommunityAuthenticatorConfig(authenticator_id);
  }

  @AuraEnabled
  public static Map<String, Object> saveAuthenticatorConfig(Id authenticator_id, Map<String, Object> config){
    cym.AdministrationContext.getContext().saveCommunityAuthenticatorConfig(authenticator_id, config);
    return config;
  }
}
