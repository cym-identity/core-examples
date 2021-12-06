public with sharing class BrowserSessionUtils {

  public static cym.Browser.Session findOrAddSession(cym.Browser browser, Id userId) {
    cym.Browser.Session session;
    for (cym.Browser.Session s : browser.sessions.asList()) {
      if (s.OwnerId == userId) {
        session = s;
        break;
      }
    }
    if (session == null) session = browser.sessions.add(userId);
    return session;
  }
}
