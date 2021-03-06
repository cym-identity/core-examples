public inherited sharing class TwilioVerify {
  private static final transient String TWILIO_URL = 'https://verify.twilio.com/v2';

  @AuraEnabled(cacheable=true)
  public static Boolean is_twilio_reachable(){
    try {
      HttpRequest req = new HttpRequest();
      req.setMethod('GET');
      req.setEndpoint(TWILIO_URL);
      HttpResponse resp = new Http().send(req);
      return true;
    } catch (System.CalloutException e) {
      return false;
    } catch (Exception e) {
      throw new AuraException(e.getMessage());
    }
  }

  public class Sms {
    cym.CommunityContext.Authenticator authenticator;
    public Sms(cym.CommunityContext.Authenticator authenticator) {
      this.authenticator = authenticator;
    }

    public Map<String, Object> initChallenge(Map<String, Object> args) {
      String phone_number = (String) args.get('phoneNumber');

      if (String.isBlank(phone_number)) throw new InvalidArgumentException('A Phone number must be provided');

      String account_sid = (String) this.authenticator.get('account_sid');
      String auth_token = (String) this.authenticator.get('auth_token');
      String service_id = (String) this.authenticator.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio configuration missing');


      Map<String, String> payload = new Map<String, String> {
        'To' => phone_number,
        'Channel' => 'sms'
      };
      if (args.get('CustomFriendlyName') != null) payload.put('CustomFriendlyName', (String) args.get('CustomFriendlyName'));
      if (args.get('Locale') != null) payload.put('Locale', (String) args.get('Locale'));
      if (args.get('CustomCode') != null) payload.put('CustomCode', (String) args.get('CustomCode'));

      if (String.isNotBlank((String) this.authenticator.get('AppHash'))) payload.put('AppHash', (String) this.authenticator.get('AppHash'));

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/Verifications');
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token)));
      req.setMethod('POST');
      req.setBody(TwilioVerify.fromMapToUrlString(payload));
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() != 201) return new Map<String, Object> {
        'error' => response,
        'statusCode' => resp.getStatusCode()
      };
      return response;
    }

    public Map<String, Object> verifyChallenge(Map<String, Object> args) {

      String account_sid = (String) this.authenticator.get('account_sid');
      String auth_token = (String) this.authenticator.get('auth_token');
      String service_id = (String) this.authenticator.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio configuration missing');

      Map<String, String> payload = new Map<String, String> {
        'VerificationSid' => (String) args.get('VerificationSid'),
        'Code' => (String) args.get('Code')
      };

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/VerificationCheck');
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token)));
      req.setMethod('POST');
      req.setBody(TwilioVerify.fromMapToUrlString(payload));
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() != 200) return new Map<String, Object> {
        'error' => response,
        'statusCode' => resp.getStatusCode()
      };
      return response;
    }
  }

  public class InvalidArgumentException extends Exception {}

  private static String fromMapToUrlString(Map<String, String> params) {
    String enc = 'UTF-8';
    String[] results = new String[] {};
    for (String key: params.keySet()) {
      results.add( EncodingUtil.urlEncode(key, enc) + '=' + EncodingUtil.urlEncode(params.get(key), enc) );
    }
    return String.join(results, '&');
  }
}
