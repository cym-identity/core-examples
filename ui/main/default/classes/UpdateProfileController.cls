public with sharing class UpdateProfileController {
  private User user;

  public User getUser() {
    return user;
  }

  public UpdateProfileController() {
    if (Auth.CommunitiesUtil.isGuestUser()) throw new NoAccessException();
    this.initUser();
  }
  public PageReference save() {
    try {
      if (String.isBlank(user.Street)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Street Field missing'));
      if (String.isBlank(user.State)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'State Field missing'));
      if (String.isBlank(user.PostalCode)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'PostalCode Field missing'));
      if (String.isBlank(user.City)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'City Field missing'));
      if (String.isBlank(user.Country)) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Country Field missing'));
      if (ApexPages.hasMessages()) return null;

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
