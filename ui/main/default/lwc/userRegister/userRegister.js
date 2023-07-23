import { LightningElement, api } from 'lwc';
import { remote } from 'c/fetch';

export default class UserRegister extends LightningElement {
  @api user;
  @api requestId;

  loading = false;
  error;
  profile;
  password;

  handleProfileFilled(e) {
    e.preventDefault();
    this.profile = e.detail;
  }

  async handleRegister(e) {
    this.loading = true;
    remote('RegisterPageController.RegisterUser', { ...this.profile, login_hint: this.profile.login, password: this.password, requestId: this.requestId})
      .then( ({ isValid }) => {
        if (isValid) this.dispatchEvent(new CustomEvent("done", { detail: { login_hint: this.profile.login }}))
      })
      .catch(error => this.error = error)
      .then(_ => this.loading = false)
  }

  handlePasswordChange(e) {
    this.password = e.target.value;
  }
}
