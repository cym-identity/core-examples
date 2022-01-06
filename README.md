## Introduction

This repository contains a Sample implementation for CYM-Identity extension points

> This application has been tested using SFDX and Scratch Orgs

## Getting started

First of all, you'll need to get and setup the CYM-Identity package

Follow the instructions available on our [website](https://www.cym-identity.com/docs/guides)

1. [Install CYM-Identity](https://www.cym-identity.com/docs/guides/installation)
1. [Set up a Community](https://www.cym-identity.com/docs/guides/communities)
1. [Set up a Realm (Optional)](https://www.cym-identity.com/docs/guides/realms)
1. [Set up a Client (Optional)](https://www.cym-identity.com/docs/guides/applications)


## Giving yourself the correct permissions

1. Assign yourself a CYM-Identity License
1. Assign yourself the `cym-identity admin` permission set

```
sfdx force:user:permset:assign --permsetname cym_identity_admin --targetusername YOUR_USER_ALIAS
```

`YOUR_USER_ALIAS` should be replace with the alias you have chosen locally on SFDX.

## Deploying the samples

Clone the repository locally on your machine where you have SFDX setup and run the following command

```
sfdx force:source:push -u YOUR_USER_ALIAS
```

> If the push fails because of conflicts, you'll need to rename the components which have the same name.

`YOUR_USER_ALIAS` should be replace with the alias you have chosen locally on SFDX.

## Configuration

### Community

#### CYM Object

1. Navigate to _CYM Identity_ App > _Communities_ Tab > Your Community
1. The community must have a `RunAs` user defined who has enough rights to access user's `SmallPhotoUrl`

#### Managing URLs

This repository requires a custom URLRewriter to be set up on the Site. It also showcases the integration of a custom URLRewriter and CYM-Identity URLRewirter

1. Navigate to _CYM Identity_ App > _Communities_ Tab > Your Community
1. On the right panel click on `Setup the URL Rewriter`
1. On the `URL Rewriter Class` enter the value : `MyCustomUrlRewriter`

#### Authenticators

1. An authenticator with the name `password` and provider `cym_SalesforceAuthenticator_Password`
1. An authenticator with the name `webauthn_platform` and provider `cym_WebAuthn` (handles fingerprints, touchid, ...)
1. An authenticator with the name `webauthn_roaming` and provider `cym_WebAuthn` (handles security keys like yubikeys ...)

### Site

In order to use all the classes and pages included in this bundle, you need to assign a permission set to your Site's Guest user

1. Navigate to _Setup_ > _User Interface_ > _Sites and Domains_ > _Sites_ > Choose your Site
1. Click on _Public Access Setting_ > _View Users_ > Choose the user displayed
1. In the section _Permission Set Assignments_, click on _Edit Assignments_ and add `site guest` permission set

### Login Experience

#### Visualforce login

If you prefer to use Visualforce pages, you can use the bundled `MyCustomLogin.page` and `MyCommunitiesSelfRegController.page`

You first need to assign this page to your community guest profile

1. Navigate to _Setup_ > _User Interface_ > _Sites and Domains_ > _Sites_ > Choose your Site
1. In the _Site Visualforce Pages_ section, click `Edit` and add `MyCustomLogin` & `MyCommunitiesSelfRegController`

Next, you can configure your community to use this page

1. Navigate to _Setup_ > _Feature Settings_ > _Digital Experiences_ > _All Sites_
1. Navigate to the _Workspaces_ of your chosen Community
1. Navigate to _Administration_ > _Login & Registration_
1. In the _Login Page Type_ choose `Visualforce Page` and enter the value `MyCustomLogin`
1. In the _Registration Page Configuration_, choose `Visualforce Page` and enter the value `MyCommunitiesSelfRegController`

#### Experience Page Builder

If you prefer to use Experience Page Builder, add the component to your login page

1. Navigate to _Setup_ > _Feature Settings_ > _Digital Experiences_ > _All Sites_
1. Navigate to the _Builder_ of your chosen Community
1. Open the configuration for your Login Page
1. Drag and drop the `Discovery UI` into the correct section of the page

Configure the login page on your Community, if not done already

1. Navigate to _Setup_ > _Feature Settings_ > _Digital Experiences_ > _All Sites_
1. Navigate to the _Workspaces_ of your chosen Community
1. Navigate to _Administration_ > _Login & Registration_
1. In _Login Page Type_, choose `Experience Page Builder` and enter the name of your Login page.

> If you only want to use the Authentication Services of CYM-Identity within your community, you can try to login to your community. If you need to authenticate and authorize applications outside Salesforce, you can continue the set up

### Realm

This sample implementation works well with Realms created from the [Getting Started](https://www.cym-identity.com/docs/guides/realms)

1. Navigate to _CYM Identity_ App > _Realms_ Tab > Your Realm > _Advanced_ Tab
1. Fill in the information below
    1. Pages
        1. Consent Page `url:/consent`
        1. Challenge Page `url:/challenge`
1. Hit save
