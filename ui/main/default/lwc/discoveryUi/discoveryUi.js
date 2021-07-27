import { LightningElement, api } from 'lwc';
import consent_terms_of_service from '@salesforce/label/cym.consent_terms_of_service';
import consent_privacy_policy from '@salesforce/label/cym.consent_privacy_policy';

import discover from '@salesforce/apex/SiteLoginController.discover';
import authenticate from '@salesforce/apex/SiteLoginController.authenticate';

export default class DiscoveryUi extends LightningElement {
  @api app;
  @api registrationUrl;
  @api forgotPasswordUrl;
  @api startURL;
  @api users;

  connectedCallback() {
    this.step = this.users && this.users.length ? 'account_chooser' : 'discovery';
  }

  get _users() {
    return this.users.map(u => {
      return Object.assign({}, u, {handleClick: (e) => {
        this.email = u.Email;
        this.handleDiscover(e);
      }})
    })
  };
  socialProviders;
  Labels = {
    consent_terms_of_service,
    consent_privacy_policy
  };
  loading = false;
  email = '';
  password;
  error;

  step = 'discovery';

  get showAccountChooser() { return this.step === 'account_chooser'; }
  get showEmail() { return this.step === 'discovery'; }
  get showLogin() { return this.step === 'login'; }
  get showRegister() { return this.step === 'register'; }

  handleEmailChange(e) {
    this.email = e.target.value;
  }

  handlePasswordChange(e) {
    this.password = e.target.value;
  }

  resetEmail() {
    this.step = this.users && this.users.length && this.users.filter(u => u.Email === this.email).length ? 'account_chooser' : 'discovery';
    this.password = '';
  }

  backToChooser() {
    this.step = 'account_chooser';
  }

  chooseAnotherUser() {
    this.step = 'discovery';
    this.email = '';
  }

  handleDiscover(e) {
    e.preventDefault();
    this.loading = true;
    discover({email : this.email, startURL : this.startURL})
      .then(({action, socialProviders}) => {
        // if (redirect) window.location.replace(redirect);
        this.step = action;
        this.socialProviders = socialProviders;
        this.loading = false;
      })
      .catch(({body}) => {
        this.loading = false;
        this.error = body.message;
        setTimeout(() => {
          this.error = undefined
        }, 3000);
      });
  }

  handleLogin(e) {
    e.preventDefault();
    this.loading = true;
    authenticate({email : this.email, password: this.password, startURL : this.startURL})
      .then(redirect => {
        if (redirect) window.location.replace(redirect);
        // this.loading = false;
      })
      .catch(({body}) => {
        this.loading = false;
        this.error = body.message;
        setTimeout(() => {
          this.error = undefined
        }, 3000);
      });
  }
}