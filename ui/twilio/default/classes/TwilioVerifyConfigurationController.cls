public with sharing class TwilioVerifyConfigurationController {
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


}
