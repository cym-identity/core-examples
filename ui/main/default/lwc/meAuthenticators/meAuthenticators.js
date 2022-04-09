import { LightningElement } from "lwc";
import { remote } from "c/fetch";

export default class MeAuthenticators extends LightningElement {
  loading = true;

  lastPasswordChangeTime;
  totpCreationDate;
  hasUserVerifiedEmailAddress;
  hasTotp;

  async connectedCallback() {
    remote("ProfileController.GetSecurityStatus")
      .then(
        ({ lastPasswordChangeTime, hasUserVerifiedEmailAddress, hasTotp, totpCreationDate }) => {
          this.lastPasswordChangeTime = new Date(lastPasswordChangeTime).toLocaleString();
          this.totpCreationDate = new Date(totpCreationDate).toLocaleString();
          this.hasUserVerifiedEmailAddress = hasUserVerifiedEmailAddress;
          this.hasTotp = hasTotp;
        }
      )
      .then((_) => (this.loading = false));
  }
}
