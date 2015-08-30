var file = "http://cpee.org/~demo/orgviz/organisation_informatik.xml";                                     var xpath = "/o:organisation/o:units/o:unit|/o:organisation/o:roles/o:role";
var subjects = "/o:organisation/o:subjects/o:subject";
var nopts = null;
var nodes2 = [];
var pp = []

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
}

var GraphWorker = function(file,xpath,subjects,nopts){
  this.nodes = [];

  this.nsResolver = function(prefix) {
    return prefix == 'o' ? "http://cpee.org/ns/organisation/1.0" : null ;
  }

  this.processData = function(data) {
    var evalue = data.evaluate('/o:organisation/o:units/o:unit|/o:organisation/o:roles/o:role',
                               data,
                               nsResolver,
                               XPathResult.ORDERED_NODE_ITERATOR_TYPE,
                               null);
    var node = evalue.iterateNext();
    for(; node && !node.invalidIteratorState; ) {
        var type = node.prefix ? node.prefix + ":" : "" + node.localName
        var id = node.id
        var curr = new Node(id, type, nopts);
        var numsubjects = data.evaluate('count(' + subjects.replace(/\/*$/,'') + '[o:relation[@' + type + '="' + id + '"]])',
                                        data,
                                        nsResolver,
                                        XPathResult.NUMBER_TYPE,
                                        null);
        curr.numsubjects = numsubjects.numberValue;
        nodes.push(curr);
        nodes2.push(node);
        var parser = new DOMParser();
        var xmlNode = parser.parseFromString(node.outerHTML, "text/xml");
        var parentsIterator = xmlNode.evaluate( "//o:parent",
                                                xmlNode,
                                                nsResolver,
                                                XPathResult.ORDERED_NODE_ITERATOR_TYPE,
                                                null);
        var pidIterator = xmlNode.evaluate( '../*[@id="' + id + '"]',
                                            xmlNode,
                                            nsResolver,
                                            XPathResult.ORDERED_NODE_ITERATOR_TYPE,
                                            null);
        var parents = parentsIterator.iterateNext();
        
        for(; parents && !parents.invalidIteratorState; ) {
          console.log(parents);
          pp.push(parents);
          parents = parentsIterator.iterateNext();
        }


        node = evalue.iterateNext()
    }
    console.log(pp);
    console.log(nodes2);
  }
  
  var client = new XMLHttpRequest();
  client.onload = function() {
    if(this.status == 200 )
    {
      //console.log(this.responseXML);
      processData(this.responseXML);
    } else {
      console.log(this)
    }
  };
  client.open("GET", file, true);
  client.send(null);
}

GraphWorker(file,xpath,subjects,nopts);
