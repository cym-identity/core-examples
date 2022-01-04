global with sharing class MyCustomUrlRewriter implements Site.UrlRewriter {
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
    }
    return results;
  }

  global PageReference mapRequestUrl(PageReference userFriendlyPage) {
    cym.URLRewriter cymURLRewriter = new cym.URLRewriter();
    PageReference cymPageReference = cymURLRewriter.mapRequestUrl(userFriendlyPage);
    if (cymPageReference != userFriendlyPage) return cymPageReference;
    // Here goes your existing code
    return userFriendlyPage;
  }
}
