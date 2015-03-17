url = "http://cpee.org/~demo/orgviz/organisation.xml"

xmlhttp=new XMLHttpRequest();
xmlhttp.open("GET",url,false);
xmlhttp.send();
xmlDoc=xmlhttp.responseXML;

function height_of_text(){
  var span = document.createElement("span");
  var text = document.createTextNode("Test");
  span.appendChild(text);
  span.style.display = "hidden";
  span.id = "textheight";
  document.body.appendChild(span);

}


### Umfang des Kreises, Position der Knoten
textgap = 3
circumference = 0
maxnoderadius = 0
maxtextwidth = 0
maxradius = 25.0
orbitgap = 5
nodegap = 10
lineheight = SVG::height_of('Text') + textgap
xgap = 5
ygap = 5
maxwidth = 0
maxheight = 0
usergap = 10


