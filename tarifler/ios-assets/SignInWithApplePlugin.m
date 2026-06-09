#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(SignInWithApplePlugin, "SignInWithApple",
    CAP_PLUGIN_METHOD(authorize, CAPPluginReturnPromise);
)
