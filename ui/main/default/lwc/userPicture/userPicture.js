import { LightningElement, api } from 'lwc';

export default class UserPicture extends LightningElement {
  @api attributes;

  _picture;
  get picture() {
    return this._picture || this.attributes.picture;
  }

  handlePictureOpen(e) {
    e.preventDefault(); e.stopPropagation();
    this.template.querySelector('input[name=picture]').click();
  }

  async handlePictureChanged(e) {
    e.preventDefault();
    this._picture = await this.readFile(e.target.files[0]);
  }

  readFile(file) {
    return new Promise((resolve) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result);
      reader.readAsDataURL(file);
    });
  }
}