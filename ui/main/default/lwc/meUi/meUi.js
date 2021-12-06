import { LightningElement, api } from 'lwc';

export default class MeUi extends LightningElement {

  @api recordId;
  acceptedFormats = ['png', 'jpg', 'jpeg'];
  handleUploadFinished(e) {
    console.log(e, this.recordId);
  }

}