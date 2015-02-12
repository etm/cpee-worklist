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
oname = fname.gsub(/\.xml$/,'.list.html') # }}}

### GraphWorker
gw = GraphWorker.new(fname, "/o:organisation/o:units/o:unit|/o:organisation/o:roles/o:role", "/o:organisation/o:subjects/o:subject", :opacity => 1.0, :y =>0, :x =>0, :shortid => '')
gw.rank_long!
puts gw.debug if debug

### Rechteckbreite, x breite, y positionen
textgap = 3
bogerl  = 10
posx    = {}
xgap    = 5
ygap    = 5
unity   = ygap
roley   = ygap
connectgap = 0
usergap = 20
lineheight   = SVG::height_of('Text') + textgap
maxtextunitwidth = 0
maxtextrolewidth = 0
subjectsymbolwidth = 5
maxwidth = 0
maxheight = 0

unodes = rnodes = 0
gw.nodes.each do |n|
  if n.type == :unit
    unodes += 1
    n.y = unity
    unity += lineheight + ygap
    n.shortid = "u#{unodes}"
  elsif n.type == :role
    rnodes += 1
    n.y = roley
    roley += lineheight + ygap
    n.shortid = "r#{rnodes}"
  end
  maxtextunitwidth = n.twidth if n.type == :unit && maxtextunitwidth < n.twidth
  maxtextrolewidth = n.twidth if n.type == :role && maxtextrolewidth < n.twidth
  if n.numsubjects > 0 && gw.maxsubjects > 0
    n.opacity = n.numsubjects * (n.opacity / gw.maxsubjects)
  else  
    n.opacity = 0
  end
end
connectgap   = (unodes + rnodes)*5
maxtextunitwidth += 2 * textgap + subjectsymbolwidth
maxtextrolewidth += 2 * textgap + subjectsymbolwidth

### Zeichnen
h = HTML.new('OrbitList')

h.add_css '.unit', <<-end
  fill: #729fcf;
  stroke: #204a87;
  stroke-width:1.5;
  cursor: pointer;
end
h.add_css '.role', <<-end
  fill: #ad7fa8;
  stroke: #5c3566;
  stroke-width:1.5;
  cursor: pointer;
end
h.add_css '.subject', <<-end
  cursor: pointer;
end
h.add_css 'text', <<-end
  font-size:10px;
  font-style:normal;
  font-variant:normal;
  font-weight:normal;
  font-stretch:normal;
  line-height:100%;
  letter-spacing:0px;
  word-spacing:0px;
  writing-mode:lr-tb;
  text-anchor:start;
  fill:#000000;
  fill-opacity:1;
  stroke:none;
  font-family:Arial;
end
h.add_css '.labeltext', <<-end
  font-weight:normal;
end
h.add_css '.btext', <<-end
  fill: #ffffff;
  stroke: #ffffff;
  font-weight:normal;
  stroke-opacity: 1;
  stroke-width: 1.5;
end
h.add_css '.role rect.highlight, .unit rect.highlight', <<-end
  stroke: #a40000;
end
h.add_css '.subject:hover .labeltext', <<-end
  fill:#a40000;
  color:#a40000;
end
h.add_css '.subject.highlightrole .labeltext', <<-end
  color:#ad7fa8;
end
h.add_css '.subject.highlightunit .labeltext', <<-end
  color:#729fcf;
end
h.add_css '.subject.highlightrole .subjecticon', <<-end
  stroke:#ad7fa8;
end
h.add_css '.subject.highlightunit .subjecticon', <<-end
  stroke:#729fcf;
end
h.add_css '.unit.connect', <<-end
  fill:none;
  stroke: #204a87;
  stroke-width:1;
end
h.add_css '.role.connect', <<-end
  fill:none;
  stroke: #5c3566;
  stroke-width:1;
end
h.add_css '.unit.connect.highlight', <<-end
  stroke: #a40000;
  stroke-opacity: 1;
end
h.add_css '.role.connect.highlight', <<-end
  stroke: #a40000;
  stroke-opacity: 1;
end
h.add_css '.connect.inactive', <<-end
  stroke: #a40000;
  stroke-opacity: 0.1;
end
h.add_css '.relation', <<-end
  fill:none;
  stroke-opacity: 0.5;
  stroke: #777676;
  stroke-width:1;
