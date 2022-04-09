import { LightningElement } from "lwc";
import { remote } from 'c/fetch';

import STATIC_RESOURCE_URL from '@salesforce/resourceUrl/MFA';

export default class AllChallenge extends LightningElement {
  supportedAuthenticators = ['email', 'sms', 'totp', 'push', 'webauthn_platform', 'webauthn_roaming'];
  startUrl = new URLSearchParams(document.location.search).get('startURL');

  fingerprintUrl = STATIC_RESOURCE_URL + "/img/fingerprint_generic_white.svg";
  registerAnimationUrl = STATIC_RESOURCE_URL + '/img/windows_register_animation.gif';
  fidoCertifiedUrl = STATIC_RESOURCE_URL + '/img/FIDO_Certified_logo_yellow.png';

  userFactors = [];
  sessionFactors = [];
  factor;
  loading = true;
  error;

  get canShowAuthenticatorChooserSection() { return !this.factor && !this.completed; }
  get canShowAuthenticatorChallengeSection() { return !!this.factor; }

  async connectedCallback() {
    try {
      const { factors, sessionFactors } = await remote('ChallengeController.LoadContext', {startURL: this.startUrl});
      this.loading = false;
      this.userFactors = factors;
      this.sessionFactors = sessionFactors || [];
    } catch (ex) {
      this.error = ex;
    }
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

  get hasAuthenticatorWebAuthnPlatform() { return this.userFactors.indexOf('webauthn_platform') > -1; }
  get hasCompletedWebAuthnPlatform() { return this.sessionFactors.indexOf('webauthn_platform') > -1; }
  get canShowAuthenticatorChooserWebAuthnPlatform() { return this.supportedAuthenticators.indexOf('webauthn_platform') > -1; }
  showAuthenticatorWebAuthnPlatform() { this.switchTo('webauthn_platform'); }
  completeAuthenticatorWebAuthnPlatform() { this.markAsComplete('webauthn_platform'); }
  get canShowAuthenticatorChallengeWebAuthnPlatform() { return this.factor === 'webauthn_platform'; }

  get hasAuthenticatorWebAuthnRoaming() { return this.userFactors.indexOf('webauthn_roaming') > -1; }
  get hasCompletedWebAuthnRoaming() { return this.sessionFactors.indexOf('webauthn_roaming') > -1; }
  get canShowAuthenticatorChooserWebAuthnRoaming() { return this.supportedAuthenticators.indexOf('webauthn_roaming') > -1; }
  showAuthenticatorWebAuthnRoaming() { this.switchTo('webauthn_roaming'); }
  completeAuthenticatorWebAuthnRoaming() { this.markAsComplete('webauthn_roaming'); }
  get canShowAuthenticatorChallengeWebAuthnRoaming() { return this.factor === 'webauthn_roaming'; }


  switchTo(to) {
    this.factor = to;
    this.error = null;
  }
  markAsComplete(f) {
    if (this.userFactors.indexOf(f) === -1) this.userFactors = [... this.userFactors, f];
    if (this.sessionFactors.indexOf(f) === -1 ) this.sessionFactors = [... this.sessionFactors, f];
    this.backToChooser();
  }
  backToChooser() { this.switchTo(undefined); }

  handleWebAuthnPlatformReady({
    detail: {
      error,
    },
  }) {
    // The browser does not support WebAuthn or does not have UserVerification
    if (error) this.supportedAuthenticators = this.supportedAuthenticators.filter(authenticator => authenticator !== 'webauthn_platform');
  }
  handleWebAuthnPlatformDone({
    detail
  }) {
    console.log('handleWebAuthnPlatformDone', JSON.stringify(detail, null, 2))
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
    },
  }) {
    if (error) this.supportedAuthenticators = this.supportedAuthenticators.filter(authenticator => authenticator !== 'webauthn_roaming');
  }
  handleWebAuthnRoamingDone({
    detail
  }) {
    console.log('handleWebAuthnRoamingDone', JSON.stringify(detail, null, 2))
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

  handleError( {detail} ) {
    console.log(JSON.parse(JSON.stringify(detail)))
    this.error = detail;
  }
}