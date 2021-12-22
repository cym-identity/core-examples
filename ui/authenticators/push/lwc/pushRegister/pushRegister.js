import { LightningElement, api } from 'lwc';

import initRegistration from "@salesforce/apex/PushChallengeController.initRegistration";

export default class PushRegister extends LightningElement {
  @api startUrl;
  connectedCallback() {
    initRegistration({
      startURL : this.startUrl
    })
    .then(resp => {
      console.log(resp);
    })
  }
}