import { LightningElement, api, wire } from 'lwc';
import remoteSiteSettingEnabled from '@salesforce/apex/TwilioVerify.is_twilio_reachable';

export default class TwilioVerifySmsConfiguration extends LightningElement {
  @api save;
  @api config;

  is_remote_site_setting_enabled;

  @wire(remoteSiteSettingEnabled)
  getRemoteSiteSettingEnabled(resp) {
    const {error, data} = resp;
    this.is_remote_site_setting_enabled = data === true;
  }

  handleClick() {
    this.save(this.config);
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
