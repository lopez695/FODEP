// L'ordre compte : sur le web, `dart.library.io` est faux et `dart.library.js_interop`
// vrai ; hors navigateur, l'inverse. Le stub ne sert que de repli.
export 'api_runtime_environment_stub.dart'
    if (dart.library.js_interop) 'api_runtime_environment_web.dart'
    if (dart.library.io) 'api_runtime_environment_io.dart';
