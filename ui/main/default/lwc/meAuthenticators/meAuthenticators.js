import { LightningElement } from "lwc";
import { remote } from "c/fetch";

export default class MeAuthenticators extends LightningElement {
  loading = true;

  lastPasswordChangeTime;
  totpCreationDate;
  hasUserVerifiedEmailAddress;
  hasTotp;
  hasSalesforceAuthenticator;
  user = {};

  socialProviders = { enrolled : [], available : []};

  modal;

  identifiers = {};
  authenticators = {};

  get showAuthenticatorRegisterTotp() {
    return !this.hasTotp && this.modal === 'authenticator.register.totp';
  }

  get showAuthenticatorRegisterEmail() {
    return !this.hasUserVerifiedEmailAddress && this.modal === 'authenticator.register.email';
  }


  async connectedCallback() {
    this.loading = true;
    remote("ProfileController.GetSecurityProfile").then(({identifiers, authenticators, id}) => {
      this.identifiers = identifiers;
      this.authenticators = authenticators;
    }).catch(console.error);
    remote("ProfileController.GetSecurityStatus")
      .then(
        ({ lastPasswordChangeTime, hasUserVerifiedEmailAddress, hasTotp, totpCreationDate, socialProviders, id, hasSalesforceAuthenticator }) => {
          this.lastPasswordChangeTime = lastPasswordChangeTime ? new Date(lastPasswordChangeTime).toLocaleString() : null;
          this.totpCreationDate = new Date(totpCreationDate).toLocaleString();
          this.hasUserVerifiedEmailAddress = hasUserVerifiedEmailAddress;
          this.hasTotp = hasTotp;
          this.socialProviders = {
            available: socialProviders.available.filter(sp => socialProviders.enrolled.indexOf(sp.id) === -1),
            enrolled: socialProviders.enrolled.map(id => socialProviders.available.find(sp => sp.id === id))
          };
          this.hasSalesforceAuthenticator = hasSalesforceAuthenticator;
          this.user = { id };
        }
      )
      .then((_) => (this.loading = false));
  }
  handleStepCompleted() {
    this.modal = null;
    this.connectedCallback();
  }

  handleRegisterTotp() {
    this.modal = 'authenticator.register.totp';
  }
  handleRegisterTotpClose() {
    this.modal = null;
  }

  handleRegisterEmail() {
    this.modal = 'authenticator.register.email';
  }
  handleRegisterEmailClose() {
    this.modal = null;
  }
}
