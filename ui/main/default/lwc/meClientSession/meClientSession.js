import { LightningElement } from 'lwc';
import getAllClientSession from '@salesforce/apex/ProfileController.getAllClientSession';
import revokeClientSession from '@salesforce/apex/ProfileController.revokeClientSession';

export default class MeClientSession extends LightningElement {
  clientSessions = [];

  connectedCallback() {
    getAllClientSession()
      .then(resp => {
        this.clientSessions = Object.keys(resp).map(key => {
          return {
            key,
            ...resp[key],
            revoke: () => {
              revokeClientSession({client_id: key})
            }
          }
        });
      });
  }
}