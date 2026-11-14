// Flutter startup deliberately leaves service-worker ownership to this file.
if ('serviceWorker' in navigator) {
  let refreshing = false;
  // Reload on first takeover too: Flutter's renderer/fonts may have loaded
  // before registration. Reloading lets this worker cache those requests.
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (!refreshing) {
      refreshing = true;
      window.location.reload();
    }
  });

  window.addEventListener('load', async () => {
    try {
      const registration = await navigator.serviceWorker.register(
        'service_worker.js', { updateViaCache: 'none' }
      );
      const checkForUpdate = () => registration.update().catch((error) => {
        console.debug('App update check deferred:', error);
      });
      // Installed PWAs can stay open for days. Check again when returning to
      // the app or reconnecting, as well as on each normal page load.
      document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') checkForUpdate();
      });
      window.addEventListener('online', checkForUpdate);
    } catch (error) {
      console.debug('Offline support could not start:', error);
    }
  });
}
