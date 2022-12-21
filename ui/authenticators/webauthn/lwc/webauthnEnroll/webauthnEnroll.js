import { LightningElement, api } from 'lwc';

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class WebauthnEnroll extends LightningElement {
  @api user;
  @api requestId;

  step = 'authenticator.register.webauthn_platform';


  get showAuthenticatorRegisterWebauthnPlatform() { return this.step === 'authenticator.register.webauthn_platform'; }
  get showAuthenticatorTryChallengeWebauthnPlatform() { return this.step === 'authenticator.try.webauthn_platform'; }

  registerWebAuthnPlatformLoading = false;

  fingerprintUrl = STATIC_RESOURCE_URL + "/img/fingerprint_generic_white.svg";
  fidoCertifiedUrl = STATIC_RESOURCE_URL + "/img/FIDO_Certified_logo_yellow.png";
  registerAnimationUrl = STATIC_RESOURCE_URL + "/img/windows_register_animation.gif";

  handleWebAuthnPlatformDone() {
    this.dispatchEvent(new CustomEvent('done', {detail : { registered : true }}));
  }

  handleWebAuthnPlatformError({ detail }) {
    const { error } = detail;
    if (error === 'InvalidStateError') {
      // The user already has a device authenticator registered
      // Device authenticators on Windows are registered at OS level, so they are usable across all browsers
      // Request the user to verify his biometric
      this.step = 'authenticator.try.webauthn_platform';
    } else if (error === 'NotAllowedError') {
      // The user has cancelled the request or the request has timeout
      // The user must try again
      this.registerWebAuthnPlatformLoading = false;
    } else {
      // Another error happened, finish the flow
      this.dispatchEvent(new CustomEvent('done', {detail : { registered : false }}));
    }
  }

  showLearnMore = false;
  toggleLearnMore() {
    this.showLearnMore = !this.showLearnMore;
  }

  skipEnrollWebAuthnPlatform() {
    this.dispatchEvent(new CustomEvent('done', {detail : { registered : false }}));
  }
}