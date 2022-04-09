public with sharing class Fetch {
  public abstract class Function {
    protected cym.Browser browser = cym.Browser.getCurrent();
    protected cym.Browser.Session session {
      get {
        for (cym.Browser.Session s : browser.sessions.asList()) if (s.OwnerId == UserInfo.getUserId()) return s;
        return null;
      }
    }
    public abstract Object execute(Map<String, Object> params);
  }
}
