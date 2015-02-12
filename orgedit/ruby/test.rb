#!/usr/bin/ruby
### All code in this file is provided under the LGPL license. Please read the file COPYING.
require 'rubygems'
require 'pp'
require 'xml/smart'
require 'optparse'
require File.expand_path(File.dirname(__FILE__) + '/lib/utils')
require File.expand_path(File.dirname(__FILE__) + '/lib/node')
require File.expand_path(File.dirname(__FILE__) + '/lib/html')
require File.expand_path(File.dirname(__FILE__) + '/lib/svg')
require File.expand_path(File.dirname(__FILE__) + '/lib/worker')

### Commandline parsing # {{{
debug = false
ARGV.options { |opt|
  opt.summary_indent = ' ' * 2
  opt.banner = "Usage:\n#{opt.summary_indent}#{File.basename($0)} [options] [FILENAME]\n"
  opt.on("Options:")
  opt.on("--help", "-h", "This text") { puts opt; exit }
  opt.on("--verbose", "-v", "Verbose calculation of graph") { debug = true }
  opt.on("Example:\n#{opt.summary_indent}#{File.basename($0)} organisation.xml")
  opt.parse!
}
if ARGV.length == 0 || !File.exists?(ARGV[0])
  puts ARGV.options
  puts "File #{ARGV[0]} not found!"
  exit
end
fname = ARGV[0]
oname = fname.gsub(/\.xml$/,'.flower.html') # }}}

### GraphWorker
gw = GraphWorker.new(fname, "/o:organisation/o:units/o:unit|/o:organisation/o:roles/o:role", "/o:organisation/o:subjects/o:subject", :radius => 8, :angle => 0, :text_x => 0, :text_y => 0, :text_cls => nil, :shortid => '')
gw.rank_long!
pp gw

