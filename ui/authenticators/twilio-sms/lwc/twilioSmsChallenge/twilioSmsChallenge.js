import { LightningElement, api } from 'lwc';
import { remote } from 'c/fetch';

// Import custom labels
import twilio_verify_register_description from '@salesforce/label/c.twilio_verify_register_description';
import twilio_verify_register_phone_label from '@salesforce/label/c.twilio_verify_register_phone_label';
import twilio_verify_register_button from '@salesforce/label/c.twilio_verify_register_button';
import twilio_verify_otp_description from '@salesforce/label/c.twilio_verify_otp_description';
import twilio_verify_otp_otp_label from '@salesforce/label/c.twilio_verify_otp_otp_label';
import twilio_verify_otp_button from '@salesforce/label/c.twilio_verify_otp_button';


export default class TwilioSmsChallenge extends LightningElement {
  @api user;
  @api requestId;


  length = 6;
  iti;
  otp = "";
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
  connectedCallback() {
    this.handleResend();
  }

  handleNext(e) {
    e.preventDefault();
    e.stopPropagation();
    this.loading = true;
    remote('TwilioVerifySmsController.VerifyVerification', {
      userId : this.user.id,
      requestId : this.requestId,
      sid: this.transactionId,
      otp: this.otp
    })
      .then( ({ isValid }) => {
        if (isValid) this.dispatchEvent(new CustomEvent("done"));
      })
      .catch(error => (this.error = error, this.loading = false))
  }

  handleOtpChange(e) {
    this.otp = e.target.value;
    this.nextDisabled = !this.otp || this.otp.length != this.length;
  }

  handleResend() {
    this.loading = true;
    remote('TwilioVerifySmsController.InitVerification', {
      userId : this.user.id,
      requestId : this.requestId
    })
      .then(resp =>( this.transactionId = resp.sid, this.loading = false))
      .catch(error => (this.error = error, this.loading = false))
  }
}