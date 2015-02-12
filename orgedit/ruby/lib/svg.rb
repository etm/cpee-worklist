require "prawn"
$pdoc = Prawn::Document.new
$pdoc.font('Helvetica',:style => :bold)
$pdoc.font_size = 10

class SVG
  def initialize
    @res = ''
    @defs = ''
    @svg = File.read(File.expand_path(File.dirname(__FILE__) + '/svg.template'))
  end

  def dump(h=100,w=100)
    (@svg % [h,w,@defs,@res]).gsub(/\n+/,"\n")
  end  

  def add_group(nid,options={})
    opts = options.map{ |name,value| "#{name}=\"#{value}\"" }.join(' ')
    @res << "<g id='#{nid}'#{opts == '' ? '' : " #{opts}"}>\n"
    yield.to_s.strip
    @res << "</g>\n"
  end

  def add_path(d,options={})
    opts = options.map{ |name,value| "#{name}=\"#{value}\"" }.join(' ')
    @res << "  <path d=\"#{d.is_a?(Array) ? d.join(' ') : d}\"#{opts == '' ? '' : " #{opts}"}/>\n"
  end
  def add_circle(cx,cy,radius,cls=nil)
    @res << "  <circle class='#{cls}' cx=\"#{cx}\" cy=\"#{cy}\" r=\"#{radius}\"/>\n"
  end
  def add_rectangle(lx,ly,opacity,lwidth,lheight, cls=nil)
     @res << "  <rect class='#{cls}' fill-opacity='#{opacity}' x=\"#{lx}\" y=\"#{ly}\" width=\"#{lwidth}\" height=\"#{lheight}\"/>\n"
  end
  def add_radialGradient(id, cls1=nil,cls2=nil)
     @defs<< "  <radialGradient id=\"#{id}\" cx=\"50%\" cy=\"50%\" r=\"70%\" fx=\"70%\" fy=\"30%\">\n    <stop offset=\"0%\" stop-color=\"#{cls1}\" stop-opacity=\"1\"/>\n    <stop offset=\"100%\" stop-color=\"#{cls2}\" stop-opacity=\"1\"/>\n  </radialGradient>\n"
  end
  def add_text(x,y,options={})
    options[:cls] ||= nil
    options[:transform] ||= nil
    opts = []
    opts << (options[:transform] ? "transform='#{options[:transform]}'" : nil)
    opts << (options[:cls] ? "class='#{options[:cls]}'" : nil)
    opts << "id=\"#{options[:id]}\"" if options[:id]
    opts.compact!
    @res << "  <text x='#{x}' y='#{y}' #{opts.join(" ")}>"
    @res << yield.to_s.strip
    @res << "</text>\n"
  end
  def add_tspan(options=[])
    options[:x] ||= nil
    options[:y] ||= nil
    options[:dx] ||= nil
    options[:dy] ||= nil
    options[:cls] ||= nil
    options[:transform] ||= nil
    opts = []
    opts << (options[:transform] ? "transform='#{options[:transform]}'" : nil)
    opts << (options[:cls] ? "class='#{options[:cls]}'" : nil)
    opts << (options[:dx] ? "dx='#{options[:dx]}'" : nil)
    opts << (options[:dy] ? "dy='#{options[:dy]}'" : nil)
    opts << (options[:x] ? "x='#{options[:x]}'" : nil)
    opts << (options[:y] ? "y='#{options[:y]}'" : nil)
    opts.compact!
    @res << "<tspan #{opts.join(" ")}>"
    @res << yield.to_s.strip
    @res << "</tspan>"
    ''
  end  

  def add_orbit(center_x,center_y,angle1,angle2,radius,oradius,options)
    x1,y1 = SVG::circle_point(center_x,center_y,radius,angle1)
    x2,y2 = SVG::circle_point(center_x,center_y,radius,angle2)

    bogerl = 10
    sect = (bogerl / (2.0 * (radius+oradius) * Math::PI)) * 360 
    #sect = 0

    ovx1,ovy1 = SVG::circle_point(center_x,center_y,radius+oradius-bogerl,angle1)
    obx1 = center_x + Math.cos(SVG::degrees_to_rad(angle1 - sect)) * (radius+oradius)
    oby1 = center_y - Math.sin(SVG::degrees_to_rad(angle1 - sect)) * (radius+oradius)

    ovx2,ovy2 = SVG::circle_point(center_x,center_y,radius+oradius-bogerl,angle2)
    obx2 = center_x + Math.cos(SVG::degrees_to_rad(angle2 + sect)) * (radius+oradius)
    oby2 = center_y - Math.sin(SVG::degrees_to_rad(angle2 + sect)) * (radius+oradius)

    if angle1 - angle2 > 180
      add_path("M #{x1} #{y1} L #{ovx1} #{ovy1} A #{bogerl} #{bogerl} 0 0 1 #{obx1} #{oby1} A #{radius+oradius} #{radius+oradius} 0 1 1 #{obx2} #{oby2} A #{bogerl} #{bogerl} 0 0 1 #{ovx2} #{ovy2} L #{x2} #{y2}",options)
    else  
      add_path("M #{x1} #{y1} L #{ovx1} #{ovy1} A #{bogerl} #{bogerl} 0 0 1 #{obx1} #{oby1} A #{radius+oradius} #{radius+oradius} 0 0 1 #{obx2} #{oby2} A #{bogerl} #{bogerl} 0 0 1 #{ovx2} #{ovy2} L #{x2} #{y2}",options)
    end  
  end
  
  def add_rectorbit(x1,y1,x2,y2,b,height,position,bogerl,options)
    if position == :left
      add_path("M #{x1} #{y1+(height/2)} h #{-b} a #{bogerl} #{bogerl} 0 0 1 #{-bogerl} #{-bogerl} V #{(y2+(height/2))+bogerl} a #{bogerl} #{bogerl} 0 0 1 #{bogerl}  #{-bogerl} h #{b} ",options)
    elsif position == :right
      add_path("M #{x1} #{y1+(height/2)} h #{b}  a #{bogerl} #{bogerl} 0 0 0 #{bogerl}  #{-bogerl} V #{(y2+(height/2))+bogerl} a #{bogerl} #{bogerl} 0 0 0 #{-bogerl} #{-bogerl} h #{-b}",options)
    end			
  end
  
  def add_subject(x,y,number,clsbody,clsnumber,clsnumbernormal,clsnumberspecial)
     subjectheadradius = 3
     add_subject_icon(x,y-subjectheadradius,clsbody,subjectheadradius)
     add_text(x, y+10,:cls => clsbody + ' ' + clsnumber) do
       add_tspan(:x => x,:y => y+10,:cls => clsnumbernormal) { number }
       add_tspan(:x => x,:y => y+10,:cls => clsnumberspecial) { '' }
     end
  end
  
  def add_subject_icon(x,y,cls,headradius)
     scale = headradius / 3
     bogerl = (11 + headradius) * scale
     y += headradius
     add_path("M #{x} #{y} L #{x+5*scale} #{y+11*scale} A #{bogerl} #{bogerl} 0 0 1 #{x-5*scale} #{y+11*scale} z",:class => cls)
     add_circle(x,y,headradius,cls)
     [x+5*scale,y+bogerl]
  end
  
  def self.width_of(str)
    $pdoc.width_of(str)
  end  
  def self.height_of(str)
    $pdoc.height_of(str)
  end  
  def self.circle_line_from(cx, cy, r, angle)
    ["M", cx, cy, "L"] + self::circle_point(cx, cy, r, angle)
  end
  def self.circle_point(cx, cy, r, angle)
    x1 = cx + r * Math.cos(self::degrees_to_rad(angle))
    y1 = cy - r * Math.sin(self::degrees_to_rad(angle))
    [x1, y1]
  end
  def self.degrees_to_rad(d)
    d * Math::PI / 180
  end 
end
