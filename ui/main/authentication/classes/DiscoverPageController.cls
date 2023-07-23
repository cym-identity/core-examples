public with sharing class DiscoverPageController extends AuthPageController {
  public AuthContext.DisplayUser[] users { get; private set; }
  public AuthContext.ExternalAuthProvider[] providers { get; private set; }

  public PageReference load() {
    cym.Community idp = cym.Community.getCurrent();
    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    this.logo = context.logo;
    if (!context.isNext(AuthContext.StepKind.IDENTITY_CHOOSE)) return context.redirect();
    // LoadContext
    this.users = context.getBrowserUsers();
    this.providers = context.getCommunityAuthProviders();
    return null;
  }

  public PageReference next() { return this.load(); }

}
