import { LightningElement } from 'lwc';
import { remote } from 'c/fetch';

export default class CriticalResource extends LightningElement {
  loading = true;
  connectedCallback() {
    remote('ProfileController.CheckCriticalAccess')
      .then(({isValid}) => {
        if (!isValid) this.dispatchEvent(new CustomEvent('challenge', {detail : {}, bubbles: true}));
        else {
          this.loading = false;
          setTimeout(() => {
            this.connectedCallback();
          }, 30_000)
        }
      })
  }

}