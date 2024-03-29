public with sharing class ConverterUtils {
  private static final Boolean isSandbox = [SELECT IsSandbox FROM Organization].IsSandbox;
  public static Map<String, String> fromMapObjectToMapString(Map<String, Object> params) {
    Map<String, String> results = new Map<String, String>();
    for (String key : params.keySet()) {
      results.put(key, (String) params.get(key));
    }
    return results;
  }
  public static String[] fromObjectArrayToStringArray(Object[] params) {
    if (params == null) return null;
    String[] result = new String[] {};
    for (Object o: params) {result.add((String) o);}
    return result;
  }
  public static Map<String, Object> toMap(Exception ex) {
    Map<String, Object> result = new Map<String, Object> {
      'error' => ex.getMessage(),
      'error_type' => ex.getTypeName()
    };
    if (ConverterUtils.isSandbox) result.put('error_stack_trace', ex.getStackTraceString().split('\n'));
    return result;
  }
  public static String fromMapToUrlString(Map<String, String> params) {
    String enc = 'UTF-8';
    String[] results = new String[] {};
    for (String key: params.keySet()) results.add( EncodingUtil.urlEncode(key, enc) + '=' + EncodingUtil.urlEncode(params.get(key), enc) );
    return String.join(results, '&');
  }
  public static String base64encode(Blob value) {
    return EncodingUtil.base64Encode(value)
      .replace('+', '-')
      .replace('/', '_')
      .replace('=', ''); // Remove the padding
  }

  public static Blob base64decode(String value) {
    return EncodingUtil.base64Decode(
      value
        .replace('-', '+')
        .replace('_', '/')
    );
  }
}
