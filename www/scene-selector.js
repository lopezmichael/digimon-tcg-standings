// scene-selector.js - Scene selection and localStorage persistence
// Handles first-visit detection, scene preference storage, and geolocation

(function() {
  'use strict';

  var STORAGE_KEY = 'digilab_scene_preference';
  var ONBOARDING_KEY = 'digilab_onboarding_complete';

  // ==========================================================================
  // LocalStorage Helpers
  // ==========================================================================

  /**
   * Get saved scene preference from localStorage
   * @returns {string|null} Scene slug or null if not set
   */
  function getSavedScene() {
    try {
      return localStorage.getItem(STORAGE_KEY);
    } catch (e) {
      // localStorage may be unavailable
      return null;
    }
  }

  /**
   * Save scene preference to localStorage
   * @param {string} sceneSlug Scene slug to save
   */
  function saveScene(sceneSlug) {
    try {
      localStorage.setItem(STORAGE_KEY, sceneSlug);
    } catch (e) {
      // localStorage may be unavailable
    }
  }

  /**
   * Check if onboarding has been completed
   * @returns {boolean}
   */
  function isOnboardingComplete() {
    try {
      return localStorage.getItem(ONBOARDING_KEY) === 'true';
    } catch (e) {
      return false;
    }
  }

  /**
   * Mark onboarding as complete
   */
  function completeOnboarding() {
    try {
      localStorage.setItem(ONBOARDING_KEY, 'true');
    } catch (e) {
      // localStorage may be unavailable
    }
  }

  // ==========================================================================
  // Geolocation
  // ==========================================================================

  /**
   * Get user's current position using browser geolocation
   * @returns {Promise<{lat: number, lng: number}>}
   */
  function getCurrentPosition() {
    return new Promise(function(resolve, reject) {
      if (!navigator.geolocation) {
        reject(new Error('Geolocation not supported'));
        return;
      }

      navigator.geolocation.getCurrentPosition(
        function(position) {
          resolve({
            lat: position.coords.latitude,
            lng: position.coords.longitude
          });
        },
        function(error) {
          reject(error);
        },
        {
          enableHighAccuracy: false,
          timeout: 10000,
          maximumAge: 300000 // 5 minutes
        }
      );
    });
  }

  /**
   * Calculate distance between two coordinates (Haversine formula)
   * @returns {number} Distance in kilometers
   */
  function calculateDistance(lat1, lng1, lat2, lng2) {
    var R = 6371; // Earth's radius in km
    var dLat = (lat2 - lat1) * Math.PI / 180;
    var dLng = (lng2 - lng1) * Math.PI / 180;
    var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLng/2) * Math.sin(dLng/2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }

  // ==========================================================================
  // Shiny Integration
  // ==========================================================================

  $(document).on('shiny:connected', function() {

    // Send initial scene preference to Shiny
    var savedScene = getSavedScene();
    var needsOnboarding = !isOnboardingComplete();

    Shiny.setInputValue('scene_from_storage', {
      scene: savedScene,
      needsOnboarding: needsOnboarding,
      timestamp: Date.now()
    }, {priority: 'event'});

    // Handler for saving scene to localStorage
    Shiny.addCustomMessageHandler('saveScenePreference', function(message) {
      var sceneSlug = message.scene;
      saveScene(sceneSlug);
      completeOnboarding();
    });

    // Handler for geolocation request
    Shiny.addCustomMessageHandler('requestGeolocation', function(message) {
      getCurrentPosition()
        .then(function(position) {
          // Find nearest scene from provided scenes
          var scenes = message.scenes || [];
          var nearestScene = null;
          var minDistance = Infinity;

          scenes.forEach(function(scene) {
            if (scene.latitude && scene.longitude) {
              var dist = calculateDistance(
                position.lat, position.lng,
                scene.latitude, scene.longitude
              );
              if (dist < minDistance) {
                minDistance = dist;
                nearestScene = scene;
              }
            }
          });

          Shiny.setInputValue('geolocation_result', {
            success: true,
            userLat: position.lat,
            userLng: position.lng,
            nearestScene: nearestScene,
            distance: minDistance,
            timestamp: Date.now()
          }, {priority: 'event'});
        })
        .catch(function(error) {
          var errorMessage = 'Unable to get location';
          if (error.code === 1) {
            errorMessage = 'Location permission denied';
          } else if (error.code === 2) {
            errorMessage = 'Location unavailable';
          } else if (error.code === 3) {
            errorMessage = 'Location request timed out';
          }

          Shiny.setInputValue('geolocation_result', {
            success: false,
            error: errorMessage,
            timestamp: Date.now()
          }, {priority: 'event'});
        });
    });

    // Handler for clearing onboarding (for testing)
    Shiny.addCustomMessageHandler('clearOnboarding', function(message) {
      try {
        localStorage.removeItem(STORAGE_KEY);
        localStorage.removeItem(ONBOARDING_KEY);
      } catch (e) {
        // Ignore
      }
    });

  });

  // Expose for debugging
  window.digilabScene = {
    getSavedScene: getSavedScene,
    saveScene: saveScene,
    isOnboardingComplete: isOnboardingComplete,
    clearOnboarding: function() {
      try {
        localStorage.removeItem(STORAGE_KEY);
        localStorage.removeItem(ONBOARDING_KEY);
      } catch (e) {
        // Ignore
      }
    }
  };

})();
