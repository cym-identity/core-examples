import { LightningElement, api } from 'lwc';
import { remote } from 'c/fetch';

export default class UserRegister extends LightningElement {
  @api user;

  loading = false;

  error;

  async handleRegister(e) {
    e.preventDefault();
    const user = e.detail;
    this.loading = true;
    remote('MyCommunitiesSelfRegController.RegisterUser', user)
      .then( ({ isValid }) => {
        if (isValid) this.dispatchEvent(new CustomEvent("done", { detail: { login_hint: user.login }}))
      })
      .catch(error => this.error = error)
      .then(_ => this.loading = false)
  }
}
