(function($, window) {
  function ServerAutoSave(form) {
    this.form = form;

    this.projectId = form.dataset.asProjectId;
    this.resourceType = form.dataset.asResourceType;
    this.resourceId = form.dataset.asResourceId;
    this._doneTypingInterval = 500;
    this._autoSaveTimedInterval = 60000;

    this.init();
  }

  ServerAutoSave.prototype = {
    init: function() {
      var that = this;
      this.editorChannel = window.App.cable.subscriptions.create({
        channel: 'EditorChannel',
        project_id: this.projectId,
        resource_id: this.resourceId,
        resource_type: this.resourceType
      },{
        connected: function() {
          console.log('Subscribed to EditorChannel');
        },
        rejected: function() {
          console.log('Error subscribing to EditorChannel');
        },
        save: function() {
          this.perform('save', { data: $(that.form).serialize() });
        }
      })

      this.behaviors();
    },
    behaviors: function() {
      // When we navigate away form the page tidy up the channel
      document.addEventListener('turbolinks:before-cache', this.cleanup.bind(this))

      // we're using a jQuery plugin for :textchange event, so need to use $()
      $(this.form).on('textchange', this._changeTimeout.bind(this));

      // A save every 60 seconds?
      // this._saveInterval = setInterval(this._changeTimeout.bind(this), this._autoSaveTimedInterval);
    },
    cleanup: function() {
      clearInterval(this._saveInterval); // Clear out the save timer
      this.editorChannel.save(); // Save the results once more

      document.removeEventListener('turbolinks:before-cache', this.cleanup)
      this.form.removeEventListener('textchange', this._changeTimeout)

      this.editorChannel.unsubscribe(); // Unsubscribe from the channel
      window.App.cable.subscriptions.remove(this.editorChannel); // Clean up the subscriptions
    },
    _changeTimeout: function() {
      clearTimeout(this._typingTimer);
      this._typingTimer = setTimeout(function() {
        this.editorChannel.save();
      }.bind(this), this._doneTypingInterval);
    }
  }

  window.ServerAutoSave = ServerAutoSave;
})(jQuery, window);
