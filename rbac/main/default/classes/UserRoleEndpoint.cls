@RestResource(urlMapping = '/realms/*/clients/*/roles/*/users/*')
global with sharing class UserRoleEndpoint {
  private static final Integer OFFSET = 0; // Use 0 when your Org does not have a namespace

  @HttpGet
  global static void doGet(){
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    response.addHeader('Content-Type', 'application/json');
    try {
      cym.Community idp = cym.Community.getCurrent();
      response.statusCode = 200;

      PathParams params = readPathParams(request.requestURI);

      Map<String, Object> introspection = ClientRoleEndpoint.introspect(params.realmName, idp.getSessionId(), 'roles.manage');

      response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
        'path' => request.requestURI.split('/'),
        'realm' => params.realmName,
        'user' => params.userId,
        'role' => params.roleName,
        'clientId' => params.clientId
      }));
    } catch (Exception ex) {
      response.statusCode = 500;
      response.responseBody = Blob.valueOf(JSON.serialize(ex));
    }
  }

  @HttpPost
  global static void doPost(){
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    response.addHeader('Content-Type', 'application/json');
    try {
      cym.Community idp = cym.Community.getCurrent();
      response.statusCode = 200;

      PathParams params = readPathParams(request.requestURI);

      Map<String, Object> introspection = ClientRoleEndpoint.introspect(params.realmName, idp.getSessionId(), 'roles.manage');




      response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
        'path' => request.requestURI.split('/'),
        'realm' => params.realmName,
        'user' => params.userId,
        'role' => params.roleName,
        'clientId' => params.clientId
      }));
    } catch (Exception ex) {
      response.statusCode = 500;
      response.responseBody = Blob.valueOf(JSON.serialize(ex));
    }
  }


  @TestVisible
  private static PathParams readPathParams(String path) {
    String[] parsed = path.split('/');
    if (parsed.size() > 9 + OFFSET) throw new InvalidArgumentException('UNKNOWN_RESOURCE');
    return new PathParams(parsed[2 + OFFSET], parsed[4 + OFFSET], parsed[6 + OFFSET], parsed.size() == 9 + OFFSET ? parsed[8 + OFFSET] : null);
  }


  private class PathParams {
    public String realmName;
    public String clientId;
    public String userId;
    public String roleName;

    public PathParams(String realmName, String clientId, String roleName, String userId) {
      this.realmName = realmName;
      this.clientId = clientId;
      this.userId = userId;
      this.roleName = roleName;
    }
  }

  public class InvalidArgumentException extends Exception {}
}
