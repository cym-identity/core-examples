import { LightningElement } from "lwc";
import { remote } from 'c/fetch';

import STATIC_RESOURCE_URL from '@salesforce/resourceUrl/MFA';

export default class AllRegister extends LightningElement {
  supportedAuthenticators = ['email', 'sms', 'totp', 'push', 'webauthn_platform', 'webauthn_roaming'];
  startUrl = new URLSearchParams(document.location.search).get('startURL');

  fingerprintUrl = STATIC_RESOURCE_URL + "/img/fingerprint_generic_white.svg";
  registerAnimationUrl = STATIC_RESOURCE_URL + '/img/windows_register_animation.gif';
  fidoCertifiedUrl = STATIC_RESOURCE_URL + '/img/FIDO_Certified_logo_yellow.png';

  userFactors = [];
  sessionFactors = [];
  factor;
  loading = true;

  get canShowAuthenticatorChooserSection() { return !this.factor && !this.completed; }
  get canShowAuthenticatorChallengeSection() { return !!this.factor; }

  get log() {
    return JSON.stringify(this._errorLog, null, 2);
  }

  async connectedCallback() {
    const { factors, sessionFactors } = await remote('ChallengeController.LoadContext', {startURL: this.startUrl});
    this.loading = false;
    this.userFactors = factors;
    this.sessionFactors = sessionFactors || [];
  }

  get hasAuthenticatorEmail() { return this.userFactors.indexOf('email') > -1; }
  get hasCompletedEmail() { return this.sessionFactors.indexOf('email') > -1; }
  get canShowAuthenticatorChooserEmail() { return this.supportedAuthenticators.indexOf('email') > -1; }
  showAuthenticatorEmail() { this.switchTo('email'); }
  completeAuthenticatorEmail() { this.markAsComplete('email'); }
  // Email verification will be done when no other factor has been completed
  get canShowAuthenticatorChallengeEmail() { return this.factor === 'email'; }

  get hasAuthenticatorTotp() { return this.userFactors.indexOf('totp') > -1; }
  get hasCompletedTotp() { return this.sessionFactors.indexOf('totp') > -1; }
  get canShowAuthenticatorChooserTotp() { return this.supportedAuthenticators.indexOf('totp') > -1; }
  showAuthenticatorTotp() { this.switchTo('totp'); }
  completeAuthenticatorTotp() { this.markAsComplete('totp'); }
  get canShowAuthenticatorChallengeTotp() { return this.factor === 'totp'; }

  // A user can register multiple Built-In Authenticators
  get hasAuthenticatorWebAuthnPlatform() { return this.sessionFactors.indexOf('webauthn_platform') > -1; }
  get hasCompletedWebAuthnPlatform() { return this.sessionFactors.indexOf('webauthn_platform') > -1; }
  get canShowAuthenticatorChooserWebAuthnPlatform() { return this.supportedAuthenticators.indexOf('webauthn_platform') > -1; }
  showAuthenticatorWebAuthnPlatform() { this.switchTo('webauthn_platform'); }
  completeAuthenticatorWebAuthnPlatform() { this.markAsComplete('webauthn_platform'); }
  get canShowAuthenticatorChallengeWebAuthnPlatform() { return this.factor === 'webauthn_platform'; }

  // A user can register multiple Roaming Authenticators
  get hasAuthenticatorWebAuthnRoaming() { return this.sessionFactors.indexOf('webauthn_roaming') > -1; }
  get hasCompletedWebAuthnRoaming() { return this.sessionFactors.indexOf('webauthn_roaming') > -1; }
  get canShowAuthenticatorChooserWebAuthnRoaming() { return this.supportedAuthenticators.indexOf('webauthn_roaming') > -1; }
  showAuthenticatorWebAuthnRoaming() { this.switchTo('webauthn_roaming'); }
  completeAuthenticatorWebAuthnRoaming() { this.markAsComplete('webauthn_roaming'); }
  get canShowAuthenticatorChallengeWebAuthnRoaming() { return this.factor === 'webauthn_roaming'; }


  switchTo(to) { if(this.userFactors.indexOf(to) === -1) this.factor = to; }
  markAsComplete(f) {
    console.log({markAsComplete: f})
    if (this.userFactors.indexOf(f) === -1) this.userFactors = [... this.userFactors, f];
    if (this.sessionFactors.indexOf(f) === -1 ) this.sessionFactors = [... this.sessionFactors, f];
    this.backToChooser();
  }
  backToChooser() { console.log({user: this.userFactors, session: this.sessionFactors, hasAuthenticatorWebAuthnPlatform: this.hasAuthenticatorWebAuthnPlatform}); this.switchTo(undefined); }

  handleWebAuthnPlatformReady({
    detail: {
      error,
      error_description,
    },
  }) {
    // The browser does not support WebAuthn or does not have UserVerification
    if (error) this.supportedAuthenticators = this.supportedAuthenticators.filter(authenticator => authenticator !== 'webauthn_platform');
  }
  handleWebAuthnPlatformError({
    detail
  }) {
    console.log('handleWebAuthnPlatformError', JSON.stringify(detail, null, 2))
    const { error } = detail;
    if (error === 'NotAllowedError') this.supportedAuthenticators = this.supportedAuthenticators.filter(authenticator => authenticator !== 'webauthn_platform');
  }

  handleWebAuthnRoamingReady({
    detail: {
      error,
      error_description,
    },
  }) {
    if (error) this.supportedAuthenticators = this.supportedAuthenticators.filter(authenticator => authenticator !== 'webauthn_roaming');
  }

  handleWebAuthnRoamingError({
    detail
  }) {
    console.log('handleWebAuthnRoamingError', JSON.stringify(detail, null, 2))
  }




  showLearnMore = false;
  toggleLearnMore() {
    this.showLearnMore = !this.showLearnMore
  }


  finish() {
    window.location.href = this.startUrl;
  }
}