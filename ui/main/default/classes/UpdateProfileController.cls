public with sharing class UpdateProfileController {
  private User user;

  public Boolean askForCompanyName {get; private set;}
  public Boolean askForAddress {get; private set;}

  public User getUser() {
    return user;
  }

  public UpdateProfileController() {
    if (Auth.CommunitiesUtil.isGuestUser()) throw new NoAccessException();
    cym.AuthorizationContext context = cym.AuthorizationContext.getContext(ApexPages.currentPage().getParameters().get('startURL'));

    cym.AuthorizationContext.Request request = context.request;
    this.initUser();

    this.askForCompanyName = (request.scope.indexOf('l2') > -1 || request.scope.indexOf('l3') > -1) && String.isBlank(this.user.CompanyName);
    this.askForAddress = request.scope.indexOf('l3') > -1 && (
      String.isBlank(this.user.Street) ||
      String.isBlank(this.user.State) ||
      String.isBlank(this.user.PostalCode) ||
      String.isBlank(this.user.City) ||
      String.isBlank(this.user.Country)
    );

    System.debug(request);


  }
  public PageReference save() {
    try {
      // if (String.isBlank(user.Street)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Street Field missing'));
      // if (String.isBlank(user.State)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'State Field missing'));
      // if (String.isBlank(user.PostalCode)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'PostalCode Field missing'));
      // if (String.isBlank(user.City)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'City Field missing'));
      // if (String.isBlank(user.Country)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Country Field missing'));
      // if (ApexPages.hasMessages()) return null;
      update user;
      return new PageReference(ApexPages.currentPage().getParameters().get('startURL'));

    } catch(DmlException e) {
        ApexPages.addMessages(e);
    }
    return null;
  }

  public void cancel() {
    this.initUser();
  }

  private void initUser() {
    this.user = new RealmExtensionCallable.Repository().findById(UserInfo.getUserId());
  }
}
