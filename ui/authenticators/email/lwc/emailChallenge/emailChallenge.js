import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import { remote } from "c/fetch";

export default class EmailChallenge extends LightningElement {
  length = 6;
  otp;
  transactionId;

  @api done;
  @api startUrl;

  error;
  nextDisabled = true;
  loading = true;

  connectedCallback() {
    if (this.loading) this.handleResend();
  }

  handleOtpChange(e) {
    this.hideError();
    this.otp = e.detail;
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  async handleNext() {
    this.hideError();
    this.loading = true;
    try {
      const { isValid } = await remote(
        "EmailChallengeController.VerifyVerification",
        {
          transactionId: this.transactionId,
          otp: this.otp,
          startURL: this.startUrl,
        }
      );
      this.loading = false;
      if (isValid) {
        this.dispatchEvent(new CustomEvent("done"));
      } else {
        this.displayError("The code entered is invalid");
      }
    } catch (e) {
      this.loading = false;
      this.displayError("An unexpected error occured");
    }
  }

  handleResend(e) {
    e && e.preventDefault();
    e && e.stopPropagation();
    this.loading = true;
    this.hideError();
    remote("EmailChallengeController.InitVerification")
      .then((resp) => {
        this.loading = false;
        this.transactionId = resp.transactionId;
      })
      .catch((_) => {
        this.loading = false;
        this.displayError("An unexpected error occured");
      });
  }

  hideError() {
    this.error = undefined;
  }

  displayError(message) {
    this.error = message;
    const evt = new ShowToastEvent({
      title: "Error",
      message: this.error,
      variant: "error",
    });
    this.dispatchEvent(evt);
  }
}
