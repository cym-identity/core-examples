global with sharing class DiscoveryController { // NOPMD.AvoidGlobalModifier

  public with sharing class LoadContext extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {

      AuthContext context = AuthContext.fromParameters(new Map<String, String> {
        'startURL' => (String) params.get('startURL'),
        'login_hint' => (String) params.get('login_hint'),
        'iid' => (String) params.get('iid')
      });

      return new Map<String, Object>{
        'logo' => context.logo,
        'socialProviders' => context.getCommunityAuthProviders(),
        'requestId' => context.request.iid,
        'users' => context.getBrowserUsers(),
        'login' => new Map<String, Object> {
          'email' => true,
          'phone' => context.community.authenticators.find('name', 'phone') != null
        }
      };
    }
  }

  public with sharing class Discover extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String login_hint = (String) params.get('login_hint');
      Users.LoginType login_type_hint = Users.LoginType.valueOf(params.get('login_type') != null ? (String) params.get('login_type') : 'unknown');
      String startURL = (String) params.get('startURL');
      String requestId = (String) params.get('requestId');

      if (String.isBlank(login_hint)) throw new InvalidArgumentException('Invalid login_hint');
      if (String.isBlank(startURL)) throw new InvalidArgumentException('Invalid startURL');
      if (String.isBlank(requestId)) throw new InvalidArgumentException('Invalid requestId');

      AuthContext context = AuthContext.fromParameters(new Map<String, String> {
        'startURL' => (String) params.get('startURL'),
        'login_hint' => (String) params.get('login_hint'),
        'iid' => (String) params.get('iid')
      });

      switch on context.next.kind {
        when IDENTITY_REGISTER {
          return new Map<String, Object> {
            'action' => 'identity.register',
            'user' => new Map<String, Object> {
              'attributes' => new Map<String, Object> {
                'id' => null,
                'login' => login_hint,
                'picture' => Site.getBaseRequestUrl() + '/profilephoto/005/M'
              },
              'socialProviders' => context.getCommunityAuthProviders(),
              'fields'=> new Map<String, Object> { 'given_name' => new Map<String, Object> { 'required' => true }, 'family_name' => new Map<String, Object> { 'required' => true } },
              'picklists' => UserUtils.getPicklists()
            }
          };
        }
        when IDENTITY_VERIFY {
          return new Map<String, Object> {
            'action' => 'identity.register.email',
            'user' => new Map<String, Object> {
              'attributes' => new Map<String, Object> {
                'id' => context.owner.user.Id,
                'login' => login_hint,
                'picture' =>  context.owner.user.MediumPhotoUrl
              }
            }
          };
        }
        when AUTHENTICATOR_REGISTER {
          return new Map<String, Object> {
            'action' => 'authenticator.register' + (context.next.authenticators.size() > 1 ? '' : ('.' + ((String) context.next.authenticators.get(0).get('name')) )),
            'authenticators' => context.next.authenticators.pluck('name').asObjects(),
            'user' => new Map<String, Object> {
              'attributes' => new Map<String, Object> {
                'id' => context.owner.user.Id,
                'login' => login_hint,
                'picture' =>  context.owner.user.MediumPhotoUrl
              }
            }
          };
        }
        when AUTHENTICATOR_VERIFY {
          return new Map<String, Object> {
            'action' => 'authenticator.challenge' + (context.next.authenticators.size() > 1 ? '' : ('.' + ((String) context.next.authenticators.get(0).get('name')) )),
            'authenticators' => context.next.authenticators.pluck('name').asObjects(),
            'user' => new Map<String, Object> {
              'attributes' => new Map<String, Object> {
                'id' => context.owner.user.Id,
                'login' => login_hint,
                'picture' =>  context.owner.user.MediumPhotoUrl
              }
            }
          };
        }
        when REDIRECT {
          return new Map<String, Object> {
            'action' => 'redirect',
            'redirect' => context.owner.session.resume(context.startURL).getUrl()
          };
        }
        when else {
          return new Map<String, Object> {
            'action' => 'unknown'
          };
        }
      }
    }
  }

  public with sharing class Authenticate extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      Id userId = (Id) params.get('userId');
      String password = (String) params.get('password');
      String requestId = (String) params.get('requestId');
      User u = new UserUtils.Repository().findById(userId);
      String username = u?.username;
      if (String.isBlank(username)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');
      cym.Community idp = cym.Community.getCurrent();

      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) idp.authenticators.find('name', 'password');
      cym.SalesforceAuthenticator.Password provider = (cym.SalesforceAuthenticator.Password) authenticator.provider;

      // if (provider.compromisesCount(password) > 0) throw new InvalidPasswordException('weak_password');


      PageReference pr = Site.login(username, password, '/');

      if (pr == null) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');

      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), userId);
      session.apply((cym.Community.Authenticator) idp.authenticators.find('name', 'password'), requestId);

      return new Map<String, Object> { 'isValid' => true };
    }
  }

  public with sharing class ResetWeakPassword extends Fetch.Function {
    public override Object execute(Map<String, Object> params) {
      String email = (String) params.get('email');
      String startURL = (String) params.get('startURL');
      String password = (String) params.get('password');
      String newPassword = (String) params.get('newPassword');
      cym.Community idp = cym.Community.getCurrent();
      cym.Community.Authenticator authenticator = (cym.Community.Authenticator) idp.authenticators.find('name', 'password');
      cym.SalesforceAuthenticator.Password provider = (cym.SalesforceAuthenticator.Password) authenticator.provider;
      User u = new UserUtils.Repository().findByEmail(email);
      String username = u?.username;
      if (String.isBlank(username)) throw new InvalidUsernameException('Your login attempt has failed. Make sure the username and password are correct.');

      // Checks that the user chosen password is compliant to Authenticator policy ie.: HaveIBeenPwnd check.
      if (provider.compromisesCount(newPassword) > 0) throw new InvalidPasswordException('weak_password');
      cym.Browser.Session session = BrowserSessionUtils.findOrAddSession(cym.Browser.getCurrent(), u.Id);
      // Setting the user password requires higher permissions than a Guest user or normal user. Hence calling using the Community Technical User
      session.getRemoteApex(DiscoveryController.ResetUserPassword.class).invoke(
        JSON.serialize(
          new Map<String, Object> {
            'userId' => u.Id,
            'oldPassword' => password,
            'newPassword' => newPassword,
            'startURL' => startURL
          }
        )
      );
      return new Map<String, Object> {
        'redirect' => session
          .apply(authenticator)
          .resume(startURL)
          .getUrl()
      };

    }
  }

  global class ResetUserPassword extends cym.Remote.Function {
    global override String execute(String p) {
      Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(p);
      String newPassword = (String) params.get('newPassword');
      String oldPassword = (String) params.get('oldPassword');

      Site.changePassword(newPassword, newPassword, oldPassword);

      return '{}';
    }
  }

  public class InvalidUsernameException extends Exception {}
  public class InvalidPasswordException extends Exception {}
  public class InvalidArgumentException extends Exception {}
}
