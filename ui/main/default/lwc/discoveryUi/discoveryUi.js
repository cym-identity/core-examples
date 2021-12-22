import { LightningElement } from "lwc";
import consent_terms_of_service from "@salesforce/label/cym.consent_terms_of_service";
import consent_privacy_policy from "@salesforce/label/cym.consent_privacy_policy";

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

import discover from "@salesforce/apex/DiscoveryController.discover";
import authenticate from "@salesforce/apex/DiscoveryController.authenticate";
import resetWeakPassword from "@salesforce/apex/DiscoveryController.resetWeakPassword";

export default class DiscoveryUi extends LightningElement {
  app;
  registrationUrl;
  forgotPasswordUrl;
  socialProviders = [];
  users = [];

  startUrl = new URLSearchParams(document.location.search).get('startURL');
  basePath = STATIC_RESOURCE_URL.split("/resource/")[0][0] === '/' ? window.location.protocol + '//' + window.location.host + STATIC_RESOURCE_URL.split("/resource/")[0] : STATIC_RESOURCE_URL.split("/resource/")[0];
  authenticators = [];
  socialProviders;
  Labels = {
    consent_terms_of_service,
    consent_privacy_policy,
  };
  loading = true;
  email = "";
  userId;
  password;
  error;
  step = "loading";


  styles = {
    Google : `background-image:url(${STATIC_RESOURCE_URL}/img/google-plus.png)`,
    Facebook : `background-image:url(${STATIC_RESOURCE_URL}/img/facebook.svg)`,
    Twitter : `background-image:url(${STATIC_RESOURCE_URL}/img/twitter.png)`,
    LinkedIn :`background-image:url(${STATIC_RESOURCE_URL}/img/linkedin.svg)`,
  }

  connectedCallback() {
    fetch(
      this.basePath + '/discover',
      {
        method: 'POST',
        headers: {
          Accept: 'application/json'
        },
        body: new URLSearchParams({
          action: 'loadContext',
          startURL: this.startUrl
        })
      }
    )
    .then(resp => resp.json())
    .then(({forgotPasswordUrl, registrationUrl, socialProviders, users, app}) => {
      this.forgotPasswordUrl = forgotPasswordUrl;
      this.registrationUrl = registrationUrl;
      this.socialProviders = (socialProviders || []).map(provider => {
        provider.style = this.styles[provider.friendlyName];
        return provider;
      });
      this.users = users;
      this.app = app;
      this.loading = false;
      this.step = this.users && this.users.length ? "account_chooser" : "discovery";
    })
    .catch(console.error);
  }

  fingerprintUrl = STATIC_RESOURCE_URL + "/img/fingerprint_generic_white.svg";
  fidoCertifiedUrl = STATIC_RESOURCE_URL + "/img/FIDO_Certified_logo_yellow.png";
  registerAnimationUrl = STATIC_RESOURCE_URL + '/img/windows_register_animation.gif';

  get _users() {
    return this.users.map((u) => {
      return Object.assign({}, u, {
        handleClick: (e) => {
          this.email = u.Email;
          this.handleDiscover(e);
        },
      });
    });
  }
  get avatar() {
    if (this.email) {
      const currentUser = this.users.find(u => u.Email === this.email);
      if (currentUser) return currentUser.SmallPhotoUrl;
    }
    return 'https://www.lightningdesignsystem.com/assets/images/avatar2.jpg';
  }

  get canShowFooterSection() { return this.app && (this.app.tos_uri || this.app.policy_uri); }

  get canShowDiscoverySection() {return ["account_chooser", "discovery"].indexOf(this.step) > -1;}
  get canShowAuthenticatorSection() {return (["authenticator_chooser", "password", "webauthn", "webauthn_platform", "totp", "webauthn_platform.register",].indexOf(this.step) > -1);}
  get canShowRegistrationSection() {return ["register"].indexOf(this.step) > -1;}

  get canShowAccountChooser() { return this.step === "account_chooser";}
  get canShowEmail() {return this.step === "discovery";}
  get canShowPassword() {return this.step === "password";}
  get canShowWebAuthnPlatform() {return this.step === "webauthn_platform";}

  get canShowRegister() {return this.step === "register";}
  get canRegisterWebAuthnPlatform() {return this.step === "webauthn_platform.register";}
  get canShowTotp() {return this.step === "totp";}

  get canShowAuthenticatorOptions() {return (this.canShowAuthenticatorSection && !this.canShowAuthenticatorChooser && this.authenticators.length > 1);}
  get canShowAuthenticatorChooser() {return this.step === "authenticator_chooser";}
  get canShowAuthenticatorChooserTotp() {return (this.step === "authenticator_chooser" && this.authenticators.indexOf("totp") > -1);}
  get canShowAuthenticatorChooserWebAuthnPlatform() {return (this.step === "authenticator_chooser" && this.authenticators.indexOf("webauthn_platform") > -1);}
  get canShowAuthenticatorChooserPassword() {return (this.step === "authenticator_chooser" && this.authenticators.indexOf("password") > -1);}

