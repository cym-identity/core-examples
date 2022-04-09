@RestResource(urlMapping='/authenticators/TwilioVerifyPush/*/webhook')
global with sharing class TwilioWebHookEndpoint {
  @HttpPost
  global static void doPost() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    response.addHeader('Access-Control-Allow-Origin', '*');
    response.addHeader('Content-Type', 'application/json');


    try {

      System.debug(JSON.serializePretty(request));

      // The community is linked to CYM Identity
      cym.Community context = cym.Community.getCurrent();
      if (context == null) throw new BadRequestException('invalid_community');
      if (!request.headers.containsKey('X-Twilio-Signature')) throw new UnAuthorizedException('Not Authorized');

      // The authenticatorName will never be empty. This is how salesforce parses the /*/ in the URL
      String authenticatorName = getAuthenticatorNameFromUri(request.requestUri);

      // Check if there's an authenticator with the correct name
      cym.Community.Authenticator authenticator = context.authenticators.find('name', authenticatorName);
      if ( authenticator == null ) throw new BadRequestException('invalid_authenticator');
      // Check if the authenticator is a TwilioVerify Push
      if (authenticator.providerName != 'TwilioVerify_Push') throw new BadRequestException('invalid_authenticator');

      String[] keys = new List<String>(request.params.keySet());
      keys.sort();

      String signature = Site.getBaseRequestUrl() + '/services/apexrest' + request.requestURI;
      for (String key : keys) signature += key + request.params.get(key);

      Boolean isValid = EncodingUtil.base64Encode(
        Crypto.generateMac('hmacSHA1', Blob.valueOf(signature), Blob.valueOf((String) authenticator.get('auth_token')))
      ) == request.headers.get('X-Twilio-Signature');

      if (!isValid) throw new BadRequestException('invalid_signature');

      switch on request.params.get('type') {
        when 'factor.verified' {

        }
        when else {

        }
      }
      response.statusCode = 200;
      response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
        'params' => keys,
        'request' => signature,
        'authtoken' => (String) authenticator.get('auth_token'),
        'isValid' => isValid
      }));
    } catch(UnAuthorizedException ex) {
      response.statusCode = 401;
      response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
        'error' => ex.getMessage()
      }));
      return;
    } catch(BadRequestException ex) {
      response.statusCode = 400;
      response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
        'error' => ex.getMessage()
      }));
      return;
    } catch (Exception ex) {
      response.statusCode = 500;
      response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object> {
        'error' => ex.getMessage()
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

  public class BadRequestException extends Exception {}
  public class ForbiddenException extends Exception {}
  public class UnAuthorizedException extends Exception {}
  public class ServerErrorException extends Exception {}

}
