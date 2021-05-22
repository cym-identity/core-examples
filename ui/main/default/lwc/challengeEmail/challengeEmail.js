import { LightningElement, api } from "lwc";
import initVerification from "@salesforce/apex/ChallengeController.initVerificationEmail";
import verifyVerification from "@salesforce/apex/ChallengeController.verifyVerificationEmail";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class ChallengeEmail extends LightningElement {
  length = 5;
  otp;
  transactionId;

  @api done;
  error;
  nextDisabled = true;
  loading = false;

  connectedCallback() {
    if (this.loading) this.handleResend();
  }

  handleOtpChange(e) {
    this.hideError();
    this.otp = e.detail;
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  handleNext() {
    this.hideError();
    this.loading = true;
    verifyVerification({
      transactionId: this.transactionId,
      otp: this.otp,
    })
      .then((resp) => {
        this.loading = false;
        if (resp.isValid) {
          this.dispatchEvent(new CustomEvent("done"));
        } else {
          this.displayError('The code entered is invalid');
        }
      })
      .catch(_ => {
        this.loading = false;
        this.displayError('An unexpected error occured');
      });
  }

  handleResend() {
    this.loading = true;
    this.hideError();
    initVerification()
      .then((resp) => {
        this.loading = false;
        this.transactionId = resp.transactionId;
      })
      .catch(_ => {
        this.loading = false;
        this.displayError('An unexpected error occured');
      });
  }

  hideError() {
    this.error = undefined;
  }

  displayError(message) {
    this.error = message
    const evt = new ShowToastEvent({
      title: 'Error',
      message: this.error,
      variant: 'error',
    });
    this.dispatchEvent(evt);
  }


}
