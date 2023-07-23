public with sharing class ApprovalController {

  public class Init extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String startURL = (String) params.get('startURL');
      cym.Authorization.Context context = cym.Authorization.getContext(startURL);
      cym.ResourceOwner owner = cym.ResourceOwner.getCurrent();
      cym.ResourceOwner.Consent consent = (cym.ResourceOwner.Consent) owner.consents.find('client', context.client.id);
      return new Map<String, Object> {
        'scopes' => new Map<String, String[]> {
          'requested' => context.authz.scopes,
          'existing' => consent?.scopes
        },
        'client' => JSON.deserializeUntyped(JSON.serialize(context.client))
      };
    }
  }

  public class Save extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String startURL = (String) params.get('startURL');
      cym.Authorization.Context context = cym.Authorization.getContext(startURL);
      cym.ResourceOwner.Consents consents = cym.ResourceOwner.getCurrent().consents;
      cym.ResourceOwner.Consent consent = (cym.ResourceOwner.Consent) consents.find('client', context.client.id);
      if (consent == null) consent = consents.add(context);
      consent.scopes = context.authz.scopes;
      consent.save();

      PageReference pr = new PageReference(startURL); // NOPMD-ApexOpenRedirect
      pr.getParameters().remove('prompt');
      return pr.getUrl();
    }
  }
}
