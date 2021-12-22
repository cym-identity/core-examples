import { LightningElement, api } from 'lwc';
import verifyVerification from "@salesforce/apex/TotpChallengeController.verifyVerification";

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class TotpChallenge extends LightningElement {
  otp;
  length = 6;
  nextDisabled = true;
  loading = false;

  @api startUrl;
  @api userId;

  basePath = STATIC_RESOURCE_URL.split("/resource/")[0][0] === '/' ? window.location.protocol + '//' + window.location.host + STATIC_RESOURCE_URL.split("/resource/")[0] : STATIC_RESOURCE_URL.split("/resource/")[0];

  secret;

  handleScanNext() {
    this.showQRCode = false;
  }

  handleOtpChange(e) {
    this.otp = e.detail;
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  handleNext() {
    this.loading = true;
    fetch(this.basePath + '/browser_handle')
      .then(response => response.json())
      .then(resp => resp.handle)
      .then(handle => {
        return verifyVerification({
          otp: this.otp,
          handle: handle,
          startURL : this.startUrl,
          userId : this.userId
        })
      }).then((resp) => {
        console.log(JSON.stringify(resp));
        const { isValid } = resp;
        if (isValid) this.dispatchEvent(new CustomEvent('done', {detail : resp}));
      })
      .catch(err => {
        this.loading = false;
        console.error(err);
        // this.dispatchEvent(new CustomEvent('done', {detail : err}))
      });
  }
}