public with sharing virtual class AuthPageController {
  public String log {
    get {
      try {
        return JSON.serialize(DEBUG_LOG);
      } catch (Exception ex) {
        return JSON.serialize(ConverterUtils.toMap(ex));
      }
    }
  }
  protected final Map<String, Object> DEBUG_LOG = new Map<String, Object> {};

  public String logo {get; protected set;}

  public AuthPageController() {
  }
}
