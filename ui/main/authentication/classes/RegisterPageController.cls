public with sharing class RegisterPageController extends AuthPageController {

  public RegisterPageController() {}

  public PageReference next() {
    Map<String, String> params = ApexPages.currentPage().getParameters();

    AuthContext context = new AuthContext(this.request, this.level);
    AuthContext.Step next = context.next();

    if (next.kind != AuthContext.StepKind.IDENTITY_REGISTER) return context.getNextStep(next, this.startURL);

    Map<String, Object> args = new Map<String, Object> {
      'login' => context.request.login_hint,
      'given_name' => params.get('given_name'),
      'family_name' => params.get('family_name'),
      'requestId' => context.request.iid
    };

    String resp = context.idp.getRemoteApex(MyCommunitiesSelfRegController.CreateUser.class)
      .invoke(
        JSON.serialize(args)
      );

    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(resp);

    Id userId = (Id) response.get('userId');
    context.idp.getRemoteApex(MyCommunitiesSelfRegController.AssignPermSetAndLicense.class)
      .invoke(
        JSON.serialize(
          new Map<String, Object> {
            'userId' => userId
          }
        )
      );

    // Since the user has been created, reload the context
    context = new AuthContext(this.request, this.level);

    next = context.next();

    return context.getNextStep(next, this.startURL);
  }
}
