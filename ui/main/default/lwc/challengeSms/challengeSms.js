import { LightningElement } from 'lwc';

import { loadScript } from "lightning/platformResourceLoader";
import intlTelInputUrl from '@salesforce/resourceUrl/IntlTelInput';

import initVerificationSms from "@salesforce/apex/ChallengeController.initVerificationSms";
import verifyVerificationSms from "@salesforce/apex/ChallengeController.verifyVerificationSms";


// Import custom labels
import twilio_verify_register_description from '@salesforce/label/c.twilio_verify_register_description';
import twilio_verify_register_phone_label from '@salesforce/label/c.twilio_verify_register_phone_label';
import twilio_verify_register_button from '@salesforce/label/c.twilio_verify_register_button';
import twilio_verify_otp_description from '@salesforce/label/c.twilio_verify_otp_description';
import twilio_verify_otp_otp_label from '@salesforce/label/c.twilio_verify_otp_otp_label';
import twilio_verify_otp_button from '@salesforce/label/c.twilio_verify_otp_button';


export default class ChallengeSms extends LightningElement {
  length = 6;
  iti;
  otp;
  loading = true;

  labels = {
    twilio_verify_register_description,
    twilio_verify_register_phone_label,
    twilio_verify_register_button,
    twilio_verify_otp_description,
    twilio_verify_otp_otp_label,
    twilio_verify_otp_button
  }

  nextDisabled = true;

  transactionId;

  get showRegister() {
    return !this.transactionId ? 'display: block;' : 'display: none;';
  }

  get showOtp() {
    return !!this.transactionId;
  }

  connectedCallback() {
    loadScript(this, intlTelInputUrl + '/js/intlTelInput.min.js')
      .then(_ => {
        this.iti = intlTelInput(this.template.querySelector(".phone-input"), {
          preferredCountries: ['fr', 'us'],
          utilsScript: intlTelInputUrl + '/js/utils.js'
        });
        this.loading = false;
      })
  }

  verify() {
    verifyVerificationSms({transactionId: this.transactionId, otp : this.otp})
      .then(result => {
        this.dispatchEvent(new CustomEvent('done', {detail : result}))
      });
  }

  challenge() {
    if (!this.iti.getNumber()) {
      console.log('must enter a phone number');
      return;
    }
    this.loading = true;
    initVerificationSms({phoneNumber: this.iti.getNumber()})
      .then(result => {
        this.loading = false;
        return Promise.resolve(result);
      })
      .then(result => {
        try {
          this.transactionId = result.transactionId;
        } catch (ex) {
          console.log(ex);
        }
      }).catch(err => {
        console.error(err);
        this.loading = false;
      });
  }

  handleOtpChange(e) {
    this.otp = e.detail;
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  handleResend() {

  }
}