end
h.add_css '.relation.inactive', <<-end
  stroke-opacity: 0.2;
end
h.add_css '.relation.role', <<-end
  stroke-opacity: 1;
  stroke: #5c3566;
end
h.add_css '.relation.unit', <<-end
  stroke-opacity: 1;
  stroke: #204a87;
end
h.add_css '.unit .subjecticon', <<-end
  fill:#ffffff;
  stroke: #204a87;
  stroke-width:1;
end
h.add_css '.role .subjecticon', <<-end
  fill:#ffffff;
  stroke: #5c3566;
  stroke-width:1;
end
h.add_css '.subject .subjecticon', <<-end
  fill:#ffffff;
  stroke: #000000;
  stroke-width:1;
end
h.add_css '.subjecticon.subjecthighlight', <<-end
  stroke: #a40000;
end
h.add_css '.subjecticon.highlight', <<-end
  stroke: #a40000;
end
h.add_css '.subjecticon.number', <<-end
  font-size:5px;
  font-style:normal;
  font-variant:normal;
  font-weight:normal;
  font-stretch:normal;
  line-height:100%;
  letter-spacing:0px;
  word-spacing:0px;
  writing-mode:lr-tb;
  text-anchor:start;
  fill:#000000;
  fill-opacity:1;
  stroke:none;
  font-family:Arial;
end
h.add_css '.subjecticon.number tspan', <<-end
  text-anchor:middle;
  text-align:center;
end
h.add_css '.subjecticon.number .inactive', <<-end
  visibility:hidden;
end
h.add_css '.plainwhite', <<-end
  fill: #ffffff;
  stroke: none;
end
h.add_css '.activefilter', <<-end
  fill: #a40000;
end

s = SVG.new

orbits = []
oid = 0
gw.nodes.each do |n|
  n.parents.each do |p|
    if n.type == :unit
      i1, i2 = [n.y, p.y].sort{|a,b|b<=>a}
    elsif n.type == :role
      i1, i2 = [n.y, p.y].sort{|a,b|b<=>a}
    end
    orb = (gw.nodes.index(p) > gw.nodes.index(n) ? gw.nodes.index(p) - gw.nodes.index(n) : gw.nodes.index(n) - gw.nodes.index(p))
    oid = oid+1
    orbits << [orb,i1,i2,"#{n.type} connect",n.type,nil,oid,p.shortid,n.shortid]
  end
end
orbits = orbits.sort{|a,b|a[0]<=>b[0]}

locount = rocount  = 1
orbits.each do |o|
  if o[0] == 1 
    o[5] = xgap
  elsif o[0] != 1 && o[4] == :unit
    locount += 1
    o[5] = locount*xgap
  elsif o[0] != 1 && o[4] == :role
    rocount += 1
    o[5] = rocount*xgap
  end
end
posx[:unit] = xgap + locount * xgap + bogerl
posx[:role] = xgap + locount * xgap + bogerl + maxtextunitwidth + connectgap + maxtextrolewidth

orbits.each do |o|
  orbitid = 'o' + o[6].to_s
  orbitrelation = 'f'+ o[7].to_s + ' t'+ o[8].to_s
  s.add_rectorbit(posx[o[4]],o[1],posx[o[4]],o[2],o[5],lineheight,o[4] == :unit ? :left : :right,bogerl, :class=> o[3] + ' ' + orbitrelation, :id => orbitid)
end
posx[:role] = posx[:role] - maxtextrolewidth

subjectintensity = {}
maxsubjectintensity = 0
subjects = []
gw.subjects.sort_by{|u| u.shortid}.each do |u|
  subjects << h.add_tag('table', :id => u.id, :class=>'subject', :onmouseover=>'s_relationstoggle(this)', :onmouseout=>'s_relationstoggle(this)') do
    h.add_tag 'tbody' do
      h.add_tag 'tr' do
        h.add_tag 'td' do
          subjectheadradius = 2.0
          si = SVG.new
          si.add_subject_icon(4,1,'subjecticon',subjectheadradius)
          si.dump(8,12)
        end
        h.add_tag 'td', :class => 'labeltext' do
          u.shortid
        end
      end  
    end  
  end

  u.relations.each do |r|
    x1 = posx[:unit] + maxtextunitwidth
    y1 = r.unit.y + 0.5*lineheight
    x2 = posx[:role]
    y2 = r.role.y + 0.5*lineheight
    subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"] ||= [0,[r.unit.shortid,r.role.shortid],x1,y1,x2,y2]
    subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"][0] += 1
    subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"][1] << u.id
    maxsubjectintensity = subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"][0] if subjectintensity["#{r.unit.shortid}--#{r.role.shortid}"][0] > maxsubjectintensity
  end
