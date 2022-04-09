import { LightningElement, api } from 'lwc';

import { remote } from 'c/fetch';

export default class UserChooser extends LightningElement {
  @api users = [];
  @api email = "";

  startUrl = new URLSearchParams(document.location.search).get("startURL") || '';
  loading = false;
  step = "discovery";
  error;
  get canShowAccountChooser() { return this.step === "account_chooser"; }
  get canShowEmail() { return this.step === "discovery";}
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
  connectedCallback() {
    if (this.email) return this.handleDiscover();
    if (this.users && this.users.length > 0) return this.step = 'account_chooser';
  }
  chooseAnotherUser() {
    this.step = "discovery";
    this.email = "";
  }
  backToChooser() {
    this.step = "account_chooser";
  }
  handleEmailChange(e) {
    this.email = e.target.value;
  }
  async handleDiscover(e) {
    if (e) e.preventDefault();
    this.loading = true;
    remote('DiscoveryController.Discover', {
      startURL: this.startUrl,
      email: this.email,
    })
      .then((resp) => {
        this.dispatchEvent(new CustomEvent('selected', { detail : resp }));
      })
      .catch(e => this.error = e)
      .then(_ => this.loading = false);
  }
}