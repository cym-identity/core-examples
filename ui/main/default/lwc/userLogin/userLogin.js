import { LightningElement, api } from "lwc";

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class UserLogin extends LightningElement {
  @api user;
  @api context;

  startUrl =
    new URLSearchParams(document.location.search).get("startURL") || "";
  loading = false;

  fingerprintUrl = STATIC_RESOURCE_URL + "/img/fingerprint_generic_white.svg";
  styles = {
    Google: `background-image:url(${STATIC_RESOURCE_URL}/img/google-plus.png)`,
    Facebook: `background-image:url(${STATIC_RESOURCE_URL}/img/facebook.svg)`,
    Twitter: `background-image:url(${STATIC_RESOURCE_URL}/img/twitter.png)`,
    LinkedIn: `background-image:url(${STATIC_RESOURCE_URL}/img/linkedin.svg)`,
  };

  socialProviders = [];
  authenticators = [];

  step = "authenticator_chooser";

  connectedCallback() {
    this.authenticators = this.user.authenticators;
    this.socialProviders = this.context.socialProviders.map(provider => Object.assign({}, provider, {style : this.styles[provider.friendlyName]}));
    this.backToAuthenticatorChooser();
  }

  resetEmail() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  handlePasswordDone({ detail : { redirect }}) {
    this.loginComplete(redirect);
  }

  get canShowAuthenticatorChooserWebAuthnPlatform() {
    return (
      this.step === "authenticator_chooser" &&
      this.authenticators.indexOf("webauthn_platform") > -1
    );
  }

  handleWebAuthnPlatformReady({ detail: { error } }) {
    if (error) {
      // The browser does not support WebAuthn or does not have UserVerification
      // Must remove the webauthn_platform from the list of authenticators and allow the user to choose another method
      this.removeAuthenticator("webauthn_platform");
      this.backToAuthenticatorChooser();
    }
  }

  handleWebAuthnPlatformDone({ detail: { redirect } }) {
    if (redirect) this.loginComplete(redirect);
    this.loading = false;
  }

  handleWebAuthnPlatformError({ detail: { error, error_description } }) {
    // The user cancelled or none of the credentials registered by the current user are part of the current device
    this.removeAuthenticator("webauthn_platform");
    this.backToAuthenticatorChooser();
    console.log({ error, error_description });
    this.error = { error, error_description };
    setTimeout(() => (this.error = null), 3000);
  }

  get canShowAuthenticatorChooserTotp() {
    return (
      this.step === "authenticator_chooser" &&
      this.authenticators.indexOf("totp") > -1
    );
  }
  get canShowAuthenticatorChooserPassword() {
    return (
      this.step === "authenticator_chooser" &&
      this.authenticators.indexOf("password") > -1
    );
  }

  get canShowPassword() {
    return this.step === "password";
  }
  get canShowWebAuthnPlatform() {
    return this.step === "webauthn_platform";
  }

  get canShowTotp() {
    return this.step === "totp";
  }

  backToAuthenticatorChooser() {
    this.step = this.authenticators.length === 1 ? this.authenticators[0] : "authenticator_chooser";
  }

  showAuthenticatorTotp() {
    this.step = "totp";
  }

  showAuthenticatorPassword() {
    this.step = "password";
  }

  handleTotpDone(e) {
    const redirect = e.detail.redirect;
    if (redirect) return this.loginComplete(redirect);
    this.loading = false;
    this.error = { error: "An error occured during your authentication" };
  }

  loginComplete(redirect) {
    this.dispatchEvent(new CustomEvent('done', { detail : { redirect }}));
  }

  get canShowAuthenticatorOptions() {
    return (
      !this.canShowAuthenticatorChooser &&
      this.authenticators.length > 1
    );
  }
  get canShowAuthenticatorChooser() {
    return this.step === "authenticator_chooser";
  }

  removeAuthenticator(name) {
    this.authenticators = this.authenticators.filter(
      (authenticator) => authenticator != name
    )
  }
}
