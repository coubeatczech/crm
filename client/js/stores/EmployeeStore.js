var AppDispatcher = require('../dispatcher/AppDispatcher');
var EventEmitter = require('events').EventEmitter;
var merge = require('react/lib/merge');
var CompanyConstants = require('../constants/CompanyConstants');
var _ = require("underscore");

var CHANGE_EVENT = "change";

var employees = {};

var EmployeeStore = merge(EventEmitter.prototype, {

  get: function(id) {
    return (
      (id === undefined) ?
      employees :
      employees[id]
    );
  },

  emitChange: function() {
    this.emit(CHANGE_EVENT);
  },

  /**
   * @param {function} callback
   */
  addChangeListener: function(callback) {
    this.on(CHANGE_EVENT, callback);
  },

  /**
   * @param {function} callback
   */
  removeChangeListener: function(callback) {
    this.removeListener(CHANGE_EVENT, callback);
  }
});

EmployeeStore.dispatchToken = AppDispatcher.register(function(payload) {
  var action = payload.action;

  switch(action.type) {

    case CompanyConstants.SERVER_INITIAL_EMPLOYEES:
      employees = action.employees;
    break;

    default:
      return true;
  }

  EmployeeStore.emitChange();
  return true; // No errors.  Needed by promise in Dispatcher.

});


module.exports = EmployeeStore;
