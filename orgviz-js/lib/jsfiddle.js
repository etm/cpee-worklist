var file = "http://cpee.org/~demo/orgviz/organisation_informatik.xml";                                     var xpath 
var subjectsin = "/o:organisation/o:subjects/o:subject";
var nopts = null;
var nodes2 = [];
if (!Array.prototype.last){
  Array.prototype.last = function(){
    return this[this.length - 1];
  };
};

function objectEquals(x, y) {
    'use strict';

    if (x === null || x === undefined || y === null || y === undefined) { return x === y; }
    // after this just checking type of one would be enough
    if (x.constructor !== y.constructor) { return false; }
    // if they are functions, they should exactly refer to same one (because of closures)
    if (x instanceof Function) { return x === y; }
    // if they are regexps, they should exactly refer to same one (it is hard to better equality check on current ES)
    if (x instanceof RegExp) { return x === y; }
    if (x === y || x.valueOf() === y.valueOf()) { return true; }
    if (Array.isArray(x) && x.length !== y.length) { return false; }

    // if they are dates, they must had equal valueOf
    if (x instanceof Date) { return false; }

    // if they are strictly equal, they both need to be object at least
    if (!(x instanceof Object)) { return false; }
    if (!(y instanceof Object)) { return false; }

    // recursive object equality check
    var p = Object.keys(x);
    return Object.keys(y).every(function (i) { return p.indexOf(i) !== -1; }) &&
        p.every(function (i) { return objectEquals(x[i], y[i]); });
};

var Node = function(id,type,opts) {                                                                                  
    this.type     = type;
    this.id       = id;
    this.rank     = 0;
    this.parents  = [];
    this.group    = 0;
    this.numsubjects = 0; 
    this.subjects = [];
    //this.twidth   = SVG.width_of(id);
    //this.theight  = SVG.height_of(id);
    //new instance variable for all elements of opts
    for (var i in opts) {
      if(opts.hasOwnProperty(i)) eval("this."+i+" = "+opts[i]+";");
    }
};

var Subject = function(shortid){                                                                                     
  this.shortid    = shortid;
  Subject.counter += 1;
  this.id         = "s"+Subject.counter;
  this.relations  = [];
};      
        
Subject.counter = 0; 

var Relation = function(unit, role){                                                                                 
    this.unit = unit;
    this.role = role;
};

function onlyUnique(value, index, self) { 
    return self.indexOf(value) === index;
}

var GraphWorker = function(file,xpath,subjects,nopts){
  this.nodes = [];
  this.subjects = [];
  this.maxsubjects = 0;
  this.paths = [];

  this.nsResolver = function(prefix) {
    return prefix == 'o' ? "http://cpee.org/ns/organisation/1.0" : null ;
  };

  this.processData = function(data) {
    var evalue = data.evaluate('/o:organisation/o:units/o:unit|/o:organisation/o:roles/o:role',
                               data,
                               nsResolver,
                               XPathResult.ORDERED_NODE_ITERATOR_TYPE,
                               null);
    var node = evalue.iterateNext();
    for(; node && !evalue.invalidIteratorState; ) {
        var type = node.localName;
        var id = node.id;
        var curr = new Node(id, type, nopts);
        var numsubjects = data.evaluate('count(' + subjects.replace(/\/*$/,'') + '[o:relation[@' + type +
                                         '="' + id + '"]])',
                                        data,
                                        nsResolver,
                                        XPathResult.NUMBER_TYPE,
                                        null);
        curr.numsubjects = numsubjects.numberValue;
        if(curr.numsubjects > this.maxsubjects) this.maxsubjects = curr.numsubjects;

        nodes2.push(node);
        for(var i = 0; i < node.childNodes.length; ++i) {
          var child = node.childNodes[i];
            if(child.nodeName == "parent") {
                var pa = child.textContent;
                //console.log(node.parentNode.childNodes.length);
                for(var j = 0; j < node.parentNode.childNodes.length; ++j) {
                    var pid = node.parentNode.childNodes[j];
                    if(pid.id == pa) {
                        curr.parents.push(pid);
                    }
                }
            }
        }
        nodes.push(curr);
        node = evalue.iterateNext();
    }

    var subjectIterator = data.evaluate(subjects.replace(/\/*$/,''),
                                        data,
                                        nsResolver,
                                        XPathResult.ORDERED_NODE_ITERATOR_TYPE,
                                        null);
    var subject = subjectIterator.iterateNext();
    for( ; subject && !subjectIterator.invalidIteratorState; ) {
      var s = new Subject(subject.id);
      for(var i = 0; i < subject.childNodes.length; ++i) {
        var child = subject.childNodes[i];
        if(child.nodeName == "relation") {
          var unit = nodes.filter(function(e) { return e.id == child.attributes["unit"].nodeValue });
          var role = nodes.filter(function(e) { return e.id == child.attributes["role"].nodeValue });
          unit.subjects = [];
          unit.subjects.push(s);
          unit = unit.filter( onlyUnique );
          role.subjects = [];
          role.subjects.push(s);
          role = role.filter( onlyUnique );
          if(unit && role ) {
            s.relations.push( new Relation(unit,role) );
          }
        }
      }
      this.subjects.push(s);
      subject = subjectIterator.iterateNext();
    }

    console.log(this.subjects);
    console.log(nodes);

    for(var node of nodes) {
      console.log(node);
      this.paths.push([node]);
      calculate_path(this.paths, this.paths.last());
    }
  };

  var calculate_path = function(paths, path) {
    var parents = path.last().parents
    console.log(paths, path);
    if(parents !== undefined && (parents.length == 0 || parents.length == 1) ) {
        console.log(parents[0]);
      if( parents[0] === undefined || path.includes(parents[0]) ) {
          return;
        }
        path.push(parents[0]);
        calculate_path(paths, path);
    } else {
        var tpath = $.extend( true, {}, path );
      for(var p of parents){
            if(tpath.includes(p)){
                continue;
            }
            if(objectEquals(p, parents[0])){
                path.push(p);
                calculate_path(paths, path);
            } else {
                paths.push( ($.extend(true, {}, tpath)).push(p) );
                calculate_path(paths, paths.last());
            }
        }
    }
  };

  var client = new XMLHttpRequest();
  client.onload = function() {
    if(this.status == 200 )
    {
      //console.log(this.responseXML);
      processData(this.responseXML);
    } else {
      console.log(this);
    }
  };
  client.open("GET", file, true);
  client.send(null);
};

GraphWorker(file,xpath,subjectsin,nopts);

