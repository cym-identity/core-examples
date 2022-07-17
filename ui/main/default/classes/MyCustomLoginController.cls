/**
 * An apex page controller that exposes the site login functionality
 */
global with sharing class MyCustomLoginController { // NOPMD.AvoidGlobalModifier
  public String backgroundColor {get; set;}
  public String login_hint {get; set;}
  public String login_type {get; set;}

  public MyCustomLoginController () {
    this.backgroundColor = new Auth.AuthConfiguration(Site.getBaseRequestUrl(), '/').getBackgroundColor();
  }

  public PageReference load() {
    if (!Auth.CommunitiesUtil.isGuestUser()) {
      String requestId = BrowserSessionUtils.getRequestId();
      BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), UserInfo.getUserId()).activate().sync(requestId);
      User u = new UserUtils.Repository().findByUsername(UserInfo.getUserName());
      this.login_hint = Users.getLoginHint(u);
      this.login_type = Users.getLoginType(u).name();
    }
    return null;
  }

}
