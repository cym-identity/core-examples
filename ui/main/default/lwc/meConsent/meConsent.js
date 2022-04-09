import { LightningElement } from "lwc";
import { remote } from "c/fetch";

export default class MeConsent extends LightningElement {
  consents = [];
  loading = true;

  get showEmpty() {
    return !this.loading && this.consents.length === 0;
  }

  connectedCallback() {
    remote("ProfileController.GetAllConsent").then((resp) => {
      this.consents = resp.map((consent) => {
        return {
          ...consent,
          createdDate: new Date(consent.createdDate).toLocaleString(),
          revoke() {
            this.loading = true;
            remote("ProfileController.RevokeConsent", {
              client: consent.id,
            }).then(this.connectedCallback.bind(this));
          },
        };
      });
      this.loading = false;
    });
  }
}
