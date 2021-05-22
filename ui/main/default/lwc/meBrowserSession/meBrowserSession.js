import { LightningElement } from 'lwc';
import revokeSession from '@salesforce/apex/ProfileController.revokeSessions';

export default class MeBrowserSession extends LightningElement {

  closeAllSessions() {
    revokeSession();
  }
}