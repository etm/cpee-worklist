var orgfile = "https://raph.cs.univie.ac.at/organisation.xml";

var GraphWorker = Class.create({
  initialize: function(file,xpath,subjects,nopts) {
    this.nodes = [];

    var schema = XMLHttpRequest();
    
    
    // validate Schema!!
     
