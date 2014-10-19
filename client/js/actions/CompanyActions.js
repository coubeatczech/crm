/*
 * CompanyActions
 */

var AppDispatcher = require('../dispatcher/AppDispatcher');
var CompanyConstants = require('../constants/CompanyConstants');
var CompanyStore = require('../stores/CompanyStore');
var $ = require("jquery");

var CompanyActions = {
  createCompany: function(company) {
    var companyAsJSON = JSON.stringify(company);
    $.ajax({
      data: companyAsJSON
      , contentType: "application/json"
      , type: "POST"
      , url: "/api/companies/new"
      , success: function(data) {
        var dataAsJSObject = JSON.parse(data);
        var createdCompany = {};
        var serverGeneratedId = dataAsJSObject["id"];
        createdCompany[serverGeneratedId] = company;
        AppDispatcher.handleServerAction({
          type: CompanyConstants.SERVER_CREATED_COMPANY
          , company: createdCompany
        });
      }
      , error: function(error) {
        var status = error.status;
        if (409 === status) {
          AppDispatcher.handleServerAction({
            type: CompanyConstants.SERVER_CREATE_COMPANY_FAIL
            , companyNameError: "Takové jméno firmy již existuje"
          })
        }
      }
    });
  } ,
  checkNameAvailability: function(enteredName) {
    var encodedName = encodeURIComponent(enteredName);
    $.ajax({
      url: "/api/companies/" + encodedName + "/availability"
      , success: function(data) {
        var response = JSON.parse(data);
        AppDispatcher.handleServerAction({
          type: CompanyConstants.CHECK_AVAILABILITY
          , companyNameAvailability: response
        });
      }
    });
  }
};

// initial fetch of all companies
$.ajax({
  url: "/api/companies"
  , success: function(data) {
    var companies = JSON.parse(data);
    AppDispatcher.handleServerAction({
      type: CompanyConstants.SERVER_INITIAL_COMPANIES
      , companies: companies
    })
  }
})

module.exports = CompanyActions;
