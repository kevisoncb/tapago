{{flutter_js}}
{{flutter_build_config}}

// Ship the renderer with the app so startup does not depend on a third-party CDN.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).toString(),
  },
});
