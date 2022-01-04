/**
 * An apex page controller that exposes the site login functionality
 */
global with sharing class MyCustomLoginController { // NOPMD.AvoidGlobalModifier
  public String backgroundColor {get; set;}

  public MyCustomLoginController () {
    this.backgroundColor = [SELECT AssetCategory, TextAsset FROM CustomBrandAsset WHERE AssetCategory = 'LoginQuaternaryColor' AND CustomBrandId IN (SELECT Id FROM CustomBrand WHERE ParentId =: Network.getNetworkId())].TextAsset;
  }

}
