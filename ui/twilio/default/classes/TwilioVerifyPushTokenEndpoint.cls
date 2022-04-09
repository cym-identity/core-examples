@RestResource(urlMapping='/authenticators/TwilioVerifyPush/*/token')
global with sharing class TwilioVerifyPushTokenEndpoint {

  @HttpPost
  global static void doPost() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    response.addHeader('Access-Control-Allow-Origin', '*');
    response.addHeader('Content-Type', 'application/json');

    try {
      // The community is linked to CYM Identity
      cym.Community context = cym.Community.getCurrent();
      if( context == null ) {
        response.statusCode = 400;
        response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
          'error' => 'invalid_community'
        }));
        return;
      }

      // The authenticatorName will always be not empty. This is how salesforce parses the /*/ in the URL
      String authenticatorName = getAuthenticatorNameFromUri(request.requestUri);

      // Check if there's an authenticator with the correct name
      TwilioVerify.Push authenticator = (TwilioVerify.Push) context.authenticators.find('name', authenticatorName);
      if( authenticator == null ) {
        response.statusCode = 400;
        response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
          'error' => 'invalid_authenticator'
        }));
        return;
      }

      // Check if the authenticator is a TwilioVerify Push
      // if (authenticator.providerName != 'TwilioVerify_Push') {
      //   response.statusCode = 400;
      //   response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
      //     'error' => 'invalid_authenticator'
      //   }));
      //   return;
      // }

      // Introspect the current session
      String client_id = (String) authenticator.get('introspection_client_id');
      String client_secret = (String) authenticator.get('introspection_client_secret');
      String introspection_endpoint = (String) authenticator.get('introspection_endpoint');

      // The configuration is incomplete
      if (String.isBlank(client_id) || String.isBlank(client_secret)) {
        response.statusCode = 401;
        response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
          'error' => 'Bad Authenticator Credentials'
        }));
        return;
      }

      // The call is under Guest Mode
      if (String.isBlank(context.getSessionId())) {
        response.statusCode = 401;
        response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
          'error' => 'You must login first'
        }));
        return;
      }

      // Introspect the Access Token
      HttpRequest req = new HttpRequest();
      req.setEndpoint(introspection_endpoint);
      req.setMethod('POST');
      req.setBody(TwilioVerifyUtils.fromMapToUrlString(new Map<String, String> {
        'token' => context.getSessionId(),
        'client_id' => client_id,
        'client_secret' => client_secret
      }));

      HttpResponse resp = new Http().send(req);

      if (resp.getStatusCode() != 200) {
        response.statusCode = 500;
        response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
          'error' => 'unable to validate the current sessin'
        }));
        return;
      }

      Map<String, Object> introspection = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());

      System.debug(introspection);

      // The Access Token has not expired or hasn't been revoked
      if (false == (Boolean) introspection.get('active')) {
        response.statusCode = 401;
        response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
          'error' => 'access_token expired revoked or invalid'
        }));
        return;
      }

      // The Access Token was issued to the client_id in the configuration
      if ((String) authenticator.get('client_id') != (String) authenticator.get('client_id')) {
        response.statusCode = 403;
        response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
          'error' => 'You are not allowed to call this endpoint'
        }));
        return;
      }

      // You can check if the user already has a push notification app and block it

      response.statusCode = 200;
      response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
        'identity' => UserInfo.getUserId(),
        'serviceId' => (String) authenticator.get('service_sid'),
        'token' => authenticator.getAccessToken()
        // 'factors' => factors,
        // 'challenges' => challenges
      }));
    } catch (Exception ex) {
      response.statusCode = 500;
      response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
        'error' => ex.getMessage(),
        'stack_trace' =>  ex.getStackTraceString().split('\n')
      }));
    }
  }

  private static String getAuthenticatorNameFromUri(String requestUri) {
    String[] split = requestUri?.split('/');
    return split == null ? null : split[String.isNotBlank(TwilioVerifyPushTokenEndpoint.namespace) ? 4 : 3];
  }

  public static String namespace {
    get {
      return [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
    }
  }

}
