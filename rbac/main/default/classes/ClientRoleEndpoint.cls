@RestResource(urlMapping = '/realms/*/clients/*/roles/*')
global with sharing class ClientRoleEndpoint {
  private static final Integer OFFSET = 0; // Use 0 when your Org does not have a namespace
  private static final String RoleManagementServerName = 'RoleManagementServer';
  private static final String RoleManagementServerCert = 'role_ressource_server';

  @HttpGet
  global static void doGet(){
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    response.addHeader('Content-Type', 'application/json');
    try {
      cym.Community idp = cym.Community.getCurrent();
      // cym.Browser browser = cym.Browser.getCurrent();

      response.statusCode = 200;

      PathParams params = readPathParams(request.requestURI);
      Map<String, Object> introspection = introspect(params.realmName, idp.getSessionId(), 'roles.manage');

      response.responseBody = Blob.valueOf(
        String.isBlank(params.roleName) ?
          JSON.serialize(new SafeRepository().listClientRoles(params.clientId)) :
          JSON.serialize(new SafeRepository().getClientRole(params.clientId, params.roleName))
      );
    } catch (InvalidArgumentException ex) {
      response.statusCode = 400;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (ForbiddenException ex) {
      response.statusCode = 403;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (NotFoundException ex) {
      response.statusCode = 404;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (Exception ex) {
      response.statusCode = 500;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    }
  }

  @HttpPost
  global static void doPost() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    response.addHeader('Content-Type', 'application/json');
    try {
      cym.Community idp = cym.Community.getCurrent();

      response.statusCode = 200;

      PathParams params = readPathParams(request.requestURI);
      if (String.isNotBlank(params.roleName)) throw new InvalidArgumentException('Must use the POST method with a Role');

      Map<String, Object> introspection = introspect(params.realmName, idp.getSessionId(), 'roles.manage');

      if ((String) introspection.get('client_id') != params.clientId) throw new ForbiddenException('Only the client_id can create its own roles');

      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.requestBody.toString());
      if (! payload.containsKey('name') || String.isBlank((String) payload.get('name')))  throw new InvalidArgumentException('You must provide a Name for the role to be created');

      ClientRole__c role = new ClientRole__c(
        Name__c = (String) payload.get('name'),
        Description__c = (String) payload.get('description'),
        Client__c = new SafeRepository().getClient(params.clientId).Id,
        IsRequiredForLogin__c = (Boolean) payload.get('isRequiredForLogin')
      );

      insert role; // NOPMD.ApexCRUDViolation

      response.responseBody = Blob.valueOf(
        JSON.serialize(role)
      );
    } catch (InvalidArgumentException ex) {
      response.statusCode = 400;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (ForbiddenException ex) {
      response.statusCode = 403;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (NotFoundException ex) {
      response.statusCode = 404;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (Exception ex) {
      response.statusCode = 500;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    }
  }

  @HttpPut
  global static void doPut() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    response.addHeader('Content-Type', 'application/json');
    try {
      cym.Community idp = cym.Community.getCurrent();

      response.statusCode = 200;

      PathParams params = readPathParams(request.requestURI);
      if (String.isBlank(params.roleName)) throw new InvalidArgumentException('Cannot PUT without a Role');

      Map<String, Object> introspection = introspect(params.realmName, idp.getSessionId(), 'roles.manage');

      if ((String) introspection.get('client_id') != params.clientId) throw new ForbiddenException('Only the client_id can create its own roles');

      Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.requestBody.toString());
      if (! payload.containsKey('name') || String.isBlank((String) payload.get('name')))  throw new InvalidArgumentException('You must provide a Name for the role to be created');

      ClientRole__c role = new SafeRepository().getClientRole(params.clientId, params.roleName);


      ClientRole__c r = new ClientRole__c(
        Id = role.Id,
        Name__c = (String) payload.get('name'),
        Description__c = (String) payload.get('description'),
        Client__c = new SafeRepository().getClient(params.clientId).Id,
        IsRequiredForLogin__c = (Boolean) payload.get('isRequiredForLogin')
      );

      update r;// NOPMD.ApexCRUDViolation

      response.responseBody = Blob.valueOf(
        JSON.serialize(r)
      );
    } catch (InvalidArgumentException ex) {
      response.statusCode = 400;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (ForbiddenException ex) {
      response.statusCode = 403;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (NotFoundException ex) {
      response.statusCode = 404;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    } catch (Exception ex) {
      response.statusCode = 500;
      response.responseBody = Blob.valueOf(JSON.serialize(ConverterUtils.toMap(ex)));
    }
  }

  public static Map<String, Object> introspect(String realm, String access_token, String scope) {
    cym__Client__c c = new UnsafeRepository().getRoleRessourceServer(realm);
    if (c == null) throw new InvalidArgumentException('invalid_configuration');
    String introspection_endpoint = Site.getBaseRequestUrl() + '/services/apexrest/cym/oauth/' + realm + '/introspect';
    Auth.JWT jwt = new Auth.JWT();
    jwt.setAud(introspection_endpoint);
    jwt.setIss(c.cym__ClientId__c);
    jwt.setSub(c.cym__ClientId__c);

    String client_assertion = new Auth.JWS(jwt, RoleManagementServerCert).getCompactSerialization();

    HttpRequest req = new HttpRequest();
    req.setMethod('POST');
    req.setEndpoint(introspection_endpoint);
    req.setBody(ConverterUtils.fromMapToUrlString(new Map<String, String> {
        'token' => access_token,
        'token_hint' => 'access_token',
        'client_assertion' => client_assertion,
        'client_assertion_type' => 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
    }));
    HttpResponse resp = new Http().send(req);
    if (resp.getStatusCode() != 200) throw new InvalidArgumentException(resp.getBody());

    Map<String, Object> introspection = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
    if (false == (Boolean) introspection.get('active')) throw new ForbiddenException('inactive_token');
    if (c.cym__ClientId__c != (String) introspection.get('sub')) throw new ForbiddenException('invalid_sub');
    if (c.cym__ClientId__c != (String) introspection.get('aud')) throw new ForbiddenException('invalid_aud');
    if (((String) introspection.get('scope'))?.split(' ').indexOf(scope) == -1) throw new ForbiddenException('invalid_scope');


    return introspection;
  }
  private without sharing class UnsafeRepository {
    public cym__Client__c getRoleRessourceServer(String realm) {
      cym__Client__c[] a = [SELECT Id, cym__ClientId__c FROM cym__Client__c WHERE Name = :RoleManagementServerName AND cym__Realm__r.cym__Name__c = : realm]; // NOPMD.ApexCRUDViolation
      if (a.size() == 0) return null;
      return a[0];
    }
  }

  @TestVisible
  private static PathParams readPathParams(String path) {
    String[] parsed = path.split('/');
    if (parsed.size() > 7 + OFFSET) throw new InvalidArgumentException('UNKNOWN_RESOURCE');
    return new PathParams(parsed[2 + OFFSET], parsed[4 + OFFSET], parsed.size() == 7 + OFFSET ? parsed[6 + OFFSET] : null);
  }
  private class PathParams {
    public String realmName;
    public String clientId;
    public String roleName;

    public PathParams(String realmName, String clientId, String roleName) {
      this.realmName = realmName;
      this.clientId = clientId;
      this.roleName = roleName;
    }
  }

  public with sharing class SafeRepository {
    public ClientRole__c[] listClientRoles(String client_id) {
      return [SELECT Id, Name__c, Description__c, IsRequiredForLogin__c FROM ClientRole__c WHERE Client__r.cym__ClientId__c = :client_id]; // NOPMD.ApexCRUDViolation
    }
    public ClientRole__c getClientRole(String client_id, String roleName) {
      ClientRole__c[] roles = [SELECT Id, Name__c, Description__c FROM ClientRole__c WHERE Client__r.cym__ClientId__c = :client_id AND Name__c = :roleName]; // NOPMD.ApexCRUDViolation
      if (roles.size() == 0) throw new NotFoundException('not found');
      return roles[0];
    }
    public cym__Client__c getClient(String client_id) {
      cym__Client__c[] c = [SELECT Id FROM cym__Client__c WHERE cym__ClientId__c = :client_id]; // NOPMD.ApexCRUDViolation
      if (c.size() == 0) throw new NotFoundException('not found');
      return c[0];
    }
  }


  public class InvalidArgumentException extends Exception {}
  public class ForbiddenException extends Exception {}
  public class NotFoundException extends Exception {}
}
