import { LightningElement, api } from "lwc";
import { remote } from 'c/fetch';

export default class TotpChallenge extends LightningElement {
  otp = "";
  length = 6;
  nextDisabled = true;
  loading = false;

  @api user;
  @api requestId;

  handleScanNext() {
    this.showQRCode = false;
  }

  handleOtpChange(e) {
    this.otp = e.target.value;
    if (this.otp.length > this.length)
      this.otp = this.otp.substring(0, this.length);
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  handleNext(e) {
    e.preventDefault();
    e.stopPropagation();
    this.loading = true;
    return remote('TotpChallengeController.VerifyVerification', {
      otp: this.otp,
      userId: this.user.id,
      requestId: this.requestId,
    })
      .then((resp) => {
        const { isValid } = resp;
        if (isValid) this.dispatchEvent(new CustomEvent("done", { detail: resp }));
      })
      .catch(({ body }) => {
        this.loading = false;
        this.dispatchEvent(
          new CustomEvent("error", {
            detail: {
              message: JSON.stringify({
                error: body.message,
                error_stack_trace: body.stackTrace.split("\n"),
              }),
            },
          })
        );
      });
  }
}
