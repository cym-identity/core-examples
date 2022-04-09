global with sharing class MyCustomUrlRewriter implements Site.UrlRewriter { // NOPMD.AvoidGlobalModifier
  global PageReference[] generateUrlFor(PageReference[] salesforceUrls) {
    PageReference[] results = new PageReference[] {};
    cym.URLRewriter cymURLRewriter = new cym.URLRewriter();
    for (PageReference pr : salesforceUrls) {
      PageReference cymPageReference = cymURLRewriter.generateUrlFor(pr);
      if (cymPageReference != pr) {
        // Include the returned value in the response
        results.add(cymPageReference);
        continue;
      }
      // Here goes your existing code
      Map<String, String> params = pr.getParameters();
      if (pr.getUrl().startsWith('/MyCustomLogin')) {
        PageReference p = new PageReference('/auth/login');
        p.getParameters().putAll(params);
        results.add(p);
        continue;
      }
      results.add(pr);
    }
    return results;
  }

  global PageReference mapRequestUrl(PageReference userFriendlyPage) {
    cym.URLRewriter cymURLRewriter = new cym.URLRewriter();
    PageReference cymPageReference = cymURLRewriter.mapRequestUrl(userFriendlyPage);
    if (cymPageReference != userFriendlyPage) return cymPageReference;
    // Here goes your existing code
    PageReference authPageReference = mapAuthRequestUrl(userFriendlyPage);
    if (authPageReference != userFriendlyPage) return authPageReference;
    return userFriendlyPage;
  }

  private PageReference mapAuthRequestUrl(PageReference userFriendlyPage) {
    String uri = userFriendlyPage.getUrl();
    System.debug(JSON.serializePretty(userFriendlyPage.getHeaders()));
    Map<String, String> params = userFriendlyPage.getParameters();
    if (uri.startsWith('/auth/login')) {
      PageReference pr = new PageReference('/MyCustomLogin');
      pr.getParameters().putAll(params);
      pr.getParameters().put('step', 'login');
      return pr;
    }
    if (uri.startsWith('/auth/register')) {
      PageReference pr = new PageReference('/MyCustomLogin');
      pr.getParameters().putAll(params);
      pr.getParameters().put('step', 'register');
      return pr;
    }
    if (uri.startsWith('/auth/challenge')) {
      PageReference pr = new PageReference('/MyCustomLogin');
      pr.getParameters().putAll(params);
      pr.getParameters().put('step', 'challenge');
      return pr;
    }
    return userFriendlyPage;
  }


}
