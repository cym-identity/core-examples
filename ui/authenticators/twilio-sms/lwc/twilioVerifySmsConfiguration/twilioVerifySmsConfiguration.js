import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAuthenticatorConfig from '@salesforce/apex/AuthenticatorConfigController.getAuthenticatorConfig';
import saveAuthenticatorConfig from '@salesforce/apex/AuthenticatorConfigController.saveAuthenticatorConfig';

import remoteSiteSettingEnabled from '@salesforce/apex/TwilioVerify.is_twilio_reachable';

export default class TwilioVerifySmsConfiguration extends LightningElement {
  @api recordId;
  config;
  loading = true;

  connectedCallback() {
    getAuthenticatorConfig({authenticator_id : this.recordId})
      .then((config) => {
        this.config = config || {};
        this.loading = false;
      })
      .catch((_) => {
        this.loading = false;
        this.notifyUser('Error', `An error occured while loading the authenticator information.`, 'error');
      });
  }

  handleClick() {
    this.loading = true;
    saveAuthenticatorConfig({authenticator_id : this.recordId, config: this.config})
      .then(config => {
        this.loading = false;
        this.config = config || {};
        this.notifyUser('Success', 'Twilio Configuration Saved', 'success');
      })
      .catch((_) => {
        this.loading = false;
        this.notifyUser('Error', `An error occured while saving.`, 'error');
      });
  }

  notifyUser(title, message, variant) {
    const toastEvent = new ShowToastEvent({ title, message, variant });
    this.dispatchEvent(toastEvent);
  }

  is_remote_site_setting_enabled;

  @wire(remoteSiteSettingEnabled)
  getRemoteSiteSettingEnabled(resp) {
    const {error, data} = resp;
    this.is_remote_site_setting_enabled = data === true;
  }

  handleAccountSIDChange(e) {
    this.config = Object.assign({}, this.config, {account_sid: e.target.value});
  }

  handleAuthTokenChange(e) {
    this.config = Object.assign({}, this.config, {auth_token: e.target.value});
  }

  handleServiceSIDChange(e) {
    this.config = Object.assign({}, this.config, {service_sid: e.target.value});
  }

  handleAppHashChange(e) {
    this.config = Object.assign({}, this.config, {AppHash: e.target.value});
  }
}
