public with sharing class RemoteController {
  public static final Map<String, Object> RESPONSE = new Map<String,Object>();
  public String log {
    get {
      return JSON.serialize(RESPONSE);
    }
  }

  public String contentType {get; private set;}
  public RemoteController() {}

  public PageReference init() {
    Map<String, String> headers = ApexPages.currentPage().getHeaders();

    this.contentType = headers.get('Accept') == 'application/json' ? 'application/json;charset=UTF-8' : 'text/html;charset=UTF-8';

    // This is a POST request from Javascript
    if (headers.get('Accept') == 'application/json' && headers.containsKey('Content-Length') && Integer.valueOf(headers.get('Content-Length')) > 0) {
      String origin = headers.get('Origin');
      String allowedOrigin = 'https://' + new URL(Site.getBaseRequestUrl()).getHost();
      // Do not support CORS
      ApexPages.currentPage().getHeaders().put('Access-Control-Allow-Origin', new URL(Site.getBaseRequestUrl()).getHost());

      // Only requests from the same domain are processed
      if (origin != allowedOrigin) return null;

      // This an XHR request made from the page itself, process it
      try {
        Map<String, String> body = ApexPages.currentPage().getParameters();

        Type action = Type.forName(null, body.get('action'));
        if (action == null) {
          RESPONSE.put('error', String.format('Type {0} is unknown or inaccessible', new String[] {body.get('action')}));
          return null;
        }
        Map<String, Object> payload = body.get('payload') != null ? (Map<String, Object>) JSON.deserializeUntyped(body.get('payload')) : new Map<String, Object> {};

        if (!Fetch.Function.class.isAssignableFrom(action)) return null;

        Fetch.Function fn = (Fetch.Function) action.newInstance();
        Object result = fn.execute(payload);
        if (response != null && result instanceof PageReference) RESPONSE.put('redirect', ((PageReference) result).getUrl());
        else RESPONSE.put('response', result);
      } catch (Exception ex) {
        RESPONSE.put('error', ConverterUtils.toMap(ex));
      }
    }
    return null;
  }


}
