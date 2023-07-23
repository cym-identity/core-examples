public with sharing class BrowserSessionUtils {

  public static String getRequestId() {
    return getRequestId(ApexPages.currentPage().getParameters().get('startURL')); // NOPMD.ApexXSSFromURLParam
  }
  public static String getRequestId(String startURL) {
    try {
      return cym.Authorization.getContext(startURL).authn.iid;
    } catch (Exception ignored) { System.debug(ConverterUtils.toMap(ignored)); }
    return ConverterUtils.base64encode(Crypto.generateAesKey(256));
  }

  public static cym.Browser.Session findOrAddSession(cym.Browser browser, Id userId) {
    cym.Browser.Session session = (cym.Browser.Session) browser.sessions.find('ownerId', userId);
    if (session == null) session = browser.sessions.add(userId);
    return session;
  }
}
