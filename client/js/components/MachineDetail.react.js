/**
 * @jsx React.DOM
 */
var React = require('react');

var B = require("react-bootstrap");
var Grid = B.Grid;
var Col = B.Col;
var Row = B.Row;
var Input = B.Input;
var Button = B.Button;

var LinkedStateMixin = require("react/lib/LinkedStateMixin");
var _ = require("underscore");

var CalendarField = require("./calendar/CalendarField.react");

var $ = require("jquery");
window.jQuery = $;
var ui = require("../../bower_components/jquery-ui/jquery-ui");
var jasny = require("../../bower_components/jasny-bootstrap/dist/js/jasny-bootstrap");

var CalendarPopover = require("./calendar/CalendarPopover.react");

var MachineDetail = React.createClass({

  mixins: [LinkedStateMixin]

  , statics: {
    serviceIntervalRow: function(key, label) {
      return (
        <Row className="form-group" key={key}>
          <Col md={2} className="control-label">
            <label>{label}</label>
          </Col>
          <Col md={2} className="control-label">
            <label>mth:</label>
          </Col>
          <Col md={3}>
            <input type="text" className="form-control" />
          </Col>
          <Col md={2} className="control-label">
            <label>měsíce:</label>
          </Col>
          <Col md={3}>
            <input type="text" className="form-control" />
          </Col>
        </Row>
      );
    }
  }

  , getInitialState: function() {
    return {
      "type": ""
    };
  }

  , componentDidMount: function() {
    $("#machine-type").autocomplete({
      source: [
        "ActionScript",
        "AppleScript",
        "Asp",
        "BASIC",
        "C",
        "C++",
        "Clojure",
        "COBOL",
        "ColdFusion",
        "Erlang",
        "Fortran",
        "Groovy",
        "Haskell",
        "Java",
        "JavaScript",
        "Lisp",
        "Perl",
        "PHP",
        "Python",
        "Ruby",
        "Scala",
        "Scheme"
      ]
    });
  }

  , setMachineStartDate: function(accuracy, date) {
  }

  , render: function() {

    var serviceIntervals = _.map(["Úvodní", "Pravidelný", "Generální"], function(label, key) {
      return MachineDetail.serviceIntervalRow("key-" + key, label);
    });

    return(
      <Grid>
        <Row>
          <Col mdOffset={3} md={6}>
            <form className="form-horizontal relative">
              <Row>
                <Col mdOffset={2} md={10}>
                  <h1>Nové zařízení</h1>
                </Col>
              </Row>
              <Row>
                <Col mdOffset={2} md={10}>
                  <h2>Údaje od výrobce</h2>
                </Col>
              </Row>
              <Input id="machine-type" type="text" label="Typ" valueLink={this.linkState("type")}
                labelClassName="col-md-2" wrapperClassName="col-md-10" groupClassName="row" />
              <Input id="machine-manufacturer" type="text" label="Výrobce" valueLink={this.linkState("manufacturer")}
                labelClassName="col-md-2" wrapperClassName="col-md-10" groupClassName="row" />
              <Row className="form-group">
                <Col md={10} mdOffset={2}>
                  <h4>Intervaly servisů</h4>
                </Col>
              </Row>
              {serviceIntervals}
              <Row>
                <Col mdOffset={2} md={10}>
                  <h2>Specifické informace</h2>
                </Col>
              </Row>
              <Row className="form-group">
                <Col md={2} className="control-label">
                  <label>Úv. stav</label>
                </Col>
                <Col md={1} className="control-label">
                  <label>mth:</label>
                </Col>
                <Col md={3}>
                  <input type="text" className="form-control" />
                </Col>
                <Col md={1} className="control-label">
                  <label>dne:</label>
                </Col>
                <Col md={5}>
                  <CalendarField
                    setValue={this.setMachineStartDate}
                    allowMonth={true}
                    yearPrevNext={true}
                  />
                </Col>
              </Row>
              <Input type="text" label="Výr. čislo" valueLink={this.linkState("serialNumber")}
                labelClassName="col-md-2" wrapperClassName="col-md-10" groupClassName="row" />
              <Row className="form-group">
                <Col md={2} className="control-label">
                  <label>Fotky</label>
                </Col>
                <Col md={10}>
                  <div className="fileinput fileinput-new" data-provides="fileinput">
                    <div className="fileinput-preview thumbnail" data-trigger="fileinput" style={{width: "200px", height: "150px;"}}></div>
                    <div>
                      <span className="btn btn-default btn-file">
                        <span className="fileinput-new">Select image</span>
                        <span className="fileinput-exists">Change</span>
                        <input type="file" name="..." />
                      </span>
                      <a href="#" className="btn btn-default fileinput-exists" data-dismiss="fileinput">Remove</a>
                    </div>
                  </div>
                </Col>
              </Row>
              <Input type="text" label="Označení" valueLink={this.linkState("mark")}
                help="Označení stroje v rámci firmy aby se poznaly 2 stejného typu"
                labelClassName="col-md-2" wrapperClassName="col-md-10" groupClassName="row" />
              <Row className="form-group">
                <Col mdOffset={2} md={10}>
                  <Button bsStyle="primary">Zadej zařízení do systému</Button>
                </Col>
              </Row>
            </form>
          </Col>
        </Row>
      </Grid>
    );
  }

  , changeTypeText: function(event) {
    var value = event.target.value;
  }

});

module.exports = MachineDetail;