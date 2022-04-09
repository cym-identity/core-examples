import { LightningElement, api } from 'lwc';
import { remote } from 'c/fetch';

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class UserRegister extends LightningElement {
  @api email;
  firstName;
  lastName;
  nickName;
  error;
  userId;
  startUrl = new URLSearchParams(document.location.search).get("startURL") || "";

  fingerprintUrl = STATIC_RESOURCE_URL + "/img/fingerprint_generic_white.svg";
  fidoCertifiedUrl = STATIC_RESOURCE_URL + "/img/FIDO_Certified_logo_yellow.png";
  registerAnimationUrl = STATIC_RESOURCE_URL + "/img/windows_register_animation.gif";

  step = "webauthn_platform.register";

  handleEmailChange(e) {
    this.email = e.target.value;
  }

  handleFirstNameChange(e) {
    this.firstName = e.target.value;
  }

  handleLastNameChange(e) {
    this.lastName = e.target.value;
  }

  handleNicknameChange(e) {
    this.nickName = e.target.value;
  }

  handleRegister(e) {
    e.preventDefault();
    remote('MyCommunitiesSelfRegController.RegisterUser', {
      email : this.email,
      firstName: this.firstName,
      lastName: this.lastName,
      nickName: this.nickName
    }).then( ({ userId }) => {
      if (userId) {
        this.userId = userId;
        this.step = "webauthn_platform.register";
      }
    }).catch(error => this.error = error);
  }

  registerWebAuthnPlatformLoading = true;

  get canRegisterWebAuthnPlatform() {
    return this.step === "webauthn_platform.register";
  }
  get canRegisterPassword() {
    return this.step === "password";
  }

  handleWebAuthnPlatformReady({ detail : { error } }) {
    // The browser does not support WebAuthn or does not have UserVerification
    if (error) return this.step = "password";
    this.registerWebAuthnPlatformLoading = false;
  }

  handleWebAuthnPlatformDone({ detail : { redirect }}) {
    this.complete(redirect);
  }

  handleWebAuthnPlatformError({ detail : { error }}) {
    console.log({ error })
    if (error === 'InvalidStateError') {
      // The user already has a device authenticator registered
      // Device authenticators on Windows are registered at OS level, so they are usable across all browsers
      // Request the user to verify his biometric
      this.step = 'webauthn_platform.challenge';
    } else if (error === 'NotAllowedError') {
      // The user has cancelled the request or the request has timeout
      // The user must try again
    } else {
      // Another error happened, ignore and continue the flow
      // window.location.replace(this.redirect);
    }
  }

  showLearnMore = false;
  toggleLearnMore() {
    this.showLearnMore = !this.showLearnMore;
  }

  complete(redirect) {
    window.location.replace(redirect);
  }
}