  handleEmailChange(e) {
    this.email = e.target.value;
  }

  handlePasswordChange(e) {
    this.password = e.target.value;
  }
  handleNewPasswordChange(e) {
    this.newPassword = e.target.value;
  }

  resetEmail() {
    this.step =
      this.users &&
      this.users.length &&
      this.users.filter((u) => u.Email === this.email).length
        ? "account_chooser"
        : "discovery";
    this.password = "";
    this.weak_password = false;
  }

  weak_password = false;
  newPassword;

  backToChooser() { this.step = "account_chooser"; }
  backToAuthenticatorChooser() { this.step = "authenticator_chooser"; }

  chooseAnotherUser() {
    this.step = "discovery";
    this.email = "";
    this.userId = "";
    this.error = "";
    this.weak_password = false;
    this.newPassword = '';
  }

  showAuthenticatorTotp() { this.step = "totp"; }

  showAuthenticatorPassword() { this.step = "password"; }

  handleTotpDone(e) {
    const redirect = e.detail.redirect;
    if (redirect) return this.loginComplete(redirect);
    this.loading = false;
    this.error = "An error occured during your authentication";
  }

  redirect;
  async loginComplete(redirect) {
    if (
      this.authenticators.indexOf("webauthn_platform") == -1 &&
      this.step !== "webauthn_platform.register"
    ) {
      this.redirect = redirect;
      this.loading = false;
      this.authenticators = [];
      this.step = "webauthn_platform.register";
      return;
    }
    return window.location.replace(redirect);
  }

  registerWebAuthnPlatformLoading = true;
  handleRegisterWebAuthnPlatformReady({
    detail: {
      error,
      error_description,
    },
  }) {
    // The browser does not support WebAuthn or does not have UserVerification
    if (error) return window.location.replace(this.redirect);
    this.registerWebAuthnPlatformLoading = false;
  }

  async handleDiscover(e) {
    e.preventDefault();
    this.loading = true;
    const { handle } = (
      await (await fetch(this.basePath + "/browser_handle")).json()
    );
    discover({ email: this.email, startURL: this.startUrl, handle })
      .then((resp) => {
        this.step = resp.action;
        this.userId = resp.userId;
        this.authenticators = resp.authenticators || [];
        this.loading = false;
      })
      .catch(({ body }) => {
        this.loading = false;
        this.error = body.message;
        setTimeout(() => {
          this.error = undefined;
        }, 3000);
      });
  }

  async handleLogin(e) {
    e.preventDefault();
    this.loading = true;
    const handle = (
      await (await fetch(this.basePath + "/browser_handle")).json()
    ).handle;

    if (this.weak_password) {
      return resetWeakPassword({
        email: this.email,
        password: this.password,
        newPassword: this.newPassword,
        startURL: this.startUrl,
        handle,
      })
        .then((redirect) => {
          if (redirect) this.loginComplete(redirect);
          this.loading = false;
        })
        .catch(({ body : {message} }) => {
          this.loading = false;
          this.error = message;
          if (message === 'weak_password') this.weak_password = true;
          setTimeout(() => {
            this.error = undefined;
          }, 3000);
        });
    } else {
      authenticate({
        email: this.email,
        password: this.password,
        startURL: this.startUrl,
        handle,
      })
        .then((redirect) => {
          if (redirect) this.loginComplete(redirect);
          this.loading = false;
        })
        .catch(({ body : {message} }) => {
          this.loading = false;
          this.error = message;
          if (message === 'weak_password') this.weak_password = true;
          setTimeout(() => {
            this.error = undefined;
          }, 3000);
        });
    }
  }

  handleWebAuthnPlatformReady({ detail: { error } }) {
    if (error) {
      // The browser does not support WebAuthn or does not have UserVerification
      // Must remove the webauthn_platform from the list of authenticators and allow the user to choose another method
      this.removeAuthenticator('webauthn_platform');
      this.backToAuthenticatorChooser();
    }
  }

  removeAuthenticator(name) {
    this.authenticators = this.authenticators.filter(authenticator => authenticator != name);
  }

  handleWebAuthnPlatformDone({ detail: { redirect } }) {
    if (redirect) return window.location.replace(redirect);
    this.loading = false;
  }

  handleWebAuthnPlatformError({ detail: { error, error_description } }) {
    // The user cancelled or none of the credentials registered by the current user are part of the current device
    this.removeAuthenticator('webauthn_platform');
    this.backToAuthenticatorChooser();
    this.error = error_description;
    setTimeout(() => {
      this.error = null;
    }, 3000);
  }

  showLearnMore = false;
  toggleLearnMore() {
    this.showLearnMore = !this.showLearnMore;
  }

  skipEnrollWebAuthnPlatform() {
    return window.location.replace(this.redirect);
  }
}
