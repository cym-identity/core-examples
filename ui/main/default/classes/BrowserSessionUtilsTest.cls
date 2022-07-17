@isTest
public with sharing class BrowserSessionUtilsTest {
  @TestSetup
  static void makeData(){
    cym.Tests.setupCommunity(UserInfo.getOrganizationId());
  }


  @isTest
  static void findOrAddSession() {
    cym.Tests.setCurrentCommunity(UserInfo.getOrganizationId());
    Test.setCurrentPage(new PageReference('/'));

    cym.Browser browser = cym.Browser.getCurrent();

    System.assertEquals(0, browser.sessions.asList().size(), 'No sessions exist');

    BrowserSessionUtils.findOrAddSession(browser, UserInfo.getUserId());

    System.assertEquals(1, browser.sessions.asList().size(), 'The user session has been added');

    BrowserSessionUtils.findOrAddSession(browser, UserInfo.getUserId());

    System.assertEquals(1, browser.sessions.asList().size(), 'A repeat call is no-op');
  }
}
