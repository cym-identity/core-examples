import { LightningElement, api } from 'lwc';

import { loadScript, loadStyle } from "lightning/platformResourceLoader";
import intlTelInputUrl from '@salesforce/resourceUrl/IntlTelInput';

export default class IntlTelInput extends LightningElement {
  iti;

  @api
  get value() { return this.iti?.getNumber();}
  set value(value) { this.iti?.setNumber(value); }

  connectedCallback() {
    Promise.all([
      loadStyle(this, intlTelInputUrl + '/css/intlTelInput.min.css'),
      loadScript(this, intlTelInputUrl + '/js/intlTelInput.min.js'),
    ]).then(_ => {
        this.iti = intlTelInput(this.template.querySelector(".phone-input"), {
          preferredCountries: ['fr', 'us'],
          utilsScript: intlTelInputUrl + '/js/utils.js'
        });
      })
  }

  handlePhoneChanged() {
    this.dispatchEvent(
      new CustomEvent('change', {detail : { isValid : this.iti.isValidNumber(), number : this.iti.getNumber(intlTelInputUtils.numberFormat.E164) }})
    );
  }
}