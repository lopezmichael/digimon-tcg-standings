// url-routing.js - Browser history handling for deep linking
// Enables shareable URLs for players, decks, stores, tournaments, and scenes

(function() {
  'use strict';

  // ==========================================================================
  // Browser History Handling
  // ==========================================================================

  // Listen for back/forward button navigation
  window.addEventListener('popstate', function(event) {
    // Notify Shiny when user navigates with browser buttons
    if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
      Shiny.setInputValue('url_popstate', {
        state: event.state,
        search: window.location.search,
        timestamp: Date.now()
      }, {priority: 'event'});
    }
  });

  // ==========================================================================
  // Shiny Message Handlers
  // ==========================================================================

  // Wait for Shiny to be ready
  $(document).on('shiny:connected', function() {

    // Listen for modal close events to clear URL entity
    // Use small delay to allow cross-modal navigation to update URL first
    $(document).on('hidden.bs.modal', '.modal', function() {
      setTimeout(function() {
        // Only clear URL if no modal is currently visible (not cross-modal nav)
        if ($('.modal:visible').length === 0) {
          if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
            Shiny.setInputValue('modal_closed', Date.now(), {priority: 'event'});
          }
        }
      }, 100);
    });

    // Handler for pushing new URL to history (adds to back button history)
    Shiny.addCustomMessageHandler('pushUrl', function(message) {
      var url = message.url || '';
      var state = message.state || {};

      // Only push if URL is different from current
      if (window.location.search !== url) {
        history.pushState(state, '', url || window.location.pathname);
      }
    });

    // Handler for replacing current URL (no history entry)
    Shiny.addCustomMessageHandler('replaceUrl', function(message) {
      var url = message.url || '';
      var state = message.state || {};
      history.replaceState(state, '', url || window.location.pathname);
    });

    // Handler for going back in history
    Shiny.addCustomMessageHandler('historyBack', function(message) {
      history.back();
    });

    // Parse initial URL and send to Shiny
    var initialSearch = window.location.search;
    if (initialSearch) {
      Shiny.setInputValue('url_initial', {
        search: initialSearch,
        timestamp: Date.now()
      }, {priority: 'event'});
    }
  });

  // ==========================================================================
  // Copy URL Functions
  // ==========================================================================

  // Copy current URL to clipboard
  window.copyCurrentUrl = function() {
    navigator.clipboard.writeText(window.location.href).then(function() {
      // Notify Shiny that link was copied (for toast notification)
      if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
        Shiny.setInputValue('link_copied', Date.now(), {priority: 'event'});
      }
    }).catch(function(err) {
      console.error('Failed to copy URL:', err);
      // Fallback: select and copy
      var textArea = document.createElement('textarea');
      textArea.value = window.location.href;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);

      if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
        Shiny.setInputValue('link_copied', Date.now(), {priority: 'event'});
      }
    });
  };

  // Copy a specific URL to clipboard
  window.copyUrl = function(url) {
    navigator.clipboard.writeText(url).then(function() {
      if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
        Shiny.setInputValue('link_copied', Date.now(), {priority: 'event'});
      }
    }).catch(function(err) {
      console.error('Failed to copy URL:', err);
    });
  };

  // ==========================================================================
  // URL Building Helpers
  // ==========================================================================

  // Build a URL with query parameters
  window.buildUrl = function(params) {
    var search = Object.keys(params)
      .filter(function(key) { return params[key] !== null && params[key] !== undefined; })
      .map(function(key) { return encodeURIComponent(key) + '=' + encodeURIComponent(params[key]); })
      .join('&');

    return search ? '?' + search : '';
  };

  // Parse query string into object
  window.parseQueryString = function(search) {
    if (!search) return {};
    search = search.replace(/^\?/, '');

    var params = {};
    search.split('&').forEach(function(pair) {
      var parts = pair.split('=');
      if (parts.length === 2) {
        params[decodeURIComponent(parts[0])] = decodeURIComponent(parts[1]);
      }
    });

    return params;
  };

})();
