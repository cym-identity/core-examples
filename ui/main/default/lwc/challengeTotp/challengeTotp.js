import { LightningElement, api } from 'lwc';
import initRegisterTotp from "@salesforce/apex/ChallengeController.initRegisterTotp";
import verifyRegisterTotp from "@salesforce/apex/ChallengeController.verifyRegisterTotp";
import verifyVerification from "@salesforce/apex/ChallengeController.verifyVerificationTotp";

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class ChallengeTotp extends LightningElement {
  otp;
  length = 6;
  nextDisabled = true;
  loading = true;

  @api startUrl;
  @api userId;

  basePath = STATIC_RESOURCE_URL.split("/resource/")[0];
  showRegistration = false;
  showQRCode = false;
  qrCodeUrl;
  secret;

  connectedCallback() {
    console.log(this.basePath);
    initRegisterTotp({
      userId: this.userId
    }).then(resp => {
      if (resp.registered) return;
      this.showRegistration = true;
      this.showQRCode = true;
      this.qrCodeUrl = resp.qrCodeUrl;
      this.secret = resp.secret;
    })
    .catch(console.error)
    .then(_ => this.loading = false);
  }

  handleScanNext() {
    this.showQRCode = false;
  }

  handleOtpChange(e) {
    this.otp = e.detail;
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  handleRegisterNext() {
    fetch(this.basePath + '/browser_handle')
      .then(response => response.json())
      .then(resp => resp.handle)
      .then(handle => {
        return verifyRegisterTotp({
          secret : this.secret,
          otp: this.otp,
          handle: handle,
          startURL : this.startUrl,
          userId : this.userId
        });
      })
      .then(({isValid}) => {
        if (isValid) {
          this.dispatchEvent(new CustomEvent('done', {detail : isValid}))
        }
      })
      .catch(console.error);
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
        const { result } = resp;
        if (result) this.dispatchEvent(new CustomEvent('done', {detail : resp}));
      })
      .catch(err => {
        this.loading = false;
        console.error(err);
        // this.dispatchEvent(new CustomEvent('done', {detail : err}))
      });
  }
}