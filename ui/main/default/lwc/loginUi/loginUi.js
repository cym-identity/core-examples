import { LightningElement, api } from 'lwc';
import consent_terms_of_service from '@salesforce/label/cym.consent_terms_of_service';
import consent_privacy_policy from '@salesforce/label/cym.consent_privacy_policy';

import authenticate from '@salesforce/apex/SiteLoginController.authenticate';

export default class LoginUi extends LightningElement {
  @api app;
  @api registrationUrl;
  @api forgotPasswordUrl;
  @api socialProviders;
  @api startURL;
  @api users;

  connectedCallback() {
    const activeSession = this.users && this.users.length && this.users.filter(u => u.IsActive);
    console.log(activeSession);
    if (activeSession && activeSession.length == 1) {
      this.step = 'login';
      this.email = activeSession[0].Email;
    } else {
      this.step = this.users && this.users.length ? 'account_chooser' : 'login';
    }
  }

  get _users() {
    return this.users.map(u => {
      return Object.assign({}, u, {handleClick: (e) => {
        this.email = u.Email;
        this.step = 'login';
      }})
    })
  };

  Labels = {
    consent_terms_of_service,
    consent_privacy_policy
  };

  loading = false;
  email = '';
  password;
  error;

  step = 'login';

  get showAccountChooser() { return this.step === 'account_chooser'; }
  get showLogin() { return this.step === 'login'; }

  handleEmailChange(e) {
    this.email = e.target.value;
  }

  handlePasswordChange(e) {
    this.password = e.target.value;
  }

  backToChooser() {
    this.step = 'account_chooser';
  }

  chooseAnotherUser() {
    this.step = 'login';
    this.email = '';
  }

  handleSubmit(e) {
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