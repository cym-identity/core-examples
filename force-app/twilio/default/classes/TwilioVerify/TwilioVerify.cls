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
    cym.AuthorizationContext.Authenticator authenticator;
    public Sms(cym.AuthorizationContext.Authenticator authenticator) {
      // if (authenticator?.provider != 'cym_TwilioVerify_Sms') throw new InvalidArgumentException('invalid authenticator');
      this.authenticator = authenticator;
    }

    // Dummy authenticator;
    // public Sms(Dummy authenticator) {}

    public String initChallenge(Map<String, Object> args) {
      String phone_number = (String) args.get('phone_number');

      if (String.isBlank(phone_number)) throw new InvalidArgumentException('A Phone number must be provided');

      String account_sid = (String) this.authenticator.get('account_sid');
      String auth_token = (String) this.authenticator.get('auth_token');
      String service_id = (String) this.authenticator.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio configuration missing');


      Map<String, String> payload = new Map<String, String> {
        'To' => phone_number,
        'Channel' => 'sms'
      };
      if (this.authenticator.get('CustomFriendlyName') != null) payload.put('CustomFriendlyName', (String) this.authenticator.get('CustomFriendlyName'));
      if (this.authenticator.get('Locale') != null) payload.put('Locale', (String) this.authenticator.get('Locale'));
      if (this.authenticator.get('CustomCode') != null) payload.put('CustomCode', (String) this.authenticator.get('CustomCode'));
      if (this.authenticator.get('AppHash') != null) payload.put('AppHash', (String) this.authenticator.get('AppHash'));

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/Verifications');
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token)));
      req.setMethod('POST');
      req.setBody(TwilioVerify.fromMapToUrlString(payload));
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() != 200) return null;
      return (String) response.get('sid');
    }

    public String verifyChallenge(Map<String, Object> args) {

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

      if (resp.getStatusCode() != 200) return null;

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      return (String) response.get('status');
    }
  }

  public class InvalidArgumentException extends Exception {}

  public class Dummy {
    public Object get(String name) { return null; }
  }

  private static String fromMapToUrlString(Map<String, String> params) {
    String enc = 'UTF-8';
    String[] results = new String[] {};
    for (String key: params.keySet()) {
      results.add( EncodingUtil.urlEncode(key, enc) + '=' + EncodingUtil.urlEncode(params.get(key), enc) );
    }
    return String.join(results, '&');
  }
}