end
subjectintensity.each do |key,ui|
  opacity = 2.9 / maxsubjectintensity * ui[0] + 0.5
  bpointx = (ui[2]+ui[4])*0.5

  s.add_path("M #{ui[2]} #{ui[3]} H #{ui[2]+10} C #{bpointx+10} #{ui[3]} #{bpointx-10} #{ui[5]} #{ui[4]-10} #{ui[5]} H #{ui[4]} ", :class => "relation #{ui[1].join(' ')}")
  #s.add_path("M #{ui[2]} #{ui[3]} L #{ui[4]} #{ui[5]}", :class => "relation #{ui[1].join(' ')}")
  h.add_css ".relation.#{ui[1].join('.')}", <<-end
    stroke-width: #{opacity};
  end
  ### insert this late to overide the dynamically created classes for the relations
  h.add_css ".relation.highlight.#{ui[1].join('.')}", <<-end
    stroke-opacity:1;
    stroke-width:1;
    stroke: #a40000;
  end
end

gw.nodes.each do |n|
  n.x = posx[n.type]
  textposy = n.y + lineheight - textgap / 2 - lineheight * 0.2
  s.add_group(n.shortid,:class=>n.type,:onmouseover=>'ur_relationstoggle(this)',:onmouseout=>'ur_relationstoggle(this)',:onclick=>'ur_filtertoggle(this)') do
    twidth = n.type == :unit ? maxtextunitwidth : maxtextrolewidth
    ### weisses 4eck damit wenn die maus im zwischenraum zwischen den nodes, die relations nicht flackern
    s.add_rectangle(n.x,n.y-ygap/2,1,twidth,lineheight+ygap,'plainwhite')
    s.add_rectangle(n.x,n.y,n.opacity,twidth,lineheight,n.type)
    maxheight = n.y + lineheight + ygap if maxheight < n.y + lineheight + ygap
    tgap = textgap
    if n.type == :unit
      s.add_subject(n.x+twidth,n.y,n.numsubjects,'subjecticon','number','normal','special inactive')
    elsif n.type == :role
      s.add_subject(n.x,n.y,n.numsubjects,'subjecticon','number','normal','special inactive')
      tgap = textgap + subjectsymbolwidth
    end
    s.add_text n.x + tgap, textposy, :cls => 'btext' do
      n.id
    end
    s.add_text n.x + tgap, textposy,:cls => 'labeltext', :id => n.shortid + '_text' do
      n.id
    end
  end  
end
maxwidth = posx[:role]+maxtextrolewidth+rocount*xgap+bogerl+usergap

c = h.add_tag 'div', :class => "tabbed rest" do
  h.add_tag 'table', :class => "tabbar" do
    h.add_tag 'tbody' do
      h.add_tag 'tr' do
        h.add_tag 'td', :class => 'tabbefore'
        h.add_tag 'td', :class => 'tab', :id => 'tabgraph' do
          h.add_tag('h1'){ 'OrbitList' }
        end
        h.add_tag 'td', :class => 'tabbehind'
      end
    end
  end
  h.add_tag 'table', :class => "tabbelow columns" do
    h.add_tag 'tbody' do
      h.add_tag 'tr' do
        h.add_tag 'td', :id => 'graphcolumn' do
          h.add_tag 'div', :class => 'column' do
            s.dump(maxwidth,maxheight)
          end
        end
        h.add_tag 'td', :id => 'usercolumn', :class => 'ui-resizable' do
          h.add_tag 'span', :id => "handle2", :class => "ui-resizable-handle ui-resizable-w" do
            "drag to resize"
          end
          h.add_tag 'div', :class => 'column' do
            subjects.join("\n");
          end
        end
      end
    end
  end
end  

h.add c
File.open(oname,'w'){|f|f.write h.dump}
