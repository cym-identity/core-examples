public with sharing class TwilioVerifyUtils {

  public static String fromMapToUrlString(Map<String, String> params) {
    String enc = 'UTF-8';
    String[] results = new String[] {};
    for (String key: params.keySet()) {
      results.add( EncodingUtil.urlEncode(key, enc) + '=' + EncodingUtil.urlEncode(params.get(key), enc) );
    }
    return String.join(results, '&');
  }
}
