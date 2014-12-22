var fangx = 0, 
    fangy = 0,
    schrittx= 800, 
    schritty=-300;

function Weg () {
  var snd = new Audio("teleportation.ogg"); // buffers automatically when created
  snd.play();
  console.log(fangx);
  fangx = fangx + schrittx; 
  fangy = fangy +schritty;
  if ((fangx > 250) || (fangx < 50)) schrittx = -schrittx;
  if ((fangy < -200) || (fangy > 50)) schritty = -schritty;
  Positionieren ("goku", fangx, fangy);
}

function Positionieren (id, xwert, ywert) {
  if (document.documentElement) {
      document.getElementById(id).style.bottom  = ywert + "px";
      document.getElementById(id).style.left = xwert + "px";
      }
  else if (document.layers)  {
      document.layers[id].top  = ywert;
      document.layers[id].left = xwert;
      }
  else if (document.all) {
      document.all[id].style.pixelTop = ywert;
      document.all[id].style.pixelLeft = xwert;
      }
}

/*HTML-Tag zum Einfügen
<div id="goku" style="position:relative;" onMouseOver="Weg()">
<img src="goku.png" alt="goku">
</div>
*/
