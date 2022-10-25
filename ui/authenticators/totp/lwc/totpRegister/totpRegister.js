import { LightningElement, api } from 'lwc';
import { remote } from 'c/fetch';

export default class TotpChallenge extends LightningElement {
  otp = "";
  length = 6;
  nextDisabled = true;
  loading = true;

  @api startUrl;
  @api user;
  @api requestId;

  @api userId;

  showQRCode = true;
  qrCodeUrl;
  secret;

  connectedCallback() {
    remote('TotpChallengeController.InitRegister', {
      userId: this.user.id,
      requestId: this.requestId
    }).then(resp => {
      this.showQRCode = true;
      this.qrCodeUrl = resp.qrCodeUrl;
      this.secret = resp.secret;
      this.mobileUrl = resp.mobileUrl;
    })
    .catch(console.error)
    .then(_ => this.loading = false);
  }

  handleScanNext() {
    this.qrCodeUrl = undefined;
    this.showQRCode = false;
  }

  handleOtpChange(e) {
    this.otp = e.target.value;
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  async handleNext(e) {
    e.preventDefault();
    e.stopPropagation();
    this.loading = true;
    return remote('TotpChallengeController.VerifyRegister', {
      secret : this.secret,
      otp: this.otp,
      startURL : this.startUrl,
      userId : this.user.id,
      requestId: this.requestId,
    })
      .then((resp) => {
        const { isValid } = resp;
        if (isValid) this.dispatchEvent(new CustomEvent('done', { detail : resp }));
      })
      .catch(err => {
        this.loading = false;
        console.error(err);
      });
  }
}