import { LightningElement, api } from "lwc";
import { remote } from "c/fetch";

export default class PushRegister extends LightningElement {
  @api startUrl;
  @api requestId;
  @api redirect;

  isEnabled = false;

  loading = true;

  connectedCallback() {
    remote("PushChallengeController.InitRegistration", {
      startURL: this.startUrl,
    }).then(({redirect, isEnabled}) => {
      this.redirect = redirect;
      this.isEnabled = isEnabled;
      this.loading = false;
    });
  }
}
