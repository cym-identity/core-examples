import { LightningElement } from "lwc";

export default class ProtectedResource extends LightningElement {
  loading = false;
  success = true;

  handleChallenge(e) {
    e.stopPropagation();
    this.success = false;
  }

  handleChallengeCompleted({ detail }) {
    const { isValid } = detail
    if (isValid) {
      this.success = true;
    }
  }
}
