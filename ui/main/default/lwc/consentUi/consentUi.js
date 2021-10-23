import { LightningElement, api } from 'lwc';
import init from '@salesforce/apex/ApprovalController.init';
import save from '@salesforce/apex/ApprovalController.save';

export default class ConsentUi extends LightningElement {
  @api startURL;
  loading = true;
  requested = [];
  existing = [];
  client;

  connectedCallback() {
    init({startURL: this.startURL}).then(resp => {
      this.existing = resp.scopes.existing || [];
      this.requested = resp.scopes.requested.filter(scope => this.existing.indexOf(scope) === -1);
      this.client = resp.client;
      this.loading = false;
    });
  }

  handleSave() {
    this.loading = true;
    save({startURL : this.startURL}).then(_ => {
      window.location.replace(this.startURL, {});
    }).catch(err => {
      console.error(JSON.stringify(err.body));
    })
  }
}