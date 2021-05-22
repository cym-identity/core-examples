import { LightningElement, api, track } from "lwc";

export default class ChallengeUi extends LightningElement {
  @api factors;
  @api credentials;
  @api startURL;
  @api isUserVerifyingPlatformAuthenticatorAvailable;
  @track factor;
  @track _errorLog = [];
  verifyWebAuthnPlatform = false;

  get log() {
    return JSON.stringify(this._errorLog, null, 2);
  }


  connectedCallback() {
    if (this.factors && this.factors.length === 0) this.factor = 'email';
    // Always prefer the internal authenticator since it's a simple auth experience
    this.factor = this.factors[this.factors.indexOf('webauthn.platform') > -1 ? this.factors.indexOf('webauthn.platform') : 0];
  }

  get remainingFactors() {
    if (this.factor === 'webauthn.platform.register') return [];
    let response = [];
    if (this.factors.indexOf('webauthn.platform') > -1) {
      response.push({
        title: "Verify your account with your biometrics",
        onclick: this.switchTo.bind(this, 'webauthn.platform'),
        style: 'webauthn.platform' != this.factor ? 'display: block;' : 'display: none;'
      });
    }
    if (this.factors.indexOf('webauthn') > -1) {
      response.push({
        title: "Verify your account with a security key",
        onclick: this.switchTo.bind(this, 'webauthn'),
        style: 'webauthn' != this.factor ? 'display: block;' : 'display: none;'
      });
    }
    if (this.factors.indexOf('totp') > -1) {
      response.push({
        title: "Verify your account with a code generated through an app",
        onclick: this.switchTo.bind(this, 'totp'),
        style: 'totp' != this.factor ? 'display: block;' : 'display: none;'
      });
    }
    if (this.factors.indexOf('sms') > -1) {
      response.push({
        title: "Verify your account with an sms",
        onclick: this.switchTo.bind(this, 'sms'),
        style: 'sms' != this.factor ? 'display: block;' : 'display: none;'
      });
    }
    return response;
  }

  // Email verification will be done when no other factor has been completed
  get showEmail() {
    return this.factor === 'email';
  }
  get showTotp() {
    return this.factor === 'totp';
  }
  get showWebAuthn() {
    return this.factor === 'webauthn';
  }
  get showWebAuthnPlatform() {
    return this.factor === 'webauthn.platform' || this.factor === 'webauthn.platform.verify';
  }
  get showEnrollWebAuthnPlatform() {
    return this.factor === 'webauthn.platform.register';
  }
  get showSms() {
    return this.factor === 'sms';
  }

  get showOtherAuthenticators() {
    return this.factor !== 'webauthn.platform.register' && this.factor !== 'webauthn.platform.verify' && this.factors.length > 1;
  }

  switchTo(to) {
    this.factor = to;
  }

  factorDone() {
    if (!this.factors.indexOf('webauthn.platform') > -1 && this.isUserVerifyingPlatformAuthenticatorAvailable) {
       this.isUserVerifyingPlatformAuthenticatorAvailable.then(canEnroll => {
        if (canEnroll) {
          this.factor = 'webauthn.platform.register';
        } else {
          this.done();
        }
      });
    } else {
      this.done();
    }
  }

  handleWebAuthnPlatformDone() {
    this.done();
  }
  handleWebAuthnPlatformError() {
    this.hasWebAuthnPlatform = false;
  }

  enrollWebAuthnPlatformDone() {
    this.done();
  }

  done() {
    this.finish();
  }

  finish() {
    window.location.href = this.startURL;
  }

  handleEnrollWebAuthnPlarformError({detail}) {
    if (detail) {
      const {name, message} = detail;
      if (name === 'InvalidStateError') {
        this.factor = 'webauthn.platform.verify';
      }
    }
    this._errorLog.push(detail);
  }

}