#### Umfang des Kreises, Position der Knoten
#textgap = 3
#circumference = 0
#maxnoderadius = 0
#maxtextwidth = 0
#maxradius = 25.0
#orbitgap = 5
#nodegap = 10
#lineheight = SVG::height_of('Text') + textgap
#xgap = 5
#ygap = 5
#maxwidth = 0
#maxheight = 0
#usergap = 10
#
#### calculate maximum unit and role size and thus the necessary circumference of the circle
#unodes = rnodes = 0
#gw.nodes.each do |n|
#  if n.type == :unit
#    unodes += 1
#    n.shortid = "u#{unodes}"
#  elsif n.type == :role
#    rnodes += 1
#    n.shortid = "r#{rnodes}"
#  end
#  if n.numsubjects > 0 && gw.maxsubjects > 0
#    n.radius = n.radius + n.numsubjects * (maxradius / gw.maxsubjects)
#  end
#  circumference += (n.radius * 2) + nodegap
#  maxnoderadius = n.radius if maxnoderadius < n.radius
#  maxtextwidth = n.twidth if maxtextwidth < n.twidth
#end
#radius = circumference / 2 / Math::PI
#
#### calculate angles for the units and roles
#asum = 0
#gw.nodes.each do |n|
#  nodediameter = n.radius * 2 + nodegap
#  half_share_of_circle = (360 * (nodediameter / (circumference / 100.0) / 100.0)) / 2
#  n.angle = asum + half_share_of_circle
#  asum = n.angle + half_share_of_circle
#end
#
#### calculate orbits and their maximum extent
#orbits = []; ucount = rcount = 2
#oid = 0
#gw.nodes.each do |n|
#  n.parents.each do |p|
#    a1, a2 = [n.angle, p.angle].sort{|a,b|b<=>a}
#    orb = (gw.nodes.index(p) > gw.nodes.index(n) ? gw.nodes.index(p) - gw.nodes.index(n) : gw.nodes.index(n) - gw.nodes.index(p))
#    oid = oid+1
#    orbits << [orb,a1,a2,n.type,nil,oid,p.shortid,n.shortid]
#  end
#end
#orbits = orbits.sort{|a,b|a[0]<=>b[0]}
#orbits.each do |o|
#  if o[0] == 1
#    o[4] = maxnoderadius+orbitgap
#  elsif o[0] > 1 && o[3] == :unit
#    o[4] = maxnoderadius+ucount*orbitgap
#    ucount += 1
#  elsif o[0] > 1 && o[3] == :role
#    o[4] = maxnoderadius+rcount*orbitgap
#    rcount += 1
#  end
#end
#
#### set default center according to maximum orbit
#center_x = radius + maxnoderadius + [ rcount * orbitgap, ucount * orbitgap ].max
#center_y = radius + maxnoderadius + [ rcount * orbitgap, ucount * orbitgap ].max
#
#### calculate all text positions 
#shiftx = shifty = 0
#gw.nodes.each do |n|
#  n.text_x,n.text_y = SVG::circle_point(center_x,center_y,radius + n.radius,n.angle)
#  if n.angle >= 0 && n.angle < 45
#    n.text_cls = 'right'; n.text_x += textgap; n.text_y += textgap
#  elsif n.angle >= 45 && n.angle < 90
#    n.text_cls = 'right'; n.text_x += textgap; n.text_y -= textgap
#  elsif n.angle >= 90 && n.angle < 135
#    n.text_cls = 'left'; n.text_x -= textgap; n.text_y -= textgap
#  elsif n.angle >= 135 && n.angle < 180
#    n.text_cls = 'left'; n.text_x -= textgap; n.text_y += textgap
#  elsif n.angle >= 180 && n.angle < 225
#    n.text_cls = 'left'; n.text_x -= textgap; n.text_y += n.theight / 2
#  elsif n.angle >= 225 && n.angle < 270
#    n.text_cls = 'left'; n.text_x -= textgap; n.text_y += n.theight 
#  elsif n.angle >= 270 && n.angle < 315
#    n.text_cls = 'right'; n.text_x += textgap; n.text_y += n.theight 
#  elsif n.angle >= 315 && n.angle < 360
#    n.text_cls = 'right'; n.text_x += textgap; n.text_y += n.theight / 2
#  end
#
#  ### shift center if text is not visible
#  if (n.text_x - n.twidth) < orbitgap && (orbitgap - (n.text_x - n.twidth)) > shiftx
#    shiftx = orbitgap - (n.text_x - n.twidth)
#  end
#  if (n.text_y - n.theight) < orbitgap && (orbitgap - (n.text_y - n.theight)) > shifty
#    shiftx = orbitgap - (n.text_y - n.theight)
#  end
#end
#
#### adjust text positions and center with necessary shift
#gw.nodes.each do |n|
#  n.text_x += shiftx
#  n.text_y += shifty
#  maxwidth = n.text_x + n.twidth if maxwidth < n.text_x + n.twidth
#end
#center_x += shiftx
#center_y += shifty
#
## for first and third quarter of the circle
#last_y        = center_y + lineheight
#last_y_height = lineheight
#gw.nodes.each do |n| #{{{
#  if n.angle >= 0 and n.angle < 90
#    if n.text_y > last_y - last_y_height - textgap
#      n.text_y = last_y - last_y_height - textgap
#    end
#  end  
#  if n.angle >= 180 and n.angle < 270
#    if n.text_y - n.theight - textgap < last_y
#      n.text_y = last_y + textgap
#    end  
#  end
#  last_y = n.text_y
#  last_y_height = n.theight
#end   #}}}
#
## for second and fourth quarter of the circle we have to do it in reverse to in order to ensure  last is correct
#last_y        = center_y - lineheight
#last_y_height = lineheight
#gw.nodes.reverse.each do |n| #{{{
#  if (n.angle >= 270 and n.angle < 360) or n.angle == 0
#    if n.text_y - n.theight - textgap < last_y
#      n.text_y = last_y + textgap
#    end  
#  end  
#  if n.angle >= 90 and n.angle < 180
#    if n.text_y > last_y - last_y_height - textgap
#      n.text_y = last_y - last_y_height - textgap
#    end
#  end
#  last_y = n.text_y
#  last_y_height = n.theight
#end   #}}}
#
#### Draw
#h = HTML.new('OrbitFlower')
#
#h.add_css '.unit', <<-end
#  fill: #729fcf;
#  stroke: #204a87;
#  stroke-width:1.5;
#  cursor: pointer;
#end
#h.add_css '.role', <<-end
#  fill: #ad7fa8;
#  stroke: #5c3566;
#  stroke-width:1.5;
#  cursor: pointer;
#end
#h.add_css '.subject', <<-end
#  cursor: pointer;
#end
#h.add_css 'text', <<-end
#  font-size:10px;
#  font-style:normal;
#  font-variant:normal;
#  font-weight:normal;
#  font-stretch:normal;
#  line-height:100%;
#  letter-spacing:0px;
#  word-spacing:0px;
#  writing-mode:lr-tb;
#  text-anchor:start;
#  fill:#000000;
#  fill-opacity:1;
#  stroke:none;
#  font-family:Arial;
#end
#h.add_css '.labeltext', <<-end
#  font-weight:normal;
#end
#h.add_css '.btext', <<-end
#  fill: #ffffff;
#  stroke: #ffffff;
#  stroke-width: 2.5;
#end
#h.add_css '.role circle.highlight, .unit circle.highlight', <<-end
#  stroke: #a40000;
#end
#h.add_css '.subject:hover .labeltext', <<-end
#  fill:#a40000;
#  color:#a40000;
#end
#h.add_css '.subject.highlightrole .labeltext', <<-end
#  color:#ad7fa8;
#end
#h.add_css '.subject.highlightunit .labeltext', <<-end
#  color:#729fcf;
#end
#h.add_css '.subject.highlightrole .subjecticon', <<-end
#  stroke:#ad7fa8;
#end
#h.add_css '.subject.highlightunit .subjecticon', <<-end
#  stroke:#729fcf;
#end
#h.add_css '.left', <<-end
#  text-align: end;
#  text-anchor: end
#end
#h.add_css '.right', <<-end
#  text-align: start;
#  text-anchor: start
#end
#h.add_css '.unit.connect', <<-end
#  fill:none;
#  stroke: #204a87;
#  stroke-width:1;
#end
#h.add_css '.role.connect', <<-end
#  fill:none;
#  stroke: #5c3566;
#  stroke-width:1;
#end
#h.add_css '.unit.connect.highlight', <<-end
#  stroke: #a40000;
#  stroke-opacity: 1;
#end
#h.add_css '.role.connect.highlight', <<-end
#  stroke: #a40000;
#  stroke-opacity: 1;
#end
#h.add_css '.connect.inactive', <<-end
#  stroke-opacity: 0.1;
#end
#h.add_css '.relation', <<-end
#  fill:none;
#  stroke: #777676;
#  stroke-width:1;
#end
#h.add_css '.relation.inactive', <<-end
#  stroke-opacity: 0.2;
#end
#h.add_css '.relation.role', <<-end
#  stroke-opacity: 1;
#  stroke: #5c3566;
#end
#h.add_css '.relation.unit', <<-end
#  stroke-opacity: 1;
#  stroke: #204a87;
#end
#h.add_css '.relation.highlight', <<-end
#  stroke-opacity: 1;
#  stroke: #a40000;
#end
#h.add_css '.subject .subjecticon', <<-end
#  fill:#ffffff;
#  stroke: #000000;
#  stroke-width:1;
#end
#h.add_css '.subjecticon.subjecthighlight', <<-end
#  stroke: #a40000;
#end
#h.add_css '.subjecticon.highlight', <<-end
#  stroke: #a40000;
#end
#h.add_css '.subjecticon.number', <<-end
#  font-size:7px;
#  font-style:normal;
#  font-variant:normal;
#  font-weight:normal;
#  font-stretch:normal;
#  line-height:100%;
#  letter-spacing:0px;
#  word-spacing:0px;
#  writing-mode:lr-tb;
#  text-anchor:start;
#  fill:#000000;
#  fill-opacity:1;
#  stroke:none;
#  font-family:Arial;
#end
#h.add_css '.subjecticon.number tspan', <<-end
#  text-anchor:middle;
#  text-align:center;
#end
#h.add_css '.subjecticon.number .inactive', <<-end
#  visibility:hidden;
#end
#h.add_css '.plainwhite', <<-end
#  fill: none;
#  stroke: #ffffff;
#  stroke-width:2.9;
#end
#h.add_css '.activefilter', <<-end
#  fill: #a40000;
#end
#
#s = SVG.new
#
#orbits.each do |o|
#  mx,my = SVG::circle_point(center_x,center_y,radius+o[4],0)
#  maxwidth = mx if maxwidth < mx
#
#  orbitid = 'o' + o[5].to_s
#  orbitrelation = 'f'+ o[6].to_s + ' t'+ o[7].to_s
#  s.add_orbit(center_x,center_y,o[1],o[2],radius,o[4], :class=> o[3].to_s + ' connect'+ ' ' + orbitrelation, :id => orbitid)
#  maxheight = my + radius + o[4] + 2 * orbitgap if maxheight < my + radius + o[4] + 2 * orbitgap 
#end
#
#subjectintensity = {}
#maxsubjectintensity = 0
#subjects = []
#gw.subjects.sort_by{|u| u.shortid}.each do |u|
#  subjects << h.add_tag('table', :id => u.id, :class=>'subject', :onmouseover=>'s_relationstoggle(this)', :onmouseout=>'s_relationstoggle(this)') do
#    h.add_tag 'tbody' do
#      h.add_tag 'tr' do
#        h.add_tag 'td' do
#          subjectheadradius = 2.0
#          si = SVG.new
#          si.add_subject_icon(4,1,'subjecticon',subjectheadradius)
#          si.dump(8,12)
#        end
#        h.add_tag 'td', :class => 'labeltext' do
#          u.shortid
#        end
#      end  
#    end  
#  end
#
#  u.relations.each do |r|
#    x1,y1 = SVG::circle_point(center_x,center_y,radius,r.unit.angle)
#    x2,y2 = SVG::circle_point(center_x,center_y,radius,r.role.angle)
#    subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"] ||= [0,[r.unit.shortid,r.role.shortid],x1,y1,x2,y2]
#    subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"][0] += 1
#    subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"][1] << u.id
#    maxsubjectintensity = subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"][0] if subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"][0] > maxsubjectintensity
#  end
#end
#subjectintensity.each do |key,ui|
#  opacity = 2.9 / maxsubjectintensity * ui[0] + 0.5
#  s.add_path("M #{ui[2]} #{ui[3]} Q #{center_x} #{center_y} #{ui[4]} #{ui[5]}", :class => "relation #{ui[1].join(' ')}")
#  h.add_css ".relation.#{ui[1].join('.')}", <<-end
#    stroke-width: #{opacity};
#  end
#  ### insert this late to overide the dynamically created classes for the relations
#  h.add_css ".relation.highlight.#{ui[1].join('.')}", <<-end
#    stroke-opacity:1;
#    stroke-width:1;
#    stroke: #a40000;
#  end
#end
#
#gw.nodes.each do |n|
#  x,y = SVG::circle_point(center_x,center_y,radius,n.angle)
#
#  s.add_group(n.shortid,:class=>n.type,:onmouseover=>'ur_relationstoggle(this)',:onmouseout=>'ur_relationstoggle(this)',:onclick=>'ur_filtertoggle(this)') do
#    s.add_circle x, y, n.radius, n.type
#    s.add_text(x, y, :cls => 'subjecticon' + ' ' + 'number') do
#      maxheight = y + n.theight * 0.2 if maxheight < y + n.theight * 0.2
#      s.add_tspan(:x => x, :y => y + n.theight * 0.2, :cls => 'normal') { n.numsubjects }
#      s.add_tspan(:x => x,:y => y + n.theight * 0.2,:cls => 'special inactive') { '' }
#    end  
#  end
#  s.add_text n.text_x, n.text_y, :cls => n.text_cls + ' btext' do
#    n.id
#  end
#  s.add_text n.text_x, n.text_y, :cls => n.text_cls + ' labeltext', :id => n.shortid + '_text' do
#    n.id
#  end
#  maxheight = n.text_y if maxheight < n.text_y
#  maxheight = y + n.radius if maxheight < y + n.radius
#end
#
#c = h.add_tag 'div', :class => "tabbed rest" do
#  h.add_tag 'table', :class => "tabbar" do
#    h.add_tag 'tbody' do
#      h.add_tag 'tr' do
#        h.add_tag 'td', :class => 'tabbefore'
#        h.add_tag 'td', :class => 'tab', :id => 'tabgraph' do
#          h.add_tag('h1'){ 'OrbitFlower' }
#        end
#        h.add_tag 'td', :class => 'tabbehind'
#      end
#    end
#  end
#  h.add_tag 'table', :class => "tabbelow columns" do
#    h.add_tag 'tbody' do
#      h.add_tag 'tr' do
#        h.add_tag 'td', :id => 'graphcolumn' do
#          h.add_tag 'div', :class => 'column' do
#            s.dump(maxwidth,maxheight)
#          end
#        end
#        h.add_tag 'td', :id => 'usercolumn', :class => 'ui-resizable' do
#          h.add_tag 'span', :id => "handle2", :class => "ui-resizable-handle ui-resizable-w" do
#            "drag to resize"
#          end
#          h.add_tag 'div', :class => 'column' do
#            subjects.join("\n");
#          end
#        end
#      end
#    end
#  end
#end  
#
#h.add c
#File.open(oname,'w'){|f|f.write h.dump}
