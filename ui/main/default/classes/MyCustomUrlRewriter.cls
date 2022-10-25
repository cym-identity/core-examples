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
      if (pr.getUrl().startsWith('/web_authn')) {
        PageReference p = new PageReference('/auth/webauthn');
        p.getParameters().putAll(params);
        results.add(p);
        continue;
      }
      if (pr.getUrl().startsWith('/discover')) {
        PageReference p = new PageReference('/auth/discover');
        p.getParameters().putAll(params);
        results.add(p);
        continue;
      }
      if (pr.getUrl().startsWith('/email')) {
        PageReference p = new PageReference('/auth/email');
        p.getParameters().putAll(params);
        results.add(p);
        continue;
      }
      if (pr.getUrl().startsWith('/totp')) {
        PageReference p = new PageReference('/auth/totp');
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
    Map<String, String> params = userFriendlyPage.getParameters();
    if (uri.startsWith('/auth/webauthn')) {
      PageReference pr = new PageReference('/web_authn');
      pr.getParameters().putAll(params);
      return pr;
    }
    if (uri.startsWith('/auth/discover')) {
      PageReference pr = new PageReference('/discover');
      pr.getParameters().putAll(params);
      return pr;
    }
    if (uri.startsWith('/auth/email')) {
      PageReference pr = new PageReference('/email');
      pr.getParameters().putAll(params);
      return pr;
    }
    if (uri.startsWith('/auth/totp')) {
      PageReference pr = new PageReference('/totp');
      pr.getParameters().putAll(params);
      return pr;
    }
    return userFriendlyPage;
  }


}
