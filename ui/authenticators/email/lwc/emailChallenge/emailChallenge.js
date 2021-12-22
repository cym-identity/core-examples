import { LightningElement, api } from "lwc";
import initVerification from "@salesforce/apex/EmailChallengeController.initVerification";
import verifyVerification from "@salesforce/apex/EmailChallengeController.verifyVerification";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import STATIC_RESOURCE_URL from '@salesforce/resourceUrl/MFA';

export default class EmailChallenge extends LightningElement {
  length = 6;
  otp;
  transactionId;
  basePath = STATIC_RESOURCE_URL.split("/resource/")[0][0] === '/' ? window.location.protocol + '//' + window.location.host + STATIC_RESOURCE_URL.split("/resource/")[0] : STATIC_RESOURCE_URL.split("/resource/")[0];

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

    const { handle } = await (await fetch(this.basePath + '/browser_handle')).json();

    try {
      const { isValid } = await verifyVerification({
        transactionId: this.transactionId,
        otp: this.otp,
        handle,
        startURL : this.startUrl
      });
      this.loading = false;
      if (isValid) {
        this.dispatchEvent(new CustomEvent("done"));
      } else {
        this.displayError('The code entered is invalid');
      }
    } catch (e) {
      this.loading = false;
      this.displayError('An unexpected error occured');
    }
  }

  handleResend(e) {
    e && e.preventDefault();
    e && e.stopPropagation();
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
