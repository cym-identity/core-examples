public with sharing class RegisterPageController extends AuthPageController {

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();

    AuthContext context = AuthContext.fromParameters(ApexPages.currentPage().getParameters());
    this.logo = context.logo;
    if (!context.isNext(AuthContext.StepKind.IDENTITY_REGISTER)) return context.redirect();

    Map<String, Object> args = new Map<String, Object> {
      'login' => context.request.login_hint,
      'given_name' => params.get('given_name'),
      'family_name' => params.get('family_name'),
      'requestId' => context.request.iid
    };

    String resp = context.community.getRemoteApex(MyCommunitiesSelfRegController.CreateUser.class)
      .invoke(
        JSON.serialize(args)
      );

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp);

    Id userId = (Id) response.get('userId');
    context.community.getRemoteApex(MyCommunitiesSelfRegController.AssignPermSetAndLicense.class)
      .invoke(
        JSON.serialize(
          new Map<String, Object> {
            'userId' => userId
          }
        )
      );

    // Since the user has been created, reload the context
    return AuthContext.fromParameters(ApexPages.currentPage().getParameters()).redirect();
  }
}
