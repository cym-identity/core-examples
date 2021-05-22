import { LightningElement, api, track } from "lwc";

export default class RegisterUi extends LightningElement {
  @api credentials;
  @api startURL;
  @api isUserVerifyingPlatformAuthenticatorAvailable;
  @track emailVerifyDone = false;
  @track _errorLog = {};

  get log() {
    return JSON.stringify(this._errorLog, null, 2);
  }

  enrollWebAuthnPlatform = false;
  get factors() {
    return this.emailVerifyDone && ["totp", "sms", "webauthn"].map((factor) => {
      switch (factor) {
        case "sms":
          return {
            title: "Register a phone number",
            onclick: this.switchTo.bind(this, "sms"),
            style: factor != this.factor ? "display: block;" : "display: none;",
          };
        case "totp":
          return {
            title: "Verify your account with a code generated through an app",
            onclick: this.switchTo.bind(this, "totp"),
            style: factor != this.factor ? "display: block;" : "display: none;",
          };
        case "webauthn":
          return {
            title: "Register a security key",
            onclick: this.switchTo.bind(this, "webauthn"),
            style: factor != this.factor ? "display: block;" : "display: none;",
          };
      }
    });
  }
  factor;

  connectedCallback() {
    this.emailVerifyDone = true;
  }

  // Email verification will be done when no other factor has been completed
  get showEmail() {
    return !this.enrollWebAuthnPlatform && !this.factors;
  }
  get showTotp() {
    return (
      !this.enrollWebAuthnPlatform && this.factors && "totp" === this.factor
    );
  }
  get showWebAuthn() {
    return (
      !this.enrollWebAuthnPlatform && this.factors && "webauthn" === this.factor
    );
  }
  get showSms() {
    return (
      !this.enrollWebAuthnPlatform && this.factors && "sms" === this.factor
    );
  }

  get showFactors() {
    return !this.enrollWebAuthnPlatform && this.factors;
  }

  switchTo(to) {
    this.factor = to;
  }

  factorDone(resp) {
    console.log(resp.detail);

    this.isUserVerifyingPlatformAuthenticatorAvailable.then((canEnroll) => {
      if (canEnroll) {
        this.enrollWebAuthnPlatform = true;
      } else {
        window.location.href = this.startURL;
      }
    });
  }


  enrollWebAuthnPlatformDone() {
    window.location.href = this.startURL;
  }

  handleEnrollWebAuthnPlatformError(err) {
    this._errorLog['handleEnrollWebAuthnPlatformError'] = err;
  }
  handleWebAuthnError(err) {
    this._errorLog['handleWebAuthnError'] = err;
  }
}
