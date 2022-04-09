import { LightningElement } from "lwc";
import { remote } from 'c/fetch';

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class DiscoveryUi extends LightningElement {

  context;
  app;
  request;
  users = [];

  startUrl =
    new URLSearchParams(document.location.search).get("startURL") || "";

  Labels = {
    consent_terms_of_service: "Terms of Service",
    consent_privacy_policy: "Privacy Policy",
  };
  loading = true;
  error = null;
  step = "loading";
  logo;

  connectedCallback() {
    remote('DiscoveryController.LoadContext', {
      startURL: this.startUrl,
    })
      .then(
        ({
          forgotPasswordUrl,
          registrationUrl,
          socialProviders,
          paths,
          request,
          users,
          app,
          logo,
        }) => {
          this.context = {
            forgotPasswordUrl,
            registrationUrl,
            socialProviders : socialProviders || [],
            paths
          }
          this.users = users || [];
          this.request = request || {};
          this.app = app;
          this.step = "discovery";
          this.logo = this.app?.logo_uri || logo;
        }
      )
      .catch((e) => (this.error = e))
      .then((_) => (this.loading = false));
  }

  fingerprintUrl = STATIC_RESOURCE_URL + "/img/fingerprint_generic_white.svg";
  fidoCertifiedUrl =
    STATIC_RESOURCE_URL + "/img/FIDO_Certified_logo_yellow.png";
  registerAnimationUrl =
    STATIC_RESOURCE_URL + "/img/windows_register_animation.gif";

  get canShowFooterSection() {
    return this.app && (this.app.tos_uri || this.app.policy_uri);
  }

  get canShowDiscoverySection() {
    return this.step === "discovery";
  }
  get canShowAuthenticatorSection() {
    return this.step === "authenticator_chooser";
  }
  get canShowRegistrationSection() {
    return this.step === "register";
  }

  handleUserSelected(e) {
    e.stopPropagation();
    const { action, user } = e.detail;
    this.step = action;
    this.user = user;
    if (this.request) this.request.login_hint = '';
  }

  backToChooser() {
    this.step = "discovery";
  }

  handleLoginDone({ detail : { redirect } }) {
    console.log({ redirect });
    console.log(JSON.parse(JSON.stringify(this.user.authenticators)));
    if (this.user.authenticators.indexOf('webauthn_platform') === -1) {
      this.redirect = redirect;
      this.step = "webauthn_platform.register";
    } else if (this.user.authenticators.indexOf('webauthn_platform') > -1 && this.user.authenticators.indexOf('totp') === -1) {
      this.redirect = redirect;
      this.step = "totp.register";
    } else {
      this.complete(redirect);
    }
  }

  redirect;
  registerWebAuthnPlatformLoading = true;

  get canRegisterWebAuthnPlatform() {
    return this.step === "webauthn_platform.register";
  }

  get canChallengeWebAuthnPlatform() {
    return this.step === 'webauthn_platform.challenge'
  }
  handleWebAuthnPlatformReady({ detail : { error } }) {
    // The browser does not support WebAuthn or does not have UserVerification
    if (error) return this.complete(this.redirect);
    this.registerWebAuthnPlatformLoading = false;
  }

  handleWebAuthnPlatformDone({ detail : { redirect }}) {
    if (this.user.authenticators.indexOf('totp') === -1) {
      this.redirect = redirect;
      this.step = "totp.register";
    } else {
      this.complete(redirect);
    }
  }

  handleWebAuthnPlatformError({ detail : { error }}) {
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

  skipEnrollWebAuthnPlatform() {
    return window.location.replace(this.redirect);
  }

  get canRegisterTotp() {
    return this.step === 'totp.register';
  }

  handleTotpRegisterDone({ detail : { redirect }}) {
    this.complete(redirect);
  }

  complete(redirect) {
    window.location.replace(redirect);
  }
}
