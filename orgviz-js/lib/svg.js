var SVG = Class.create({
  initialize: function(){
    this.res = '';
    this.defs = '';
  },
  add_group: function(nid, block, options){
    options = (typeof options === "undefined") ? {} : options;
    var opts = "";
    for (var i in options) {
          opts += i + "=\"" + options[i] + "\" ";
    }
    this.res += "<g id='" + nid + "'" + (opts == "") ? "" : " " + opts + ">\n";
    TODO yield!!
    this.refs += "</g>\n";
  },
  add_path: function(d,options){
    options = (typeof options === "undefined") ? {} : options;
    var opts = "";
    for (var i in options) {
          if(options.hasOwnProperty(i)) opts += i + "=\"" + options[i] + "\" ";
    }
    this.res += "  <path d='" + (typeof d === "object" ? d.join(" ") : d) + "'" + (opts == "" ? "" : " " + opts) + "/>\n";
  },
  add_circle: function(cx, cy, radius, cls){
    cls = (typeof cls === "undefined") ? '' : cls;
    this.res += "  <circle class='" +cls+ "' cx=\"" +cx+ "\" cy=\"" +cy+"\" r=\""+ radius+ "\"/>\n";
  },
  add_rectangle: function(lx,ly,opacity,lwidth,lheight, cls){
    cls = (typeof cls === "undefined") ? '' : cls;
    this.res += "  <rect class='" +cls+ "' fill-opacity='" +opacity+ "' x=\"" +lx+ "\" y=\"" +ly+ "\" width=\"" +lwidth+ "\" height=\"" +lheight+ "\"/>\n";
  },
  add_radialGradient: function(id, cls1, cls2){
    cls1 = (typeof cls1 === "undefined") ? '' : cls1;
    cls2 = (typeof cls2 === "undefined") ? '' : cls2;
    this.defs += "  <radialGradient id=\""+id+"\" cx=\"50%\" cy=\"50%\" r=\"70%\" fx=\"70%\" fy=\"30%\">\n    <stop offset=\"0%\" stop-color=\""+cls1+"\" stop-opacity=\"1\"/>\n    <stop offset=\"100%\" stop-color=\""+cls2+"\" stop-opacity=\"1\"/>\n  </radialGradient>\n"
  },
  add_text: function(x, y, options) {
    options = (typeof options === "undefined") ? {} : options;
    options["cls"] = (typeof options["cls"] === "undefined") ? '' : options["cls"];
    options["transform"] = (typeof options["transform"] === "undefined") ? '' : options["transform"];
    this.res += "  <text x='"+x+"' y='"+y+"'"+ 
                ((typeof options["cls"] === "undefined") ? '' : " class='"+options["cls"]+"'") +
                ((typeof options["transform"] === "undefined") ? '' : " transform='"+options["transform"]+"'") +
                ((typeof options["id"] === "undefined") ? '' : " id='"+options["id"]+"'") +
                ">";
    TODO yield
    this.res += "</text>\n";
  },
  add_tspan: function(options){
    options = (typeof options === "undefined") ? {} : options;
    this.res += "  <tspan x='"+x+"' y='"+y+"'"+ 
                ((typeof options["transform"] === "undefined") ? '' : " transform='"+options["transform"]+"'") +
                ((typeof options["cls"] === "undefined") ? '' : " class='"+options["cls"]+"'") +
                ((typeof options["dx"] === "undefined") ? '' : " dx='"+options["dx"]+"'") +
                ((typeof options["dy"] === "undefined") ? '' : " dy='"+options["dy"]+"'") +
                ((typeof options["x"] === "undefined") ? '' : " x='"+options["x"]+"'") +
                ((typeof options["y"] === "undefined") ? '' : " y='"+options["y"]+"'") +
                ">";
    TODO yield
    this.res += "</tspan>\n";
    return '';
  },
  add_orbit: function(center_x, center_y, angle1, angle2, radius, oradius, options) {
    var x1 = circle_point(center_x, center_y, radius, angle1);
    var y1 = circle_point(center_x, center_y, radius, angle1);
    var x2 = circle_point(center_x, center_y, radius, angle2);
    var y2 = circle_point(center_x, center_y, radius, angle2);

    var bogerl = 10;
    var sect = (bogerl / (2.0 * (radius+oradius) * Math.PI)) * 360;

    var ovx1 = circle_point(center_x,center_y,radius+oradius-bogerl,angle1);
    var ovy1 = circle_point(center_x,center_y,radius+oradius-bogerl,angle1);
    var obx1 = center_x + Math.cos(degrees_to_rad(angle1 - sect)) * (radius+oradius);
    var oby1 = center_y - Math.sin(degrees_to_rad(angle1 - sect)) * (radius+oradius);

    var ovx2 = circle_point(center_x,center_y,radius+oradius-bogerl,angle2);
    var ovy2 = circle_point(center_x,center_y,radius+oradius-bogerl,angle2);
    var obx2 = center_x + Math.cos(degrees_to_rad(angle2 + sect)) * (radius+oradius);
    var oby2 = center_y - Math.sin(degrees_to_rad(angle2 + sect)) * (radius+oradius);

    var path = '';
    if(angle1 - angle2 > 180){
      path = "M "+x1+" "+y1+" L "+ovx1+" "+ovy1+" A "+bogerl+" "+bogerl+" 0 0 1 "+obx1+" "+oby1+" A "+radius+oradius+" "+radius+oradius+" 0 1 1 "+obx2+" "+oby2+" A "+bogerl+" "+bogerl+" 0 0 1 "+ovx2+" "+ovy2+" L "+x2+" "+y2;
    } 
    else{
      path = "M "+x1+" "+y1+" L "+ovx1+" "+ovy1+" A "+bogerl+" "+bogerl+" 0 0 1 "+obx1+" "+oby1+" A "+radius+oradius+" "+radius+oradius+" 0 0 1 "+obx2+" "+oby2+" A "+bogerl+" "+bogerl+" 0 0 1 "+ovx2+" "+ovy2+" L "+x2+" "+y2;
    }
    add_path(path, options);
  },
  add_rectorbit: function(x1,y1,x2,y2,b,height,position,bogerl,options){
    if(position == "left"){
      add_path("M "+x1+" "+y1+(height/2)+" h -"+b+" a "+bogerl+" "+bogerl+" 0 0 1 -"+bogerl+" -"+bogerl+" V "+(y2+(height/2))+bogerl+" a "+bogerl+" "+bogerl+" 0 0 1 "+bogerl+"  -"+bogerl+" h "+b+" ",options);
    }
    else if(position == "right") {
      add_path("M "+x1+" "+y1+(height/2)+" h "+b+"  a "+bogerl+" "+bogerl+" 0 0 0 "+bogerl+"  -"+bogerl+" V "+(y2+(height/2))+bogerl+" a "+bogerl+" "+bogerl+" 0 0 0 -"+bogerl+" -"+bogerl+" h -"+b+" ",options);
    }
  },
  add_subject: function(x,y,number,clsbody,clsnumber,clsnumbernormal,clsnumberspecial){
    var subjectheadradius = 3;
    add_subject_icon(x,y-subjectheadradius,clsbody,subjectheadradius);
    //TODO yield & variablen!!
    add_text(x, y+10,:cls => clsbody + ' ' + clsnumber) do                                                           
      add_tspan(:x => x,:y => y+10,:cls => clsnumbernormal) { number }
      add_tspan(:x => x,:y => y+10,:cls => clsnumberspecial) { '' }
    end
  },
  add_subject_icon: function(x,y,cls,headradius){
    var scale = headradius / 3;
    var bogerl = (11 + headradius) * scale;
    y += headradius;
    add_path("M "+x+" "+y+" L "+x+5*scale+" "+y+11*scale+" A "+bogerl+" "+bogerl+" 0 0 1 "+x-5*scale+" "+y+11*scale+" z", {class : cls});
    add_circle(x,y,headradius,cls);
    return [x+5*scale,y+bogerl];
  },
  //TODO self methoden
});
