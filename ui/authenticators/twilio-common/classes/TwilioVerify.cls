global inherited sharing class TwilioVerify { // NOPMD-AvoidGlobalModifier
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

  global class Sms extends cym.Community.AuthenticatorProvider {

    public override Object initVerification(cym.Browser.Session session, Map<String, Object> args) {
      String phone_number = (String) args.get('phoneNumber');

      if (String.isBlank(phone_number)) throw new InvalidArgumentException('A Phone number must be provided');

      String account_sid = (String) this.get('account_sid');
      String auth_token = (String) this.get('auth_token');
      String service_id = (String) this.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio configuration missing');


      Map<String, String> payload = new Map<String, String> {
        'To' => phone_number,
        'Channel' => 'sms'
      };
      if (args.get('CustomFriendlyName') != null) payload.put('CustomFriendlyName', (String) args.get('CustomFriendlyName'));
      if (args.get('Locale') != null) payload.put('Locale', (String) args.get('Locale'));
      if (args.get('CustomCode') != null) payload.put('CustomCode', (String) args.get('CustomCode'));

      if (String.isNotBlank((String) this.get('AppHash'))) payload.put('AppHash', (String) this.get('AppHash'));

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/Verifications');
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token))); // NOPMD.ApexSuggestUsingNamedCred
      req.setMethod('POST');
      req.setBody(ConverterUtils.fromMapToUrlString(payload));
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() != 201) return new Map<String, Object> {
        'error' => response,
        'statusCode' => resp.getStatusCode()
      };
      return response;
    }

    public override Object verifyVerification(cym.Browser.Session session, Map<String, Object> args) {
      String account_sid = (String) this.get('account_sid');
      String auth_token = (String) this.get('auth_token');
      String service_id = (String) this.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio configuration missing');

      Map<String, String> payload = new Map<String, String> {
        'VerificationSid' => (String) args.get('VerificationSid'),
        'Code' => (String) args.get('Code')
      };

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/VerificationCheck');
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token))); // NOPMD.ApexSuggestUsingNamedCred
      req.setMethod('POST');
      req.setBody(ConverterUtils.fromMapToUrlString(payload));
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() != 200) return new Map<String, Object> {
        'error' => response,
        'statusCode' => resp.getStatusCode()
      };
      return response;
    }
  }

  public class Factor {

  }

  global class Push extends cym.Community.AuthenticatorProvider {
    // cym.Community.Authenticator authenticator;
    // public Push(cym.Community.Authenticator authenticator) {
    //   this.authenticator = authenticator;
    // }

    public Map<String, Object> getFactor(String sid) {
      String account_sid = (String) this.get('account_sid');
      String auth_token = (String) this.get('auth_token');
      String service_id = (String) this.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio Verify configuration missing');

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/Entities/' + UserInfo.getUserId() + '/Factors/' + sid);
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token))); // NOPMD.ApexSuggestUsingNamedCred
      req.setMethod('GET');
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() != 200) throw new TwilioGetFactorsException((String) response.get('error'));
      return response;
    }
    public Object[] getFactors() { return getFactors(UserInfo.getUserId()); }
    public Object[] getFactors(Id user_id) {
      String account_sid = (String) this.get('account_sid');
      String auth_token = (String) this.get('auth_token');
      String service_id = (String) this.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio Verify configuration missing');

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/Entities/' + user_id + '/Factors');
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token))); // NOPMD.ApexSuggestUsingNamedCred
      req.setMethod('GET');
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() == 404) return new Object[] {};
      if (resp.getStatusCode() != 200) throw new TwilioGetFactorsException((String) response.get('error'));
      return (Object[]) response.get('factors');
    }

    public String getAccessToken() {
      String account_sid = (String) this.get('account_sid');
      String auth_token = (String) this.get('auth_token');
      String service_id = (String) this.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio Verify configuration missing');

      Map<String, String> payload = new Map<String, String> {
        'Identity' => UserInfo.getUserId(),
        'FactorType' => 'push'
      };

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/AccessTokens');
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token))); // NOPMD.ApexSuggestUsingNamedCred
      req.setMethod('POST');
      req.setBody(ConverterUtils.fromMapToUrlString(payload));
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() != 200) throw new TwilioGetAccessTokenException((String) response.get('error'));
      return (String) response.get('token');
    }

    public Map<String, Object> challenge(String sid) {
      return challenge(UserInfo.getUserId(), sid);
    }

    public Map<String, Object> challenge(Id user_id, String sid) {
      String account_sid = (String) this.get('account_sid');
      String auth_token = (String) this.get('auth_token');
      String service_id = (String) this.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio Verify configuration missing');

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/Entities/' + user_id + '/Challenges');
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token))); // NOPMD.ApexSuggestUsingNamedCred
      req.setMethod('POST');
      req.setBody(
        TwilioVerifyUtils.fromMapToUrlString(
          new Map<String, String> {
            'Details.Message' => 'You have a login request pending',
            'Details.Fields' => JSON.serialize(new Map<String, Object> {
              'label' => 'msg',
              'value' => 'Challenge details shown to user'
            }),
            'FactorSid' => sid
          }
        )
      );
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      return response;
      }

    public String verify(String challengeSid) {
      return verify(UserInfo.getUserId(), challengeSid);
    }

    public String verify(Id user_id, String challengeSid) {
      String account_sid = (String) this.get('account_sid');
      String auth_token = (String) this.get('auth_token');
      String service_id = (String) this.get('service_sid');
      if (String.isBlank(account_sid) || String.isBlank(auth_token) || String.isBlank(service_id)) throw new InvalidArgumentException('Twilio Verify configuration missing');

      HttpRequest req = new HttpRequest();
      req.setEndpoint(TWILIO_URL + '/Services/' + service_id + '/Entities/' + user_id + '/Challenges/' + challengeSid);
      req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(account_sid + ':' + auth_token))); // NOPMD.ApexSuggestUsingNamedCred
      req.setMethod('GET');
      HttpResponse resp = new Http().send(req);

      Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
      if (resp.getStatusCode() != 200) throw new TwilioGetFactorsException((String) response.get('error'));
      return (String) response.get('status');
    }
  }

  public class InvalidArgumentException extends Exception {}
  public class TwilioGetAccessTokenException extends Exception {}
  public class TwilioGetFactorsException extends Exception {}

  private static String fromMapToUrlString(Map<String, String> params) {
    String enc = 'UTF-8';
    String[] results = new String[] {};
    for (String key: params.keySet()) {
      results.add( EncodingUtil.urlEncode(key, enc) + '=' + EncodingUtil.urlEncode(params.get(key), enc) );
    }
    return String.join(results, '&');
  }
}
