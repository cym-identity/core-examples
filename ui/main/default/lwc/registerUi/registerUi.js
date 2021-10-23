import { LightningElement, api, track } from "lwc";

import MFA_STATIC_RESOURCE_URL from '@salesforce/resourceUrl/MFA';

export default class RegisterUi extends LightningElement {
  @api credentials;
  @api startUrl;
  @api isUserVerifyingPlatformAuthenticatorAvailable;
  @api handle;
  @api basePath;
  @track emailVerifyDone = false;
  @track _errorLog = {};

  registerAnimationUrl = MFA_STATIC_RESOURCE_URL + '/img/windows_register_animation.gif';
  fidoCertifiedUrl = MFA_STATIC_RESOURCE_URL + '/img/FIDO_Certified_logo_yellow.png';

  get log() {
    return JSON.stringify(this._errorLog, null, 2);
  }

  enrollWebAuthnPlatform = false;
  get factors() {
    return this.emailVerifyDone && ["totp", "sms", "email", "webauthn"].map((factor) => {
      switch (factor) {
        case "sms":
          return {
            title: "Register a phone number",
            onclick: this.switchTo.bind(this, "sms"),
            style: factor != this.factor ? "display: block;" : "display: none;",
          };
        case "email":
          return {
            title: "Use your email",
            onclick: this.switchTo.bind(this, "email"),
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
    return !this.enrollWebAuthnPlatform && this.factors && "email" === this.factor;
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
    const { redirect } = resp.detail;

    this.isUserVerifyingPlatformAuthenticatorAvailable.then((canEnroll) => {
      if (canEnroll) {
        this.enrollWebAuthnPlatform = true;
      } else {
        window.location.href = redirect || this.startUrl;
      }
    });
  }


  enrollWebAuthnPlatformDone() {
    window.location.href = this.startUrl;
  }

  handleEnrollWebAuthnPlatformError(err) {
    this._errorLog['handleEnrollWebAuthnPlatformError'] = err;
  }
  handleWebAuthnError(err) {
    this._errorLog['handleWebAuthnError'] = err;
  }

  skipEnrollWebAuthnPlatform() {
    this.done();
  }

  showLearnMore = false;
  toggleLearnMore() {
    this.showLearnMore = !this.showLearnMore
  }
}
