import { LightningElement, api } from "lwc";
import { remote } from "c/fetch";

export default class PushRegister extends LightningElement {
  @api startUrl;
  @api requestId;
  @api redirect;

  loading = true;

  connectedCallback() {
    remote("PushChallengeController.InitRegistration", {
      startURL: this.startUrl,
    }).then(({redirect}) => {
      this.redirect = redirect;
      this.loading = false;
    });
  }
}
