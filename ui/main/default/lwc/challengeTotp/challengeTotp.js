import { LightningElement, api } from 'lwc';
import initRegisterTotp from "@salesforce/apex/ChallengeController.initRegisterTotp";
import verifyRegisterTotp from "@salesforce/apex/ChallengeController.verifyRegisterTotp";
import verifyVerification from "@salesforce/apex/ChallengeController.verifyVerificationTotp";

export default class ChallengeTotp extends LightningElement {
  otp;
  length = 6;
  nextDisabled = true;
  loading = true;

  @api done;

  showRegistration = false;
  showQRCode = false;
  qrCodeUrl;
  secret;

  connectedCallback() {
    initRegisterTotp().then(resp => {
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
    verifyRegisterTotp({secret : this.secret, otp: this.otp})
      .then(({isValid}) => {
        if (isValid) {
          this.dispatchEvent(new CustomEvent('done', {detail : isValid}))
        }
      })
      .catch(console.error);
  }

  handleNext() {
    this.loading = true;
    verifyVerification({
      otp: this.otp,
    }).then((resp) => {
      this.loading = false;
      this.dispatchEvent(new CustomEvent('done', {detail : resp}))
    })
    .catch(err => {
      this.loading = false;
      console.error(err);
      this.dispatchEvent(new CustomEvent('done', {detail : err}))
    });
  }
}