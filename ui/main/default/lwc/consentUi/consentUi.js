import { LightningElement, api } from 'lwc';

import { remote } from 'c/fetch';

export default class ConsentUi extends LightningElement {
  @api startURL;
  loading = true;
  requested = [];
  existing = [];
  client;

  connectedCallback() {
    remote('ApprovalController.Init', {startURL: this.startURL}).then(resp => {
      this.existing = resp.scopes.existing || [];
      this.requested = resp.scopes.requested.filter(scope => this.existing.indexOf(scope) === -1);
      this.client = resp.client;
      this.loading = false;
    });
  }

  handleSave() {
    this.loading = true;
    remote('ApprovalController.Save', {startURL : this.startURL}).then(startURL => {
      if (! startURL) return this.loading = false;
      window.location.replace(startURL, {});
    }).catch(err => {
      console.error(JSON.stringify(err.body));
    })
  }
}
