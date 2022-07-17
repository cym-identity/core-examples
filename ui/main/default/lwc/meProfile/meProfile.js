import { LightningElement } from 'lwc';
import { remote } from 'c/fetch';

export default class MeProfile extends LightningElement {

  loading = true;
  user;

  connectedCallback() {
    remote('ProfileController.GetProfile')
      .then(user => this.user = user)
      .then(_ => this.loading = false)
  }

  async handleSave(e) {
    e.preventDefault();
    const user = e.detail;
    this.loading = true;
    remote('ProfileController.UpdateProfile', user)
      .then( user => this.user = user).catch(error => this.error = error)
      .then(_ => this.loading = false)
  }
}