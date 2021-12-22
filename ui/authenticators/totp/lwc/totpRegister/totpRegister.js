import { LightningElement, api } from 'lwc';
import initRegisterTotp from "@salesforce/apex/TotpChallengeController.initRegister";
import verifyRegisterTotp from "@salesforce/apex/TotpChallengeController.verifyRegister";

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class TotpChallenge extends LightningElement {
  otp;
  length = 6;
  nextDisabled = true;
  loading = true;

  @api startUrl;
  @api userId;

  basePath = STATIC_RESOURCE_URL.split("/resource/")[0][0] === '/' ? window.location.protocol + '//' + window.location.host + STATIC_RESOURCE_URL.split("/resource/")[0] : STATIC_RESOURCE_URL.split("/resource/")[0];
  showQRCode = true;
  qrCodeUrl;
  secret;

  connectedCallback() {
    initRegisterTotp({
      userId: this.userId
    }).then(resp => {
      this.showQRCode = true;
      this.qrCodeUrl = resp.qrCodeUrl;
      this.secret = resp.secret;
    })
    .catch(console.error)
    .then(_ => this.loading = false);
  }

  handleScanNext() {
    this.qrCodeUrl = undefined;
    this.showQRCode = false;
  }

  handleOtpChange(e) {
    this.otp = e.detail;
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  async handleNext() {
    this.loading = true;
    const { handle } = await (await fetch(this.basePath + '/browser_handle')).json();
    return verifyRegisterTotp({
      secret : this.secret,
      otp: this.otp,
      handle: handle,
      startURL : this.startUrl,
      userId : this.userId
    })
      .then((resp) => {
        const { isValid } = resp;
        if (isValid) this.dispatchEvent(new CustomEvent('done', {detail : resp}));
      })
      .catch(err => {
        this.loading = false;
        console.error(err);
      });
  }
}