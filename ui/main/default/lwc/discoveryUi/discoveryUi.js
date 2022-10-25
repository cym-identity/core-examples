import { LightningElement, api } from "lwc";
import { remote } from 'c/fetch';

export default class DiscoveryUi extends LightningElement {
  @api login_hint;
  startUrl = new URLSearchParams(document.location.search).get("startURL") || "";
  Labels = {
    consent_terms_of_service: "Terms of Service",
    consent_privacy_policy: "Privacy Policy",
  };

  loading = true;
  error = null;
  step = { action: "loading" };
  app;
  users = [];
  socialProviders = []
  logo;
  requestId;
  login = { email : false, phone : false }

  connectedCallback() {
    remote('DiscoveryController.LoadContext', {
      startURL: this.startUrl,
    })
      .then(
        ({
          socialProviders = [],
          login_hint,
          users = [],
          app,
          logo,
          requestId,
          login
        }) => {
          this.socialProviders = socialProviders;
          this.users = users;
          this.app = app;
          this.logo = this.app?.logo_uri || logo;
          this.requestId = requestId;
          this.login = login;
          // The application has requested that a specific user logs in
          if (login_hint) {
            this.handleUserSelected(new CustomEvent('done', {detail : { login_hint }}));
          // An active Salesforce session exists
          } else if (this.login_hint) {
            this.handleUserSelected(new CustomEvent('done', {detail : { login_hint: this.login_hint }}))
          } else {
            this.step = { action: "identity.choose" };
            this.loading = false;
          }
        }
      )
      .catch((e) => (this.error = e, this.loading = false));
  }

  get canShowFooterSection() { return this.app && (this.app.tos_uri || this.app.policy_uri); }

  get showIdentityChoose() { return this.step.action === 'identity.choose'; }

  get showIdentityRegister() { return this.step.action === 'identity.register'; }
  get showIdentityRegisterPhone() { return this.step.action === 'identity.register.phone'; }
  get showIdentityRegisterEmail() { return this.step.action === 'identity.register.email'; }

  get showAuthenticatorChallengeTotp() { return this.step.action === 'authenticator.challenge.totp'; }
  get showAuthenticatorChallengeEmail() { return this.step.action === 'authenticator.challenge.email'; }
  get showAuthenticatorChallengePhone() { return this.step.action === 'authenticator.challenge.phone'; }
  get showAuthenticatorChallengeWebauthnPlatform() { return this.step.action === 'authenticator.challenge.webauthn_platform'; }
  get showAuthenticatorChallengeWebauthnRoaming() { return this.step.action === 'authenticator.challenge.webauthn_roaming'; }
  get showAuthenticatorChallengePassword() { return this.step.action === 'authenticator.challenge.password'; }

  get showAuthenticatorChallengeTwitter() { return this.step.action === 'authenticator.challenge.Twitter'; }
  get showAuthenticatorChallengeGoogle() { return this.step.action === 'authenticator.challenge.Google'; }
  get showAuthenticatorChallengeFacebook() { return this.step.action === 'authenticator.challenge.Facebook'; }
  get showAuthenticatorChallengeLinkedIn() { return this.step.action === 'authenticator.challenge.LinkedIn'; }

  get twitter() { return this.socialProviders.filter(provider => provider.friendlyName === 'Twitter'); }
  get google() { return this.socialProviders.filter(provider => provider.friendlyName === 'Google'); }
  get facebook() { return this.socialProviders.filter(provider => provider.friendlyName === 'Facebook'); }
  get linkedin() { return this.socialProviders.filter(provider => provider.friendlyName === 'LinkedIn'); }

  get showAuthenticatorRegisterTotp() { return this.step.action === 'authenticator.register.totp'; }
  get showAuthenticatorRegisterPhone() { return this.step.action === 'authenticator.register.phone'; }
  get showAuthenticatorRegisterWebauthnPlatform() { return this.step.action === 'authenticator.register.webauthn_platform'; }
  get showAuthenticatorRegisterWebauthnRoaming() { return this.step.action === 'authenticator.register.webauthn_roaming'; }

  handleUserSelected(e) {
    e.stopPropagation();
    this.login_hint = e.detail.login_hint;
    this.handleStepCompleted();
  }

  handleStepCompleted() {
    this.loading = true;
    remote('DiscoveryController.Discover', {
      startURL: this.startUrl,
      login_hint: this.login_hint,
      requestId: this.requestId,
    })
      .then(( detail ) => {
        if (detail.action === 'redirect') return this.complete(detail.redirect);
        this.step = detail;
        this.loading = false;
      })
      .catch(e => {
        this.error = e;
        this.loading = false;
      });
  }

  backToChooser() { this.step = { action: "identity.choose" }; }

  handleWebAuthnEnrollCompleted() { this.complete(this.step.redirect); }
  handleWebAuthnError({ detail : { error, error_description } }) {
    if (error == 'SecurityError') this.error = { error : error_description };
  }

  complete(redirect) { window.location.replace(redirect); }
}
