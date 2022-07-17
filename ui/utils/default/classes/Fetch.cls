public with sharing class Fetch {
  public abstract class Function {
    protected cym.Browser browser = cym.Browser.getCurrent();
    protected cym.Browser.Session session {
      get {
        return (cym.Browser.Session) browser.sessions.find('ownerId', UserInfo.getUserId());
      }
    }
    public abstract Object execute(Map<String, Object> params);
  }
}
