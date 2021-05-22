import { LightningElement } from 'lwc';
import getAllConsent from '@salesforce/apex/ProfileController.getAllConsent';
import revokeConsent from '@salesforce/apex/ProfileController.revokeConsent';

export default class MeConsent extends LightningElement {
  consents = [];

  connectedCallback() {
    getAllConsent()
      .then(resp => {
        this.consents = Object.keys(resp).map(key => {
          return {
            key,
            client: resp[key].client,
            scopes: resp[key].scopes,
            revoke: () => {
              revokeConsent({client_id: key})
            }
          }
        });
      })
  }


}