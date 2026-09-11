/**
 * Loads the Datadog Browser RUM SDK and wires it to the storefront.
 * Configuration comes from rum-config.js, rendered at container start.
 */
(function () {
  var cfg = window.DEMO_RUM || {};

  if (!cfg.applicationId || !cfg.clientToken ||
      cfg.applicationId.indexOf('replace_with') === 0) {
    console.warn('[RUM] Not configured. Set DD_RUM_APPLICATION_ID and ' +
                 'DD_RUM_CLIENT_TOKEN in .env, then restart the web container.');
    document.addEventListener('DOMContentLoaded', function () {
      var banner = document.getElementById('rum-banner');
      if (banner) banner.style.display = 'block';
    });
    return;
  }

  var script = document.createElement('script');
  script.src = cfg.cdn;
  script.async = true;
  script.onload = function () {
    window.DD_RUM.init({
      applicationId: cfg.applicationId,
      clientToken: cfg.clientToken,
      site: cfg.site,
      service: '__DEMO_NAME__-web-browser',
      env: 'demo',
      version: '1.4.0',
      sessionSampleRate: 100,
      sessionReplaySampleRate: 100,
      trackUserInteractions: true,
      trackResources: true,
      trackLongTasks: true,
      defaultPrivacyLevel: 'allow',
      traceSampleRate: 100,
      // Connect browser sessions to backend traces on the same origin.
      allowedTracingUrls: [
        function (url) { return url.indexOf(window.location.origin) === 0; }
      ]
    });
    window.DD_RUM.startSessionReplayRecording();
    console.log('[RUM] initialised for __DEMO_NAME__-web-browser');
  };
  script.onerror = function () {
    console.error('[RUM] failed to load the browser SDK from ' + cfg.cdn);
  };
  document.head.appendChild(script);
})();
