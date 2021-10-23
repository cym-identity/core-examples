public with sharing class BrowserHandleController {
  public static final transient Map<String, Object> RESPONSE = new Map<String, Object>();
  public String log {
    get {
      try {
        return JSON.serialize(RESPONSE);
      } catch (Exception ex) {
        return JSON.serialize(new Map<String, Object> {
          'error' => ex.getMessage(),
          'error_description' => null,
          'error_stack_trace' => ex.getStackTraceString().split('\n')
        });
      }
    }
  }

  public BrowserHandleController() {
    RESPONSE.put(
      'handle',
      cym.Browser.getCurrent().handle.value
    );
  }
}
