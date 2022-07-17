import { LightningElement, api } from 'lwc';
import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class IdpChallenge extends LightningElement {
  @api providers;
  styles = {
    Google: `background-image:url(${STATIC_RESOURCE_URL}/img/google-plus.png)`,
    Facebook: `background-image:url(${STATIC_RESOURCE_URL}/img/facebook.svg)`,
    Twitter: `background-image:url(${STATIC_RESOURCE_URL}/img/twitter.png)`,
    LinkedIn: `background-image:url(${STATIC_RESOURCE_URL}/img/linkedin.svg)`,
  };

  get socialProviders() {
    return (this.providers || []).map(provider => Object.assign({}, provider, {style : this.styles[provider.friendlyName]}));
  }

}